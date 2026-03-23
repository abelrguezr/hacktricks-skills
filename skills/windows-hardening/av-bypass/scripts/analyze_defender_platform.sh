#!/bin/bash
# Windows Defender Platform Analysis Script
# For authorized security research and detection engineering

# Usage: ./analyze_defender_platform.sh [platform_path]
# Default: C:\ProgramData\Microsoft\Windows Defender\Platform\

PLATFORM_PATH="${1:-C:\\ProgramData\\Microsoft\\Windows Defender\\Platform\\}"

echo "=== Defender Platform Analysis ==="
echo "Platform Path: $PLATFORM_PATH"
echo ""

# Check for symlinks in platform directory
echo "Checking for directory symlinks..."
find "$PLATFORM_PATH" -maxdepth 1 -type l -ls 2>/dev/null || echo "No symlinks found or path not accessible"
echo ""

# List all platform versions
echo "Platform versions found:"
ls -la "$PLATFORM_PATH" 2>/dev/null | grep -E "^d" | awk '{print $9}' | sort -V || echo "Unable to list directory"
echo ""

# Check for recent modifications
echo "Recently modified directories (last 7 days):"
find "$PLATFORM_PATH" -maxdepth 1 -type d -mtime -7 -ls 2>/dev/null || echo "Unable to check modification times"
echo ""

# Check for non-standard paths
echo "Checking for non-standard platform paths..."
for dir in "$PLATFORM_PATH"/*/; do
    if [ -d "$dir" ]; then
        basename_dir=$(basename "$dir")
        # Check if it's a symlink
        if [ -L "$dir" ]; then
            target=$(readlink "$dir")
            echo "SYMLINK: $basename_dir -> $target"
        fi
    fi
done
echo ""

echo "=== Analysis Complete ==="
echo "Note: This script is for authorized security research only."
