#!/bin/bash
set -euo pipefail

# Test script for building and validating NVIDIA drivers 535.183.01 and 550.90.07
# with kernel compatibility patches for Flatcar 6.12.58

FLATCAR_KERNEL_VERSION="6.12.58-flatcar"
DOCKER_HUB_USER="${DOCKER_HUB_USER:-nikbo}"
WORK_ID="${1:-nicolita}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================="
echo "  NVIDIA Driver 535/550 Patch Testing"
echo "========================================="
echo ""
echo "[INFO] Testing patched drivers for Flatcar ${FLATCAR_KERNEL_VERSION}"
echo "[INFO] Work ID: ${WORK_ID}"
echo "[INFO] Docker Hub user: ${DOCKER_HUB_USER}"
echo ""

# Test 535.183.01
echo "=========================================="
echo "[TEST 1/2] Building driver 535.183.01 with patches"
echo "=========================================="

"${SCRIPT_DIR}/build-driver.sh" "535.183.01" "${FLATCAR_KERNEL_VERSION}" "${DOCKER_HUB_USER}" "${WORK_ID}"

if [ $? -eq 0 ]; then
    echo "[SUCCESS] Driver 535.183.01 built successfully!"
else
    echo "[FAILED] Driver 535.183.01 build failed"
    exit 1
fi

echo ""

# Test 550.90.07
echo "=========================================="
echo "[TEST 2/2] Building driver 550.90.07 with patches"
echo "=========================================="

"${SCRIPT_DIR}/build-driver.sh" "550.90.07" "${FLATCAR_KERNEL_VERSION}" "${DOCKER_HUB_USER}" "${WORK_ID}"

if [ $? -eq 0 ]; then
    echo "[SUCCESS] Driver 550.90.07 built successfully!"
else
    echo "[FAILED] Driver 550.90.07 build failed"
    exit 1
fi

echo ""
echo "=========================================="
echo "[SUCCESS] All patched drivers built successfully!"
echo "=========================================="
echo ""
echo "Built images:"
echo "  - ${DOCKER_HUB_USER}/nvidia-driver:535.183.01-${WORK_ID}-${FLATCAR_KERNEL_VERSION}"
echo "  - ${DOCKER_HUB_USER}/nvidia-driver:550.90.07-${WORK_ID}-${FLATCAR_KERNEL_VERSION}"
echo ""
echo "Next steps:"
echo "1. Log in to Docker Hub: docker login"
echo "2. Push images:"
echo "   docker push ${DOCKER_HUB_USER}/nvidia-driver:535.183.01-${WORK_ID}-${FLATCAR_KERNEL_VERSION}"
echo "   docker push ${DOCKER_HUB_USER}/nvidia-driver:550.90.07-${WORK_ID}-${FLATCAR_KERNEL_VERSION}"
echo "3. Test driver initialization on GPU nodes"
echo ""

