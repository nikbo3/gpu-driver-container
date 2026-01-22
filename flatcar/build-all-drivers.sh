#!/bin/bash
#
# Build script for multiple NVIDIA driver versions on Flatcar 6.12.58
# Usage: ./build-all-drivers.sh [work_id]
#
# Example: ./build-all-drivers.sh nicolita
#
# This script builds driver containers for all required driver versions
# and optionally tags them for pushing to a registry.
#
# Note: For Docker Hub, set DOCKER_HUB_USER environment variable:
#   export DOCKER_HUB_USER=nikbo
#   ./build-all-drivers.sh nicolita
#
# This will create tags like: nikbo/nvidia-driver:535.183.01-nicolita-6.12.58-flatcar
# (Docker Hub user 'nikbo' with work ID 'nicolita' in the version tag)

set -e

# Configuration
DRIVER_VERSIONS=("535.183.01" "550.90.07" "580.95.05")
KERNEL_VERSION="6.12.58-flatcar"
DOCKER_REGISTRY="${DOCKER_REGISTRY:-}"  # Set to your registry, e.g., "ethosk8sinfrastructure.azurecr.io"
DOCKER_HUB_USER="${DOCKER_HUB_USER:-}"  # Docker Hub username (e.g., nikbo)
WORK_ID="${1:-}"  # Work identifier for tagging (e.g., nicolita)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "Dockerfile" ] || [ ! -f "nvidia-driver" ]; then
    log_error "Please run this script from the flatcar/ directory"
    exit 1
fi

# Print banner
echo "=========================================="
echo "  NVIDIA Driver Multi-Version Builder"
echo "=========================================="
echo ""
log_info "Building drivers for Flatcar ${KERNEL_VERSION}"
log_info "Driver versions: ${DRIVER_VERSIONS[*]}"
[ -n "${WORK_ID}" ] && log_info "Work ID: ${WORK_ID}"
[ -n "${DOCKER_HUB_USER}" ] && log_info "Docker Hub user: ${DOCKER_HUB_USER}"
[ -n "${DOCKER_REGISTRY}" ] && log_info "Custom registry: ${DOCKER_REGISTRY}"
echo ""

# Build each driver version
for DRIVER_VERSION in "${DRIVER_VERSIONS[@]}"; do
    echo ""
    echo "=========================================="
    log_info "Building driver version ${DRIVER_VERSION}"
    echo "=========================================="
    echo ""
    
    # Build the initial driver container
    log_info "Step 1/3: Building driver container image..."
    docker build --pull \
        --build-arg DRIVER_VERSION="${DRIVER_VERSION}" \
        --tag "nvidia/nvidia-driver-flatcar:${DRIVER_VERSION}" \
        --file Dockerfile . || {
        log_error "Failed to build driver ${DRIVER_VERSION}"
        continue
    }
    log_success "Built nvidia/nvidia-driver-flatcar:${DRIVER_VERSION}"
    
    # Run the container to precompile kernel modules
    log_info "Step 2/3: Precompiling kernel modules for ${KERNEL_VERSION}..."
    
    # Clean up any existing container
    docker stop nvidia-driver-build-${DRIVER_VERSION} 2>/dev/null || true
    docker rm nvidia-driver-build-${DRIVER_VERSION} 2>/dev/null || true
    
    # Run the build container
    docker run -d --privileged --pid=host \
        -v /run/nvidia:/run/nvidia:shared \
        -v /tmp/nvidia:/var/log \
        -v /usr/lib64/modules:/usr/lib64/modules \
        --name "nvidia-driver-build-${DRIVER_VERSION}" \
        "nvidia/nvidia-driver-flatcar:${DRIVER_VERSION}" update || {
        log_error "Failed to start build container for driver ${DRIVER_VERSION}"
        continue
    }
    
    # Wait for build to complete
    log_info "Building kernel modules (this may take several minutes)..."
    log_info "Watching logs for completion..."
    
    # Follow logs until we see "Done" or timeout after 15 minutes
    timeout 900 bash -c "docker logs -f nvidia-driver-build-${DRIVER_VERSION} 2>&1 | grep -q 'Done'" || {
        log_error "Build timeout or failed for driver ${DRIVER_VERSION}"
        docker logs --tail 50 "nvidia-driver-build-${DRIVER_VERSION}"
        docker stop "nvidia-driver-build-${DRIVER_VERSION}" 2>/dev/null || true
        docker rm "nvidia-driver-build-${DRIVER_VERSION}" 2>/dev/null || true
        continue
    }
    
    log_success "Kernel modules built successfully"
    
    # Commit the container with new entrypoint
    log_info "Step 3/3: Creating final driver image..."
    docker commit \
        --change='ENTRYPOINT ["nvidia-driver", "init"]' \
        "nvidia-driver-build-${DRIVER_VERSION}" \
        "nvidia/nvidia-kmods-driver-flatcar:${DRIVER_VERSION}" || {
        log_error "Failed to commit driver ${DRIVER_VERSION}"
        continue
    }
    log_success "Created nvidia/nvidia-kmods-driver-flatcar:${DRIVER_VERSION}"
    
    # Clean up build container
    docker stop "nvidia-driver-build-${DRIVER_VERSION}" 2>/dev/null || true
    docker rm "nvidia-driver-build-${DRIVER_VERSION}" 2>/dev/null || true
    
    # Tag for registry if work ID provided
    if [ -n "${WORK_ID}" ]; then
        TAG_NAME="${DRIVER_VERSION}-${WORK_ID}-${KERNEL_VERSION}"
        
        if [ -n "${DOCKER_REGISTRY}" ]; then
            # Tag for custom registry (e.g., Azure ACR)
            docker tag "nvidia/nvidia-kmods-driver-flatcar:${DRIVER_VERSION}" \
                "${DOCKER_REGISTRY}/nvidia-driver:${TAG_NAME}"
            log_success "Tagged as ${DOCKER_REGISTRY}/nvidia-driver:${TAG_NAME}"
        elif [ -n "${DOCKER_HUB_USER}" ]; then
            # Tag for Docker Hub with specific username
            docker tag "nvidia/nvidia-kmods-driver-flatcar:${DRIVER_VERSION}" \
                "${DOCKER_HUB_USER}/nvidia-driver:${TAG_NAME}"
            log_success "Tagged as ${DOCKER_HUB_USER}/nvidia-driver:${TAG_NAME}"
        else
            # Tag for Docker Hub using work ID as username (fallback)
            docker tag "nvidia/nvidia-kmods-driver-flatcar:${DRIVER_VERSION}" \
                "${WORK_ID}/nvidia-driver:${TAG_NAME}"
            log_success "Tagged as ${WORK_ID}/nvidia-driver:${TAG_NAME}"
        fi
    fi
    
    log_success "✓ Driver ${DRIVER_VERSION} build complete!"
done

# Summary
echo ""
echo "=========================================="
echo "  Build Summary"
echo "=========================================="
echo ""

log_info "Built images:"
docker images | grep -E "nvidia.*driver.*flatcar" | grep -E "($(IFS='|'; echo "${DRIVER_VERSIONS[*]}"))"

echo ""
echo "=========================================="
echo "  Next Steps"
echo "=========================================="
echo ""

if [ -n "${WORK_ID}" ]; then
    log_info "To push images to registry:"
    echo ""
    for DRIVER_VERSION in "${DRIVER_VERSIONS[@]}"; do
        TAG_NAME="${DRIVER_VERSION}-${WORK_ID}-${KERNEL_VERSION}"
        if [ -n "${DOCKER_REGISTRY}" ]; then
            echo "  docker push ${DOCKER_REGISTRY}/nvidia-driver:${TAG_NAME}"
        elif [ -n "${DOCKER_HUB_USER}" ]; then
            echo "  docker push ${DOCKER_HUB_USER}/nvidia-driver:${TAG_NAME}"
        else
            echo "  docker push ${WORK_ID}/nvidia-driver:${TAG_NAME}"
        fi
    done
    echo ""
fi

log_info "To test a driver (example with ${DRIVER_VERSIONS[0]}):"
echo ""
echo "  docker run -d --privileged --pid=host \\"
echo "    -v /run/nvidia:/run/nvidia:shared \\"
echo "    -v /tmp/nvidia:/var/log \\"
echo "    -v /usr/lib64/modules:/usr/lib64/modules \\"
echo "    nvidia/nvidia-kmods-driver-flatcar:${DRIVER_VERSIONS[0]}"
echo ""
echo "  docker exec -it \$(docker ps -q -f ancestor=nvidia/nvidia-kmods-driver-flatcar:${DRIVER_VERSIONS[0]}) nvidia-smi"
echo ""

log_success "All builds complete!"

