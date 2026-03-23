#!/bin/bash
# macOS Bundle Inspector
# Quick inspection of bundle structure and metadata

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <path-to-bundle>"
    echo "Example: $0 /Applications/Safari.app"
    exit 1
fi

BUNDLE_PATH="$1"

if [ ! -d "$BUNDLE_PATH" ]; then
    echo "Error: Path does not exist: $BUNDLE_PATH"
    exit 1
fi

echo "========================================"
echo "macOS Bundle Inspector"
echo "========================================"
echo "Bundle: $BUNDLE_PATH"
echo ""

# Check if it's a valid bundle
if [ ! -f "$BUNDLE_PATH/Contents/Info.plist" ]; then
    echo "Warning: Not a standard macOS bundle (missing Contents/Info.plist)"
else
    echo "[+] Valid bundle structure detected"
fi

echo ""
echo "--- Bundle Structure ---"
ls -la "$BUNDLE_PATH/Contents/" 2>/dev/null || echo "[!] Cannot read Contents directory"

echo ""
echo "--- Info.plist Keys ---"
if [ -f "$BUNDLE_PATH/Contents/Info.plist" ]; then
    echo "CFBundleIdentifier:"
    /usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$BUNDLE_PATH/Contents/Info.plist" 2>/dev/null || echo "[!] Not found"
    echo ""
    echo "CFBundleExecutable:"
    /usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$BUNDLE_PATH/Contents/Info.plist" 2>/dev/null || echo "[!] Not found"
    echo ""
    echo "LSMinimumSystemVersion:"
    /usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$BUNDLE_PATH/Contents/Info.plist" 2>/dev/null || echo "[!] Not found"
else
    echo "[!] Info.plist not found"
fi

echo ""
echo "--- Embedded Bundles ---"
find "$BUNDLE_PATH/Contents" -name "*.app" -o -name "*.framework" -o -name "*.plugin" -o -name "*.xpc" 2>/dev/null | head -20 || echo "[!] None found"

echo ""
echo "--- Code Signature Check ---"
codesign --verify --deep --strict "$BUNDLE_PATH" 2>&1 && echo "[+] Signature verification passed" || echo "[!] Signature verification failed or not signed"

echo ""
echo "--- Executable Analysis ---"
EXECUTABLE_NAME=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$BUNDLE_PATH/Contents/Info.plist" 2>/dev/null)
if [ -n "$EXECUTABLE_NAME" ] && [ -f "$BUNDLE_PATH/Contents/MacOS/$EXECUTABLE_NAME" ]; then
    echo "Executable: $EXECUTABLE_NAME"
    echo ""
    echo "RPATH entries:"
    otool -l "$BUNDLE_PATH/Contents/MacOS/$EXECUTABLE_NAME" 2>/dev/null | grep -A2 RPATH || echo "[!] No RPATH entries found"
    echo ""
    echo "Linked libraries (first 10):"
    otool -L "$BUNDLE_PATH/Contents/MacOS/$EXECUTABLE_NAME" 2>/dev/null | head -10 || echo "[!] Cannot read linked libraries"
else
    echo "[!] Executable not found or Info.plist missing CFBundleExecutable"
fi

echo ""
echo "========================================"
echo "Inspection complete"
echo "========================================"
