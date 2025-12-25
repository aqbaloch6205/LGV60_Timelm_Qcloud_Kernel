#!/bin/bash
set -e

# Toolchain and identity
TOOLCHAIN_PATH=$HOME/zyc-clang/bin
export KBUILD_BUILD_USER="QCloudfx"
export KBUILD_BUILD_HOST="Abdul-Qadeer"
export ARCH=arm64
export SUBARCH=arm64
export PATH="$TOOLCHAIN_PATH:$PATH"

GIT_COMMIT_ID=$(git rev-parse --short=8 HEAD)
DEFCONFIG="vendor/arabella_defconfig"
OUT_DIR="out"

# Verify toolchain
if ! command -v clang >/dev/null 2>&1; then
    echo "Error: Clang not found at $TOOLCHAIN_PATH"
    exit 1
fi

echo "Cleaning old builds..."
rm -rf $OUT_DIR anykernel/ *.zip

echo "Cloning AnyKernel3..."
git clone https://github.com/liyafe1997/AnyKernel3 -b kona --single-branch --depth=1 anykernel

echo "Starting Build for Arabella..."
# Use LLVM=1 to ensure the integrated linker/assembler is used
MAKE_ARGS="O=$OUT_DIR ARCH=arm64 CC=clang CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- LLVM=1 LLVM_IAS=1"

# 1. Generate Config
make $MAKE_ARGS $DEFCONFIG

# 2. Compile Kernel
make $MAKE_ARGS -j$(nproc)

# 3. Handle Outputs
if [ -f "$OUT_DIR/arch/arm64/boot/Image" ]; then
    echo "Kernel compiled successfully."
    
    # Generate concatenated DTB exactly like your previous logic
    echo "Merging DTBs..."
    find $OUT_DIR/arch/arm64/boot/dts -name '*.dtb' -exec cat {} + > $OUT_DIR/arch/arm64/boot/dtb

    # Prepare AnyKernel folder
    mkdir -p anykernel/kernels/
    cp $OUT_DIR/arch/arm64/boot/Image anykernel/kernels/
    cp $OUT_DIR/arch/arm64/boot/dtb anykernel/kernels/

    # Create Flashable Zip
    cd anykernel
    ZIP_NAME="Qcloudfx-Kernel-JhatPat-$(date +%Y%m%d)-${GIT_COMMIT_ID}.zip"
    zip -r9 "../$ZIP_NAME" ./* -x .git .gitignore out/
    cd ..
    
    echo "Build Complete: $ZIP_NAME"
else
    echo "Build Failed: Image not found."
    exit 1
fi

