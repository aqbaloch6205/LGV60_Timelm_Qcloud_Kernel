#!/bin/bash
# LG V60 (timelm) DTB/DTBO Build Script (Clang-Linker Fixed)
set -euo pipefail

TOOLCHAIN_PATH="$HOME/zyc-clang/bin"
OUT_DIR="out"
DEFCONFIG="vendor/timelm-perf_defconfig"

# Check toolchain
if [ ! -d "$TOOLCHAIN_PATH" ]; then
    echo "Error: TOOLCHAIN_PATH [$TOOLCHAIN_PATH] does not exist."
    exit 1
fi

export PATH="$TOOLCHAIN_PATH:$PATH"
export ARCH=arm64
export SUBARCH=arm64

# Key Fix: Define the full LLVM toolset so vdso_prepare doesn't crash
MAKE_ARGS=(
    O="$OUT_DIR"
    CC=clang
    HOSTCC=gcc
    LD=ld.lld
    AR=llvm-ar
    NM=llvm-nm
    OBJCOPY=llvm-objcopy
    OBJDUMP=llvm-objdump
    STRIP=llvm-strip
    LLVM=1
    LLVM_IAS=1
    CROSS_COMPILE=aarch64-linux-gnu-
    CLANG_TRIPLE=aarch64-linux-gnu-
)

# Clean previous build
rm -rf "$OUT_DIR"

echo "--- CONFIGURING KERNEL ---"
make "${MAKE_ARGS[@]}" "$DEFCONFIG"

echo "--- CHECKING DTS FILES ---"
# Find the problematic DTS file and check it
PROBLEMATIC_DTS="arch/arm64/boot/dts/vendor/lge/kona-timelm/kona-timelm_lao_com/kona-timelm_dcm_jp_rev-0.0-overlay.dts"

if [ -f "$PROBLEMATIC_DTS" ]; then
    echo "Checking problematic DTS file: $PROBLEMATIC_DTS"
    
    # First, check syntax with dtc directly
    if [ -f "scripts/dtc/dtc" ]; then
        echo "Running dtc syntax check on problematic DTS..."
        ./scripts/dtc/dtc -I dts -O dts "$PROBLEMATIC_DTS" -o /dev/null 2>&1 | head -20
    fi
    
    # Check for common issues
    echo "Checking for common DTS issues..."
    
    # 1. Check for missing semicolons
    echo "1. Checking for missing semicolons..."
    grep -n ";" "$PROBLEMATIC_DTS" | tail -5 || true
    
    # 2. Check for unterminated strings
    echo "2. Checking string balance..."
    STRING_BALANCE=$(grep -o '"' "$PROBLEMATIC_DTS" | wc -l)
    if [ $((STRING_BALANCE % 2)) -ne 0 ]; then
        echo "WARNING: Unbalanced quotes in DTS file (count: $STRING_BALANCE)"
    fi
    
    # 3. Look for obvious syntax errors
    echo "3. Looking for common syntax patterns..."
    grep -n "{" "$PROBLEMATIC_DTS" | wc -l
    grep -n "}" "$PROBLEMATIC_DTS" | wc -l
    
    echo "DTS check complete. The file exists but may contain syntax errors."
else
    echo "ERROR: Problematic DTS file not found: $PROBLEMATIC_DTS"
    echo "Looking for similar files..."
    find arch/arm64/boot/dts/vendor/lge -name "*timelm*dcm*jp*.dts" 2>/dev/null || true
fi

# Also check all DTS files in the timelm directory
echo ""
echo "Checking all timelm DTS files..."
TIMELM_DTS_DIR="arch/arm64/boot/dts/vendor/lge/kona-timelm"
if [ -d "$TIMELM_DTS_DIR" ]; then
    echo "Found timelm DTS directory. Contains:"
    find "$TIMELM_DTS_DIR" -name "*.dts" | head -10
fi

echo ""
echo "--- BUILDING DTBs ONLY ---"
# We use V=1 to see the real error if it fails
# Temporarily continue on error to get more diagnostics
set +e
make "${MAKE_ARGS[@]}" V=1 dtbs 2>&1 | tee build.log
BUILD_STATUS=$?
set -e

if [ $BUILD_STATUS -ne 0 ]; then
    echo "=== BUILD FAILED ==="
    echo "Last 20 lines of build output:"
    tail -20 build.log
    
    echo ""
    echo "=== DTC ERROR ANALYSIS ==="
    # Extract DTC command that failed
    FAILED_CMD=$(grep -B5 "ERROR: Input tree has errors" build.log | grep "dtc" | tail -1)
    if [ -n "$FAILED_CMD" ]; then
        echo "Failed DTC command: $FAILED_CMD"
        
        # Try to extract the temporary DTS file path
        TEMP_DTS=$(echo "$FAILED_CMD" | grep -o "\.dts\.tmp[^ ]*" || echo "")
        if [ -n "$TEMP_DTS" ] && [ -f "$OUT_DIR/$TEMP_DTS" ]; then
            echo "Temporary DTS file exists at: $OUT_DIR/$TEMP_DTS"
            echo "First 10 lines of problematic DTS:"
            head -10 "$OUT_DIR/$TEMP_DTS"
        fi
    fi
    
    # Check if we should force build
    echo ""
    echo "=== POSSIBLE WORKAROUNDS ==="
    echo "1. Check the DTS file for syntax errors"
    echo "2. Try building with -f (force) flag by modifying the Makefile"
    echo "3. Remove or disable the problematic overlay if not needed"
    
    exit 1
fi

# Collect DTBs/DTBOs
DTB_OUT="$OUT_DIR/arch/arm64/boot/dtb"
mkdir -p "$DTB_OUT"
find "$OUT_DIR/arch/arm64/boot/dts" -name '*.dtb' -exec cp {} "$DTB_OUT/" \; 2>/dev/null || true
find "$OUT_DIR/arch/arm64/boot/dts" -name '*.dtbo' -exec cp {} "$DTB_OUT/" \; 2>/dev/null || true

echo "--- VERIFICATION ---"
if [ "$(ls -A $DTB_OUT 2>/dev/null)" ]; then
    echo "DTB/DTBO Build successful. Files found:"
    ls -la "$DTB_OUT/" | head -10
else
    echo "DTB/DTBO Build failed. No files found in $DTB_OUT."
    
    # Check what was actually built
    echo "Checking build output directory..."
    find "$OUT_DIR/arch/arm64/boot" -name "*.dtb" -o -name "*.dtbo" 2>/dev/null || true
    
    exit 1
fi

echo "Done. Check $DTB_OUT for compiled files."
