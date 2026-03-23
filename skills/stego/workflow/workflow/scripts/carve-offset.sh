#!/bin/bash
# Carve data from a specific offset in a file
# Useful when binwalk reports signatures but extraction fails

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <source_file> <offset> [output_file]"
    echo "Example: $0 image.png 12345 carved.zip"
    echo ""
    echo "To find offsets, run: binwalk <file>"
    exit 1
fi

SOURCE="$1"
OFFSET="$2"
OUTPUT="${3:-carved_$(basename "$SOURCE")_offset_${OFFSET}.bin}"

if [ ! -f "$SOURCE" ]; then
    echo "Error: Source file '$SOURCE' not found"
    exit 1
fi

echo "Carving from offset $OFFSET..."
echo "Source: $SOURCE"
echo "Output: $OUTPUT"

# Carve the data
dd if="$SOURCE" of="$OUTPUT" bs=1 skip="$OFFSET"

echo ""
echo "Carved file info:"
file "$OUTPUT"
ls -lah "$OUTPUT"

echo ""
echo "First 32 bytes (hex):"
xxd -g 1 -l 32 "$OUTPUT"

echo ""
echo "Carving complete. Check the output file with 'file' and appropriate tools."
