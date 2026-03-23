#!/bin/bash
# Steganography Triage Script
# Quick systematic analysis of a file for hidden content

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <target_file>"
    echo "Example: $0 suspicious.png"
    exit 1
fi

TARGET="$1"
OUTPUT_DIR="stego_analysis_$(basename "$TARGET")"

if [ ! -f "$TARGET" ]; then
    echo "Error: File '$TARGET' not found"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "=== Steganography Triage Report ==="
echo "Target: $TARGET"
echo "Output: $OUTPUT_DIR/"
echo ""

# 1. Basic file info
echo "=== 1. File Identification ==="
file "$TARGET"
ls -lah "$TARGET"
echo ""

# 2. Metadata extraction
echo "=== 2. Metadata (exiftool) ==="
if command -v exiftool &> /dev/null; then
    exiftool "$TARGET" 2>/dev/null | head -50
else
    echo "exiftool not installed"
fi
echo ""

# 3. String extraction
echo "=== 3. Strings (first 20 lines) ==="
strings -n 6 "$TARGET" 2>/dev/null | head -20
echo "..."
echo "=== 3. Strings (last 20 lines) ==="
strings -n 6 "$TARGET" 2>/dev/null | tail -20
echo ""

# 4. Binwalk analysis
echo "=== 4. Binwalk Analysis ==="
if command -v binwalk &> /dev/null; then
    binwalk "$TARGET" 2>/dev/null || echo "binwalk found no signatures"
else
    echo "binwalk not installed"
fi
echo ""

# 5. Check trailing bytes
echo "=== 5. Last 200 bytes (hex) ==="
tail -c 200 "$TARGET" | xxd
echo ""

# 6. Magic bytes
echo "=== 6. Magic bytes (first 32 bytes) ==="
xxd -g 1 -l 32 "$TARGET"
echo ""

# 7. Try as archive
echo "=== 7. Archive inspection ==="
if command -v 7z &> /dev/null; then
    echo "7z listing:"
    7z l "$TARGET" 2>/dev/null || echo "Not a 7z archive"
fi
if command -v unzip &> /dev/null; then
    echo "unzip listing:"
    unzip -l "$TARGET" 2>/dev/null || echo "Not a zip archive"
fi
echo ""

# 8. File size analysis
echo "=== 8. Size Analysis ==="
SIZE=$(stat -c%s "$TARGET" 2>/dev/null || stat -f%z "$TARGET" 2>/dev/null)
echo "File size: $SIZE bytes"

# Check if size is a perfect square (potential QR code)
SQRT=$(echo "sqrt($SIZE)" | bc 2>/dev/null || python3 -c "import math; print(int(math.isqrt($SIZE)))" 2>/dev/null || echo "N/A")
if [ "$SQRT" != "N/A" ]; then
    SQUARE=$((SQRT * SQRT))
    if [ "$SQUARE" -eq "$SIZE" ]; then
        echo "⚠️  WARNING: File size ($SIZE) is a perfect square ($SQRT x $SQRT)"
        echo "   This could indicate raw pixel data for a QR code or image"
    fi
fi
echo ""

echo "=== Triage Complete ==="
echo "Results saved to: $OUTPUT_DIR/"
echo ""
echo "Next steps:"
echo "- If image: run zsteg, pngcheck, or Stegsolve"
echo "- If audio: check spectrogram with Sonic Visualiser"
echo "- If binwalk found signatures: run 'binwalk -e $TARGET'"
echo "- If suspicious offsets: carve with 'dd if=$TARGET of=carved.bin bs=1 skip=<offset>'"
