#!/bin/bash
# macOS Binary Security Flag Checker
# Usage: ./check_security_flags.sh <binary_path>

if [ -z "$1" ]; then
    echo "Usage: $0 <binary_path>"
    echo "Example: $0 /bin/ls"
    exit 1
fi

BINARY="$1"

echo "=== Security Analysis: $BINARY ==="
echo ""

# Get header info
HEADER_INFO=$(otool -hv "$BINARY" 2>/dev/null)

if [ -z "$HEADER_INFO" ]; then
    echo "Error: Could not read Mach-O header"
    exit 1
fi

echo "--- Security Flags ---"
echo ""

# Check PIE
if echo "$HEADER_INFO" | grep -q "PIE"; then
    echo "✓ PIE (Position Independent Executable): ENABLED"
    echo "  - Binary can be loaded at any address"
    echo "  - Helps mitigate return-oriented programming attacks"
else
    echo "✗ PIE: NOT ENABLED"
    echo "  - Binary has fixed load address"
    echo "  - More vulnerable to certain attacks"
fi
echo ""

# Check NOUNDEFS
if echo "$HEADER_INFO" | grep -q "NOUNDEFS"; then
    echo "✓ NOUNDEFS: ENABLED"
    echo "  - No undefined references"
    echo "  - Fully linked binary"
else
    echo "✗ NOUNDEFS: NOT SET"
    echo "  - May have undefined references"
fi
echo ""

# Check NO_HEAP_EXECUTION
if echo "$HEADER_INFO" | grep -q "NO_HEAP_EXECUTION"; then
    echo "✓ NO_HEAP_EXECUTION: ENABLED"
    echo "  - Heap is not executable"
    echo "  - Prevents heap-based code injection"
else
    echo "✗ NO_HEAP_EXECUTION: NOT SET"
    echo "  - Heap may be executable (security risk)"
fi
echo ""

# Check ALLOW_STACK_EXECUTION
if echo "$HEADER_INFO" | grep -q "ALLOW_STACK_EXECUTION"; then
    echo "✗ ALLOW_STACK_EXECUTION: ENABLED"
    echo "  - Stack is executable (SECURITY RISK)"
    echo "  - Allows stack-based code injection"
else
    echo "✓ ALLOW_STACK_EXECUTION: NOT SET"
    echo "  - Stack is not executable"
fi
echo ""

# Check SPLIT_SEGS
if echo "$HEADER_INFO" | grep -q "SPLIT_SEGS"; then
    echo "✓ SPLIT_SEGS: ENABLED"
    echo "  - Read-only and read-write segments are split"
    echo "  - Improves security by separating code and data"
else
    echo "✗ SPLIT_SEGS: NOT SET"
fi
echo ""

# Check for encryption
ENCRYPTION=$(otool -l "$BINARY" 2>/dev/null | grep -A3 "LC_ENCRYPTION_INFO")
if [ -n "$ENCRYPTION" ]; then
    echo "--- Encryption ---"
    echo "✓ Binary has encryption info"
    echo "$ENCRYPTION"
else
    echo "--- Encryption ---"
    echo "✗ No encryption detected"
fi
echo ""

# Check code signature
SIG_INFO=$(codesign -dv --verbose=2 "$BINARY" 2>/dev/null)
if [ -n "$SIG_INFO" ] && echo "$SIG_INFO" | grep -q "Authority\|Identifier"; then
    echo "--- Code Signature ---"
    echo "✓ Binary is code signed"
    echo "$SIG_INFO" | head -5
else
    echo "--- Code Signature ---"
    echo "✗ Binary is not code signed"
fi
echo ""

# Check DYLD restrictions
RESTRICT=$(otool -l "$BINARY" 2>/dev/null | grep -A5 "LC_RESTRICT")
if [ -n "$RESTRICT" ]; then
    echo "--- DYLD Environment Variables ---"
    echo "✓ Binary ignores DYLD environment variables"
    echo "  - More secure against library injection"
else
    echo "--- DYLD Environment Variables ---"
    echo "✗ Binary may respect DYLD environment variables"
    echo "  - Vulnerable to DYLD_INSERT_LIBRARY attacks"
fi
echo ""

echo "=== Summary ==="
SECURE_FLAGS=0
INSECURE_FLAGS=0

[ -n "$(echo "$HEADER_INFO" | grep "PIE")" ] && ((SECURE_FLAGS++))
[ -n "$(echo "$HEADER_INFO" | grep "NO_HEAP_EXECUTION")" ] && ((SECURE_FLAGS++))
[ -n "$(echo "$HEADER_INFO" | grep "SPLIT_SEGS")" ] && ((SECURE_FLAGS++))
[ -z "$(echo "$HEADER_INFO" | grep "ALLOW_STACK_EXECUTION")" ] && ((SECURE_FLAGS++))

[ -n "$(echo "$HEADER_INFO" | grep "ALLOW_STACK_EXECUTION")" ] && ((INSECURE_FLAGS++))
[ -z "$(echo "$HEADER_INFO" | grep "PIE")" ] && ((INSECURE_FLAGS++))

echo "Secure flags: $SECURE_FLAGS"
echo "Insecure flags: $INSECURE_FLAGS"

if [ $INSECURE_FLAGS -gt 0 ]; then
    echo ""
    echo "⚠ WARNING: This binary has security concerns"
fi
