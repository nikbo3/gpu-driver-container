# Kernel Compatibility Patches for NVIDIA Drivers on Flatcar 6.12.58+

This directory contains patches to enable older NVIDIA driver versions (535.x and 550.x) to compile against Linux kernel 6.12.58+.

## Patches Included

### 1. `kernel-6.5-follow-pte.patch`
**Target**: Drivers 535.183.01, 550.90.07  
**Kernel Version**: 6.5+  
**Issue**: The `follow_pfn()` function was removed from the kernel in version 6.5 and replaced with `follow_pte()`.

**Error without patch**:
```
os-mlock.c:42:12: error: implicit declaration of function 'follow_pfn'
```

**Fix**: Replaces the removed `follow_pfn()` call with the new `follow_pte()` API, including proper page table entry handling and unlocking.

### 2. `kernel-6.12-drm-poll.patch`
**Target**: Drivers 535.183.01, 550.90.07  
**Kernel Version**: 6.12+  
**Issue**: The `output_poll_changed` callback was removed from `drm_mode_config_funcs` in kernel 6.12. Hotplug events are now handled automatically by `drm_client_dev_hotplug()`.

**Error without patch**:
```
nvidia-drm-drv.c:188:6: error: 'const struct drm_mode_config_funcs' has no member named 'output_poll_changed'
```

**Fix**: Conditionally compiles out the `output_poll_changed` callback for kernel 6.12+.

## How Patches Are Applied

Patches are automatically applied during the container build process in the `nvidia-driver` script, right before compilation begins. The patching happens inside the Flatcar development environment chroot.

## Testing Status

- ✅ Driver 580.95.05: No patches needed (native kernel 6.12 support)
- ⏳ Driver 535.183.01: Patches applied, testing in progress
- ⏳ Driver 550.90.07: Patches applied, testing in progress

## References

- **Kernel 6.5 follow_pte change**: https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=233eb0bf3b94
- **Kernel 6.12 DRM changes**: https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/log/drivers/gpu/drm?h=v6.12
- **NVIDIA Driver Container**: https://github.com/NVIDIA/gpu-driver-container

## Contributing

If you encounter additional kernel API incompatibilities, please:
1. Document the error message and affected kernel version
2. Create a minimal patch file following the existing format
3. Update this README with the new patch details
4. Test thoroughly before deployment

