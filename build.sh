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
DEFCONFIG="vendor/JhatPat_defconfig"
OUT_DIR="out"

# Verify toolchain
if ! command -v clang >/dev/null 2>&1; then
    echo "Error: Clang not found at $TOOLCHAIN_PATH"
    exit 1
fi

echo "Cleaning old builds..."
rm -rf $OUT_DIR anykernel/ *.zip

echo "Cloning AnyKernel3..."
git clone https://github.com/aqbaloch6205/AnyKernel3 -b kona --single-branch --depth=1 anykernel

echo "Starting Build for Jhat-Pat..."
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
    ZIP_NAME="Jhat-Pat-Kernel-Qcloudfx-$(date +%Y%m%d)-${GIT_COMMIT_ID}.zip"
    zip -r9 "../$ZIP_NAME" ./* -x .git .gitignore out/
    cd ..
    
    echo "Build Complete: $ZIP_NAME"
else
    echo "Build Failed: Image not found."
    exit 1
fi

<<<<<<< HEAD
=======
echo "Generating [out/arch/arm64/boot/dtb]......"
find out/arch/arm64/boot/dts -name '*.dtb' -exec cat {} + >out/arch/arm64/boot/dtb

rm -rf anykernel/kernels/

mkdir -p anykernel/kernels/

cp out/arch/arm64/boot/Image anykernel/kernels/
cp out/arch/arm64/boot/dtb anykernel/kernels/

cd anykernel 

ZIP_FILENAME=Kernel_AOSP_${TARGET_DEVICE}_${KSU_ZIP_STR}_$(date +'%Y%m%d_%H%M%S')_anykernel3_${GIT_COMMIT_ID}.zip

zip -r9 $ZIP_FILENAME ./* -x .git .gitignore out/ ./*.zip

mv $ZIP_FILENAME ../

cd ..


echo "Build for AOSP finished."

# ------------- End of Building for AOSP -------------
#  If you don't need AOSP you can comment out the above block [Building for AOSP]


# ------------- Building for MIUI -------------


echo "Clearning [out/] and build for MIUI....."
rm -rf out/

dts_source=arch/arm64/boot/dts/vendor/qcom

# Backup dts
cp -a ${dts_source} .dts.bak

# Correct panel dimensions on MIUI builds
sed -i 's/<154>/<1537>/g' ${dts_source}/dsi-panel-j1s*
sed -i 's/<154>/<1537>/g' ${dts_source}/dsi-panel-j2*
sed -i 's/<155>/<1544>/g' ${dts_source}/dsi-panel-j3s-37-02-0a-dsc-video.dtsi
sed -i 's/<155>/<1545>/g' ${dts_source}/dsi-panel-j11-38-08-0a-fhd-cmd.dtsi
sed -i 's/<155>/<1546>/g' ${dts_source}/dsi-panel-k11a-38-08-0a-dsc-cmd.dtsi
sed -i 's/<155>/<1546>/g' ${dts_source}/dsi-panel-l11r-38-08-0a-dsc-cmd.dtsi
sed -i 's/<70>/<695>/g' ${dts_source}/dsi-panel-j11-38-08-0a-fhd-cmd.dtsi
sed -i 's/<70>/<695>/g' ${dts_source}/dsi-panel-j3s-37-02-0a-dsc-video.dtsi
sed -i 's/<70>/<695>/g' ${dts_source}/dsi-panel-k11a-38-08-0a-dsc-cmd.dtsi
sed -i 's/<70>/<695>/g' ${dts_source}/dsi-panel-l11r-38-08-0a-dsc-cmd.dtsi
sed -i 's/<71>/<710>/g' ${dts_source}/dsi-panel-j1s*
sed -i 's/<71>/<710>/g' ${dts_source}/dsi-panel-j2*

# Enable back mi smartfps while disabling qsync min refresh-rate
sed -i 's/\/\/ mi,mdss-dsi-pan-enable-smart-fps/mi,mdss-dsi-pan-enable-smart-fps/g' ${dts_source}/dsi-panel*
sed -i 's/\/\/ mi,mdss-dsi-smart-fps-max_framerate/mi,mdss-dsi-smart-fps-max_framerate/g' ${dts_source}/dsi-panel*
sed -i 's/\/\/ qcom,mdss-dsi-pan-enable-smart-fps/qcom,mdss-dsi-pan-enable-smart-fps/g' ${dts_source}/dsi-panel*
sed -i 's/qcom,mdss-dsi-qsync-min-refresh-rate/\/\/qcom,mdss-dsi-qsync-min-refresh-rate/g' ${dts_source}/dsi-panel*

# Enable back refresh rates supported on MIUI
sed -i 's/120 90 60/120 90 60 50 30/g' ${dts_source}/dsi-panel-g7a-36-02-0c-dsc-video.dtsi
sed -i 's/120 90 60/120 90 60 50 30/g' ${dts_source}/dsi-panel-g7a-37-02-0a-dsc-video.dtsi
sed -i 's/120 90 60/120 90 60 50 30/g' ${dts_source}/dsi-panel-g7a-37-02-0b-dsc-video.dtsi
sed -i 's/144 120 90 60/144 120 90 60 50 48 30/g' ${dts_source}/dsi-panel-j3s-37-02-0a-dsc-video.dtsi


# Enable back brightness control from dtsi
sed -i 's/\/\/39 00 00 00 00 00 03 51 03 FF/39 00 00 00 00 00 03 51 03 FF/g' ${dts_source}/dsi-panel-j9-38-0a-0a-fhd-video.dtsi
sed -i 's/\/\/39 00 00 00 00 00 03 51 0D FF/39 00 00 00 00 00 03 51 0D FF/g' ${dts_source}/dsi-panel-j2-p2-1-38-0c-0a-dsc-cmd.dtsi
sed -i 's/\/\/39 00 00 00 00 00 05 51 0F 8F 00 00/39 00 00 00 00 00 05 51 0F 8F 00 00/g' ${dts_source}/dsi-panel-j1s-42-02-0a-dsc-cmd.dtsi
sed -i 's/\/\/39 00 00 00 00 00 05 51 0F 8F 00 00/39 00 00 00 00 00 05 51 0F 8F 00 00/g' ${dts_source}/dsi-panel-j1s-42-02-0a-mp-dsc-cmd.dtsi
sed -i 's/\/\/39 00 00 00 00 00 05 51 0F 8F 00 00/39 00 00 00 00 00 05 51 0F 8F 00 00/g' ${dts_source}/dsi-panel-j2-mp-42-02-0b-dsc-cmd.dtsi
sed -i 's/\/\/39 00 00 00 00 00 05 51 0F 8F 00 00/39 00 00 00 00 00 05 51 0F 8F 00 00/g' ${dts_source}/dsi-panel-j2-p2-1-42-02-0b-dsc-cmd.dtsi
sed -i 's/\/\/39 00 00 00 00 00 05 51 0F 8F 00 00/39 00 00 00 00 00 05 51 0F 8F 00 00/g' ${dts_source}/dsi-panel-j2s-mp-42-02-0a-dsc-cmd.dtsi
sed -i 's/\/\/39 01 00 00 00 00 03 51 00 00/39 01 00 00 00 00 03 51 00 00/g' ${dts_source}/dsi-panel-j2-38-0c-0a-dsc-cmd.dtsi
sed -i 's/\/\/39 01 00 00 00 00 03 51 00 00/39 01 00 00 00 00 03 51 00 00/g' ${dts_source}/dsi-panel-j2-38-0c-0a-dsc-cmd.dtsi
sed -i 's/\/\/39 01 00 00 00 00 03 51 03 FF/39 01 00 00 00 00 03 51 03 FF/g' ${dts_source}/dsi-panel-j11-38-08-0a-fhd-cmd.dtsi
sed -i 's/\/\/39 01 00 00 00 00 03 51 03 FF/39 01 00 00 00 00 03 51 03 FF/g' ${dts_source}/dsi-panel-j9-38-0a-0a-fhd-video.dtsi
sed -i 's/\/\/39 01 00 00 00 00 03 51 07 FF/39 01 00 00 00 00 03 51 07 FF/g' ${dts_source}/dsi-panel-j1u-42-02-0b-dsc-cmd.dtsi
sed -i 's/\/\/39 01 00 00 00 00 03 51 07 FF/39 01 00 00 00 00 03 51 07 FF/g' ${dts_source}/dsi-panel-j2-42-02-0b-dsc-cmd.dtsi
sed -i 's/\/\/39 01 00 00 00 00 03 51 07 FF/39 01 00 00 00 00 03 51 07 FF/g' ${dts_source}/dsi-panel-j2-p1-42-02-0b-dsc-cmd.dtsi
sed -i 's/\/\/39 01 00 00 00 00 03 51 0F FF/39 01 00 00 00 00 03 51 0F FF/g' ${dts_source}/dsi-panel-j1u-42-02-0b-dsc-cmd.dtsi
sed -i 's/\/\/39 01 00 00 00 00 03 51 0F FF/39 01 00 00 00 00 03 51 0F FF/g' ${dts_source}/dsi-panel-j2-42-02-0b-dsc-cmd.dtsi
sed -i 's/\/\/39 01 00 00 00 00 03 51 0F FF/39 01 00 00 00 00 03 51 0F FF/g' ${dts_source}/dsi-panel-j2-p1-42-02-0b-dsc-cmd.dtsi
sed -i 's/\/\/39 01 00 00 00 00 05 51 07 FF 00 00/39 01 00 00 00 00 05 51 07 FF 00 00/g' ${dts_source}/dsi-panel-j1s-42-02-0a-dsc-cmd.dtsi
sed -i 's/\/\/39 01 00 00 00 00 05 51 07 FF 00 00/39 01 00 00 00 00 05 51 07 FF 00 00/g' ${dts_source}/dsi-panel-j1s-42-02-0a-mp-dsc-cmd.dtsi
sed -i 's/\/\/39 01 00 00 00 00 05 51 07 FF 00 00/39 01 00 00 00 00 05 51 07 FF 00 00/g' ${dts_source}/dsi-panel-j2-mp-42-02-0b-dsc-cmd.dtsi
sed -i 's/\/\/39 01 00 00 00 00 05 51 07 FF 00 00/39 01 00 00 00 00 05 51 07 FF 00 00/g' ${dts_source}/dsi-panel-j2-p2-1-42-02-0b-dsc-cmd.dtsi
sed -i 's/\/\/39 01 00 00 00 00 05 51 07 FF 00 00/39 01 00 00 00 00 05 51 07 FF 00 00/g' ${dts_source}/dsi-panel-j2s-mp-42-02-0a-dsc-cmd.dtsi
sed -i 's/\/\/39 01 00 00 01 00 03 51 03 FF/39 01 00 00 01 00 03 51 03 FF/g' ${dts_source}/dsi-panel-j11-38-08-0a-fhd-cmd.dtsi
sed -i 's/\/\/39 01 00 00 11 00 03 51 03 FF/39 01 00 00 11 00 03 51 03 FF/g' ${dts_source}/dsi-panel-j2-p2-1-38-0c-0a-dsc-cmd.dtsi


make $MAKE_ARGS ${TARGET_DEVICE}_defconfig

if [ $KSU_ENABLE -eq 1 ]; then
    scripts/config --file out/.config -e KSU
else
    scripts/config --file out/.config -d KSU
fi


scripts/config --file out/.config \
    --set-str STATIC_USERMODEHELPER_PATH /system/bin/micd \
    -e PERF_CRITICAL_RT_TASK	\
    -e SF_BINDER		\
    -e OVERLAY_FS		\
    -d DEBUG_FS \
    -e MIGT \
    -e MIGT_ENERGY_MODEL \
    -e MIHW \
    -e PACKAGE_RUNTIME_INFO \
    -e BINDER_OPT \
    -e KPERFEVENTS \
    -e MILLET \
    -e PERF_HUMANTASK \
    -d LTO_CLANG \
    -d LOCALVERSION_AUTO \
    -e SF_BINDER \
    -e XIAOMI_MIUI \
    -d MI_MEMORY_SYSFS \
    -e TASK_DELAY_ACCT \
    -e MIUI_ZRAM_MEMORY_TRACKING \
    -d CONFIG_MODULE_SIG_SHA512 \
    -d CONFIG_MODULE_SIG_HASH \
    -e MI_FRAGMENTION \
    -e PERF_HELPER \

make $MAKE_ARGS -j$(nproc)



if [ -f "out/arch/arm64/boot/Image" ]; then
    echo "The file [out/arch/arm64/boot/Image] exists. MIUI Build successfully."
else
    echo "The file [out/arch/arm64/boot/Image] does not exist. Seems MIUI build failed."
    exit 1
fi

echo "Generating [out/arch/arm64/boot/dtb]......"
find out/arch/arm64/boot/dts -name '*.dtb' -exec cat {} + >out/arch/arm64/boot/dtb


# Restore modified dts
rm -rf ${dts_source}
mv .dts.bak ${dts_source}

rm -rf anykernel/kernels/
mkdir -p anykernel/kernels/

cp out/arch/arm64/boot/Image anykernel/kernels/
cp out/arch/arm64/boot/dtb anykernel/kernels/

echo "Build for MIUI finished."
# ------------- End of Building for MIUI -------------
#  If you don't need MIUI you can comment out the above block [Building for MIUI]


cd anykernel 

ZIP_FILENAME=Kernel_MIUI_${TARGET_DEVICE}_${KSU_ZIP_STR}_$(date +'%Y%m%d_%H%M%S')_anykernel3_${GIT_COMMIT_ID}.zip

zip -r9 $ZIP_FILENAME ./* -x .git .gitignore out/ ./*.zip

mv $ZIP_FILENAME ../

cd ..

echo "Done. The flashable zip is: [./$ZIP_FILENAME]"
>>>>>>> 1b1a44df5fec (Import perf_helper for MIUI build)
