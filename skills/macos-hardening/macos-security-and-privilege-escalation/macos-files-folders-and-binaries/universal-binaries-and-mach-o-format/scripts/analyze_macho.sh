#!/bin/bash
# macOS Mach-O Binary Analysis Script
# Usage: ./analyze_macho.sh <binary_path>

if [ -z "$1" ]; then
    echo "Usage: $0 <binary_path>"
    echo "Example: $0 /bin/ls"
    exit 1
fi

BINARY="$1"

if [ ! -f "$BINARY" ]; then
    echo "Error: File not found: $BINARY"
    exit 1
fi

echo "========================================"
echo "Mach-O Binary Analysis: $BINARY"
echo "========================================"
echo ""

# Check if file exists and is readable
if [ ! -r "$BINARY" ]; then
    echo "Error: Cannot read file: $BINARY"
    exit 1
fi

echo "=== FILE TYPE ==="
file "$BINARY"
echo ""

echo "=== FAT HEADER (Universal Binary Info) ==="
otool -f -v "$BINARY" 2>/dev/null || echo "Not a universal binary or error reading"
echo ""

echo "=== MACH-O HEADER ==="
otool -hv "$BINARY" 2>/dev/null || echo "Error reading Mach-O header"
echo ""

echo "=== FILE TYPE DETAIL ==="
otool -hv "$BINARY" 2>/dev/null | grep -E "filetype|EXECUTE|DYLIB|BUNDLE" || echo "Could not determine file type"
echo ""

echo "=== SECURITY FLAGS ==="
otool -hv "$BINARY" 2>/dev/null | grep -E "PIE|NOUNDEFS|NO_HEAP_EXECUTION|ALLOW_STACK|DYLDLINK" || echo "No security flags found"
echo ""

echo "=== DYNAMIC LIBRARY DEPENDENCIES ==="
otool -L "$BINARY" 2>/dev/null || echo "No dependencies or error"
echo ""

echo "=== LOAD COMMANDS SUMMARY ==="
otool -l "$BINARY" 2>/dev/null | grep "cmd " | head -20 || echo "Error reading load commands"
echo ""

echo "=== SEGMENT INFO ==="
otool -l "$BINARY" 2>/dev/null | grep -A2 "LC_SEGMENT" | head -30 || echo "Error reading segments"
echo ""

echo "=== CODE SIGNATURE ==="
codesign -dv --verbose=2 "$BINARY" 2>/dev/null || echo "Not code signed or error checking signature"
echo ""

echo "=== ENCRYPTION INFO ==="
otool -l "$BINARY" 2>/dev/null | grep -A3 "LC_ENCRYPTION_INFO" || echo "No encryption info found"
echo ""

echo "=== DYLD RESTRICTIONS ==="
otool -l "$BINARY" 2>/dev/null | grep -A5 "LC_RESTRICT" || echo "No DYLD restrictions found"
echo ""

echo "=== ENTRY POINT (LC_MAIN) ==="
otool -l "$BINARY" 2>/dev/null | grep -A10 "LC_MAIN" || echo "No LC_MAIN found"
echo ""

echo "=== SEGMENT SIZES ==="
size -m "$BINARY" 2>/dev/null || echo "Error getting segment sizes"
echo ""

echo "========================================"
echo "Analysis complete"
echo "========================================"
