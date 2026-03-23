#!/bin/bash
# Android Partition Discovery Script
# Usage: ./discover_partitions.sh
# Requires: Device connected via ADB

set -e

echo "=== Android Partition Discovery ==="
echo "Timestamp: $(date -Iseconds)"
echo ""

# Check ADB connection
if ! adb devices | grep -q "device"; then
    echo "Error: No Android device connected via ADB"
    echo "Please connect device and enable USB debugging"
    exit 1
fi

echo "Connected device:"
adb devices

echo ""
echo "=== Partition Information ==="
echo ""

# Get partition list
echo "--- /proc/partitions ---"
adb shell cat /proc/partitions 2>/dev/null || echo "(requires root access)"

echo ""
echo "--- Disk usage ---"
adb shell df -h 2>/dev/null || echo "(requires root access)"

echo ""
echo "--- Block devices ---"
adb shell ls -la /dev/block/ 2>/dev/null || echo "(requires root access)"

echo ""
echo "=== Analysis ==="
echo ""
echo "Common partition paths:"
echo "  /dev/block/mmcblk0     - Main flash memory (whole device)"
echo "  /dev/block/mmcblk0p*   - Individual partitions"
echo "  /dev/block/platform/*/by-name/* - Named partitions"
echo ""
echo "To create a full disk image (requires root):"
echo "  adb shell dd if=/dev/block/mmcblk0 of=/sdcard/blk0.img bs=4096"
echo "  adb pull /sdcard/blk0.img ./blk0.img"
echo ""
echo "To create a specific partition image:"
echo "  adb shell dd if=/dev/block/mmcblk0pX of=/sdcard/partitionX.img bs=4096"
echo "  adb pull /sdcard/partitionX.img ./partitionX.img"
