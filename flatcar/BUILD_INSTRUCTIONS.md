# Building NVIDIA Drivers for Flatcar 6.12.58

## Quick Start

### Prerequisites

1. **Flatcar instance** running kernel 6.12.58-flatcar
2. **GPU instance type** (e.g., g4dn.xlarge, p3.2xlarge, p4d.24xlarge)
3. **Kernel modules loaded**:
   ```bash
   sudo modprobe -a loop i2c_core ipmi_msghandler
   ```
4. **NVIDIA Container Toolkit installed** (see main SOP)

### Build All Three Required Versions

```bash
cd flatcar
chmod +x build-all-drivers.sh

# Set your Docker Hub username (if different from work ID)
export DOCKER_HUB_USER=nikbo

# Build all versions (nicolita = work ID for tagging)
./build-all-drivers.sh nicolita
```

**Expected build time:** ~30-45 minutes for all three drivers

### What Gets Built

This will create the following images:

| Driver Version | Image Name | Tag |
|---------------|------------|-----|
| 535.183.01 | nvidia/nvidia-kmods-driver-flatcar | 535.183.01 |
| 550.90.07 | nvidia/nvidia-kmods-driver-flatcar | 550.90.07 |
| 580.95.05 | nvidia/nvidia-kmods-driver-flatcar | 580.95.05 |

And if you provided a work ID and Docker Hub username:

| Driver Version | Pushable Image |
|---------------|----------------|
| 535.183.01 | nikbo/nvidia-driver:535.183.01-nicolita-6.12.58-flatcar |
| 550.90.07 | nikbo/nvidia-driver:550.90.07-nicolita-6.12.58-flatcar |
| 580.95.05 | nikbo/nvidia-driver:580.95.05-nicolita-6.12.58-flatcar |

*Note: `nikbo` is the Docker Hub username, `nicolita` is the work identifier in the tag*

---

## Build Process Explained

### Step-by-Step for Each Driver

The build script performs these steps for each driver version:

#### 1. Build Initial Container
```bash
docker build --pull \
  --build-arg DRIVER_VERSION=550.90.07 \
  --tag nvidia/nvidia-driver-flatcar:550.90.07 \
  --file Dockerfile .
```

#### 2. Precompile Kernel Modules
```bash
docker run -d --privileged --pid=host \
  -v /run/nvidia:/run/nvidia:shared \
  -v /tmp/nvidia:/var/log \
  -v /usr/lib64/modules:/usr/lib64/modules \
  --name nvidia-driver-build-550.90.07 \
  nvidia/nvidia-driver-flatcar:550.90.07 update
```

This step:
- Downloads Flatcar development container (6.12.58)
- Compiles NVIDIA kernel modules for 6.12.58-flatcar
- Packages precompiled modules
- Takes 8-12 minutes per driver

#### 3. Create Runtime Image
```bash
docker commit \
  --change='ENTRYPOINT ["nvidia-driver", "init"]' \
  nvidia-driver-build-550.90.07 \
  nvidia/nvidia-kmods-driver-flatcar:550.90.07
```

#### 4. Tag for Registry (Optional)
```bash
docker tag nvidia/nvidia-kmods-driver-flatcar:550.90.07 \
  nicolita/nvidia-driver:550.90.07-nicolita-6.12.58-flatcar
```

---

## Build Individual Versions

To build just one driver:

```bash
./build-driver.sh 535.183.01 nicolita
```

Or manually:

```bash
export DRIVER_VERSION=535.183.01

# Build
docker build --pull \
  --build-arg DRIVER_VERSION=${DRIVER_VERSION} \
  --tag nvidia/nvidia-driver-flatcar:${DRIVER_VERSION} \
  --file Dockerfile .

# Precompile
docker run -d --privileged --pid=host \
  -v /run/nvidia:/run/nvidia:shared \
  -v /tmp/nvidia:/var/log \
  -v /usr/lib64/modules:/usr/lib64/modules \
  --name nvidia-driver \
  nvidia/nvidia-driver-flatcar:${DRIVER_VERSION} update

# Monitor
docker logs -f nvidia-driver

# Wait for "Done" message, then commit
docker commit \
  --change='ENTRYPOINT ["nvidia-driver", "init"]' \
  nvidia-driver \
  nvidia/nvidia-kmods-driver-flatcar:${DRIVER_VERSION}

# Cleanup
docker stop nvidia-driver && docker rm nvidia-driver
```

---

## Testing Built Drivers

### Test Driver 535.183.01
```bash
docker run -d --privileged --pid=host \
  -v /run/nvidia:/run/nvidia:shared \
  -v /tmp/nvidia:/var/log \
  -v /usr/lib64/modules:/usr/lib64/modules \
  --name test-driver-535 \
  nvidia/nvidia-kmods-driver-flatcar:535.183.01

# Wait a few seconds, then test
docker exec -it test-driver-535 nvidia-smi

# Check kernel modules
lsmod | grep nvidia
```

### Test All Versions
```bash
# Test 535.183.01
docker run -d --privileged --pid=host \
  -v /run/nvidia:/run/nvidia:shared \
  -v /tmp/nvidia:/var/log \
  -v /usr/lib64/modules:/usr/lib64/modules \
  --name test-535 \
  nvidia/nvidia-kmods-driver-flatcar:535.183.01

sleep 10
docker exec -it test-535 nvidia-smi
docker stop test-535 && docker rm test-535

# Repeat for 550.90.07 and 580.95.05
```

---

## Pushing to Registry

### Docker Hub

```bash
# Login to Docker Hub
docker login

# Push all versions (nikbo = Docker Hub user, nicolita = work ID)
for version in 535.183.01 550.90.07 580.95.05; do
  docker push nikbo/nvidia-driver:${version}-nicolita-6.12.58-flatcar
done
```

### Custom Registry (Azure ACR)

```bash
# Set registry
export DOCKER_REGISTRY=ethosk8sinfrastructure.azurecr.io

# Login
az acr login --name ethosk8sinfrastructure

# Rebuild with registry tags (no need for DOCKER_HUB_USER when using custom registry)
./build-all-drivers.sh nicolita

# Push
for version in 535.183.01 550.90.07 580.95.05; do
  docker push ${DOCKER_REGISTRY}/nvidia-driver:${version}-nicolita-6.12.58-flatcar
done
```

### Understanding the Tagging Convention

The image tags follow this format:
```
<docker-hub-user>/nvidia-driver:<driver-version>-<work-id>-<kernel-version>
```

**Example:** `nikbo/nvidia-driver:550.90.07-nicolita-6.12.58-flatcar`

- **nikbo**: Docker Hub username (personal account)
- **550.90.07**: NVIDIA driver version
- **nicolita**: Work identifier (who built it)
- **6.12.58-flatcar**: Flatcar kernel version

This allows:
- Pushing to your personal Docker Hub account
- Tracking who built which version
- Identifying the exact kernel version compatibility

---

## Troubleshooting Build Issues

### Issue: resize2fs fails

**Error:**
```
resize2fs: Filesystem has unsupported feature(s) (/dev/loop7)
```

**Fix:** Ensure you're using the updated `nvidia-driver` script from this fork (includes e2fsck fix).

### Issue: Build timeout

**Error:**
```
Build timeout or failed for driver X.X.X
```

**Fix:** 
1. Check logs: `docker logs nvidia-driver-build-X.X.X`
2. Verify kernel version: `uname -r` (should be 6.12.58-flatcar)
3. Ensure enough disk space: `df -h` (need ~10GB free)

### Issue: Driver version not found

**Error:**
```
curl: (22) The requested URL returned error: 404
```

**Fix:** Verify driver version exists at https://us.download.nvidia.com/tesla/

### Issue: Out of memory during build

**Error:**
```
Cannot allocate memory
```

**Fix:** Use a larger instance type (minimum: 8GB RAM, recommended: 16GB+)

---

## Build Time Estimates

| Instance Type | RAM | Build Time (all 3) | Build Time (single) |
|--------------|-----|-------------------|---------------------|
| g4dn.xlarge | 16GB | ~35 minutes | ~12 minutes |
| g4dn.2xlarge | 32GB | ~30 minutes | ~10 minutes |
| p3.2xlarge | 61GB | ~25 minutes | ~8 minutes |

---

## Disk Space Requirements

| Component | Space Needed |
|-----------|-------------|
| Base images | ~2GB |
| Single driver build | ~4GB |
| All three drivers | ~12GB |
| **Total recommended** | **20GB** |

Verify available space before building:
```bash
df -h /
```

---

## Next Steps After Building

1. **Push to registry** (see above)
2. **Update Kubernetes DaemonSet** to use your images
3. **Deploy to GPU nodes**
4. **Verify with workload**:
   ```bash
   kubectl run nvidia-smi --image=nvidia/cuda:12.0.0-base-ubuntu22.04 --rm -it --restart=Never -- nvidia-smi
   ```

---

## Additional Resources

- Full documentation: [FLATCAR_6.12_NOTES.md](./FLATCAR_6.12_NOTES.md)
- Main README: [README.md](./README.md)
- Kubernetes deployment: See FLATCAR_6.12_NOTES.md#kubernetes-deployment

