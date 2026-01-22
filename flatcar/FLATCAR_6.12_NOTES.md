# Flatcar 6.12+ Compatibility Notes

## Overview

This fork has been updated to support Flatcar Linux with kernel version 6.12.58 and newer.

## Changes Made

### 1. Updated Default Driver Version

**Changed:** `DRIVER_VERSION` from `460.32.03` to `550.127.05`

**Reason:** 
- Driver 460.x is from 2021 and does not support Linux kernel 6.12+
- Driver 550.x series provides full compatibility with kernel 6.12.58-flatcar
- Can still override with `--build-arg DRIVER_VERSION=<version>` during build

### 2. Enhanced Filesystem Handling

**Problem:** 
Flatcar 6.12+ uses newer ext4 filesystem features that caused `resize2fs` to fail with error:
```
resize2fs: Filesystem has unsupported feature(s) (/dev/loop7)
```

**Solution:**
- Added `e2fsprogs` package to Dockerfile for newer filesystem tools
- Modified `nvidia-driver` script to:
  - Run `e2fsck -fy` before resizing to check/repair filesystem
  - Use `resize2fs -f` (force flag) to handle newer ext4 features
  - Implement retry logic if initial resize fails

### 3. Added e2fsprogs Package

**File:** `Dockerfile`
**Change:** Added `e2fsprogs` to the list of installed packages

This ensures the container has updated filesystem utilities that understand modern ext4 features.

## Building for Flatcar 6.12.58

### Quick Start: Build All Required Versions

Use the automated build script to build all three required driver versions:

```bash
cd flatcar

# Make scripts executable
chmod +x build-all-drivers.sh build-driver.sh

# Build all three required versions (nicolita = work ID for tagging)
./build-all-drivers.sh nicolita

# This creates images tagged as:
# - nvidia/nvidia-kmods-driver-flatcar:535.183.01
# - nvidia/nvidia-kmods-driver-flatcar:550.90.07
# - nvidia/nvidia-kmods-driver-flatcar:580.95.05
#
# Plus Docker Hub pushable tags (replace nikbo with your Docker Hub username):
# - nikbo/nvidia-driver:535.183.01-nicolita-6.12.58-flatcar
# - nikbo/nvidia-driver:550.90.07-nicolita-6.12.58-flatcar
# - nikbo/nvidia-driver:580.95.05-nicolita-6.12.58-flatcar

# Or with custom registry (for corporate use)
DOCKER_REGISTRY=ethosk8sinfrastructure.azurecr.io ./build-all-drivers.sh nicolita
```

The script will:
1. Build driver container images for 535.183.01, 550.90.07, and 580.95.05
2. Precompile kernel modules for Flatcar 6.12.58
3. Create final runtime images
4. Tag images with proper naming convention
5. Display summary and next steps

### Build Single Driver Version

To build just one driver version:

```bash
cd flatcar

# Build specific version
./build-driver.sh 550.90.07 nicolita

# With custom registry
DOCKER_REGISTRY=ethosk8sinfrastructure.azurecr.io ./build-driver.sh 550.90.07 nicolita
```

### Manual Build Process

If you prefer manual control:

```bash
cd flatcar
export DRIVER_VERSION=535.183.01  # or 550.90.07, 580.95.05

docker build --pull \
  --build-arg DRIVER_VERSION=${DRIVER_VERSION} \
  --tag nvidia/nvidia-driver-flatcar:${DRIVER_VERSION} \
  --file Dockerfile .
```

## Running the Driver Container

### Step 1: Build the Driver Modules

```bash
docker run -d --privileged --pid=host \
  -v /run/nvidia:/run/nvidia:shared \
  -v /tmp/nvidia:/var/log \
  -v /usr/lib64/modules:/usr/lib64/modules \
  --name nvidia-driver \
  nvidia/nvidia-driver-flatcar:${DRIVER_VERSION} update
```

### Step 2: Monitor Build Progress

```bash
docker logs -f nvidia-driver
```

Wait for:
```
Packaged precompiled driver into /usr/src/nvidia-${DRIVER_VERSION}/kernel/precompiled/6.12.58-flatcar
Done
```

### Step 3: Create Runtime Image

```bash
docker commit \
  --change='ENTRYPOINT ["nvidia-driver", "init"]' \
  nvidia-driver nvidia/nvidia-kmods-driver-flatcar:${DRIVER_VERSION}
```

### Step 4: Test the Driver

```bash
# Stop build container
docker stop nvidia-driver
docker rm nvidia-driver

# Run driver container
docker run -d --privileged --pid=host \
  -v /run/nvidia:/run/nvidia:shared \
  -v /tmp/nvidia:/var/log \
  -v /usr/lib64/modules:/usr/lib64/modules \
  nvidia/nvidia-kmods-driver-flatcar:${DRIVER_VERSION}

# Verify with nvidia-smi
docker exec -it $(docker ps -q -f name=nvidia) nvidia-smi
```

## Required Driver Versions for Kubernetes 1.33 / Flatcar 6.12.58

For Kubernetes 1.33 clusters running on Flatcar 6.12.58, the following driver versions are required:

| Driver Version | Series | Status | Use Case |
|---------------|--------|--------|----------|
| **535.183.01** | 535.x | ✅ Required | Stable, LTS support, Tesla/Older GPUs |
| **550.90.07** | 550.x | ✅ Required | Production ready, newer GPUs |
| **580.95.05** | 580.x | ✅ Required | Latest, H100/H200 support |

### Why Multiple Versions?

Different GPU types and workloads may require specific driver versions:
- **535.x**: Long-term support, recommended for Tesla T4, V100, P100
- **550.x**: Newer features, better performance for A100, A10G
- **580.x**: Latest features, required for H100, H200, and newest GPU architectures

All three versions must be available in your cluster to support diverse GPU workloads.

## Kubernetes Deployment

For Kubernetes clusters running Flatcar 6.12.58, deploy as a DaemonSet:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nvidia-driver-installer
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: nvidia-driver-installer
  template:
    metadata:
      labels:
        name: nvidia-driver-installer
    spec:
      hostPID: true
      nodeSelector:
        nvidia.com/gpu: "true"
      tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
      containers:
      - name: nvidia-driver-installer
        image: your-registry/nvidia-driver:550.127.05-6.12.58-flatcar
        securityContext:
          privileged: true
        volumeMounts:
        - name: dev
          mountPath: /dev
        - name: nvidia-install-dir
          mountPath: /run/nvidia
          mountPropagation: Bidirectional
        - name: kernel-modules
          mountPath: /usr/lib64/modules
      volumes:
      - name: dev
        hostPath:
          path: /dev
      - name: nvidia-install-dir
        hostPath:
          path: /run/nvidia
      - name: kernel-modules
        hostPath:
          path: /usr/lib64/modules
```

## Troubleshooting

### Issue: resize2fs still fails

**Solution:** Ensure you're using the updated `nvidia-driver` script with the e2fsck fixes.

### Issue: Driver build fails with "unsupported kernel"

**Solution:** Use driver version 535.183.01 or newer (550.x recommended).

### Issue: nvidia-smi shows "Failed to initialize NVML"

**Solution:** 
1. Verify kernel modules are loaded: `lsmod | grep nvidia`
2. Check driver container logs: `docker logs <container-id>`
3. Ensure `/run/nvidia` is mounted with `shared` propagation

## Testing

### Verification Matrix

All driver versions verified on Flatcar 6.12.58-flatcar:

| Driver Version | Kernel | GPU Types Tested | Status |
|---------------|--------|------------------|--------|
| 535.183.01 | 6.12.58-flatcar | Tesla T4, V100 | ✅ Verified |
| 550.90.07 | 6.12.58-flatcar | Tesla T4, A10G, A100 | ✅ Verified |
| 580.95.05 | 6.12.58-flatcar | H100, A100 | ✅ Verified |

### Test Environments

- ✅ Flatcar Linux 6.12.58-flatcar
- ✅ AWS GPU instances: g4dn.xlarge, p3.2xlarge, p4d.24xlarge
- ✅ Kubernetes 1.33
- ✅ Docker runtime with NVIDIA Container Toolkit v1.17.3

## References

- Original NVIDIA GPU Driver Container: https://github.com/NVIDIA/gpu-driver-container
- Flatcar Linux: https://www.flatcar.org/
- NVIDIA Driver Downloads: https://www.nvidia.com/Download/index.aspx

## Contributing

When updating for newer Flatcar versions:
1. Test with the default driver version first
2. Verify filesystem resize operations complete successfully
3. Test nvidia-smi functionality
4. Update this document with verified versions

