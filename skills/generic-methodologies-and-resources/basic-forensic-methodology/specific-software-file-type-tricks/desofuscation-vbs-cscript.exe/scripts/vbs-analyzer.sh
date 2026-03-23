#!/bin/bash
# VBS File Analyzer - Quick reconnaissance for VBS files
# Usage: ./vbs-analyzer.sh <script.vbs>

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <script.vbs>"
    echo "  Analyzes a VBS file for obfuscation and suspicious patterns"
    exit 1
fi

SCRIPT="$1"

if [ ! -f "$SCRIPT" ]; then
    echo "Error: File not found: $SCRIPT"
    exit 1
fi

echo "========================================"
echo "VBS File Analysis: $SCRIPT"
echo "========================================"
echo ""

# File information
echo "## File Information"
echo "Path: $(realpath "$SCRIPT")"
echo "Size: $(wc -c < "$SCRIPT") bytes"
echo "Lines: $(wc -l < "$SCRIPT")"
echo ""

# Check file type
echo "## File Type"
file "$SCRIPT"
echo ""

# Extract comments
echo "## Comments Found"
COMMENT_COUNT=$(grep -c "'" "$SCRIPT" 2>/dev/null || echo "0")
echo "Total lines with comments: $COMMENT_COUNT"
echo ""

if [ "$COMMENT_COUNT" -gt 0 ]; then
    echo "Sample comments:"
    grep "'" "$SCRIPT" | head -5 | sed 's/^/  /'
    echo ""
fi

# Check for obfuscation patterns
echo "## Obfuscation Indicators"

# Base64 patterns
BASE64_COUNT=$(grep -cE "[A-Za-z0-9+/]{40,}={0,2}" "$SCRIPT" 2>/dev/null || echo "0")
echo "Potential Base64 strings (>40 chars): $BASE64_COUNT"

# Hex strings
HEX_COUNT=$(grep -cE "&H[0-9A-Fa-f]+" "$SCRIPT" 2>/dev/null || echo "0")
echo "Hex literals (&H...): $HEX_COUNT"

# Chr() chains
CHR_COUNT=$(grep -cE "Chr\s*\(\s*[0-9]+\s*\)" "$SCRIPT" 2>/dev/null || echo "0")
echo "Chr() function calls: $CHR_COUNT"

# Eval/Execute
EVAL_COUNT=$(grep -ciE "(eval|execute)\s*\(" "$SCRIPT" 2>/dev/null || echo "0")
echo "Eval/Execute calls: $EVAL_COUNT"

# String concatenation chains
CONCAT_COUNT=$(grep -cE '".*"\s*&\s*".*"' "$SCRIPT" 2>/dev/null || echo "0")
echo "String concatenations: $CONCAT_COUNT"

echo ""

# Check for suspicious objects
echo "## Suspicious COM Objects"

# Network objects
NETWORK_COUNT=$(grep -ciE "(xmlhttp|winhttp|socket|winsock)" "$SCRIPT" 2>/dev/null || echo "0")
echo "Network objects (XMLHTTP/WinHTTP): $NETWORK_COUNT"

# Shell object
SHELL_COUNT=$(grep -ciE "wscript\.shell|shell\.run" "$SCRIPT" 2>/dev/null || echo "0")
echo "WScript.Shell references: $SHELL_COUNT"

# FileSystemObject
FSO_COUNT=$(grep -ciE "filesystemobject|fso\." "$SCRIPT" 2>/dev/null || echo "0")
echo "FileSystemObject references: $FSO_COUNT"

# Registry access
REG_COUNT=$(grep -ciE "regwrite|regread|wsh\.reg" "$SCRIPT" 2>/dev/null || echo "0")
echo "Registry access: $REG_COUNT"

# Process creation
PROCESS_COUNT=$(grep -ciE "createshell|run\s*\(" "$SCRIPT" 2>/dev/null || echo "0")
echo "Process execution patterns: $PROCESS_COUNT"

echo ""

# Check for anti-analysis
echo "## Anti-Analysis Indicators"

SLEEP_COUNT=$(grep -ciE "wscript\.sleep" "$SCRIPT" 2>/dev/null || echo "0")
echo "WScript.Sleep calls: $SLEEP_COUNT"

# Common VM detection strings
VM_PATTERNS=("vmware" "virtualbox" "vbox" "qemu" "sandbox" "debugger")
for pattern in "${VM_PATTERNS[@]}"; do
    COUNT=$(grep -ci "$pattern" "$SCRIPT" 2>/dev/null || echo "0")
    if [ "$COUNT" -gt 0 ]; then
        echo "VM/sandbox detection ($pattern): $COUNT"
    fi
done

echo ""

# Generate hash
echo "## File Hash"
if command -v md5sum &> /dev/null; then
    echo "MD5: $(md5sum "$SCRIPT" | cut -d' ' -f1)"
elif command -v md5 &> /dev/null; then
    echo "MD5: $(md5 -q "$SCRIPT")"
fi

if command -v sha256sum &> /dev/null; then
    echo "SHA256: $(sha256sum "$SCRIPT" | cut -d' ' -f1)"
fi

echo ""
echo "========================================"
echo "Analysis complete. Review findings above."
echo "========================================"
