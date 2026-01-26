#!/bin/bash
#
# Build script for a single NVIDIA driver version on Flatcar 6.12.58
# Usage: ./build-driver.sh <driver_version> [username]
#
# Example: ./build-driver.sh 550.90.07 nikbo

set -e

# Configuration
DRIVER_VERSION="${1:-}"
USERNAME="${2:-}"
KERNEL_VERSION="6.12.58-flatcar"
DOCKER_REGISTRY="${DOCKER_REGISTRY:-}"  # Set to your registry

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validate input
if [ -z "${DRIVER_VERSION}" ]; then
    log_error "Usage: $0 <driver_version> [username]"
    echo ""
    echo "Example: $0 550.90.07 nicolita"
    echo ""
    echo "Supported versions for Flatcar 6.12.58:"
    echo "  - 535.183.01"
    echo "  - 550.90.07"
    echo "  - 580.95.05"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "Dockerfile" ] || [ ! -f "nvidia-driver" ]; then
    log_error "Please run this script from the flatcar/ directory"
    exit 1
fi

echo "=========================================="
echo "  NVIDIA Driver Builder"
echo "=========================================="
echo ""
log_info "Driver version: ${DRIVER_VERSION}"
log_info "Kernel version: ${KERNEL_VERSION}"
log_info "Username: ${USERNAME:-<none>}"
echo ""

# Step 1: Build the driver container
log_info "Step 1/3: Building driver container image..."
docker build --pull \
    --build-arg DRIVER_VERSION="${DRIVER_VERSION}" \
    --tag "nvidia/nvidia-driver-flatcar:${DRIVER_VERSION}" \
    --file Dockerfile . || {
    log_error "Failed to build driver ${DRIVER_VERSION}"
    exit 1
}
log_success "Built nvidia/nvidia-driver-flatcar:${DRIVER_VERSION}"

# Step 2: Precompile kernel modules
log_info "Step 2/3: Precompiling kernel modules for ${KERNEL_VERSION}..."

# Clean up any existing container
docker stop nvidia-driver 2>/dev/null || true
docker rm nvidia-driver 2>/dev/null || true

# Run the build container
docker run -d --privileged --pid=host \
    -v /run/nvidia:/run/nvidia:shared \
    -v /tmp/nvidia:/var/log \
    -v /usr/lib64/modules:/usr/lib64/modules \
    --name nvidia-driver \
    "nvidia/nvidia-driver-flatcar:${DRIVER_VERSION}" update || {
    log_error "Failed to start build container"
    exit 1
}

log_info "Building kernel modules (this may take several minutes)..."
log_info "Following build logs..."
echo ""

# Follow logs
docker logs -f nvidia-driver &
LOGS_PID=$!

# Wait for "Done" message or timeout
timeout 900 bash -c 'while ! docker logs nvidia-driver 2>&1 | grep -q "Done"; do sleep 2; done' || {
    kill $LOGS_PID 2>/dev/null || true
    log_error "Build timeout or failed"
    echo ""
    log_info "Last 50 lines of logs:"
    docker logs --tail 50 nvidia-driver
    exit 1
}

kill $LOGS_PID 2>/dev/null || true
echo ""
log_success "Kernel modules built successfully"

# Step 3: Commit the container
log_info "Step 3/3: Creating final driver image..."
docker commit \
    --change='ENTRYPOINT ["nvidia-driver", "init"]' \
    nvidia-driver \
    "nvidia/nvidia-kmods-driver-flatcar:${DRIVER_VERSION}" || {
    log_error "Failed to commit driver image"
    exit 1
}
log_success "Created nvidia/nvidia-kmods-driver-flatcar:${DRIVER_VERSION}"

# Clean up build container
docker stop nvidia-driver 2>/dev/null || true
docker rm nvidia-driver 2>/dev/null || true

# Tag for registry if username provided
if [ -n "${USERNAME}" ]; then
    TAG_NAME="${DRIVER_VERSION}-${USERNAME}-${KERNEL_VERSION}"
    
    if [ -n "${DOCKER_REGISTRY}" ]; then
        docker tag "nvidia/nvidia-kmods-driver-flatcar:${DRIVER_VERSION}" \
            "${DOCKER_REGISTRY}/nvidia-driver:${TAG_NAME}"
        log_success "Tagged as ${DOCKER_REGISTRY}/nvidia-driver:${TAG_NAME}"
    else
        docker tag "nvidia/nvidia-kmods-driver-flatcar:${DRIVER_VERSION}" \
            "${USERNAME}/nvidia-driver:${TAG_NAME}"
        log_success "Tagged as ${USERNAME}/nvidia-driver:${TAG_NAME}"
    fi
fi

echo ""
echo "=========================================="
echo "  Build Complete!"
echo "=========================================="
echo ""

log_info "Built image:"
docker images | grep "nvidia.*driver.*flatcar" | grep "${DRIVER_VERSION}"

echo ""
log_info "To test the driver:"
echo ""
echo "  docker run -d --privileged --pid=host \\"
echo "    -v /run/nvidia:/run/nvidia:shared \\"
echo "    -v /tmp/nvidia:/var/log \\"
echo "    -v /usr/lib64/modules:/usr/lib64/modules \\"
echo "    nvidia/nvidia-kmods-driver-flatcar:${DRIVER_VERSION}"
echo ""
echo "  docker exec -it \$(docker ps -q -f ancestor=nvidia/nvidia-kmods-driver-flatcar:${DRIVER_VERSION}) nvidia-smi"
echo ""

if [ -n "${USERNAME}" ]; then
    log_info "To push to registry:"
    echo ""
    TAG_NAME="${DRIVER_VERSION}-${USERNAME}-${KERNEL_VERSION}"
    if [ -n "${DOCKER_REGISTRY}" ]; then
        echo "  docker push ${DOCKER_REGISTRY}/nvidia-driver:${TAG_NAME}"
    else
        echo "  docker push ${USERNAME}/nvidia-driver:${TAG_NAME}"
    fi
    echo ""
fi

log_success "Done!"

