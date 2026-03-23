#!/bin/bash
# macOS Application Signature Checker
# Usage: ./check-signature.sh <path-to-app>

if [ -z "$1" ]; then
    echo "Usage: $0 <path-to-app>"
    echo "Example: $0 /Applications/Safari.app"
    exit 1
fi

APP_PATH="$1"

if [ ! -e "$APP_PATH" ]; then
    echo "Error: Path does not exist: $APP_PATH"
    exit 1
fi

echo "========================================"
echo "macOS Application Signature Analysis"
echo "Target: $APP_PATH"
echo "========================================"
echo ""

echo "=== 1. Basic Signature Verification ==="
codesign --verify --verbose "$APP_PATH" 2>&1
echo ""

echo "=== 2. Signer Information ==="
codesign -vv -d "$APP_PATH" 2>&1 | grep -E "Authority|TeamIdentifier|Identifier|Label" | head -20
echo ""

echo "=== 3. Notarization Status ==="
NOTARIZED=$(codesign -dv --verbose "$APP_PATH" 2>&1 | grep -i "notarized")
if [ -n "$NOTARIZED" ]; then
    echo "✓ Notarization found:"
    echo "$NOTARIZED"
else
    echo "✗ No notarization ticket found"
fi
echo ""

echo "=== 4. Gatekeeper Assessment ==="
spctl --assess -v "$APP_PATH" 2>&1
echo ""

echo "=== 5. Entitlements ==="
codesign -d --entitlements :- "$APP_PATH" 2>&1 | head -30
echo ""

echo "=== 6. Quarantine Status ==="
if xattr "$APP_PATH" 2>/dev/null | grep -q "com.apple.quarantine"; then
    echo "✓ Quarantine attribute present:"
    xattr -l "$APP_PATH" 2>/dev/null | grep -A 5 "com.apple.quarantine"
else
    echo "✗ No quarantine attribute found"
fi
echo ""

echo "=== 7. Provenance (macOS Ventura+) ==="
if xattr -p com.apple.provenance "$APP_PATH" 2>/dev/null | grep -q .; then
    echo "✓ Provenance attribute present:"
    xattr -p com.apple.provenance "$APP_PATH" 2>/dev/null | hexdump -C | head -10
else
    echo "✗ No provenance attribute found"
fi
echo ""

echo "========================================"
echo "Analysis Complete"
echo "========================================"
