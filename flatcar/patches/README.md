# Kernel Compatibility Patches for NVIDIA Drivers

This directory contains patches to make older NVIDIA driver versions (535.x and 550.x) compatible with Flatcar Linux kernel 6.12.58.

## Patches

### kernel-6.5-follow-pte.patch
**Purpose:** Fixes `follow_pfn` function removal in kernel 6.5+

**Issue:** The `follow_pfn()` kernel function was removed in Linux kernel 6.5 and replaced with `follow_pte()`.

**Solution:** Replaces `follow_pfn(vma, address, pfn)` with `follow_pte(vma, address, pfn)` in `nvidia/os-mlock.c`.

**Affected Drivers:** 535.183.01, 550.90.07

---

### kernel-6.12-drm-poll.patch
**Purpose:** Fixes `output_poll_changed` callback removal in kernel 6.12+

**Issue:** The `output_poll_changed` callback was removed from `struct drm_mode_config_funcs` in Linux kernel 6.12. Hotplug events are now handled automatically by `drm_client_dev_hotplug()`.

**Solution:** Removes the line `.output_poll_changed = nv_drm_output_poll_changed,` from the `nv_drm_mode_config_funcs` structure in `nvidia-drm/nvidia-drm-drv.c`.

**Affected Drivers:** 535.183.01, 550.90.07

---

## Usage

These patches are automatically applied during the driver build process by the `nvidia-driver` script when running inside the Flatcar development container.

The patches are applied in the chroot environment after kernel sources are installed but before compilation begins (see lines 248-274 in `nvidia-driver` script).

## Patch Application

Patches are applied with `-p2` flag because they need to be applied from within the `/usr/src/nvidia-*/kernel` directory:

```bash
cd /usr/src/nvidia-*/kernel
patch -p2 < /patches/kernel-6.5-follow-pte.patch
patch -p2 < /patches/kernel-6.12-drm-poll.patch
```
