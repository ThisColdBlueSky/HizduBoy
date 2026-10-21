# Positron Kernel for POCO X4 Pro 5G / Redmi Note 11 Pro 5G (`veux` / `peux`)

Custom Linux kernel based on Android Common Kernel (ACK) 5.4 for Snapdragon 695 / SM6375 devices.

- **Target Devices**: POCO X4 Pro 5G (`veux`), Redmi Note 11 Pro 5G / Pro+ 5G (`peux`)
- **Kernel Version**: `5.4.302~positron`
- **Compiler**: ClangBuiltLinux LLVM 22.1.7 (AOSP / Linux kernel.org prebuilts)
- **Defconfig**: `arch/arm64/configs/veux_defconfig`
- **Installer**: AnyKernel3 with device-specific dynamic HAL patching

---

## Architecture & Design

### 1. Dual KernelSU & Normal Mechanism
The kernel source includes built-in KernelSU support via manual VFS hooks (`fs/exec.c`, `fs/open.c`, `fs/read_write.c`, `fs/stat.c`):
- **Normal Flavor**: Compiled with `CONFIG_KSU` disabled (`# CONFIG_KSU is not set`).
- **KernelSU Flavor**: Compiled with `CONFIG_KSU=y`.
- **Unified Dual-Mode Package**: An AnyKernel3 zip containing the standard unrooted `Image`, combined with a binary delta `ksu.bdf` (generated using `bsdiff Image Image_KSU ksu.bdf`). If a `KSU_UNLOCK` trigger exists in `$AKHOME` during flashing, AnyKernel patches the image using `bspatch` before flashing to the `boot` partition.

### 2. AnyKernel3 Packaging & Xiaomi Dynamic HAL Patching
AnyKernel3 dynamically detects stock MIUI/HyperOS vs AOSP custom ROM HALs in `/vendor`:
- Dynamically patches sound codec nodes (`aw88261` / `fs1962`) in `dtb`.
- Corrects display panel physical dimensions for stock display composer.
- Fixes NFC (`pn557`) and IR SPI compatible properties.
- Wipes the redundant `dtbo` partition (`erase_dtbo`) to avoid conflicts.

---

## Building Locally

### Prerequisites
Install compilation dependencies and Clang:
```bash
sudo apt-get update
sudo apt-get install -y bc bison build-essential ccache curl flex \
  gcc-aarch64-linux-gnu gcc-arm-linux-gnueabi git libssl-dev libelf-dev \
  lz4 xz-utils zip bsdiff python3
```

### Build Commands
Using the helper script:
```bash
# Build both Standard and KernelSU versions + Unified zip:
./build.sh --both

# Build KernelSU version only:
./build.sh --ksu

# Build Standard version only:
./build.sh --normal
```

---

## GitHub Actions Automated CI/CD

An automated workflow is provided at `.github/workflows/build.yml`:
- **Triggers**:
  - Manual trigger via **Actions > Build Positron Kernel > Run workflow** (`workflow_dispatch`), allowing selection between `both`, `ksu`, or `normal`.
  - Automatic build on `git push` to `main`.
- **Outputs**:
  - Automatically builds using ClangBuiltLinux LLVM 22.1.7.
  - Generates ready-to-flash AnyKernel3 `.zip` archives.
  - Automatically creates GitHub Releases with SHA-256 checksums.

---

# How do I submit patches to Android Common Kernels

1. BEST: Make all of your changes to upstream Linux. If appropriate, backport to the stable releases.
   These patches will be merged automatically in the corresponding common kernels. If the patch is already
   in upstream Linux, post a backport of the patch that conforms to the patch requirements below.

2. LESS GOOD: Develop your patches out-of-tree (from an upstream Linux point-of-view). Unless these are
   fixing an Android-specific bug, these are very unlikely to be accepted unless they have been
   coordinated with kernel-team@android.com. If you want to proceed, post a patch that conforms to the
   patch requirements below.

# Common Kernel patch requirements

- All patches must conform to the Linux kernel coding standards and pass `script/checkpatch.pl`
- Patches shall not break gki_defconfig or allmodconfig builds for arm, arm64, x86, x86_64 architectures
(see  https://source.android.com/setup/build/building-kernels)
- If the patch is not merged from an upstream branch, the subject must be tagged with the type of patch:
`UPSTREAM:`, `BACKPORT:`, `FROMGIT:`, `FROMLIST:`, or `ANDROID:`.
- All patches must have a `Change-Id:` tag (see https://gerrit-review.googlesource.com/Documentation/user-changeid.html)
- If an Android bug has been assigned, there must be a `Bug:` tag.
- All patches must have a `Signed-off-by:` tag by the author and the submitter

Additional requirements are listed below based on patch type

## Requirements for backports from mainline Linux: `UPSTREAM:`, `BACKPORT:`

- If the patch is a cherry-pick from Linux mainline with no changes at all
    - tag the patch subject with `UPSTREAM:`.
    - add upstream commit information with a `(cherry-picked from ...)` line
    - Example:
        - if the upstream commit message is
```
        important patch from upstream

        This is the detailed description of the important patch

        Signed-off-by: Fred Jones <fred.jones@foo.org>
```
        - then Joe Smith would upload the patch for the common kernel as
```
        UPSTREAM: important patch from upstream

        This is the detailed description of the important patch

        Signed-off-by: Fred Jones <fred.jones@foo.org>

        Bug: 135791357
        Change-Id: I4caaaa566ea080fa148c5e768bb1a0b6f7201c01
        (cherry-picked from c31e73121f4c1ec41143423ac6ce3ce6dafdcec1)
        Signed-off-by: Joe Smith <joe.smith@foo.org>
```

- If the patch requires any changes from the upstream version, tag the patch with `BACKPORT:`
instead of `UPSTREAM:`.
    - use the same tags as `UPSTREAM:`
    - add comments about the changes under the `(cherry-picked from ...)` line
    - Example:
```
        BACKPORT: important patch from upstream

        This is the detailed description of the important patch

        Signed-off-by: Fred Jones <fred.jones@foo.org>

        Bug: 135791357
        Change-Id: I4caaaa566ea080fa148c5e768bb1a0b6f7201c01
        (cherry-picked from c31e73121f4c1ec41143423ac6ce3ce6dafdcec1)
        [ Resolved minor conflict in drivers/foo/bar.c ]
        Signed-off-by: Joe Smith <joe.smith@foo.org>
```

## Requirements for other backports: `FROMGIT:`, `FROMLIST:`,

- If the patch has been merged into an upstream maintainer tree, but has not yet
been merged into Linux mainline
    - tag the patch subject with `FROMGIT:`
    - add info on where the patch came from as `(cherry picked from commit <sha1> <repo> <branch>)`. This
must be a stable maintainer branch (not rebased, so don't use `linux-next` for example).
    - if changes were required, use `BACKPORT: FROMGIT:`
    - Example:
        - if the commit message in the maintainer tree is
```
        important patch from upstream

        This is the detailed description of the important patch

        Signed-off-by: Fred Jones <fred.jones@foo.org>
```
        - then Joe Smith would upload the patch for the common kernel as
```
        FROMGIT: important patch from upstream

        This is the detailed description of the important patch

        Signed-off-by: Fred Jones <fred.jones@foo.org>

        Bug: 135791357
        (cherry picked from commit 878a2fd9de10b03d11d2f622250285c7e63deace
         https://git.kernel.org/pub/scm/linux/kernel/git/foo/bar.git test-branch)
        Change-Id: I4caaaa566ea080fa148c5e768bb1a0b6f7201c01
        Signed-off-by: Joe Smith <joe.smith@foo.org>
```


- If the patch has been submitted to LKML, but not accepted into any maintainer tree
    - tag the patch subject with `FROMLIST:`
    - add a `Link:` tag with a link to the submittal on lore.kernel.org
    - if changes were required, use `BACKPORT: FROMLIST:`
    - Example:
```
        FROMLIST: important patch from upstream

        This is the detailed description of the important patch

        Signed-off-by: Fred Jones <fred.jones@foo.org>

        Bug: 135791357
        Link: https://lore.kernel.org/lkml/20190619171517.GA17557@someone.com/
        Change-Id: I4caaaa566ea080fa148c5e768bb1a0b6f7201c01
        Signed-off-by: Joe Smith <joe.smith@foo.org>
```

## Requirements for Android-specific patches: `ANDROID:`

- If the patch is fixing a bug to Android-specific code
    - tag the patch subject with `ANDROID:`
    - add a `Fixes:` tag that cites the patch with the bug
    - Example:
```
        ANDROID: fix android-specific bug in foobar.c

        This is the detailed description of the important fix

        Fixes: 1234abcd2468 ("foobar: add cool feature")
        Change-Id: I4caaaa566ea080fa148c5e768bb1a0b6f7201c01
        Signed-off-by: Joe Smith <joe.smith@foo.org>
```

- If the patch is a new feature
    - tag the patch subject with `ANDROID:`
    - add a `Bug:` tag with the Android bug (required for android-specific features)

# Vibrator driver for HHG device
## How to merge the driver into kernel source tree

 1. Copy \${this_project}/drivers/hid/hid-aksys.c into \${your_kernel_root}/drivers/hid/

 2. Compare and merge \${this_project}/drivers/hid/hid-ids.h into \${your_kernel_root}/drivers/hid/hid-ids.h :
 Add the following code before the last line of this file

    ```c
		#define USB_VENDER_ID_QUALCOMM  0x0a12
		#define USB_VENDER_ID_TEMP_HHG_AKSY 0x1234
		#define USB_PRODUCT_ID_AKSYS_HHG  0x1000
    ```

 3. Merge \${this_project}/drivers/hid/Kconfig into \${your_kernel_root}/drivers/hid/Kconfig :
Add the following code before the last line of this file

		config HID_AKSYS_QRD
    		tristate "AKSys gamepad USB adapter support"
    		depends on HID
    		---help---
    		Support for AKSys gamepad USB adapter

    	config AKSYS_QRD_FF
    		bool "AKSys gamepad USB adapter force feedback support"
    		depends on HID_AKSYS_QRD
    		select INPUT_FF_MEMLESS
    		---help---
    		Say Y here if you have a AKSys gamepad USB adapter and want to
    		enable force feedback support for it.
    		
 4. Merge \${this_project}/drivers/hid/Makefile into \${your_kernel_root}/drivers/hid/Makefile :
 Add the following code at the end of this file

		obj-$(CONFIG_HID_AKSYS_QRD)	+= hid-aksys.o
		
 5. Modify your kernel's default build configuration file. Add the following two lines:

        CONFIG_HID_AKSYS_QRD=m
        CONFIG_AKSYS_QRD_FF=y
