#!/bin/bash
# APFS Enumeration Script for macOS Security Analysis
# Usage: ./apfs-enumerate.sh [--output FILE]

set -e

OUTPUT_FILE="${1:-/dev/stdout}"

if [[ "$OUTPUT_FILE" == "/dev/stdout" ]]; then
    OUTPUT_FILE="/dev/stdout"
fi

echo "# APFS Enumeration Report" > "$OUTPUT_FILE"
echo "Generated: $(date)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "Warning: Not running as root. Some commands may fail." >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
fi

echo "## Disk Overview" >> "$OUTPUT_FILE"
echo "```bash" >> "$OUTPUT_FILE"
diskutil list 2>&1 >> "$OUTPUT_FILE" || echo "diskutil list failed" >> "$OUTPUT_FILE"
echo "```" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "## APFS Container Details" >> "$OUTPUT_FILE"
echo "```bash" >> "$OUTPUT_FILE"
diskutil apfs list 2>&1 >> "$OUTPUT_FILE" || echo "diskutil apfs list failed" >> "$OUTPUT_FILE"
echo "```" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "## APFS Snapshots" >> "$OUTPUT_FILE"
echo "```bash" >> "$OUTPUT_FILE"
diskutil apfs listSnapshots 2>&1 >> "$OUTPUT_FILE" || echo "diskutil apfs listSnapshots failed" >> "$OUTPUT_FILE"
echo "```" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "## Firmlinks" >> "$OUTPUT_FILE"
echo "```bash" >> "$OUTPUT_FILE"
if [[ -f /usr/share/firmlinks ]]; then
    cat /usr/share/firmlinks >> "$OUTPUT_FILE"
else
    echo "/usr/share/firmlinks not found" >> "$OUTPUT_FILE"
fi
echo "```" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "## Volume Mount Points" >> "$OUTPUT_FILE"
echo "```bash" >> "$OUTPUT_FILE"
ls -la /System/Volumes/ 2>&1 >> "$OUTPUT_FILE" || echo "Cannot access /System/Volumes/" >> "$OUTPUT_FILE"
echo "```" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "## Snapshot Mount Points" >> "$OUTPUT_FILE"
echo "```bash" >> "$OUTPUT_FILE"
if [[ -d /Volumes/.snapshots ]]; then
    ls -la /Volumes/.snapshots/ 2>&1 >> "$OUTPUT_FILE"
else
    echo "/Volumes/.snapshots not found or empty" >> "$OUTPUT_FILE"
fi
echo "```" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

if [[ "$OUTPUT_FILE" != "/dev/stdout" ]]; then
    echo "Report saved to: $OUTPUT_FILE"
else
    cat "$OUTPUT_FILE"
fi
