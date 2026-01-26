#!/bin/bash
#
# Test newer point releases of 535 and 550 branches
# These may have kernel 6.12 support built-in
#
# Usage: ./test-newer-releases.sh
#

set -e

KERNEL_VERSION="6.12.58-flatcar"
DOCKER_HUB_USER="${DOCKER_HUB_USER:-nikbo}"
WORK_ID="${1:-nicolita}"

# Latest releases to test (as of Jan 2026)
# Check https://www.nvidia.com/Download/Find.aspx for most recent
DRIVER_VERSIONS_TO_TEST=(
    "535.216.03"  # Latest LTS 535 branch
    "550.127.05"  # Latest Production 550 branch
    "550.135"     # Even newer 550 if available
)

echo "=============================================="
echo "  Testing Newer NVIDIA Driver Releases"
echo "=============================================="
echo ""
echo "[INFO] Kernel: ${KERNEL_VERSION}"
echo "[INFO] Docker Hub User: ${DOCKER_HUB_USER}"
echo "[INFO] Work ID: ${WORK_ID}"
echo "[INFO] Versions to test: ${DRIVER_VERSIONS_TO_TEST[*]}"
echo ""
echo "NOTE: These newer point releases may have kernel 6.12"
echo "      support built-in, avoiding the need for patches."
echo ""

SUCCESS_VERSIONS=()
FAILED_VERSIONS=()

for DRIVER_VERSION in "${DRIVER_VERSIONS_TO_TEST[@]}"; do
    echo ""
    echo "=============================================="
    echo "[TEST] Driver ${DRIVER_VERSION}"
    echo "=============================================="
    echo ""
    
    # Check if driver exists by trying to download the run file
    DRIVER_URL="https://download.nvidia.com/XFree86/Linux-x86_64/${DRIVER_VERSION}/NVIDIA-Linux-x86_64-${DRIVER_VERSION}.run"
    
    echo "[INFO] Checking if driver ${DRIVER_VERSION} exists..."
    if ! curl --head --silent --fail "${DRIVER_URL}" > /dev/null 2>&1; then
        echo "[SKIP] Driver ${DRIVER_VERSION} not found at NVIDIA download servers"
        echo "       URL: ${DRIVER_URL}"
        FAILED_VERSIONS+=("${DRIVER_VERSION} (not found)")
        continue
    fi
    
    echo "[INFO] Driver ${DRIVER_VERSION} exists! Proceeding with build..."
    echo ""
    
    # Build using our existing build-driver.sh script
    if ./build-driver.sh "${DRIVER_VERSION}" "${KERNEL_VERSION}" "${DOCKER_HUB_USER}" "${WORK_ID}"; then
        echo ""
        echo "[SUCCESS] ✅ Driver ${DRIVER_VERSION} built successfully!"
        SUCCESS_VERSIONS+=("${DRIVER_VERSION}")
    else
        echo ""
        echo "[FAILED] ❌ Driver ${DRIVER_VERSION} failed to build"
        FAILED_VERSIONS+=("${DRIVER_VERSION}")
        echo ""
        echo "[INFO] Continuing with next version..."
    fi
    
    echo ""
done

echo ""
echo "=============================================="
echo "  Test Summary"
echo "=============================================="
echo ""

if [ ${#SUCCESS_VERSIONS[@]} -gt 0 ]; then
    echo "✅ SUCCESSFUL BUILDS:"
    for version in "${SUCCESS_VERSIONS[@]}"; do
        echo "   - ${version}"
        echo "     Image: ${DOCKER_HUB_USER}/nvidia-driver:${version}-${WORK_ID}-${KERNEL_VERSION}"
    done
    echo ""
fi

if [ ${#FAILED_VERSIONS[@]} -gt 0 ]; then
    echo "❌ FAILED BUILDS:"
    for version in "${FAILED_VERSIONS[@]}"; do
        echo "   - ${version}"
    done
    echo ""
fi

echo "=============================================="
echo ""

if [ ${#SUCCESS_VERSIONS[@]} -eq 0 ]; then
    echo "[CONCLUSION] None of the newer releases worked."
    echo ""
    echo "Next steps:"
    echo "1. Review DRIVER_535_550_SOLUTION_STRATEGY.md"
    echo "2. Try Approach 2: Apply DRM compatibility patch"
    echo "3. Check build logs for specific errors"
    echo ""
    exit 1
else
    echo "[CONCLUSION] ✅ Found ${#SUCCESS_VERSIONS[@]} working driver version(s)!"
    echo ""
    echo "Next steps:"
    echo "1. Test the driver(s) with nvidia-smi"
    echo "2. Push to Docker Hub (if not auto-pushed)"
    echo "3. Update documentation with successful versions"
    echo ""
    
    if [ ${#SUCCESS_VERSIONS[@]} -eq ${#DRIVER_VERSIONS_TO_TEST[@]} ]; then
        echo "🎉 All tested versions worked! You're all set!"
    else
        echo "Note: Some versions failed. See strategy doc for"
        echo "      patching approaches if those versions are critical."
    fi
    echo ""
    exit 0
fi

