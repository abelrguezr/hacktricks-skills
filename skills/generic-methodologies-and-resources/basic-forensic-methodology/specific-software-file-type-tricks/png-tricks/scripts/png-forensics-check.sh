#!/bin/bash
# PNG Forensics Quick Check Script
# Performs initial validation and metadata extraction on PNG files

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <png_file> [output_dir]"
    echo "Example: $0 suspicious.png ./analysis"
    exit 1
fi

PNG_FILE="$1"
OUTPUT_DIR="${2:-.}"

if [ ! -f "$PNG_FILE" ]; then
    echo "Error: File not found: $PNG_FILE"
    exit 1
fi

# Create output directory if specified
if [ "$OUTPUT_DIR" != "." ]; then
    mkdir -p "$OUTPUT_DIR"
fi

echo "=== PNG Forensics Analysis ==="
echo "File: $PNG_FILE"
echo ""

# 1. File type identification
echo "--- File Type ---"
file "$PNG_FILE"
echo ""

# 2. PNG validation
echo "--- PNG Validation ---"
if command -v pngcheck &> /dev/null; then
    pngcheck -v "$PNG_FILE" 2>&1 || true
else
    echo "pngcheck not installed. Install with: apt install pngcheck"
fi
echo ""

# 3. Metadata extraction
echo "--- Metadata ---"
if command -v exiftool &> /dev/null; then
    exiftool "$PNG_FILE" 2>/dev/null || echo "exiftool not available"
else
    echo "exiftool not installed. Install with: apt install libimage-exiftool-perl"
fi
echo ""

# 4. Text chunks
echo "--- Text Chunks ---"
if command -v ztxt &> /dev/null; then
    ztxt -l "$PNG_FILE" 2>/dev/null || echo "No text chunks found or ztxt not available"
else
    echo "ztxt not installed. Try: apt install png-tools"
fi
echo ""

# 5. String extraction
echo "--- Extracted Strings (first 50 lines) ---"
if command -v strings &> /dev/null; then
    strings "$PNG_FILE" | head -50
else
    echo "strings not available"
fi
echo ""

# 6. Check for trailing data
echo "--- Trailing Data Check ---"
if command -v pngcheck &> /dev/null; then
    if pngcheck -v "$PNG_FILE" 2>&1 | grep -q "after IEND"; then
        echo "WARNING: Data found after IEND chunk!"
        echo "This may contain hidden data."
    else
        echo "No trailing data detected."
    fi
fi
echo ""

# 7. File size and basic stats
echo "--- File Statistics ---"
ls -lh "$PNG_FILE"
echo ""

echo "=== Analysis Complete ==="
echo "Review the output above for anomalies."
echo "For deeper analysis, consider:"
echo "  - Steganography tools (steghide, zsteg)"
echo "  - Hex editor (xxd, hexdump)"
echo "  - Image manipulation (ImageMagick)"
