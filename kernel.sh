#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================
# Jhat-Pat Kernel - LG V60
# By QCloudFx
# ==============================

TOOLCHAIN_PATH="$HOME/zyc-clang/bin"
DEFCONFIG="vendor/JhatPat_defconfig"
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
    KSU_ZIP_STR="BakaSU-SuSFS-KPM"
elif [[ -n "${1:-}" ]]; then
    echo "Usage: $0 [ksu]"
    exit 2
fi

GIT_COMMIT_ID="$(git rev-parse --short=8 HEAD)"
BUILD_DATE="$(date +'%Y%m%d_%H%M%S')"

echo "===================================="
echo " Jhat-Pat Kernel - LG V60"
echo " Builder : QCloudFx"
echo " Commit  : $GIT_COMMIT_ID"
echo " KSU     : $KSU_ENABLE"
echo "===================================="

# ==============================
# Clean & ccache
# ==============================

mkdir -p "$CCACHE_DIR"
ccache --max-size="$CCACHE_MAXSIZE"

rm -rf "$OUT_DIR" "$ANYKERNEL_DIR"
rm -f Jhat-Pat-V60-*.zip

# ==============================
# AnyKernel3 - default branch
# ==============================

git clone \
    https://github.com/aqbaloch6205/AnyKernel3 \
    --single-branch \
    --depth=1 \
    "$ANYKERNEL_DIR"

# ==============================
# Kernel source adjustment
# ==============================

sed -i 's/cortex-a77\.cortex-a55/cortex-a77/g' \
    arch/arm64/Makefile

# ==============================
# BakaSU + nomount
# ==============================

if [[ "$KSU_ENABLE" -eq 1 ]]; then
    curl -LSs \
        "https://raw.githubusercontent.com/Baka-SU/BakaSU/main/kernel/setup.sh" \
        | bash

    curl -LSs \
        "https://raw.githubusercontent.com/maxsteeel/nomount/refs/heads/dev/kernel/setup.sh" \
        | bash
fi

# ==============================
# Compiler settings
# ==============================

MAKE_ARGS=(
    "O=$OUT_DIR"
    "ARCH=arm64"
    "SUBARCH=arm64"
    "CC=ccache clang"
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

# ==============================
# Generate defconfig
# ==============================

make "${MAKE_ARGS[@]}" "$DEFCONFIG"

CONFIG_FILE="$OUT_DIR/.config"

# ==============================
# KSU / SuSFS / KPM config
# ==============================

if [[ "$KSU_ENABLE" -eq 1 ]]; then

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

make "${MAKE_ARGS[@]}" olddefconfig

# ==============================
# Build kernel
# ==============================

make "${MAKE_ARGS[@]}" -j"$(nproc)"

BOOT_DIR="$OUT_DIR/arch/arm64/boot"

# ==============================
# Merge DTBs
# ==============================

find "$BOOT_DIR/dts" -type f -name '*.dtb' -print0 \
    | sort -z \
    | xargs -0 cat > "$BOOT_DIR/dtb"

# ==============================
# KPM patch
# ==============================

if [[ "$KSU_ENABLE" -eq 1 ]]; then

    PATCH_URL="https://github.com/SukiSU-Ultra/SukiSU_KernelPatch_patch/releases/download/0.13.0/patch_linux"

    curl -fL --retry 3 "$PATCH_URL" \
        -o "$BOOT_DIR/patch_linux"

    chmod +x "$BOOT_DIR/patch_linux"

    (
        cd "$BOOT_DIR"
        ./patch_linux
        mv oImage Image
        rm -f patch_linux
    )

fi

# ==============================
# Package AnyKernel3
# ==============================

mkdir -p "$ANYKERNEL_DIR/kernels"

cp "$BOOT_DIR/Image" "$ANYKERNEL_DIR/kernels/Image"
cp "$BOOT_DIR/dtb" "$ANYKERNEL_DIR/kernels/dtb"

if [[ -f "$BOOT_DIR/dtbo.img" ]]; then
    cp "$BOOT_DIR/dtbo.img" "$ANYKERNEL_DIR/dtbo.img"
fi

ZIP_NAME="Jhat-Pat-V60-${KSU_ZIP_STR}-${BUILD_DATE}-${GIT_COMMIT_ID}.zip"

(
    cd "$ANYKERNEL_DIR"
    zip -r9 "../$ZIP_NAME" . \
        -x ".git/*" ".gitignore" "out/*" "*.zip"
)

# ==============================
# Finish
# ==============================

ccache -s

echo "===================================="
echo " Build completed!"
echo " ZIP: $ZIP_NAME"
echo "===================================="
