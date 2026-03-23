#!/bin/bash
# Extract comprehensive metadata from audio/video files
# Usage: extract_metadata.sh <filename>

if [ -z "$1" ]; then
    echo "Usage: $0 <filename>"
    echo "Example: $0 sample.mp3"
    exit 1
fi

FILE="$1"
OUTPUT_DIR="metadata_output"
mkdir -p "$OUTPUT_DIR"

echo "=== Metadata Extraction for: $FILE ==="
echo "Timestamp: $(date)"
echo ""

# File type check
echo "=== File Type ==="
file "$FILE"
echo ""

# Magic bytes
echo "=== Magic Bytes (first 64 bytes) ==="
xxd "$FILE" | head -4
echo ""

# exiftool metadata
echo "=== EXIFTool Metadata ==="
if command -v exiftool &> /dev/null; then
    exiftool "$FILE" > "$OUTPUT_DIR/exiftool_output.txt" 2>&1
    cat "$OUTPUT_DIR/exiftool_output.txt"
else
    echo "exiftool not installed"
fi
echo ""

# mediainfo
echo "=== MediaInfo ==="
if command -v mediainfo &> /dev/null; then
    mediainfo "$FILE" > "$OUTPUT_DIR/mediainfo_output.txt" 2>&1
    cat "$OUTPUT_DIR/mediainfo_output.txt"
else
    echo "mediainfo not installed"
fi
echo ""

# ffprobe for video/audio containers
echo "=== FFprobe Stream Info ==="
if command -v ffprobe &> /dev/null; then
    ffprobe -v quiet -print_format json -show_streams -show_format "$FILE" > "$OUTPUT_DIR/ffprobe_output.json" 2>&1
    cat "$OUTPUT_DIR/ffprobe_output.json"
else
    echo "ffprobe not installed"
fi
echo ""

# Strings search
echo "=== Interesting Strings ==="
strings "$FILE" 2>/dev/null | grep -iE "flag|secret|hidden|password|key|ctf|solution|answer" | head -20
echo ""

# Check for appended data
echo "=== File End (last 200 bytes) ==="
xxd "$FILE" | tail -10
echo ""

# binwalk for embedded files
echo "=== Binwalk Analysis ==="
if command -v binwalk &> /dev/null; then
    binwalk "$FILE" > "$OUTPUT_DIR/binwalk_output.txt" 2>&1
    cat "$OUTPUT_DIR/binwalk_output.txt"
else
    echo "binwalk not installed"
fi
echo ""

echo "=== Metadata extraction complete ==="
echo "Results saved to: $OUTPUT_DIR/"
