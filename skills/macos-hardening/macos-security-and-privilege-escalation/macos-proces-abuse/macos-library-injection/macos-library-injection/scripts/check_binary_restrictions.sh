#!/bin/bash
# Check macOS binary restrictions for library injection
# Usage: ./check_binary_restrictions.sh <binary_path>

if [ -z "$1" ]; then
    echo "Usage: $0 <binary_path>"
    echo "Example: $0 /usr/bin/ls"
    exit 1
fi

BINARY="$1"

if [ ! -f "$BINARY" ]; then
    echo "Error: File not found: $BINARY"
    exit 1
fi

echo "=== Binary Restriction Analysis ==="
echo "Binary: $BINARY"
echo ""

# Check file permissions and ownership
echo "--- File Permissions ---"
ls -la "$BINARY"

# Check for setuid/setgid
if [ -u "$BINARY" ]; then
    echo "[!] SETUID bit is SET"
elif [ -g "$BINARY" ]; then
    echo "[!] SETGID bit is SET"
else
    echo "[+] No setuid/setgid bits"
fi
echo ""

# Check codesign information
echo "--- Code Signing ---"
codesign --display --verbose "$BINARY" 2>/dev/null || echo "[!] Not code signed"
echo ""

# Check for hardened runtime
echo "--- Hardened Runtime Check ---"
CODEDIR=$(codesign --display --verbose "$BINARY" 2>/dev/null | grep -i "CodeDirectory")
if echo "$CODEDIR" | grep -q "runtime"; then
    echo "[!] Hardened runtime is ENABLED"
else
    echo "[+] Hardened runtime is NOT enabled"
fi
echo ""

# Check entitlements
echo "--- Entitlements ---"
ENTITLEMENTS=$(codesign -dv --entitlements :- "$BINARY" 2>/dev/null)
if [ -n "$ENTITLEMENTS" ]; then
    echo "$ENTITLEMENTS"
    
    # Check for specific entitlements
    if echo "$ENTITLEMENTS" | grep -q "com.apple.security.cs.allow-dyld-environment-variables"; then
        echo "[+] Has allow-dyld-environment-variables entitlement"
    else
        echo "[!] Missing allow-dyld-environment-variables entitlement"
    fi
    
    if echo "$ENTITLEMENTS" | grep -q "com.apple.security.cs.disable-library-validation"; then
        echo "[+] Has disable-library-validation entitlement"
    else
        echo "[!] Missing disable-library-validation entitlement"
    fi
else
    echo "[!] No entitlements found (not code signed or no entitlements)"
fi
echo ""

# Check for __RESTRICT section
echo "--- __RESTRICT Section Check ---"
if otool -l "$BINARY" 2>/dev/null | grep -q "__RESTRICT"; then
    echo "[!] Binary has __RESTRICT section"
else
    echo "[+] No __RESTRICT section found"
fi
echo ""

# Summary
echo "=== Summary ==="
echo "DYLD_INSERT_LIBRARIES will likely:"

BLOCKED=0

# Check setuid/setgid
if [ -u "$BINARY" ] || [ -g "$BINARY" ]; then
    echo "  - BLOCKED: setuid/setgid binary"
    BLOCKED=1
fi

# Check __RESTRICT section
if otool -l "$BINARY" 2>/dev/null | grep -q "__RESTRICT"; then
    echo "  - BLOCKED: __RESTRICT section present"
    BLOCKED=1
fi

# Check hardened runtime without entitlement
if echo "$CODEDIR" | grep -q "runtime"; then
    if ! echo "$ENTITLEMENTS" | grep -q "com.apple.security.cs.allow-dyld-environment-variables"; then
        echo "  - BLOCKED: hardened runtime without allow-dyld-environment-variables"
        BLOCKED=1
    fi
fi

if [ $BLOCKED -eq 0 ]; then
    echo "  - MAY WORK: No obvious restrictions found"
    echo "  - Note: Library validation may still apply"
fi

echo ""
echo "To test at runtime (if binary is running):"
echo "  csops -status <pid>"
echo "  Check if flag 0x800 (CS_RESTRICT) is set"
