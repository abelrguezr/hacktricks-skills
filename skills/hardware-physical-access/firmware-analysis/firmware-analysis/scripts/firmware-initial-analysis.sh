#!/bin/bash
# Firmware Initial Analysis Script
# Performs basic inspection of a firmware binary

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <firmware.bin> [output_dir]"
    echo "Performs initial analysis on a firmware binary"
    exit 1
fi

FIRMWARE="$1"
OUTPUT_DIR="${2:-.}"

if [ ! -f "$FIRMWARE" ]; then
    echo "Error: File not found: $FIRMWARE"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "=== Firmware Initial Analysis ==="
echo "Target: $FIRMWARE"
echo "Output: $OUTPUT_DIR"
echo ""

# File type identification
echo "[1/7] File type identification..."
file "$FIRMWARE" > "$OUTPUT_DIR/file_output.txt"
cat "$OUTPUT_DIR/file_output.txt"
echo ""

# String extraction
echo "[2/7] Extracting strings..."
strings -n8 "$FIRMWARE" > "$OUTPUT_DIR/strings.txt"
echo "Extracted $(wc -l < "$OUTPUT_DIR/strings.txt") strings to strings.txt"

# Strings with hex offsets
echo "[3/7] Extracting strings with offsets..."
strings -tx "$FIRMWARE" > "$OUTPUT_DIR/strings_hex.txt"
echo "Saved to strings_hex.txt"

# Header dump
echo "[4/7] Dumping header (first 512 bytes)..."
hexdump -C -n 512 "$FIRMWARE" > "$OUTPUT_DIR/hexdump_header.txt"
echo "Saved to hexdump_header.txt"

# Partition analysis
echo "[5/7] Checking for partitions..."
fdisk -lu "$FIRMWARE" > "$OUTPUT_DIR/fdisk_output.txt" 2>&1 || true
cat "$OUTPUT_DIR/fdisk_output.txt"
echo ""

# Entropy analysis
echo "[6/7] Analyzing entropy..."
if command -v binwalk &> /dev/null; then
    binwalk -E "$FIRMWARE" > "$OUTPUT_DIR/entropy.txt" 2>&1 || true
    cat "$OUTPUT_DIR/entropy.txt"
else
    echo "Warning: binwalk not installed. Install with: pip install binwalk"
fi
echo ""

# Embedded file detection
echo "[7/7] Detecting embedded files..."
if command -v binwalk &> /dev/null; then
    binwalk "$FIRMWARE" > "$OUTPUT_DIR/binwalk_scan.txt" 2>&1 || true
    cat "$OUTPUT_DIR/binwalk_scan.txt"
else
    echo "Warning: binwalk not installed"
fi
echo ""

echo "=== Analysis Complete ==="
echo "Results saved to: $OUTPUT_DIR"
echo ""
echo "Next steps:"
echo "  - Review strings.txt for credentials and URLs"
echo "  - Check entropy.txt for encryption indicators"
echo "  - Use binwalk -ev <firmware> to extract filesystem"
