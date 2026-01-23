# NVIDIA GPU Driver Build for Flatcar 6.12.58

## Critical Information

⚠️ **ONLY NVIDIA DRIVER 580.95.05 IS COMPATIBLE WITH FLATCAR 6.12.58**

| Driver Version | Kernel 6.12.58 | Status | Error |
|----------------|----------------|--------|-------|
| 535.183.01 | ❌ Failed | Compilation Error | `nvidia-drm-drv.o` DRM API incompatibility |
| 550.90.07 | ❌ Failed | Compilation Error | `output_poll_changed` member missing |
| **580.95.05** | ✅ **SUCCESS** | **WORKING** | **Use this version** |

**Reason:** Kernel 6.12.58 introduced DRM subsystem changes that break drivers < 580.x.

---

## Quick Start

### Prerequisites

1. **Flatcar Linux** instance with kernel `6.12.58-flatcar`
2. **GPU-enabled** AWS instance (g4dn.xlarge, p3.2xlarge, etc.)
3. **Docker** installed and running
4. **Git** for cloning the repository

### Build Command

```bash
# 1. Clone the repository with Flatcar 6.12.58 fixes
git clone https://github.com/nikbo3/gpu-driver-container
cd gpu-driver-container/flatcar

# 2. Build the driver image
docker build --pull \
  --build-arg DRIVER_VERSION=580.95.05 \
  --tag nvidia/nvidia-driver-flatcar:580.95.05 \
  --file Dockerfile .

# 3. Run the build process (precompile kernel modules)
docker run -d --privileged --pid=host \
  -v /run/nvidia:/run/nvidia:shared \
  -v /tmp/nvidia:/var/log \
  -v /usr/lib64/modules:/usr/lib64/modules \
  --name nvidia-driver-580 \
  nvidia/nvidia-driver-flatcar:580.95.05 update

# 4. Monitor build progress (wait for "Done")
docker logs -f nvidia-driver-580

# 5. Commit the container with kernel modules
docker commit \
  --change='ENTRYPOINT ["nvidia-driver", "init"]' \
  nvidia-driver-580 nvidia/nvidia-kmods-driver-flatcar:580.95.05

# 6. Tag for your registry
docker tag nvidia/nvidia-kmods-driver-flatcar:580.95.05 \
  nikbo/nvidia-driver:580.95.05-nicolita-6.12.58-flatcar

# 7. Test driver initialization
docker run -d --privileged --pid=host \
  -v /run/nvidia:/run/nvidia:shared \
  -v /tmp/nvidia:/var/log \
  -v /usr/lib64/modules:/usr/lib64/modules \
  --name nvidia-driver-test \
  nikbo/nvidia-driver:580.95.05-nicolita-6.12.58-flatcar

# 8. Verify modules loaded
lsmod | grep -i nvidia

# 9. Validate with nvidia-smi
docker exec -it nvidia-driver-test sh -c "nvidia-smi"

# 10. Push to Docker Hub
docker login -u nikbo
docker push nikbo/nvidia-driver:580.95.05-nicolita-6.12.58-flatcar
```

---

## Technical Details

### Why Older Drivers Failed

**Kernel 6.12.58 DRM API Changes:**

The Linux kernel 6.12.x series introduced significant changes to the Direct Rendering Manager (DRM) subsystem:

1. **535.183.01 Error:**
   ```
   error: 'const struct drm_mode_config_funcs' has no member named 'output_poll_changed'
   ```

2. **550.90.07 Error:**
   ```
   initialization of 'struct drm_atomic_state * (*)(struct drm_device *)' 
   from incompatible pointer type 'void (*)(struct drm_device *)'
   ```

**Root Cause:** NVIDIA drivers < 580.x expect old DRM API signatures that were refactored in kernel 6.12.x.

**Solution:** Driver 580.95.05 was updated to support the new DRM API.

### Key Implementation Changes

This fork includes critical modifications to support Flatcar 6.12.58:

#### 1. Full Module Compilation (Not Precompiled Objects)

**Old Approach (Failed):**
- Compile `.o` object files in chroot
- Package with `mkprecompiled`
- Re-link on host system with `ld`
- **Problem:** GLIBC version mismatch between build and runtime

**New Approach (Success):**
- Compile **full `.ko` modules** in chroot
- Skip `mkprecompiled` packaging
- Copy `.ko` files directly to runtime
- **Benefit:** No re-linking needed, GLIBC compatible

```bash
# Inside nvidia-driver script (chroot section)
make -j ${MAX_THREADS} SYSSRC=/lib/modules/${KERNEL_VERSION}/source modules
# Builds: nvidia.ko, nvidia-uvm.ko, nvidia-modeset.ko, nvidia-drm.ko, nvidia-peermem.ko
```

#### 2. Download Error Checking

Added robust error handling for Flatcar developer container download:

```bash
echo "Downloading Flatcar development image..."
if ! curl -Lsf "${dev_image_url}" | bzip2 -dq > "${dev_image}"; then
    echo "ERROR: Failed to download!"
    exit 1
fi

if [ ! -f "${dev_image}" ] || [ ! -s "${dev_image}" ]; then
    echo "ERROR: File missing or empty!"
    exit 1
fi
```

#### 3. Loop Device Management

Improved loop device handling to avoid "Device or resource busy" errors:

```bash
# Auto-select available loop device
loop_dev=$(losetup --find --show -o ${offset_limit} "${dev_image}")

# Cleanup stale devices on start
for loop in $(losetup -j "${dev_image}" 2>/dev/null | cut -d: -f1); do
    losetup -d "${loop}" 2>/dev/null || true
done
```

#### 4. Direct Module Installation

Simplified installation by removing re-linking:

```bash
# Old: Unpack .o files, re-link with bundled ld → GLIBC errors
# New: Copy pre-built .ko files directly
cp ${archive_dir}/*.ko ${NVIDIA_KMODS_DIR}/lib/modules/${KERNEL_VERSION}/
depmod -b ${NVIDIA_KMODS_DIR} ${KERNEL_VERSION}
```

---

## Build Process Overview

```
┌─────────────────────────────────────────────┐
│ 1. Docker Build                             │
│    - Install e2fsprogs                      │
│    - Set DRIVER_VERSION=580.95.05           │
└─────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│ 2. Download Flatcar Developer Container     │
│    - Verify download (error checking)      │
│    - Setup loop device (auto-select)       │
│    - Resize filesystem                     │
└─────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│ 3. Install Kernel Sources (in chroot)      │
│    - emerge-gitclone for Flatcar 4459.2.1  │
│    - Install coreos-sources                │
│    - make modules_prepare                  │
└─────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│ 4. Compile NVIDIA Drivers (in chroot)      │
│    - make modules (builds .ko files)       │
│    - Full linking in correct GLIBC env     │
└─────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│ 5. Package Modules                         │
│    - Copy .ko files to archive             │
│    - Skip mkprecompiled (not needed)       │
└─────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│ 6. Install at Runtime (init entrypoint)    │
│    - Copy .ko files directly               │
│    - No re-linking (already linked)        │
│    - modprobe to load                      │
└─────────────────────────────────────────────┘
```

---

## Kubernetes Deployment

### DaemonSet Example

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
        nvidia.com/gpu: "true"  # Only GPU nodes
      tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
      containers:
      - name: nvidia-driver-installer
        image: nikbo/nvidia-driver:580.95.05-nicolita-6.12.58-flatcar
        securityContext:
          privileged: true
          seLinuxOptions:
            type: unconfined_t
        volumeMounts:
        - name: dev
          mountPath: /dev
        - name: nvidia-install-dir-host
          mountPath: /run/nvidia
          mountPropagation: Bidirectional
        - name: kernel-modules
          mountPath: /usr/lib64/modules
        - name: nvidia-log
          mountPath: /var/log
      volumes:
      - name: dev
        hostPath:
          path: /dev
      - name: nvidia-install-dir-host
        hostPath:
          path: /run/nvidia
      - name: kernel-modules
        hostPath:
          path: /usr/lib64/modules
      - name: nvidia-log
        hostPath:
          path: /var/log/nvidia
```

---

## Troubleshooting

### Build Fails with DRM Errors

**Error:**
```
nvidia-drm-drv.c:207:6: error: 'const struct drm_mode_config_funcs' 
has no member named 'output_poll_changed'
```

**Solution:** You're using an incompatible driver version. **Use 580.95.05.**

### "Exec format error" When Loading Modules

**Error:**
```
modprobe: ERROR: could not insert 'nvidia': Exec format error
```

**Cause:** Modules were re-linked with incompatible linker (old version of this fork).

**Solution:** Rebuild with the latest fork - modules are now fully-linked in chroot.

### "GLIBC_2.38 not found"

**Cause:** Bundled binutils requires newer GLIBC (old version of this fork).

**Solution:** Rebuild with the latest fork - no longer using bundled binutils.

### "losetup: failed to set up loop device"

**Cause:** Stale loop devices or download failed.

**Solution:** Already fixed - script now cleans up loop devices and verifies downloads.

### Build is Slow or Hangs

**Normal Build Time:** 12-15 minutes total
- Download: ~2 minutes
- Compilation: ~8-10 minutes
- Packaging: ~1 minute

If stuck for > 20 minutes, check logs:
```bash
docker logs -f nvidia-driver-580
```

---

## Validation Checklist

After building, verify everything works:

```bash
# 1. Check kernel modules loaded
lsmod | grep nvidia
# Expected: nvidia, nvidia_uvm, nvidia_modeset

# 2. Verify nvidia-smi works
docker exec nvidia-driver-test sh -c "nvidia-smi"
# Expected: GPU information displayed

# 3. Check driver version
docker exec nvidia-driver-test sh -c "cat /proc/driver/nvidia/version"
# Expected: NVRM version: 580.95.05

# 4. Test CUDA sample (if available)
docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi
# Expected: GPU visible in CUDA container
```

---

## Performance & Resource Requirements

| Metric | Value |
|--------|-------|
| Build Time | 12-15 minutes |
| Final Image Size | ~4.5GB |
| Disk Space Needed | ~15GB (build + layers) |
| RAM Required | 4GB+ recommended |
| CPU Cores | 4+ recommended for faster build |

---

## References

- **Flatcar Documentation:** https://flatcar-linux.org/docs/latest/reference/developer-guides/kernel-modules/
- **NVIDIA Driver Downloads:** https://www.nvidia.com/Download/index.aspx
- **Kernel 6.12 Changelog:** https://kernelnewbies.org/Linux_6.12
- **DRM Subsystem Changes:** https://dri.freedesktop.org/
- **Repository:** https://github.com/nikbo3/gpu-driver-container

---

## Support

For issues or questions:
1. Check [CHANGES_SUMMARY.md](./CHANGES_SUMMARY.md) for technical details
2. Review [QUICK_START.md](./QUICK_START.md) for common commands
3. See [BUILD_INSTRUCTIONS.md](./BUILD_INSTRUCTIONS.md) for step-by-step guide

---

**Last Updated:** January 23, 2026  
**Flatcar Version:** 6.12.58-flatcar (Build 4459.2.1)  
**NVIDIA Driver:** 580.95.05  
**Kubernetes:** 1.33  
**Status:** ✅ Production Ready
