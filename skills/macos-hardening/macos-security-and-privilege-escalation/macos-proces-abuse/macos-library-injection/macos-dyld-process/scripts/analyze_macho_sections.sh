#!/bin/bash
# Analyze Mach-O binary sections
# Usage: ./analyze_macho_sections.sh <binary_path>

BINARY="${1:-}"

if [[ -z "$BINARY" ]]; then
    echo "Usage: $0 <binary_path>"
    exit 1
fi

if [[ ! -f "$BINARY" ]]; then
    echo "Error: File not found: $BINARY"
    exit 1
fi

echo "Mach-O Section Analysis: $BINARY"
echo "==========================================="
echo ""

# Check if file is Mach-O
FILE_TYPE=$(file "$BINARY")
echo "File type: $FILE_TYPE"
echo ""

# List all sections
echo "All Sections:"
echo "-------------"
objdump --section-headers "$BINARY" 2>/dev/null || otool -l "$BINARY" | grep -A 100 "Load command" | head -100
echo ""

# Focus on stub-related sections
echo "Stub-Related Sections:"
echo "----------------------"
for section in "__stubs" "__stub_helper" "__got" "__nl_symbol_ptr" "__la_symbol_ptr" "__auth_stubs" "__auth_got"; do
    if objdump --section-headers "$BINARY" 2>/dev/null | grep -q "$section"; then
        echo "Found: $section"
        objdump --section-headers "$BINARY" 2>/dev/null | grep "$section"
    fi
done
echo ""

# Disassemble stubs if they exist
echo "Stub Disassembly:"
echo "-----------------"
if objdump --section-headers "$BINARY" 2>/dev/null | grep -q "__stubs"; then
    objdump -d --section=__stubs "$BINARY" 2>/dev/null | head -50
else
    echo "No __stubs section found"
fi
echo ""

# Show imports
echo "Imported Symbols (first 20):"
echo "----------------------------"
if command -v otool &> /dev/null; then
    otool -L "$BINARY" 2>/dev/null | head -20
else
    echo "otool not available"
fi
