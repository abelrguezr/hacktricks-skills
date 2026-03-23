#!/bin/bash
# Validate code signatures on a macOS app bundle
# Detects if resources have been tampered with

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

echo "Verifying code signature for $TARGET_APP..."
echo ""

# Run deep verification
if codesign --verify --deep --strict --verbose=4 "$TARGET_APP" 2>&1; then
    echo ""
    echo "[✓] Code signature verification PASSED"
    echo "    The bundle appears to be intact and properly signed."
    exit 0
else
    echo ""
    echo "[✗] Code signature verification FAILED"
    echo "    The bundle may have been tampered with or is improperly signed."
    echo ""
    echo "Additional checks:"
    
    # Show signature info
    echo "  Signature details:"
    codesign -d --verbose=4 "$TARGET_APP" 2>/dev/null | head -20 || echo "    Unable to read signature details"
    
    exit 1
fi
