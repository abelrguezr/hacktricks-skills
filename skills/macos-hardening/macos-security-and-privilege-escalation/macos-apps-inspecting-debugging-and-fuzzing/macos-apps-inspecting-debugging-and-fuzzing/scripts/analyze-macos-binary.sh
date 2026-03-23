#!/bin/bash
# macOS Binary Analysis Script
# Performs comprehensive static analysis on a macOS binary

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <path/to/binary>"
    echo "Example: $0 /bin/ls"
    exit 1
fi

BINARY="$1"
OUTPUT_DIR="${BINARY%.*/analysis_$(basename "$BINARY")}"

if [ ! -f "$BINARY" ]; then
    echo "Error: Binary not found: $BINARY"
    exit 1
fi

echo "=== macOS Binary Analysis ==="
echo "Target: $BINARY"
echo "Output: $OUTPUT_DIR"
echo ""

mkdir -p "$OUTPUT_DIR"

# Basic file info
echo "=== File Information ==="
file "$BINARY" > "$OUTPUT_DIR/01_file_info.txt"
cat "$OUTPUT_DIR/01_file_info.txt"
echo ""

# Check if it's a Mach-O binary
if ! file "$BINARY" | grep -q "Mach-O"; then
    echo "Warning: Not a Mach-O binary"
fi

# Architecture
echo "=== Architecture ==="
vtool -a "$BINARY" 2>/dev/null || otool -hv "$BINARY" 2>/dev/null | head -20 > "$OUTPUT_DIR/02_architecture.txt" || true
cat "$OUTPUT_DIR/02_architecture.txt" 2>/dev/null || echo "Could not determine architecture"
echo ""

# Linked libraries
echo "=== Linked Libraries ==="
otool -L "$BINARY" > "$OUTPUT_DIR/03_linked_libraries.txt" 2>&1 || true
cat "$OUTPUT_DIR/03_linked_libraries.txt"
echo ""

# Load commands (sections)
echo "=== Load Commands ==="
otool -l "$BINARY" > "$OUTPUT_DIR/04_load_commands.txt" 2>&1 || true
echo "First 50 lines:"
head -50 "$OUTPUT_DIR/04_load_commands.txt"
echo "... (full output in $OUTPUT_DIR/04_load_commands.txt)"
echo ""

# Symbols
echo "=== Symbols (first 100) ==="
nm "$BINARY" 2>/dev/null | head -100 > "$OUTPUT_DIR/05_symbols.txt" || true
cat "$OUTPUT_DIR/05_symbols.txt"
echo "... (full output in $OUTPUT_DIR/05_symbols.txt)"
echo ""

# Code signature
echo "=== Code Signature ==="
codesign -vv -d "$BINARY" 2>&1 | grep -E "Authority|TeamIdentifier|Identifier|Signer" > "$OUTPUT_DIR/06_codesign.txt" || true
cat "$OUTPUT_DIR/06_codesign.txt" || echo "No code signature found"
echo ""

# Entitlements
echo "=== Entitlements ==="
codesign -d --entitlements :- "$BINARY" 2>/dev/null > "$OUTPUT_DIR/07_entitlements.txt" || true
if [ -s "$OUTPUT_DIR/07_entitlements.txt" ]; then
    cat "$OUTPUT_DIR/07_entitlements.txt"
else
    echo "No entitlements found or unable to extract"
fi
echo ""

# Strings analysis
echo "=== String Analysis ==="
strings "$BINARY" > "$OUTPUT_DIR/08_all_strings.txt" 2>/dev/null || true
TOTAL_STRINGS=$(wc -l < "$OUTPUT_DIR/08_all_strings.txt" 2>/dev/null || echo "0")
echo "Total strings: $TOTAL_STRINGS"

# Check for suspicious strings
echo ""
echo "Suspicious strings (debug, ptrace, vmware, etc.):"
grep -iE "(ptrace|debug|vmware|virtual|sandbox|entitlement|keychain|password|secret)" "$OUTPUT_DIR/08_all_strings.txt" 2>/dev/null | head -20 > "$OUTPUT_DIR/09_suspicious_strings.txt" || true
cat "$OUTPUT_DIR/09_suspicious_strings.txt" || echo "None found"
echo ""

# Check for Swift metadata
echo "=== Swift Metadata Sections ==="
otool -l "$BINARY" 2>/dev/null | grep "__swift5" > "$OUTPUT_DIR/10_swift_sections.txt" || true
if [ -s "$OUTPUT_DIR/10_swift_sections.txt" ]; then
    cat "$OUTPUT_DIR/10_swift_sections.txt"
else
    echo "No Swift metadata sections found"
fi
echo ""

# Check for Objective-C metadata
echo "=== Objective-C Metadata ==="
otool -ov "$BINARY" 2>/dev/null | head -50 > "$OUTPUT_DIR/11_objc_metadata.txt" || true
if [ -s "$OUTPUT_DIR/11_objc_metadata.txt" ]; then
    echo "First 50 lines:"
    cat "$OUTPUT_DIR/11_objc_metadata.txt"
else
    echo "No Objective-C metadata found or unable to extract"
fi
echo ""

# Check for packed sections
echo "=== Packed Binary Indicators ==="
otool -l "$BINARY" 2>/dev/null | grep "__XHDR" > "$OUTPUT_DIR/12_packed_check.txt" || true
if [ -s "$OUTPUT_DIR/12_packed_check.txt" ]; then
    echo "WARNING: Possible UPX packing detected (__XHDR section)"
    cat "$OUTPUT_DIR/12_packed_check.txt"
else
    echo "No obvious packing indicators found"
fi
echo ""

# Entropy check (basic)
echo "=== Entropy Check ==="
if command -v shasum &> /dev/null; then
    # Basic entropy estimation via string ratio
    BINARY_SIZE=$(stat -f%z "$BINARY" 2>/dev/null || stat -c%s "$BINARY" 2>/dev/null || echo "0")
    STRING_COUNT=$(wc -l < "$OUTPUT_DIR/08_all_strings.txt" 2>/dev/null || echo "0")
    if [ "$BINARY_SIZE" -gt 0 ]; then
        STRING_RATIO=$(echo "scale=4; $STRING_COUNT * 100 / $BINARY_SIZE" | bc 2>/dev/null || echo "N/A")
        echo "String ratio: $STRING_RATIO strings per 100 bytes"
        if [ "$(echo "$STRING_RATIO < 0.1" | bc 2>/dev/null)" = "1" ]; then
            echo "WARNING: Low string ratio may indicate packing or encryption"
        fi
    fi
fi
echo ""

# Disassembly (first function)
echo "=== Disassembly (main or _start, first 30 lines) ==="
otool -tv "$BINARY" 2>/dev/null | grep -A 30 "main\|_start" | head -30 > "$OUTPUT_DIR/13_disassembly.txt" || true
if [ -s "$OUTPUT_DIR/13_disassembly.txt" ]; then
    cat "$OUTPUT_DIR/13_disassembly.txt"
else
    echo "Could not disassemble main function"
fi
echo ""

echo "=== Analysis Complete ==="
echo "Results saved to: $OUTPUT_DIR/"
echo ""
echo "Next steps:"
echo "  - Review $OUTPUT_DIR/09_suspicious_strings.txt for red flags"
echo "  - Check $OUTPUT_DIR/07_entitlements.txt for requested permissions"
echo "  - Use lldb for dynamic analysis: lldb $BINARY"
echo "  - Run with dtruss for syscall tracing: sudo dtruss -c $BINARY"
