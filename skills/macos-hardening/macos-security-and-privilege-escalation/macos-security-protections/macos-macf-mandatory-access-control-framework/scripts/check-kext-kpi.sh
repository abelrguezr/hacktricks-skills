#!/bin/bash
# Check KPI dependencies for a kext
# Usage: ./check-kext-kpi.sh <path-to-kext>

set -e

if [[ -z "$1" ]]; then
    echo "Usage: $0 <path-to-kext>"
    echo "Example: $0 /System/Library/Extensions/Sandbox.kext"
    exit 1
fi

KEXT_PATH="$1"
PLIST_PATH="$KEXT_PATH/Contents/Info.plist"

if [[ ! -f "$PLIST_PATH" ]]; then
    echo "Error: Info.plist not found at $PLIST_PATH"
    exit 1
fi

echo "Checking KPI dependencies for: $KEXT_PATH"
echo "=========================================="

# Check if it's a security extension
if grep -q "AppleSecurityExtension" "$PLIST_PATH" 2>/dev/null; then
    echo "✓ This is a security extension kext"
else
    echo "  This is NOT a security extension kext"
fi

echo ""
echo "KPI Dependencies:"
echo "------------------------------------------"

# Extract OSBundleLibraries section
if command -v plutil &> /dev/null; then
    # Use plutil to parse the plist
    echo "OSBundleLibraries:"
    plutil -p "$PLIST_PATH" 2>/dev/null | grep -A 100 "OSBundleLibraries" | head -50 || echo "  (could not parse)"
else
    # Fallback: grep for dependencies
    echo "  (install plutil for better parsing)"
    grep -A 5 "OSBundleLibraries" "$PLIST_PATH" 2>/dev/null || echo "  (not found)"
fi

echo ""
echo "Checking for MACF KPI (com.apple.kpi.dsep):"
if grep -q "com.apple.kpi.dsep" "$PLIST_PATH" 2>/dev/null; then
    echo "✓ Kext declares MACF dependency"
else
    echo "  Kext does NOT declare MACF dependency"
fi

echo ""
echo "=========================================="
