#!/bin/bash
# Android Disk Image Creation Script
# Usage: ./create_disk_image.sh <block_device> [output_file] [block_size]
# Example: ./create_disk_image.sh /dev/block/mmcblk0 blk0.img 4096
# Requires: Root access on device

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <block_device> [output_file] [block_size]"
    echo "Example: $0 /dev/block/mmcblk0 blk0.img 4096"
    echo ""
    echo "Common block devices:"
    echo "  /dev/block/mmcblk0     - Full flash memory"
    echo "  /dev/block/mmcblk0p1   - First partition"
    echo "  /dev/block/mmcblk0pX   - Partition X"
    exit 1
fi

BLOCK_DEVICE="$1"
OUTPUT_FILE="${2:-./disk_image.img}"
BLOCK_SIZE="${3:-4096}"

# Check ADB connection
if ! adb devices | grep -q "device"; then
    echo "Error: No Android device connected via ADB"
    exit 1
fi

echo "=== Android Disk Image Creation ==="
echo "Timestamp: $(date -Iseconds)"
echo "Block device: $BLOCK_DEVICE"
echo "Output file: $OUTPUT_FILE"
echo "Block size: $BLOCK_SIZE"
echo ""

# Create image on device
echo "Creating disk image on device..."
echo "This may take several minutes depending on device storage size."
echo ""

# Run dd command on device
adb shell "dd if=$BLOCK_DEVICE of=/sdcard/temp_image.img bs=$BLOCK_SIZE status=progress"

# Pull image to local machine
echo ""
echo "Pulling image to local machine..."
adb pull /sdcard/temp_image.img "$OUTPUT_FILE"

# Clean up temporary file on device
adb shell "rm /sdcard/temp_image.img"

# Calculate hash
echo ""
echo "Image created successfully!"
echo "File: $OUTPUT_FILE"
echo "Size: $(du -h "$OUTPUT_FILE" | cut -f1)"
echo ""
echo "SHA256 hash:"
sha256sum "$OUTPUT_FILE"

echo ""
echo "=== Next Steps ==="
echo "1. Verify the image integrity using the hash above"
echo "2. Mount the image for analysis (use read-only mode)"
echo "3. Document the extraction in your case notes"
