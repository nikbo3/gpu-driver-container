000+0 records in
3000+0 records out
3145728000 bytes (3.1 GB, 2.9 GiB) copied, 6.46957 s, 486 MB/s
DEBUG: About to run losetup...
DEBUG: Command will be: losetup --find --show -o 2097152 /usr/src/nvidia-535.183.01/flatcar_developer_container.bin
DEBUG: File check before losetup:
DEBUG: Current loop devices before setup:
DEBUG: Running losetup now...
DEBUG: losetup completed with exit code: 0
DEBUG: losetup output: '/dev/loop6'
resize2fs 1.46.5 (30-Dec-2021)
resize2fs: Filesystem has unsupported feature(s) (/dev/loop6)
++ cat /usr/src/linux/include/config/kernel.release
cat: /usr/src/linux/include/config/kernel.release: No such file or directory
++ ls /lib/modules
+ KERNEL_VERSION=6.12.58-flatcar
++ echo 6.12.58-flatcar
++ cut -d - -f1
+ KERNEL_STRING=6.12.58
+ echo 'Installing kernel sources for kernel version 6.12.58-flatcar...'
+ source /etc/os-release
++ NAME='Flatcar Container Linux by Kinvolk'
++ ID=flatcar
++ ID_LIKE=coreos
++ VERSION=4459.2.1
++ VERSION_ID=4459.2.1
++ BUILD_ID=2025-11-23-2139
++ SYSEXT_LEVEL=1.0
++ PRETTY_NAME='Flatcar Container Linux by Kinvolk 4459.2.1 (Oklo)'
++ ANSI_COLOR='38;5;75'
++ HOME_URL=https://flatcar.org/
++ BUG_REPORT_URL=https://issues.flatcar.org
++ FLATCAR_BOARD=amd64-usr
++ CPE_NAME='cpe:2.3:o:flatcar-linux:flatcar_linux:4459.2.1:*:*:*:*:*:*:*'
++ echo 4459 2 1
++ awk '{print $1}'
+ '[' 4459 -lt 2346 ']'
++ cat /usr/src/version.txt
++ xargs
+ export FLATCAR_BUILD=4459 FLATCAR_BRANCH=2 FLATCAR_PATCH=1 FLATCAR_VERSION=4459.2.1 FLATCAR_VERSION_ID=4459.2.1 FLATCAR_BUILD_ID=2025-11-23-2139 FLATCAR_SDK_VERSION=4459.0.0
+ FLATCAR_BUILD=4459
+ FLATCAR_BRANCH=2
+ FLATCAR_PATCH=1
+ FLATCAR_VERSION=4459.2.1
+ FLATCAR_VERSION_ID=4459.2.1
+ FLATCAR_BUILD_ID=2025-11-23-2139
+ FLATCAR_SDK_VERSION=4459.0.0
+ emerge-gitclone
Cloning into '/var/lib/portage/scripts'...



You are in 'detached HEAD' state. You can look around, make experimental
changes and commit them, and you can discard any commits you make in this
state without impacting any branches by switching back to a branch.

If you want to create a new branch to retain commits you create, you may
do so (now or later) by using -c with the switch command. Example:

  git switch -c <new-branch-name>

Or undo this operation with:

  git switch -

Turn off this advice by setting config variable advice.detachedHead to false

HEAD is now at 996a905679 New version: stable-4459.2.1
+ export OVERLAY_VERSION=stable-4459.2.1
+ OVERLAY_VERSION=stable-4459.2.1
+ export PORTAGE_VERSION=stable-4459.2.1
+ PORTAGE_VERSION=stable-4459.2.1
+ git -C /var/lib/portage/coreos-overlay checkout stable-4459.2.1
HEAD is now at 996a905679 New version: stable-4459.2.1
+ git -C /var/lib/portage/portage-stable checkout stable-4459.2.1
HEAD is now at 996a905679 New version: stable-4459.2.1
+ emerge -gKq coreos-sources



+ PORTAGE_VERSION=stable-4459.2.1
+ git -C /var/lib/portage/coreos-overlay checkout stable-4459.2.1
HEAD is now at 996a905679 New version: stable-4459.2.1
+ git -C /var/lib/portage/portage-stable checkout stable-4459.2.1
HEAD is now at 996a905679 New version: stable-4459.2.1
+ emerge -gKq coreos-sources
+ emerge -q --jobs 4 --load-average 4 coreos-sources
+ rm -f /usr/src/linux
+ ln -s /usr/src/linux-6.12.58-coreos /usr/src/linux
+ cp /lib/modules/6.12.58-flatcar/build/.config /usr/src/linux
+ echo '=== Setting kernel config to defaults (non-interactive) ==='
+ make -C /usr/src/linux olddefconfig
+ echo '=== Running modules_prepare (this may take a moment) ==='
+ make -C /usr/src/linux modules_prepare
+ echo '=== modules_prepare completed successfully ==='
+ cp /lib/modules/6.12.58-flatcar/build/Module.symvers /usr/src/linux/
+ depmod 6.12.58-flatcar
+ mkdir -p /usr/src/linux/proc
+ cp /proc/version /usr/src/linux/proc/
+ echo '=== DEBUG: About to start compilation phase ==='
+ echo '=== Checking NVIDIA sources ==='
=== DEBUG: About to start compilation phase ===
+ ls -la /usr/src/
+ ls -la /usr/src/nvidia-535.183.01/kernel
+ echo '=== Applying kernel compatibility patches ==='
+ cd /usr/src/nvidia-535.183.01/kernel
+ '[' -f /patches/kernel-6.5-follow-pte.patch ']'
+ echo 'Warning: kernel-6.5-follow-pte.patch not found'
+ '[' -f /patches/kernel-6.12-drm-poll.patch ']'
+ echo 'Warning: kernel-6.12-drm-poll.patch not found'
+ echo '=== Patches applied, proceeding with compilation ==='
++ gcc --version
++ head -1
+ echo '=== Compiling NVIDIA driver kernel modules with gcc (Gentoo Hardened 14.3.0 p8) 14.3.0 ==='
+ '[' -f /lib/modules/6.12.58-flatcar/build/scripts/module.lds ']'
+ echo 'Copying module.lds...'
+ cp /lib/modules/6.12.58-flatcar/build/scripts/module.lds /usr/src/nvidia-535.183.01/kernel
+ echo 'Changing to NVIDIA kernel directory...'
+ cd /usr/src/nvidia-535.183.01/kernel
++ pwd
+ echo 'Current directory: /usr/src/nvidia-535.183.01/kernel'
+ echo 'Files in directory:'
+ ls -la
+ export IGNORE_CC_MISMATCH=1
+ IGNORE_CC_MISMATCH=1
+ export IGNORE_MISSING_MODULE_SYMVERS=1
+ IGNORE_MISSING_MODULE_SYMVERS=1
+ echo '=== Starting make command (building full kernel modules) ==='
+ make -j SYSSRC=/lib/modules/6.12.58-flatcar/source modules
warning: the compiler differs from the one used to build the kernel
  The kernel was built by: x86_64-cros-linux-gnu-gcc (Gentoo Hardened 14.3.0 p8) 14.3.0
  You are using:           cc (Gentoo Hardened 14.3.0 p8) 14.3.0
echo 'Changing to NVIDIA kernel directory...'
+ cd /usr/src/nvidia-535.183.01/kernel
++ pwd
+ echo 'Current directory: /usr/src/nvidia-535.183.01/kernel'
+ echo 'Files in directory:'
+ ls -la
+ export IGNORE_CC_MISMATCH=1
+ IGNORE_CC_MISMATCH=1
+ export IGNORE_MISSING_MODULE_SYMVERS=1
+ IGNORE_MISSING_MODULE_SYMVERS=1
+ echo '=== Starting make command (building full kernel modules) ==='
+ make -j SYSSRC=/lib/modules/6.12.58-flatcar/source modules
warning: the compiler differs from the one used to build the kernel
  The kernel was built by: x86_64-cros-linux-gnu-gcc (Gentoo Hardened 14.3.0 p8) 14.3.0
  You are using:           cc (Gentoo Hardened 14.3.0 p8) 14.3.0
/usr/src/nvidia-535.183.01/kernel/nvidia/libspdm_aead.c:41:5: warning: no previous prototype for 'libspdm_aead_prealloc' [-Wmissing-prototypes]
   41 | int libspdm_aead_prealloc(void **context, char const *alg)
      |     ^~~~~~~~~~~~~~~~~~~~~
/usr/src/nvidia-535.183.01/kernel/nvidia/libspdm_aead.c:171:5: warning: no previous prototype for 'libspdm_aead_prealloced' [-Wmissing-prototypes]
  171 | int libspdm_aead_prealloced(void *context,
      |     ^~~~~~~~~~~~~~~~~~~~~~~


