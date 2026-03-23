#!/bin/bash
# Find all nib resources within a macOS app bundle

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 /path/to/target.app"
    echo "Example: $0 /Applications/SomeApp.app"
    exit 1
fi

TARGET_APP="$1"

if [ ! -d "$TARGET_APP" ]; then
    echo "Error: $TARGET_APP does not exist or is not a directory"
    exit 1
fi

echo "Searching for nib resources in $TARGET_APP..."
echo ""

# Find .nib files
nib_count=$(find "$TARGET_APP" -type f -name "*.nib" 2>/dev/null | wc -l | tr -d ' ')
if [ "$nib_count" -gt 0 ]; then
    echo "[.nib files]"
    find "$TARGET_APP" -type f -name "*.nib" 2>/dev/null | while read -r f; do
        echo "  $f"
    done
    echo ""
fi

# Find .xib files (editable source)
xib_count=$(find "$TARGET_APP" -type f -name "*.xib" 2>/dev/null | wc -l | tr -d ' ')
if [ "$xib_count" -gt 0 ]; then
    echo "[.xib files]"
    find "$TARGET_APP" -type f -name "*.xib" 2>/dev/null | while read -r f; do
        echo "  $f"
    done
    echo ""
fi

# Check Info.plist for NSMainNibFile
info_plist="$TARGET_APP/Contents/Info.plist"
if [ -f "$info_plist" ]; then
    if /usr/libexec/PlistBuddy -c "Print :NSMainNibFile" "$info_plist" >/dev/null 2>&1; then
        main_nib=$(/usr/libexec/PlistBuddy -c "Print :NSMainNibFile" "$info_plist" 2>/dev/null)
        echo "[Info.plist]"
        echo "  NSMainNibFile: $main_nib"
        echo ""
    fi
fi

echo "Search complete."
