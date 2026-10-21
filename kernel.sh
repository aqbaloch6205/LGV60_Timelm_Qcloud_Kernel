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
DEFCONFIG_FILE="arch/arm64/configs/$DEFCONFIG"

OUT_DIR="out"
ANYKERNEL_DIR="anykernel"

export KBUILD_BUILD_USER="QCloudFx"
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
    echo "Usage: $0 [ksu]"
    exit 2
fi

GIT_COMMIT_ID="$(git rev-parse --short=8 HEAD)"
BUILD_DATE="$(date +'%Y%m%d_%H%M%S')"

echo "========================================================="
echo " Jhat-Pat Kernel - Next Gen 2.0"
echo " Device: LG V60 ThinQ (timelm)"
echo " Toolchain: ZyC Clang 16"
echo " Defconfig: $DEFCONFIG_FILE"
echo " Commit: $GIT_COMMIT_ID"
echo " KernelSU: $KSU_ENABLE"
echo "========================================================="

# -------------------- CCACHE -----------------------------

mkdir -p "$CCACHE_DIR"
ccache --max-size="$CCACHE_MAXSIZE"

# -------------------- Clean Old Build --------------------

echo "[*] Cleaning old builds..."

rm -rf "$OUT_DIR" "$ANYKERNEL_DIR"
rm -f Jhat-Pat-V60-*.zip

# -------------------- AnyKernel3 Setup -------------------

echo "[*] Cloning AnyKernel3 (kona)..."

git clone https://github.com/aqbaloch6205/AnyKernel3 --single-branch --depth=1 "$ANYKERNEL_DIR"

# -------------------- ZyC Clang Fix ----------------------

echo "[*] Patching ARM64 target for ZyC Clang 16..."

sed -i 's/cortex-a77\.cortex-a55/cortex-a77/g' \
    arch/arm64/Makefile

# -------------------- KernelSU Setup ---------------------

if [[ "$KSU_ENABLE" -eq 1 ]]; then
    echo "========================================================="
    echo "[*] Installing ReSukiSU (builtin mode)"
    echo "========================================================="

    curl -fLSs --retry 3 \
        "https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/main/kernel/setup.sh" \
        | bash -s builtin

    echo "[*] ReSukiSU setup finished."
fi

# -------------------- Make Arguments ---------------------

MAKE_ARGS=(
    "O=$OUT_DIR"
    "ARCH=arm64"
    "SUBARCH=arm64"
    "CC=clang"
    "HOSTCC=clang"
    "CLANG_TRIPLE=aarch64-linux-gnu-"
    "CROSS_COMPILE=aarch64-linux-gnu-"
    "CROSS_COMPILE_ARM32=arm-linux-gnueabi-"
    "CROSS_COMPILE_COMPAT=arm-linux-gnueabi-"
    "LLVM=1"
    "LLVM_IAS=1"
    "LD=ld.lld"
    "AR=llvm-ar"
    "NM=llvm-nm"
    "OBJCOPY=llvm-objcopy"
    "OBJDUMP=llvm-objdump"
    "STRIP=llvm-strip"
    "KCFLAGS=-Wno-error -Wno-error=incompatible-pointer-types"
)

# -------------------- Generate Defconfig -----------------

echo "[*] Generating JhatPat defconfig..."

make "${MAKE_ARGS[@]}" "$DEFCONFIG"

CONFIG_FILE="$OUT_DIR/.config"

# -------------------- KernelSU / SuSFS Config ------------

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
    echo "[*] Disabling KernelSU / SuSFS / KPM..."

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
        -d KSU_DEBUG \
        -d KALLSYMS_ALL \
        -e PERF_HELPER
fi

# -------------------- Resolve Configuration --------------

echo "[*] Resolving Kconfig dependencies..."

make "${MAKE_ARGS[@]}" olddefconfig

# -------------------- Compile Kernel ---------------------

echo "========================================================="
echo "[*] Compiling Jhat-Pat kernel..."
echo "========================================================="

make "${MAKE_ARGS[@]}" -j"$(nproc)"

BOOT_DIR="$OUT_DIR/arch/arm64/boot"

# -------------------- Merge DTBs -------------------------

echo "[*] Merging DTBs..."

find "$BOOT_DIR/dts" -type f -name '*.dtb' -print0 \
    | sort -z \
    | xargs -0 cat > "$BOOT_DIR/dtb"

# -------------------- KPM Patch --------------------------

if [[ "$KSU_ENABLE" -eq 1 ]]; then
    echo "========================================================="
    echo "[*] Applying SukiSU KernelPatch v0.13.0"
    echo "========================================================="

    PATCH_URL="https://github.com/SukiSU-Ultra/SukiSU_KernelPatch_patch/releases/download/0.13.0/patch_linux"

    curl -fL --retry 3 \
        "$PATCH_URL" \
        -o "$BOOT_DIR/patch_linux"

    chmod +x "$BOOT_DIR/patch_linux"

    (
        cd "$BOOT_DIR"
        ./patch_linux
        mv oImage Image
        rm -f patch_linux
    )

    echo "[+] KPM patch command completed."
fi

# -------------------- Prepare AnyKernel3 -----------------

echo "[*] Preparing AnyKernel3..."

mkdir -p "$ANYKERNEL_DIR/kernels"

cp "$BOOT_DIR/Image" "$ANYKERNEL_DIR/kernels/Image"
cp "$BOOT_DIR/dtb" "$ANYKERNEL_DIR/kernels/dtb"

if [[ -f "$BOOT_DIR/dtbo.img" ]]; then
    cp "$BOOT_DIR/dtbo.img" "$ANYKERNEL_DIR/kernels/dtbo.img"
fi

# -------------------- Create Flashable ZIP ----------------

ZIP_NAME="Jhat-Pat-V60-${KSU_ZIP_STR}-${BUILD_DATE}-${GIT_COMMIT_ID}.zip"

echo "[*] Creating flashable ZIP..."

(
    cd "$ANYKERNEL_DIR"
    zip -r9 "../$ZIP_NAME" . \
        -x ".git/*" ".gitignore" "out/*" "*.zip"
)

# -------------------- Finished ----------------------------

echo "========================================================="
echo "[+] BUILD PROCESS FINISHED"
echo "[+] Device: LG V60 ThinQ (timelm)"
echo "[+] KernelSU: $KSU_ENABLE"
echo "[+] Image: $BOOT_DIR/Image"
echo "[+] DTB: $BOOT_DIR/dtb"
echo "[+] ZIP: $ZIP_NAME"
echo "========================================================="

echo "[*] CCACHE statistics:"
ccache -s
