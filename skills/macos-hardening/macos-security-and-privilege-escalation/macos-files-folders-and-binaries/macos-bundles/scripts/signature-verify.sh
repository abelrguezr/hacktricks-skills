#!/bin/bash
# macOS Bundle Signature Verifier
# Comprehensive code signature verification and analysis

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
echo "macOS Bundle Signature Verifier"
echo "========================================"
echo "Bundle: $BUNDLE_PATH"
echo ""

echo "--- Basic Signature Check ---"
if codesign --verify --deep --strict "$BUNDLE_PATH" 2>/dev/null; then
    echo "[+] Deep signature verification: PASSED"
else
    echo "[!] Deep signature verification: FAILED or not signed"
fi

echo ""
echo "--- Signature Details ---"
codesign -dv --verbose=4 "$BUNDLE_PATH" 2>/dev/null || echo "[!] Cannot read signature details"

echo ""
echo "--- Entitlements Check ---"
# Check for library validation bypass
if codesign -dv --verbose=4 "$BUNDLE_PATH" 2>/dev/null | grep -q "com.apple.security.cs.disable-library-validation"; then
    echo "[!] WARNING: Library validation is DISABLED"
    echo "   This bundle may be vulnerable to dylib hijacking"
else
    echo "[+] Library validation appears to be ENABLED"
fi

echo ""
echo "--- Team Identifier ---"
TEAM_ID=$(codesign -dv --verbose=4 "$BUNDLE_PATH" 2>/dev/null | grep "Team ID" | awk '{print $NF}')
if [ -n "$TEAM_ID" ]; then
    echo "Team ID: $TEAM_ID"
else
    echo "[!] Team ID not found (may be ad-hoc signed)"
fi

echo ""
echo "--- Ad-hoc Signature Check ---"
if codesign -dv --verbose=4 "$BUNDLE_PATH" 2>/dev/null | grep -q "-"; then
    echo "[!] WARNING: Bundle appears to be ad-hoc signed"
    echo "   Ad-hoc signatures provide minimal security"
else
    echo "[+] Bundle appears to be properly signed"
fi

echo ""
echo "--- Embedded Bundle Signatures ---"
for bundle in $(find "$BUNDLE_PATH/Contents" -name "*.app" -o -name "*.framework" -o -name "*.plugin" -o -name "*.xpc" 2>/dev/null | head -10); do
    echo "Checking: $bundle"
    if codesign --verify --deep --strict "$bundle" 2>/dev/null; then
        echo "  [+] Signed"
    else
        echo "  [!] Not signed or signature invalid"
    fi
done

echo ""
echo "========================================"
echo "Signature verification complete"
echo "========================================"
