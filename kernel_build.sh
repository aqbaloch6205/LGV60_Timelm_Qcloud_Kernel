#!/bin/bash
#
# Copyright (C) 2020-2021 Adithya R.

set -e # Hentikan skrip jika ada perintah yang gagal

SECONDS=0 # Timer bawaan bash
ZIPNAME="Bhazheng-kernel-LMV600$(date '+%Y%m%d-%H%M').zip"
AK3_DIR="$HOME/android/AnyKernel3"
DEFCONFIG="vendor/arabella_defconfig"
LOCAL_SAVE_DIR="$HOME" # Direktori penyimpanan lokal
LOG_FILE="$LOCAL_SAVE_DIR/build_$(date '+%Y%m%d-%H%M').log" # Nama file log
DESKTOP_DIR="$HOME/Desktop" # Direktori Desktop

# Bersihkan dan siapkan direktori build
make clean &>> "$LOG_FILE"
make mrproper &>> "$LOG_FILE"

# Informasi build
export KBUILD_BUILD_USER=Bhazheng
export KBUILD_BUILD_HOST=cachyos
export ARCH=arm64
export SUBARCH=ARM64
export CLANG_PATH="$HOME/r547379/bin" # Gunakan path absolut untuk CLANG_PATH
export PATH="$CLANG_PATH:$PATH"
# export DTC_EXT="$LOCAL_SAVE_DIR/Toolchain/dtc_kernel/linux-x86/dtc/dtc" # Gunakan path absolut

# Regenerate defconfig jika diperlukan
if [[ $1 = "-r" || $1 = "--regen" ]]; then
    make O=out ARCH=arm64 $DEFCONFIG savedefconfig &> "$LOG_FILE"
    cp out/defconfig arch/arm64/configs/$DEFCONFIG &>> "$LOG_FILE"
    exit
fi

mkdir -p out &>> "$LOG_FILE"

# Konfigurasi variabel lingkungan
# export CROSS_COMPILE="~/aarch64-linux-android-4.9/bin/aarch64-linux-android-" # Gunakan tanda kutip untuk string
# export CROSS_COMPILE_ARM32="~/arm-linux-androideabi-4.9/bin/arm-linux-androideabi-" # Gunakan tanda kutip untuk string
# export CROSS_COMPILE=aarch64-linux-gnu-
# export CROSS_COMPILE_ARM32=arm-linux-gnueabi-
# export CLANG_TRIPLE="~/aarch64-linux-android-4.9/bin/aarch64-linux-gnu-" # Gunakan tanda kutip untuk string
# export CLANG_TRIPLE="~/aarch64-linux-android-4.9/bin/aarch64-linux-gnu-" # Gunakan tanda kutip untuk string

# Konfigurasi Kernel
# make CC=clang AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip O=out $DEFCONFIG &>> "$LOG_FILE"

# Persiapan direktori output

make O=out $DEFCONFIG &>> "$LOG_FILE"

echo -e "\nStarting compilation...\n" | tee -a "$LOG_FILE"

# Kompilasi Kernel
make -j$(nproc) O=out CC=clang CROSS_COMPILE=aarch64-linux-gnu- LLVM=1 LLVM_IAS=1 &>> "$LOG_FILE"
