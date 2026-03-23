#!/bin/bash
# Find and extract embedded files using multiple methods
# Combines binwalk, foremost, and manual carving

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <target_file>"
    echo "Example: $0 suspicious.png"
    exit 1
fi

TARGET="$1"
OUTPUT_DIR="embedded_$(basename "$TARGET")"

if [ ! -f "$TARGET" ]; then
    echo "Error: File '$TARGET' not found"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "=== Embedded File Extraction ==="
echo "Target: $TARGET"
echo "Output: $OUTPUT_DIR/"
echo ""

# Method 1: Binwalk
echo "=== Method 1: Binwalk ==="
if command -v binwalk &> /dev/null; then
    echo "Scanning for embedded files..."
    binwalk "$TARGET" > "$OUTPUT_DIR/binwalk_scan.txt" 2>&1
    cat "$OUTPUT_DIR/binwalk_scan.txt"
    
    echo ""
    echo "Extracting with binwalk -e..."
    binwalk -e -M "$TARGET" -d "$OUTPUT_DIR/binwalk_extract/" 2>/dev/null || true
    
    if [ -d "$OUTPUT_DIR/binwalk_extract" ]; then
        echo "Extracted files:"
        find "$OUTPUT_DIR/binwalk_extract" -type f -exec ls -lah {} \;
    fi
else
    echo "binwalk not installed"
fi
echo ""

# Method 2: Foremost
echo "=== Method 2: Foremost ==="
if command -v foremost &> /dev/null; then
    echo "Carving with foremost..."
    foremost -i "$TARGET" -o "$OUTPUT_DIR/foremost_output/" 2>/dev/null || true
    
    if [ -d "$OUTPUT_DIR/foremost_output" ]; then
        echo "Carved files:"
        find "$OUTPUT_DIR/foremost_output" -type f -name "*.*" -exec ls -lah {} \;
    fi
else
    echo "foremost not installed"
fi
echo ""

# Method 3: Check common archive formats
echo "=== Method 3: Archive inspection ==="
for TOOL in "7z" "unzip" "tar"; do
    if command -v "$TOOL" &> /dev/null; then
        echo "Trying $TOOL..."
        case "$TOOL" in
            7z)
                7z x -o"$OUTPUT_DIR/7z_extract/" "$TARGET" 2>/dev/null && \
                    echo "7z extraction successful" || echo "7z: not an archive"
                ;;
            unzip)
                unzip -o -d "$OUTPUT_DIR/unzip_extract/" "$TARGET" 2>/dev/null && \
                    echo "unzip extraction successful" || echo "unzip: not a zip archive"
                ;;
            tar)
                tar -xf "$TARGET" -C "$OUTPUT_DIR/tar_extract/" 2>/dev/null && \
                    echo "tar extraction successful" || echo "tar: not a tar archive"
                ;;
        esac
    fi
done
echo ""

# Summary
echo "=== Extraction Summary ==="
echo "Check these directories for extracted files:"
find "$OUTPUT_DIR" -type d -maxdepth 2 | sort
echo ""
echo "File types found:"
find "$OUTPUT_DIR" -type f -exec file {} \; 2>/dev/null | cut -d: -f2 | sort | uniq -c | sort -rn
