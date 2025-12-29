#!/bin/bash
set -e

# --- Configuration ---
TOOLCHAIN_PATH=$HOME/zyc-clang/bin
export KBUILD_BUILD_USER="QCloudfx"
export KBUILD_BUILD_HOST="Abdul-Qadeer"
export ARCH=arm64
export SUBARCH=arm64
export PATH="$TOOLCHAIN_PATH:$PATH"

GIT_COMMIT_ID=$(git rev-parse --short=8 HEAD)
DEFCONFIG="vendor/JhatPat_defconfig"
OUT_DIR="out"
ANYKERNEL_DIR="anykernel"

# Determine if KSU is enabled
KSU_ENABLE=0
KSU_ZIP_STR="NoKSU"
if [ "$1" == "ksu" ]; then
    KSU_ENABLE=1
    KSU_ZIP_STR="KSU-SuSFS-v2.0.0"
fi

# Verify toolchain
if ! command -v clang >/dev/null 2>&1; then
    echo "Error: Clang not found at $TOOLCHAIN_PATH"
    exit 1
fi

echo "Cleaning old builds..."
rm -rf $OUT_DIR $ANYKERNEL_DIR *.zip

echo "Cloning AnyKernel3..."
git clone https://github.com/liyafe1997/AnyKernel3 -b kona --single-branch --depth=1 $ANYKERNEL_DIR

echo "Starting Build for Jhat-Pat (KSU=$KSU_ENABLE)..."

# --- FIXED SECTION: Using Array to handle quotes correctly ---
MAKE_ARGS=(
    O="$OUT_DIR"
    ARCH=arm64
    CC=clang
    CROSS_COMPILE=aarch64-linux-gnu-
    CROSS_COMPILE_ARM32=arm-linux-gnueabi-
    LLVM=1
    LLVM_IAS=1
    KCFLAGS="-Wno-error -Wno-error=incompatible-pointer-types"
)

# 1. Generate Base Config
make "${MAKE_ARGS[@]}" $DEFCONFIG

# 2. Inject SuSFS v2.0.0 & KSU Configs (Xiaomi Dev Method)
if [ $KSU_ENABLE -eq 1 ]; then
    echo "KSU is enabled"
    # Exact Xiaomi dev trick: pulling the remote setup logic
    curl -LSs "https://raw.githubusercontent.com/ApartTUSITU/SukiSU-Ultra/main/kernel/setup.sh" | bash -s ApartTUSITU
    
    echo "Applying SuSFS v2.0.0 Configs..."
    ./scripts/config --file $OUT_DIR/.config \
        -e KSU \
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
        -e THREAD_INFO_IN_TASK \
        -e KPM
else
    echo "KSU is disabled"
    ./scripts/config --file $OUT_DIR/.config -d KSU
fi

# 3. Compile Kernel
make "${MAKE_ARGS[@]}" -j$(nproc)

# 4. Handle Outputs
if [ -f "$OUT_DIR/arch/arm64/boot/Image" ]; then
    echo "Kernel compiled successfully."
    
    # Merge DTBs
    echo "Merging DTBs..."
    find $OUT_DIR/arch/arm64/boot/dts -name '*.dtb' -exec cat {} + > $OUT_DIR/arch/arm64/boot/dtb

    # KPM Support Patch (Xiaomi Dev Method)
    if [ $KSU_ENABLE -eq 1 ]; then
        echo "Applying KPM support patch..."
        cd $OUT_DIR/arch/arm64/boot/
        wget https://github.com/SukiSU-Ultra/SukiSU_KernelPatch_patch/releases/download/0.12.2/patch_linux
        chmod +x patch_linux
        ./patch_linux 
        rm Image
        mv oImage Image
        cd -
    fi

    # Prepare AnyKernel folder
    mkdir -p $ANYKERNEL_DIR/kernels/
    cp $OUT_DIR/arch/arm64/boot/Image $ANYKERNEL_DIR/kernels/
    cp $OUT_DIR/arch/arm64/boot/dtb $ANYKERNEL_DIR/kernels/

    # Create Flashable Zip
    cd $ANYKERNEL_DIR
    ZIP_NAME="Jhat-Pat-V60-${KSU_ZIP_STR}-$(date +%Y%m%d)-${GIT_COMMIT_ID}.zip"
    zip -r9 "../$ZIP_NAME" ./* -x .git .gitignore out/
    cd ..
    
    echo "Build Complete: $ZIP_NAME"
else
    echo "Build Failed: Image not found."
    exit 1
fi
