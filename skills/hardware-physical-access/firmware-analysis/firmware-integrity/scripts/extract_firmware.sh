#!/bin/bash
# Firmware Extraction Helper
# Extracts firmware using binwalk and other tools

set -e

FIRMWARE_FILE="${1:-firmware.bin}"
OUTPUT_DIR="${2:-./extracted}"

if [[ ! -f "$FIRMWARE_FILE" ]]; then
    echo "Error: Firmware file not found: $FIRMWARE_FILE"
    echo "Usage: $0 <firmware_file> [output_directory]"
    echo "Example: $0 firmware.bin ./extracted"
    exit 1
fi

echo "=== Firmware Extraction ==="
echo "Input: $FIRMWARE_FILE"
echo "Output: $OUTPUT_DIR"
echo "Size: $(du -h "$FIRMWARE_FILE" | cut -f1)"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Check for required tools
if ! command -v binwalk &> /dev/null; then
    echo "Error: binwalk not found"
    echo "Install with: sudo apt-get install binwalk"
    exit 1
fi

# Extract firmware
echo "=== Extracting Firmware ==="
echo "Running binwalk extraction..."
binwalk -e -M "$FIRMWARE_FILE" -D "all" -d "$OUTPUT_DIR" 2>&1 | tee "$OUTPUT_DIR/extraction.log"

echo ""
echo "=== Extraction Complete ==="
echo ""

# Show extracted contents
echo "=== Extracted Contents ==="
if [[ -d "$OUTPUT_DIR" ]]; then
    echo "Directory structure:"
    find "$OUTPUT_DIR" -type f | head -30
    echo ""
    echo "Total files: $(find "$OUTPUT_DIR" -type f | wc -l)"
else
    echo "No files extracted"
fi
echo ""

# Identify key components
echo "=== Key Components ==="

# Find kernel
KERNEL=$(find "$OUTPUT_DIR" -name "*kernel*" -o -name "*vmlinux*" -o -name "*uImage*" 2>/dev/null | head -1)
if [[ -n "$KERNEL" ]]; then
    echo "Kernel: $KERNEL"
    file "$KERNEL" 2>/dev/null || true
else
    echo "Kernel: Not found"
fi
echo ""

# Find rootfs
ROOTFS=$(find "$OUTPUT_DIR" -type d -name "*rootfs*" -o -name "*squashfs*" -o -name "*jffs2*" 2>/dev/null | head -1)
if [[ -n "$ROOTFS" ]]; then
    echo "Rootfs: $ROOTFS"
else
    echo "Rootfs: Not found (may need manual extraction)"
fi
echo ""

# Find binaries
echo "=== Executable Binaries ==="
find "$OUTPUT_DIR" -type f -executable 2>/dev/null | head -10
echo ""

# Architecture detection
echo "=== Architecture Detection ==="
FIRST_BIN=$(find "$OUTPUT_DIR" -type f -executable 2>/dev/null | head -1)
if [[ -n "$FIRST_BIN" ]] && [[ -f "$FIRST_BIN" ]]; then
    file "$FIRST_BIN"
else
    echo "No executables found for architecture detection"
fi
echo ""

# Summary
echo "=== Summary ==="
echo "Extraction saved to: $OUTPUT_DIR"
echo ""
echo "Next steps:"
echo "1. Review extracted files: ls -la $OUTPUT_DIR"
echo "2. Identify architecture: file <binary>"
echo "3. Set up cross-compiler for target architecture"
echo "4. Use scripts/generate_payload.sh or scripts/cross_compile_backdoor.sh"
echo ""
echo "For more analysis:"
echo "  strings $FIRMWARE_FILE | grep -iE '(http|ssh|telnet|root)'
echo "  binwalk -D 'all' $FIRMWARE_FILE"
