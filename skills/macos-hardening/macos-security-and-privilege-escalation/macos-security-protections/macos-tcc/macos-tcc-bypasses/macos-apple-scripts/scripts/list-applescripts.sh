#!/bin/bash
# List and analyze all AppleScript files in a directory

set -e

TARGET_DIR="${1:-.}"

echo "=== AppleScript File Scanner ==="
echo "Scanning: $TARGET_DIR"
echo ""

# Find all .scpt files
SCPT_FILES=$(find "$TARGET_DIR" -name "*.scpt" -type f 2>/dev/null)

if [ -z "$SCPT_FILES" ]; then
    echo "No .scpt files found in $TARGET_DIR"
    exit 0
fi

echo "Found AppleScript files:"
echo ""

for SCRIPT in $SCPT_FILES; do
    echo "--- $SCRIPT ---"
    
    # File type
    FILE_TYPE=$(file "$SCRIPT" 2>/dev/null || echo "Unknown")
    echo "Type: $FILE_TYPE"
    
    # File size
    FILE_SIZE=$(stat -f%z "$SCRIPT" 2>/dev/null || stat -c%s "$SCRIPT" 2>/dev/null || echo "Unknown")
    echo "Size: $FILE_SIZE bytes"
    
    # Modification time
    MOD_TIME=$(stat -f%Sm "$SCRIPT" 2>/dev/null || stat -c%y "$SCRIPT" 2>/dev/null || echo "Unknown")
    echo "Modified: $MOD_TIME"
    
    # Try to decompile (just check if possible)
    if command -v osadecompile &> /dev/null; then
        if osadecompile "$SCRIPT" &>/dev/null; then
            echo "Status: Decompilable"
        else
            echo "Status: Read-only (requires disassembly)"
        fi
    fi
    
    echo ""
done

echo "=== Summary ==="
echo "Total .scpt files: $(echo "$SCPT_FILES" | wc -l | tr -d ' ')"
echo ""
echo "To analyze a specific file:"
echo "  ./analyze-applescript.sh <file.scpt> --all"
