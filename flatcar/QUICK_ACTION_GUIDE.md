# Quick Action Guide: Fixing Drivers 535 & 550

## TL;DR - What to Do Now

You have **3 new files** to help fix the remaining drivers:

1. **`DRIVER_535_550_SOLUTION_STRATEGY.md`** - Full technical analysis
2. **`test-newer-releases.sh`** - Automated testing script ⭐ **START HERE**
3. **`nvidia-drm-compat-6.12.patch`** - Compatibility patch (if needed)

---

## Step 1: Try Newer Releases (Easiest, Highest Success Rate)

**Why:** NVIDIA may have released newer versions with kernel 6.12 support

```bash
cd /home/core/gpu-driver-container/flatcar

# Make sure you're on your Flatcar 6.12.58 instance
export DOCKER_HUB_USER=nikbo
./test-newer-releases.sh nicolita
```

**What it does:**
- Tests `535.216.03` (latest LTS 535 branch)
- Tests `550.127.05` (latest Production 550 branch)
- Tests `550.135` (if it exists)
- Auto-builds any that succeed
- Auto-tags for Docker Hub

**Expected time:** 2-4 hours per driver

### If This Works: ✅ You're Done!

Push the images and update docs:
```bash
docker login -u nikbo
docker push nikbo/nvidia-driver:535.216.03-nicolita-6.12.58-flatcar
docker push nikbo/nvidia-driver:550.127.05-nicolita-6.12.58-flatcar
```

---

## Step 2: If Step 1 Fails - Apply Compatibility Patch

**Why:** The error is likely just `output_poll_changed` callback removal

### 2.1: Identify the Exact Error Location

Run a build manually to see the error:
```bash
export DRIVER_VERSION=535.183.01
docker build --pull \
  --build-arg DRIVER_VERSION=${DRIVER_VERSION} \
  --tag nvidia/nvidia-driver-flatcar:${DRIVER_VERSION} \
  --file Dockerfile .

docker run -d --privileged --pid=host \
  -v /run/nvidia:/run/nvidia:shared \
  -v /tmp/nvidia:/var/log \
  -v /usr/lib64/modules:/usr/lib64/modules \
  --name nvidia-driver-debug \
  nvidia/nvidia-driver-flatcar:${DRIVER_VERSION} update

# Watch for the error
docker logs -f nvidia-driver-debug
```

### 2.2: Update the Patch with Correct Line Numbers

The error will show something like:
```
kernel/nvidia-drm/nvidia-drm-connector.c:XXX:YY: error: 'struct drm_mode_config_funcs' has no member named 'output_poll_changed'
```

Note the **line number (XXX)** and update `nvidia-drm-compat-6.12.patch`:
```patch
--- a/kernel/nvidia-drm/nvidia-drm-connector.c
+++ b/kernel/nvidia-drm/nvidia-drm-connector.c
@@ -XXX,7 +XXX,9 @@ static const struct drm_mode_config_funcs nv_mode_config_funcs = {
```
Replace `XXX` with the actual line number from the error.

### 2.3: Modify Dockerfile to Apply Patch

Edit `Dockerfile`, add after line 35 (before the final COPY):
```dockerfile
# Copy DRM compatibility patch
COPY nvidia-drm-compat-6.12.patch /tmp/nvidia-drm-compat-6.12.patch
```

### 2.4: Modify nvidia-driver Script to Apply Patch

Edit `nvidia-driver`, find the section after driver extraction (around line 125, before compilation starts inside chroot):

Add this block:
```bash
# Apply kernel 6.12 DRM compatibility patch if present
if [ -f /tmp/nvidia-drm-compat-6.12.patch ]; then
    echo "=== Applying kernel 6.12 DRM compatibility patch ==="
    cd /usr/src/nvidia-${DRIVER_VERSION}/kernel
    if patch -p1 --dry-run < /tmp/nvidia-drm-compat-6.12.patch >/dev/null 2>&1; then
        patch -p1 < /tmp/nvidia-drm-compat-6.12.patch
        echo "✓ Patch applied successfully"
    else
        echo "⚠ Patch did not apply cleanly - will attempt compilation anyway"
    fi
    cd -
fi
```

### 2.5: Rebuild

```bash
./build-driver.sh 535.183.01 6.12.58-flatcar nikbo nicolita
```

---

## Step 3: If Step 2 Fails - Advanced Debugging

### Check for Multiple DRM API Issues

If patching `output_poll_changed` doesn't fix it, there may be other API changes:

```bash
# Extract the full error log
docker logs nvidia-driver-debug 2>&1 | grep "error:" > /tmp/nvidia-drm-errors.txt
cat /tmp/nvidia-drm-errors.txt
```

**Common additional issues:**
- `drm_atomic_helper_commit` signature changes
- `drm_connector_init` parameter changes
- Missing include files

### Create Additional Compatibility Stubs

See **DRIVER_535_550_SOLUTION_STRATEGY.md** → Approach 3 for details on creating shims.

---

## Decision Tree

```
Start Here
    ↓
┌─────────────────────────────┐
│ Run test-newer-releases.sh  │
└─────────────┬───────────────┘
              ↓
        ┌─────┴─────┐
        │  Works?   │
        └─────┬─────┘
              ↓
       ┌──────┴──────┐
       │ YES         │ NO
       ↓             ↓
    ✅ DONE      Apply Patch
                 (Step 2)
                     ↓
              ┌──────┴──────┐
              │   Works?    │
              └──────┬──────┘
                     ↓
              ┌──────┴──────┐
              │ YES         │ NO
              ↓             ↓
           ✅ DONE    Debug & Shim
                      (Step 3)
                           ↓
                    Review Strategy Doc
```

---

## What to Report Back

If you need help, provide:

1. **Driver version** you're testing
2. **Exact error message** (with line numbers)
3. **Which approach** you tried (Step 1, 2, or 3)
4. **Full compilation log** (last 50 lines)

---

## Success Indicators

For each working driver:
- ✅ `docker build` succeeds
- ✅ Container runs: `docker run nvidia/nvidia-kmods-driver-flatcar:XXX`
- ✅ Modules load: `lsmod | grep nvidia`
- ✅ `nvidia-smi` shows GPU info

---

## Files Reference

| File | Purpose | When to Use |
|------|---------|-------------|
| `test-newer-releases.sh` | Auto-test newer driver versions | **START HERE** |
| `DRIVER_535_550_SOLUTION_STRATEGY.md` | Full technical strategy | Reference / deep dive |
| `nvidia-drm-compat-6.12.patch` | DRM compatibility patch | If newer releases don't exist/work |
| `build-driver.sh` | Single driver build script | Manual builds |
| `build-all-drivers.sh` | Build multiple versions | After you know what works |

---

## Timeline Estimates

| Approach | Time | Success Probability |
|----------|------|---------------------|
| **Newer Releases** | 2-4 hours | 🟢 70% |
| **DRM Patch** | 4-8 hours | 🟡 50% |
| **Advanced Shims** | 8-16 hours | 🟡 40% |

---

**Ready?** Start with `./test-newer-releases.sh nicolita` and report back! 🚀

