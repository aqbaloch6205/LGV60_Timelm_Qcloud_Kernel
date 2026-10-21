#!/usr/bin/env bash
set -Eeuo pipefail

# =========================================================
# Jhat-Pat Kernel - Next Gen 2.0
# Device: LG V60 ThinQ (LM-V600 / timelm)
# Toolchain: ZyC Clang 16
# Optional: ReSukiSU + SuSFS + KPM
# =========================================================

# -------------------- Configuration ----------------------

TOOLCHAIN_PATH="$HOME/zyc-clang/bin"
DEFCONFIG="vendor/JhatPat_defconfig"
OUT_DIR="out"
ANYKERNEL_DIR="anykernel"

export KBUILD_BUILD_USER="QCloudfx"
export KBUILD_BUILD_HOST="Abdul-Qadeer"
export ARCH=arm64
export SUBARCH=arm64
export PATH="$TOOLCHAIN_PATH:$PATH"

export CCACHE_DIR="${CCACHE_DIR:-$HOME/.cache/ccache_mikernel}"
export CCACHE_MAXSIZE="${CCACHE_MAXSIZE:-5G}"
export USE_CCACHE=1

KSU_ENABLE=0
KSU_ZIP_STR="NoKSU"

if [[ "${1:-}" == "ksu" ]]; then
    KSU_ENABLE=1
    KSU_ZIP_STR="ReSukiSU-SuSFS-KPM"
elif [[ -n "${1:-}" ]]; then
    echo "[!] Usage: $0 [ksu]"
    exit 2
fi

# -------------------- Preflight --------------------------

if [[ ! -f Makefile ]]; then
    echo "[!] Run this script from the kernel source root."
    exit 1
fi

if [[ ! -f "$DEFCONFIG" ]]; then
    echo "[!] Defconfig not found: $DEFCONFIG"
    exit 1
fi

if [[ ! -x "$TOOLCHAIN_PATH/clang" ]]; then
    echo "[!] Clang not found: $TOOLCHAIN_PATH/clang"
    exit 1
fi

if ! command -v ccache >/dev/null 2>&1; then
    echo "[!] ccache is not installed."
    exit 1
fi

if ! command -v zip >/dev/null 2>&1; then
    echo "[!] zip is not installed."
    exit 1
fi

if ! command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
    echo "[!] aarch64-linux-gnu-gcc is missing."
    echo "[!] Install the required cross-compiler or verify your toolchain."
    exit 1
fi

if ! command -v arm-linux-gnueabi-gcc >/dev/null 2>&1; then
    echo "[!] arm-linux-gnueabi-gcc is missing."
    echo "[!] Install the required 32-bit cross-compiler."
    exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "[!] Git repository not detected."
    exit 1
fi

GIT_COMMIT_ID="$(git rev-parse --short=8 HEAD)"
BUILD_DATE="$(date +'%Y%m%d_%H%M%S')"

echo "========================================================="
echo " Thunder Kernel - Next Gen 2.0"
echo " Device: LG V60 ThinQ"
echo " Defconfig: $DEFCONFIG"
echo " Commit: $GIT_COMMIT_ID"
echo " KernelSU: $KSU_ENABLE"
echo "========================================================="

echo "[*] Clang version:"
clang --version

mkdir -p "$CCACHE_DIR"
ccache --max-size="$CCACHE_MAXSIZE"

# -------------------- Clean old build --------------------

echo "[*] Cleaning previous output..."

rm -rf "$OUT_DIR" "$ANYKERNEL_DIR"
rm -f Jhat-Pat-V60-*.zip

# -------------------- KernelSU Setup ---------------------

if [[ "$KSU_ENABLE" -eq 1 ]]; then
    echo "========================================================="
    echo "[*] Installing ReSukiSU integration"
    echo "========================================================="

    # Uses the same ReSukiSU setup source as the Xiaomi
    # reference workflow. Review upstream changes before use.
    curl -fLSs \
      "https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/main/kernel/setup.sh" \
      | bash

    echo "[*] ReSukiSU setup command completed."
    echo "[!] Manual hook integration must already be supported"
    echo "[!] by this kernel source for the selected integration."
fi

# -------------------- AnyKernel3 Setup -------------------

echo "[*] Cloning Jhat-Pat AnyKernel3..."

git clone \
    https://github.com/aqbaloch6205/AnyKernel3 \
    -b master \
    --single-branch \
    --depth=1 \
    "$ANYKERNEL_DIR"

# -------------------- Make Configuration -----------------

MAKE_ARGS=(
    "O=$OUT_DIR"
    ARCH=arm64
    SUBARCH=arm64
    CC="ccache clang"
    HOSTCC=clang
    CROSS_COMPILE=aarch64-linux-gnu-
    CROSS_COMPILE_ARM32=arm-linux-gnueabi-
    LLVM=1
    LLVM_IAS=1
    KCFLAGS="-Wno-error -Wno-error=incompatible-pointer-types"
)

echo "[*] Generating kernel defconfig..."

make "${MAKE_ARGS[@]}" "$DEFCONFIG"

CONFIG_FILE="$OUT_DIR/.config"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "[!] Kernel .config was not generated."
    exit 1
fi

# -------------------- KernelSU Configuration -------------

if [[ "$KSU_ENABLE" -eq 1 ]]; then
    echo "[*] Enabling ReSukiSU / SuSFS / KPM options..."

    ./scripts/config --file "$CONFIG_FILE" \
        -e KSU \
        -e THREAD_INFO_IN_TASK \
        -e KSU_SUSFS \
        -e KSU_SUSFS_SUS_PATH \
        -e KSU_SUSFS_SUS_MOUNT \
        -e KSU_SUSFS_SUS_KSTAT \
        -e KSU_SUSFS_SPOOF_UNAME \
        -e KSU_SUSFS_ENABLE_LOG \
        -e KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS \
        -e KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG \
        -e KSU_SUSFS_OPEN_REDIRECT \
        -e KSU_SUSFS_SUS_MAP \
        -e KPM \
        -e KALLSYMS \
        -e KALLSYMS_ALL \
        -e PERF_HELPER
else
    echo "[*] Disabling KernelSU / SuSFS / KPM options..."

    ./scripts/config --file "$CONFIG_FILE" \
        -d KSU \
        -d KSU_SUSFS \
        -d KSU_SUSFS_SUS_PATH \
        -d KSU_SUSFS_SUS_MOUNT \
        -d KSU_SUSFS_SUS_KSTAT \
        -d KSU_SUSFS_SPOOF_UNAME \
        -d KSU_SUSFS_ENABLE_LOG \
        -d KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS \
        -d KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG \
        -d KSU_SUSFS_OPEN_REDIRECT \
        -d KSU_SUSFS_SUS_MAP \
        -d KPM \
        -e PERF_HELPER
fi

# Resolve Kconfig dependencies.
echo "[*] Resolving kernel configuration..."

make "${MAKE_ARGS[@]}" olddefconfig

# -------------------- Verify Configuration ---------------

if [[ "$KSU_ENABLE" -eq 1 ]]; then
    echo "[*] Verifying required configuration symbols..."

    for symbol in KSU KSU_SUSFS KPM KALLSYMS KALLSYMS_ALL; do
        if ! grep -qx "CONFIG_${symbol}=y" "$CONFIG_FILE"; then
            echo "[!] Required symbol CONFIG_${symbol}=y is missing."
            echo "[!] Check source support and Kconfig dependencies."
            exit 1
        fi
    done

    echo "[+] Core KSU / SuSFS / KPM configuration verified."
fi

# -------------------- Compile Kernel ----------------------

echo "========================================================="
echo "[*] Compiling Jhat-Pat kernel..."
echo "========================================================="

make "${MAKE_ARGS[@]}" -j"$(nproc)"

BOOT_DIR="$OUT_DIR/arch/arm64/boot"
IMAGE="$BOOT_DIR/Image"

if [[ ! -s "$IMAGE" ]]; then
    echo "[!] Kernel compilation did not produce a valid Image."
    exit 1
fi

echo "[+] Kernel Image generated."

# -------------------- Merge DTBs --------------------------

echo "[*] Collecting device tree binaries..."

if [[ ! -d "$BOOT_DIR/dts" ]]; then
    echo "[!] DTB directory not found: $BOOT_DIR/dts"
    exit 1
fi

DTB_COUNT="$(find "$BOOT_DIR/dts" -type f -name '*.dtb' | wc -l)"

if [[ "$DTB_COUNT" -eq 0 ]]; then
    echo "[!] No DTB files were generated."
    exit 1
fi

find "$BOOT_DIR/dts" -type f -name '*.dtb' -print0 \
    | sort -z \
    | xargs -0 cat > "$BOOT_DIR/dtb"

if [[ ! -s "$BOOT_DIR/dtb" ]]; then
    echo "[!] Combined DTB file is empty."
    exit 1
fi

echo "[+] Combined $DTB_COUNT DTB files."

# -------------------- KPM Patch ---------------------------

if [[ "$KSU_ENABLE" -eq 1 ]]; then
    echo "========================================================="
    echo "[*] Downloading SukiSU KernelPatch tool v0.13.0"
    echo "========================================================="

    PATCH_DIR="$BOOT_DIR"
    PATCH_URL="https://github.com/SukiSU-Ultra/SukiSU_KernelPatch_patch/releases/download/0.13.0/patch_linux"

    curl -fL --retry 3 "$PATCH_URL" -o "$PATCH_DIR/patch_linux"
    chmod +x "$PATCH_DIR/patch_linux"

    if [[ ! -s "$PATCH_DIR/patch_linux" ]]; then
        echo "[!] KernelPatch download failed."
        exit 1
    fi

    echo "[*] Applying KPM patch..."

    (
        cd "$PATCH_DIR"
        ./patch_linux
    )

    # This release/tool is expected to produce oImage.
    # Do not replace the original Image unless the output exists.
    if [[ ! -s "$PATCH_DIR/oImage" ]]; then
        echo "[!] KPM patch did not produce a non-empty oImage."
        echo "[!] Original Image has been preserved."
        exit 1
    fi

    mv "$PATCH_DIR/oImage" "$PATCH_DIR/Image"
    rm -f "$PATCH_DIR/patch_linux"

    echo "[+] Patched kernel Image verified."
fi

# -------------------- Prepare AnyKernel3 ------------------

echo "[*] Preparing flashable ZIP..."

mkdir -p "$ANYKERNEL_DIR/kernels"

cp "$BOOT_DIR/Image" "$ANYKERNEL_DIR/kernels/Image"
cp "$BOOT_DIR/dtb" "$ANYKERNEL_DIR/kernels/dtb"

if [[ -s "$BOOT_DIR/dtbo.img" ]]; then
    cp "$BOOT_DIR/dtbo.img" "$ANYKERNEL_DIR/kernels/dtbo.img"
fi

# -------------------- Package ZIP -------------------------

ZIP_NAME="Jhat-Pat-V60-${KSU_ZIP_STR}-${BUILD_DATE}-${GIT_COMMIT_ID}.zip"

(
    cd "$ANYKERNEL_DIR"
    zip -r9 "../$ZIP_NAME" . \
        -x ".git/*" ".gitignore" "out/*" "*.zip"
)

if [[ ! -s "$ZIP_NAME" ]]; then
    echo "[!] Flashable ZIP creation failed."
    exit 1
fi

echo "[*] Verifying ZIP integrity..."

unzip -t "$ZIP_NAME"

echo "========================================================="
echo "[+] BUILD COMPLETED"
echo "[+] Device: LG V60 ThinQ"
echo "[+] KernelSU: $KSU_ENABLE"
echo "[+] Image: $BOOT_DIR/Image"
echo "[+] DTB: $BOOT_DIR/dtb"
echo "[+] ZIP: $ZIP_NAME"
echo "========================================================="

echo "[*] ccache statistics:"
ccache -s