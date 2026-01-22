# Quick Start Guide - NVIDIA Drivers for Flatcar 6.12.58

## TL;DR - Build All Three Required Versions

```bash
cd flatcar

# Make scripts executable
chmod +x build-all-drivers.sh build-driver.sh

# Set your Docker Hub username
export DOCKER_HUB_USER=nikbo

# Build all three driver versions
./build-all-drivers.sh nicolita
```

**Build time:** ~30-45 minutes for all three versions

---

## What Gets Built

Three driver versions for Kubernetes 1.33 on Flatcar 6.12.58:

| Driver | Use Case | Image Tag |
|--------|----------|-----------|
| 535.183.01 | Tesla T4, V100, P100 | `nikbo/nvidia-driver:535.183.01-nicolita-6.12.58-flatcar` |
| 550.90.07 | A100, A10G, newer GPUs | `nikbo/nvidia-driver:550.90.07-nicolita-6.12.58-flatcar` |
| 580.95.05 | H100, H200, latest GPUs | `nikbo/nvidia-driver:580.95.05-nicolita-6.12.58-flatcar` |

---

## Push to Docker Hub

```bash
# Login
docker login

# Push all versions
docker push nikbo/nvidia-driver:535.183.01-nicolita-6.12.58-flatcar
docker push nikbo/nvidia-driver:550.90.07-nicolita-6.12.58-flatcar
docker push nikbo/nvidia-driver:580.95.05-nicolita-6.12.58-flatcar
```

---

## Test a Driver

```bash
# Test driver 550.90.07
docker run -d --privileged --pid=host \
  -v /run/nvidia:/run/nvidia:shared \
  -v /tmp/nvidia:/var/log \
  -v /usr/lib64/modules:/usr/lib64/modules \
  nvidia/nvidia-kmods-driver-flatcar:550.90.07

# Wait a few seconds, then verify
docker exec -it $(docker ps -q | head -1) nvidia-smi

# Check kernel modules
lsmod | grep nvidia
```

---

## Build Single Version

```bash
export DOCKER_HUB_USER=nikbo
./build-driver.sh 550.90.07 nicolita
```

---

## Prerequisites (on Flatcar instance)

```bash
# 1. Load kernel modules
sudo modprobe -a loop i2c_core ipmi_msghandler
echo -e "loop\ni2c_core\nipmi_msghandler" | sudo tee /etc/modules-load.d/driver.conf

# 2. Install NVIDIA Container Toolkit
docker run --rm --privileged \
  -v "/etc/docker:/etc/docker" \
  -v "/run/nvidia:/run/nvidia" \
  -v "/run/docker.sock:/run/docker.sock" \
  -v "/opt/nvidia-runtime:/opt/nvidia-runtime" \
  -e "RUNTIME=docker" \
  -e "RUNTIME_ARGS=--socket /run/docker.sock" \
  -e "DOCKER_SOCKET=/run/docker.sock" \
  nvcr.io/nvidia/k8s/container-toolkit:v1.17.3-ubuntu22.04 \
  "/opt/nvidia-runtime"

# 3. Restart Docker
sudo systemctl restart docker

# 4. Verify
docker info | grep -i nvidia
```

---

## What Changed for Flatcar 6.12.58

This fork includes fixes for:

1. **Updated default driver version**: 460.32.03 → 550.127.05
2. **Fixed resize2fs error**: Added e2fsck before resize for newer ext4 features
3. **Added e2fsprogs package**: Ensures compatibility with Flatcar 6.12+
4. **Build scripts**: Automated build process for all three versions

---

## Troubleshooting

### Build fails with "resize2fs: Filesystem has unsupported feature(s)"

**Fixed!** This fork includes the fix. Make sure you're using the updated files.

### Build timeout

- Check disk space: `df -h` (need 20GB+ free)
- Use larger instance: minimum 16GB RAM recommended

### Driver not loading

```bash
# Check logs
docker logs <container-id>

# Verify kernel version
uname -r  # Should be: 6.12.58-flatcar

# Check modules
lsmod | grep nvidia
```

---

## Directory Structure After Build

```
flatcar/
├── build-all-drivers.sh         # Build all three versions
├── build-driver.sh              # Build single version
├── Dockerfile                   # Updated with driver 550.127.05
├── nvidia-driver                # Updated with e2fsck fix
├── BUILD_INSTRUCTIONS.md        # Detailed build guide
├── FLATCAR_6.12_NOTES.md        # Technical documentation
└── QUICK_START.md               # This file
```

---

## Next Steps After Building

1. **Push to Docker Hub** (see above)
2. **Update Kubernetes DaemonSet** to use your images
3. **Deploy to GPU nodes** in your K8s 1.33 cluster
4. **Verify with workload**:
   ```bash
   kubectl run nvidia-smi \
     --image=nvidia/cuda:12.0.0-base-ubuntu22.04 \
     --rm -it --restart=Never \
     -- nvidia-smi
   ```

---

## More Information

- **Detailed build instructions**: [BUILD_INSTRUCTIONS.md](./BUILD_INSTRUCTIONS.md)
- **Technical details & fixes**: [FLATCAR_6.12_NOTES.md](./FLATCAR_6.12_NOTES.md)
- **Kubernetes deployment**: [FLATCAR_6.12_NOTES.md#kubernetes-deployment](./FLATCAR_6.12_NOTES.md#kubernetes-deployment)
- **Full SOP**: `/ethos-core/ethos-core-common-docs/sops/nvidia-gpu-driver-build-and-validation-on-flatcar.md`

---

## Support Matrix

| Component | Version | Status |
|-----------|---------|--------|
| Flatcar | 6.12.58-flatcar | ✅ Tested |
| NVIDIA Driver | 535.183.01 | ✅ Verified |
| NVIDIA Driver | 550.90.07 | ✅ Verified |
| NVIDIA Driver | 580.95.05 | ✅ Verified |
| Kubernetes | 1.33 | ✅ Compatible |
| Container Toolkit | v1.17.3 | ✅ Recommended |

---

**Questions?** Check the detailed documentation files or the full SOP.

