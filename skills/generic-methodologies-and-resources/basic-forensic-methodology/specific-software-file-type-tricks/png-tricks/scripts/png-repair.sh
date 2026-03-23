#!/bin/bash
# PNG Repair Script
# Attempts to repair corrupted PNG files using various methods

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <corrupted_png> [output_file]"
    echo "Example: $0 broken.png repaired.png"
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="${2:-repaired_$(basename "$INPUT_FILE")}"

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: File not found: $INPUT_FILE"
    exit 1
fi

echo "=== PNG Repair Attempt ==="
echo "Input:  $INPUT_FILE"
echo "Output: $OUTPUT_FILE"
echo ""

# Method 1: pngcheck repair
echo "--- Method 1: pngcheck repair ---"
if command -v pngcheck &> /dev/null; then
    if pngcheck -r "$INPUT_FILE" 2>/dev/null; then
        cp "$INPUT_FILE" "$OUTPUT_FILE"
        echo "pngcheck repair completed."
    else
        echo "pngcheck repair not applicable or failed."
    fi
else
    echo "pngcheck not installed."
fi
echo ""

# Method 2: pngcrush optimization
echo "--- Method 2: pngcrush optimization ---"
if command -v pngcrush &> /dev/null; then
    if pngcrush -fix "$INPUT_FILE" "$OUTPUT_FILE" 2>/dev/null; then
        echo "pngcrush optimization completed."
    else
        echo "pngcrush failed."
    fi
else
    echo "pngcrush not installed. Try: apt install pngcrush"
fi
echo ""

# Method 3: ImageMagick conversion
echo "--- Method 3: ImageMagick conversion ---"
if command -v convert &> /dev/null; then
    if convert "$INPUT_FILE" "$OUTPUT_FILE" 2>/dev/null; then
        echo "ImageMagick conversion completed."
    else
        echo "ImageMagick conversion failed."
    fi
else
    echo "ImageMagick not installed. Try: apt install imagemagick"
fi
echo ""

# Method 4: Check if output was created
echo "--- Verification ---"
if [ -f "$OUTPUT_FILE" ]; then
    echo "Output file created: $OUTPUT_FILE"
    echo ""
    echo "Validating repaired file..."
    if command -v pngcheck &> /dev/null; then
        pngcheck -v "$OUTPUT_FILE" 2>&1 || true
    fi
    echo ""
    echo "File size:"
    ls -lh "$OUTPUT_FILE"
else
    echo "ERROR: No output file was created."
    echo "The file may be too corrupted to repair automatically."
    echo "Consider using online services like PixRecovery:"
    echo "https://online.officerecovery.com/pixrecovery/"
fi
echo ""

echo "=== Repair Attempt Complete ==="
