#!/bin/bash
# macOS Code Signature Verification Script
# Checks code signatures, entitlements, and validity

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <path/to/binary|app>"
    echo "Example: $0 /bin/ls"
    echo "        $0 /Applications/Safari.app"
    exit 1
fi

TARGET="$1"

if [ ! -e "$TARGET" ]; then
    echo "Error: Target not found: $TARGET"
    exit 1
fi

echo "=== Code Signature Analysis ==="
echo "Target: $TARGET"
echo ""

# Check if it's a signed binary
echo "--- Signature Status ---"
if codesign -v "$TARGET" 2>/dev/null; then
    echo "✓ Binary is signed and valid"
else
    echo "✗ Binary is not signed or signature is invalid"
fi
echo ""

# Detailed signature info
echo "--- Signature Details ---"
codesign -vv -d "$TARGET" 2>&1 | tee >(grep -E "Authority|TeamIdentifier|Identifier|Signer|Info" >&3) > /dev/null
echo ""

# Team identifier
echo "--- Team Identifier ---"
TEAM_ID=$(codesign -dv --entitlements : "$TARGET" 2>/dev/null | grep -i "com.apple.team.id" | awk -F'"' '{print $2}')
if [ -n "$TEAM_ID" ]; then
    echo "Team ID: $TEAM_ID"
else
    echo "No Team ID found"
fi
echo ""

# Entitlements
echo "--- Entitlements ---"
ENTITLEMENTS=$(codesign -d --entitlements :- "$TARGET" 2>/dev/null)
if [ -n "$ENTITLEMENTS" ]; then
    echo "$ENTITLEMENTS"
    
    # Check for high-risk entitlements
    echo ""
    echo "--- High-Risk Entitlements Check ---"
    HIGH_RISK=(
        "com.apple.security.get-task-allow"
        "com.apple.security.task-port"
        "com.apple.security.system-policy.all-files"
        "com.apple.security.cs.allow-jit"
        "com.apple.security.cs.allow-unsigned-executable-memory"
        "com.apple.security.cs.disable-library-validation"
        "com.apple.security.cs.disable-executable-page-protection"
    )
    
    for entitlement in "${HIGH_RISK[@]}"; do
        if echo "$ENTITLEMENTS" | grep -q "$entitlement"; then
            echo "⚠ WARNING: $entitlement"
        fi
    done
else
    echo "No entitlements found"
fi
echo ""

# Validate with spctl
echo "--- Gatekeeper Validation ---"
if spctl --assess --verbose "$TARGET" 2>&1; then
    echo "✓ Gatekeeper validation passed"
else
    echo "✗ Gatekeeper validation failed or not applicable"
fi
echo ""

# Check for ad-hoc signing
echo "--- Signing Type ---"
SIGNER=$(codesign -dv --verbose=2 "$TARGET" 2>&1 | grep -i "Authority" | head -1)
if echo "$SIGNER" | grep -qi "ad-hoc"; then
    echo "⚠ WARNING: Binary appears to be ad-hoc signed"
elif echo "$SIGNER" | grep -qi "Apple"; then
    echo "✓ Signed by Apple"
else
    echo "Info: $SIGNER"
fi
echo ""

# Check for modified contents
echo "--- Integrity Check ---"
if codesign --verify --verbose="$TARGET" 2>&1; then
    echo "✓ Contents have not been modified since signing"
else
    echo "⚠ WARNING: Contents may have been modified"
fi
echo ""

# For apps, check nested binaries
echo "--- Nested Binaries (if applicable) ---"
if [[ "$TARGET" == *.app ]]; then
    echo "Checking nested executables in app bundle..."
    find "$TARGET" -type f -perm /111 2>/dev/null | while read -r nested; do
        echo "  $nested:"
        if codesign -v "$nested" 2>/dev/null; then
            echo "    ✓ Signed"
        else
            echo "    ✗ Not signed"
        fi
    done
else
    echo "Not an app bundle"
fi
echo ""

echo "=== Signature Analysis Complete ==="
