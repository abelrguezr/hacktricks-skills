#!/bin/bash
# Docker File Comparison Script
# Compares a file from a container against the original from a fresh container
# Usage: ./docker-forensics-file-compare.sh <container_name> <image_name> <file_path>

set -e

if [ $# -lt 3 ]; then
    echo "Usage: $0 <container_name> <image_name> <file_path>"
    echo "Example: $0 wordpress lamp-wordpress /etc/shadow"
    exit 1
fi

CONTAINER="$1"
IMAGE="$2"
FILE_PATH="$3"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="file_comparison_${TIMESTAMP}"

mkdir -p "$OUTPUT_DIR"

echo "=== Docker File Comparison ==="
echo "Container: $CONTAINER"
echo "Image: $IMAGE"
echo "File: $FILE_PATH"
echo "Output: $OUTPUT_DIR/"
echo ""

# Extract file from the suspect container
echo "[1/4] Extracting file from container..."
docker cp "$CONTAINER:$FILE_PATH" "$OUTPUT_DIR/suspect_file" 2>&1 || {
    echo "ERROR: Failed to extract file from container"
    exit 1
}
echo "Extracted: $OUTPUT_DIR/suspect_file"
echo ""

# Create a temporary container from the image
echo "[2/4] Creating fresh container for comparison..."
TEMP_CONTAINER="temp_compare_${TIMESTAMP}"
docker run -d --name "$TEMP_CONTAINER" "$IMAGE" sleep 3600 > /dev/null 2>&1
echo "Created temporary container: $TEMP_CONTAINER"
echo ""

# Extract original file
echo "[3/4] Extracting original file..."
docker cp "$TEMP_CONTAINER:$FILE_PATH" "$OUTPUT_DIR/original_file" 2>&1 || {
    echo "WARNING: File does not exist in original image"
    echo "This means the file was ADDED to the container"
    docker rm -f "$TEMP_CONTAINER" > /dev/null 2>&1
    echo ""
    echo "Suspect file saved to: $OUTPUT_DIR/suspect_file"
    exit 0
}
echo "Extracted: $OUTPUT_DIR/original_file"
echo ""

# Compare files
echo "[4/4] Comparing files..."
echo "=== File sizes ==="
ls -la "$OUTPUT_DIR/suspect_file" "$OUTPUT_DIR/original_file"
echo ""

echo "=== MD5 checksums ==="
md5sum "$OUTPUT_DIR/suspect_file" "$OUTPUT_DIR/original_file" 2>/dev/null || sha256sum "$OUTPUT_DIR/suspect_file" "$OUTPUT_DIR/original_file"
echo ""

echo "=== Diff output ==="
if diff "$OUTPUT_DIR/original_file" "$OUTPUT_DIR/suspect_file" > "$OUTPUT_DIR/diff_output.txt" 2>&1; then
    echo "FILES ARE IDENTICAL"
else
    echo "FILES DIFFER!"
    echo ""
    echo "Differences:"
    head -50 "$OUTPUT_DIR/diff_output.txt"
    if [ $(wc -l < "$OUTPUT_DIR/diff_output.txt") -gt 50 ]; then
        echo "... ($(wc -l < "$OUTPUT_DIR/diff_output.txt") total lines in diff)"
    fi
fi
echo ""

# Generate report
echo "=== Comparison Report ===" > "$OUTPUT_DIR/comparison_report.txt"
echo "Container: $CONTAINER" >> "$OUTPUT_DIR/comparison_report.txt"
echo "Image: $IMAGE" >> "$OUTPUT_DIR/comparison_report.txt"
echo "File: $FILE_PATH" >> "$OUTPUT_DIR/comparison_report.txt"
echo "Timestamp: $TIMESTAMP" >> "$OUTPUT_DIR/comparison_report.txt"
echo "" >> "$OUTPUT_DIR/comparison_report.txt"
echo "Suspect file checksum: $(md5sum "$OUTPUT_DIR/suspect_file" 2>/dev/null | cut -d' ' -f1 || sha256sum "$OUTPUT_DIR/suspect_file" | cut -d' ' -f1)" >> "$OUTPUT_DIR/comparison_report.txt"
echo "Original file checksum: $(md5sum "$OUTPUT_DIR/original_file" 2>/dev/null | cut -d' ' -f1 || sha256sum "$OUTPUT_DIR/original_file" | cut -d' ' -f1)" >> "$OUTPUT_DIR/comparison_report.txt"
echo "" >> "$OUTPUT_DIR/comparison_report.txt"
if diff -q "$OUTPUT_DIR/original_file" "$OUTPUT_DIR/suspect_file" > /dev/null 2>&1; then
    echo "RESULT: Files are IDENTICAL - no modification detected" >> "$OUTPUT_DIR/comparison_report.txt"
else
    echo "RESULT: Files DIFFER - modification detected!" >> "$OUTPUT_DIR/comparison_report.txt"
fi
echo "" >> "$OUTPUT_DIR/comparison_report.txt"
echo "Full diff saved to: diff_output.txt" >> "$OUTPUT_DIR/comparison_report.txt"

echo "Report saved to: $OUTPUT_DIR/comparison_report.txt"
cat "$OUTPUT_DIR/comparison_report.txt"
echo ""

# Cleanup
echo "Cleaning up temporary container..."
docker rm -f "$TEMP_CONTAINER" > /dev/null 2>&1

echo "=== Comparison Complete ==="
