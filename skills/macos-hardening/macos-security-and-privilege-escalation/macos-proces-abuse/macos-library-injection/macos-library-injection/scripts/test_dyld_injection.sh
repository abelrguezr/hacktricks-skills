#!/bin/bash
# Test DYLD_INSERT_LIBRARIES injection on a binary
# Usage: ./test_dyld_injection.sh <binary_path> <library_path>

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <binary_path> <library_path>"
    echo "Example: $0 /usr/bin/ls /path/to/inject.dylib"
    echo ""
    echo "Note: The library should be a valid dylib that can be loaded."
    echo "For testing, you can create a simple dylib that prints a message."
    exit 1
fi

BINARY="$1"
LIBRARY="$2"

if [ ! -f "$BINARY" ]; then
    echo "Error: Binary not found: $BINARY"
    exit 1
fi

if [ ! -f "$LIBRARY" ]; then
    echo "Error: Library not found: $LIBRARY"
    echo ""
    echo "To create a test library, you can use:"
    echo "  gcc -dynamiclib -o inject.dylib inject.c"
    echo ""
    echo "Example inject.c:"
    echo "  #include <stdio.h>"
    echo "  __attribute__((constructor)) void init() {"
    echo "      fprintf(stderr, \"[+] Library injected!\\n\");"
    echo "  }"
    exit 1
fi

echo "=== DYLD_INSERT_LIBRARIES Injection Test ==="
echo "Binary: $BINARY"
echo "Library: $LIBRARY"
echo ""

# First, check restrictions
echo "--- Pre-flight Checks ---"

# Check setuid/setgid
if [ -u "$BINARY" ] || [ -g "$BINARY" ]; then
    echo "[!] Binary is setuid/setgid - injection will be BLOCKED"
    echo "    DYLD_* variables are pruned for setuid/setgid binaries"
    exit 1
fi
echo "[+] Binary is not setuid/setgid"

# Check __RESTRICT section
if otool -l "$BINARY" 2>/dev/null | grep -q "__RESTRICT"; then
    echo "[!] Binary has __RESTRICT section - injection will be BLOCKED"
    exit 1
fi
echo "[+] No __RESTRICT section found"

# Check hardened runtime
CODEDIR=$(codesign --display --verbose "$BINARY" 2>/dev/null | grep -i "CodeDirectory")
if echo "$CODEDIR" | grep -q "runtime"; then
    echo "[!] Binary has hardened runtime"
    
    # Check for entitlement
    ENTITLEMENTS=$(codesign -dv --entitlements :- "$BINARY" 2>/dev/null)
    if echo "$ENTITLEMENTS" | grep -q "com.apple.security.cs.allow-dyld-environment-variables"; then
        echo "[+] Has allow-dyld-environment-variables entitlement"
    else
        echo "[!] Missing allow-dyld-environment-variables entitlement"
        echo "    Injection will likely be BLOCKED"
    fi
else
    echo "[+] No hardened runtime"
fi
echo ""

# Check library validation
echo "--- Library Validation Check ---"
if echo "$CODEDIR" | grep -q "runtime"; then
    ENTITLEMENTS=$(codesign -dv --entitlements :- "$BINARY" 2>/dev/null)
    if echo "$ENTITLEMENTS" | grep -q "com.apple.security.cs.disable-library-validation"; then
        echo "[+] Library validation is disabled"
    else
        echo "[!] Library validation is enabled"
        echo "    The library must be signed with the same certificate as the binary"
        
        # Check if library is signed
        if codesign -dv "$LIBRARY" 2>/dev/null; then
            echo "[+] Library is code signed"
        else
            echo "[!] Library is not code signed"
            echo "    Injection will likely FAIL due to library validation"
        fi
    fi
else
    echo "[i] Library validation check not applicable (no hardened runtime)"
fi
echo ""

# Attempt injection
echo "--- Injection Test ---"
echo "Running: DYLD_INSERT_LIBRARIES=$LIBRARY $BINARY"
echo ""

# Run with injection
DYLD_INSERT_LIBRARIES="$LIBRARY" "$BINARY" 2>&1
RESULT=$?

echo ""
echo "Exit code: $RESULT"

if [ $RESULT -eq 0 ]; then
    echo "[+] Injection test completed successfully"
    echo "    Check output for signs of library execution"
else
    echo "[!] Injection test failed with exit code $RESULT"
    echo "    This may indicate:"
    echo "    - Library injection was blocked"
    echo "    - Library failed to load"
    echo "    - Binary crashed due to injection"
fi

echo ""
echo "=== Notes ==="
echo "If injection was blocked, check:"
echo "  1. Binary restrictions (setuid, __RESTRICT, hardened runtime)"
echo "  2. Library validation requirements"
echo "  3. Runtime flags: csops -status <pid> (check for 0x800)"
