#!/bin/bash
# macOS Bundle Info.plist Extractor
# Extract and display all Info.plist keys and values

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <path-to-bundle>"
    echo "Example: $0 /Applications/Safari.app"
    exit 1
fi

BUNDLE_PATH="$1"
INFO_PLIST="$BUNDLE_PATH/Contents/Info.plist"

if [ ! -f "$INFO_PLIST" ]; then
    echo "Error: Info.plist not found at $INFO_PLIST"
    exit 1
fi

echo "========================================"
echo "macOS Bundle Info.plist Extractor"
echo "========================================"
echo "Bundle: $BUNDLE_PATH"
echo "Info.plist: $INFO_PLIST"
echo ""

echo "--- Essential Keys ---"
echo ""

echo "CFBundleIdentifier:"
/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$INFO_PLIST" 2>/dev/null || echo "[!] Not found"
echo ""

echo "CFBundleExecutable:"
/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$INFO_PLIST" 2>/dev/null || echo "[!] Not found"
echo ""

echo "CFBundleName:"
/usr/libexec/PlistBuddy -c "Print :CFBundleName" "$INFO_PLIST" 2>/dev/null || echo "[!] Not found"
echo ""

echo "CFBundleVersion:"
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST" 2>/dev/null || echo "[!] Not found"
echo ""

echo "CFBundleShortVersionString:"
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || echo "[!] Not found"
echo ""

echo "LSMinimumSystemVersion:"
/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$INFO_PLIST" 2>/dev/null || echo "[!] Not found"
echo ""

echo "--- URL Types (Potential Hijacking Vectors) ---"
echo ""
if /usr/libexec/PlistBuddy -c "Print :CFBundleURLTypes" "$INFO_PLIST" 2>/dev/null | grep -q "dict"; then
    echo "URL schemes registered:"
    /usr/libexec/PlistBuddy -c "Print :CFBundleURLTypes" "$INFO_PLIST" 2>/dev/null || echo "[!] Cannot read"
else
    echo "[+] No URL schemes registered"
fi
echo ""

echo "--- Main Nib File (Potential Injection Vector) ---"
echo ""
echo "NSMainNibFile:"
/usr/libexec/PlistBuddy -c "Print :NSMainNibFile" "$INFO_PLIST" 2>/dev/null || echo "[!] Not found (uses default)"
echo ""

echo "--- App Sandbox ---"
echo ""
if /usr/libexec/PlistBuddy -c "Print :LSApplicationCategoryType" "$INFO_PLIST" 2>/dev/null | grep -q "dict"; then
    echo "LSApplicationCategoryType:"
    /usr/libexec/PlistBuddy -c "Print :LSApplicationCategoryType" "$INFO_PLIST" 2>/dev/null || echo "[!] Cannot read"
else
    echo "[+] No application category specified"
fi
echo ""

echo "--- Full Info.plist (Pretty Printed) ---"
echo ""
if command -v plutil &> /dev/null; then
    plutil -p "$INFO_PLIST" 2>/dev/null || echo "[!] Cannot parse Info.plist"
else
    echo "[!] plutil not available, showing raw plist"
    cat "$INFO_PLIST"
fi

echo ""
echo "========================================"
echo "Info.plist extraction complete"
echo "========================================"
