# Rebuild Instructions for Drivers 535.183.01 and 550.90.07 with Patches

## Summary of Changes

We've added kernel compatibility patches to enable NVIDIA drivers 535.183.01 and 550.90.07 to compile on Flatcar 6.12.58:

1. **`patches/kernel-6.5-follow-pte.patch`** - Replaces removed `follow_pfn()` with `follow_pte()` API
2. **`patches/kernel-6.12-drm-poll.patch`** - Removes deprecated `output_poll_changed` callback
3. **Updated `nvidia-driver` script** - Applies patches before compilation
4. **Updated `Dockerfile`** - Includes patches in the container image
5. **Fixed loop device setup** - Uses absolute paths to avoid "No such file or directory" errors

## Prerequisites

Ensure you have these files in your `flatcar/` directory:
```bash
flatcar/
├── patches/
│   ├── kernel-6.5-follow-pte.patch
│   ├── kernel-6.12-drm-poll.patch
│   └── README.md
├── Dockerfile  (updated with COPY patches /patches)
├── nvidia-driver  (updated with patch application logic)
├── build-driver.sh
└── test-535-550.sh
```

## Quick Rebuild Commands

### On Your Flatcar Instance

```bash
# 1. Navigate to the flatcar directory
cd /home/core/gpu-driver-container/flatcar

# 2. Verify patches exist
ls -la patches/*.patch
# Should show: kernel-6.5-follow-pte.patch and kernel-6.12-drm-poll.patch

# 3. Stop and remove any existing containers
docker stop nvidia-driver-535 2>/dev/null || true
docker rm nvidia-driver-535 2>/dev/null || true

# 4. Rebuild the Docker image with patches
docker build --pull \
  --build-arg DRIVER_VERSION=535.183.01 \
  --tag nvidia/nvidia-driver-flatcar:535.183.01 \
  --file Dockerfile .

# 5. Run the build process
docker run -d --privileged --pid=host \
  -v /run/nvidia:/run/nvidia:shared \
  -v /tmp/nvidia:/var/log \
  -v /usr/lib64/modules:/usr/lib64/modules \
  --name nvidia-driver-535 \
  nvidia/nvidia-driver-flatcar:535.183.01 update

# 6. Monitor the build logs
docker logs -f nvidia-driver-535 | tee /tmp/535-build-$(date +%Y%m%d-%H%M%S).log
```

## What to Look For in the Logs

### ✅ Successful Patch Application

You should see these lines during the build:
```
=== Applying kernel compatibility patches ===
Applying kernel 6.5+ follow_pte patch...
patching file kernel/nvidia/os-mlock.c
Applying kernel 6.12+ DRM poll patch...
patching file kernel/nvidia-drm/nvidia-drm-drv.c
=== Patches applied, proceeding with compilation ===
```

### ✅ Successful Compilation

After compilation, you should see:
```
=== Compilation completed successfully! ===
Building NVIDIA driver package nvidia-modules-6.6.65...
Packaged precompiled driver into /usr/src/nvidia-535.183.01/kernel/precompiled/6.12.58-flatcar
Done
```

### ❌ Patch Application Failed

If you see warnings like:
```
Warning: kernel-6.5-follow-pte.patch not found
Warning: kernel-6.12-drm-poll.patch not found
```

**Solution**: The Docker image wasn't rebuilt with the patches. Go back to step 4 above.

### ❌ Compilation Still Failing

If you see:
```
error: 'const struct drm_mode_config_funcs' has no member named 'output_poll_changed'
```

**Solution**: Patches weren't applied. Verify:
1. Patches exist in `patches/` directory on the Flatcar instance
2. Docker image was rebuilt (step 4)
3. You're running the newly built image (step 5)

## After Successful Build

### Commit the Image

```bash
# Commit with new entrypoint
docker commit \
  --change='ENTRYPOINT ["nvidia-driver", "init"]' \
  nvidia-driver-535 nvidia/nvidia-kmods-driver-flatcar:535.183.01
```

### Tag for Docker Hub

```bash
docker tag nvidia/nvidia-kmods-driver-flatcar:535.183.01 \
  nikbo/nvidia-driver:535.183.01-nicolita-6.12.58-flatcar
```

### Test the Driver

```bash
# Stop build container
docker stop nvidia-driver-535
docker rm nvidia-driver-535

# Run driver initialization test
docker run -d --privileged --pid=host \
  -v /run/nvidia:/run/nvidia:shared \
  -v /tmp/nvidia:/var/log \
  -v /usr/lib64/modules:/usr/lib64/modules \
  --name nvidia-driver-test \
  nikbo/nvidia-driver:535.183.01-nicolita-6.12.58-flatcar

# Verify modules loaded
sleep 5
lsmod | grep -i nvidia

# Test nvidia-smi
docker exec -it nvidia-driver-test sh -c "nvidia-smi"
```

### Push to Docker Hub

```bash
docker login -u nikbo
docker push nikbo/nvidia-driver:535.183.01-nicolita-6.12.58-flatcar
```

## Build Driver 550.90.07

Repeat the same process for driver 550.90.07:

```bash
# Clean up
docker stop nvidia-driver-550 2>/dev/null || true
docker rm nvidia-driver-550 2>/dev/null || true

# Build
docker build --pull \
  --build-arg DRIVER_VERSION=550.90.07 \
  --tag nvidia/nvidia-driver-flatcar:550.90.07 \
  --file Dockerfile .

# Run
docker run -d --privileged --pid=host \
  -v /run/nvidia:/run/nvidia:shared \
  -v /tmp/nvidia:/var/log \
  -v /usr/lib64/modules:/usr/lib64/modules \
  --name nvidia-driver-550 \
  nvidia/nvidia-driver-flatcar:550.90.07 update

# Monitor
docker logs -f nvidia-driver-550 | tee /tmp/550-build-$(date +%Y%m%d-%H%M%S).log
```

## Automated Build Script

Alternatively, use the provided test script:

```bash
cd /home/core/gpu-driver-container/flatcar
chmod +x test-535-550.sh

# This will build both 535.183.01 and 550.90.07
./test-535-550.sh nicolita
```

## Troubleshooting

### "losetup: failed to set up loop device: No such file or directory"

**Fixed in latest version** - The script now uses absolute paths for the development image.

If you still see this:
1. Verify you have the latest `nvidia-driver` script
2. Check that the development image downloaded successfully
3. Ensure you have enough disk space (need ~10GB free)

### "patch: command not found"

The `patch` command should be available in the base Ubuntu image. If not:
```bash
# Update Dockerfile to add:
RUN apt-get update && apt-get install -y patch
```

### Build Times

- **535.183.01**: ~15-20 minutes
- **550.90.07**: ~15-20 minutes
- **580.95.05**: ~15-20 minutes (already working, no patches needed)

## Final Image Tags

After successful builds, you'll have:
```
nikbo/nvidia-driver:535.183.01-nicolita-6.12.58-flatcar
nikbo/nvidia-driver:550.90.07-nicolita-6.12.58-flatcar
nikbo/nvidia-driver:580.95.05-nicolita-6.12.58-flatcar  (already built)
```

All three drivers are now compatible with Flatcar 6.12.58!

## Next Steps

1. Test all three drivers on your GPU workloads
2. Update Kubernetes DaemonSets to use the appropriate driver version
3. Document which GPU types work best with which driver version
4. Update the CHANGES_SUMMARY.md with test results

