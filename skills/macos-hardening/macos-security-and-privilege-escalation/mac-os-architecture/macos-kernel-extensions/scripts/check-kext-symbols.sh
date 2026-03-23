#!/bin/bash
# Check kernelcache or kext for symbols
# Usage: ./check-kext-symbols.sh <kernelcache-path|kext-path>

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <kernelcache-path|kext-path>"
    exit 1
fi

TARGET="$1"

if [ ! -f "$TARGET" ]; then
    echo "ERROR: File not found: $TARGET"
    exit 1
fi

echo "=== Symbol Analysis: $TARGET ==="
echo ""

# Count symbols
SYMBOL_COUNT=$(nm -a "$TARGET" 2>/dev/null | wc -l)
echo "Total symbols: $SYMBOL_COUNT"

if [ "$SYMBOL_COUNT" -gt 1000 ]; then
    echo "Status: ✓ Has symbols (debuggable)"
else
    echo "Status: ✗ Stripped or minimal symbols"
fi

echo ""
echo "=== Symbol Types ==="
UNDEFINED=$(nm -a "$TARGET" 2>/dev/null | grep " U " | wc -l)
DEFINED=$(nm -a "$TARGET" 2>/dev/null | grep -v " U " | wc -l)
echo "Undefined symbols: $UNDEFINED"
echo "Defined symbols: $DEFINED"

echo ""
echo "=== Sample Symbols ==="
nm -a "$TARGET" 2>/dev/null | head -20

echo ""
echo "=== Exported Functions (potential hooks) ==="
nm -a "$TARGET" 2>/dev/null | grep " T " | head -10

echo ""
echo "=== Recommendations ==="
if [ "$SYMBOL_COUNT" -gt 1000 ]; then
    echo "- This binary has symbols and can be debugged with LLDB"
    echo "- Use: lldb -n kernel_task"
else
    echo "- Consider downloading a KDK with symbols"
    echo "- Use disarm with xnu.matchers for symbolication"
    echo "- Download from: https://github.com/dortania/KdkSupportPkg/releases"
fi
