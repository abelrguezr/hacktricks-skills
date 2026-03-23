#!/bin/bash
# macOS Quarantine Attribute Analyzer
# Usage: ./analyze-quarantine.sh <path-to-file-or-directory>

if [ -z "$1" ]; then
    echo "Usage: $0 <path-to-file-or-directory>"
    echo "Example: $0 /path/to/file.app"
    echo "         $0 /Applications"
    exit 1
fi

TARGET="$1"

echo "========================================"
echo "macOS Quarantine Attribute Analysis"
echo "Target: $TARGET"
echo "========================================"
echo ""

if [ -f "$TARGET" ]; then
    # Single file analysis
    echo "=== File: $TARGET ==="
    
    echo "All extended attributes:"
    xattr "$TARGET" 2>/dev/null || echo "No extended attributes found"
    echo ""
    
    if xattr "$TARGET" 2>/dev/null | grep -q "com.apple.quarantine"; then
        echo "=== Quarantine Attribute Details ==="
        echo "Raw value (hex):"
        xattr -p com.apple.quarantine "$TARGET" 2>/dev/null | xxd
        echo ""
        echo "Human-readable:"
        xattr -l "$TARGET" 2>/dev/null | grep -A 5 "com.apple.quarantine"
        echo ""
        
        # Parse quarantine flags
        echo "=== Quarantine Flags Analysis ==="
        FLAGS=$(xattr -p com.apple.quarantine "$TARGET" 2>/dev/null | head -c 4 | xxd -p)
        echo "Flag bytes: $FLAGS"
        
        # Check for user approved flag (0x0040)
        if echo "$FLAGS" | grep -qi "40"; then
            echo "✓ User has approved this file (QTN_FLAG_USER_APPROVED)"
        else
            echo "✗ File has not been user-approved"
        fi
    else
        echo "=== No Quarantine Attribute ==="
        echo "This file will NOT be checked by Gatekeeper"
        echo ""
        echo "To add quarantine attribute (for testing):"
        echo "  xattr -w com.apple.quarantine '0081;$(date +%s);Safari;' $TARGET"
    fi
    
else
    # Directory analysis
    echo "=== Scanning Directory for Quarantined Files ==="
    
    QUARANTINED_COUNT=0
    TOTAL_COUNT=0
    
    while IFS= read -r -d '' file; do
        TOTAL_COUNT=$((TOTAL_COUNT + 1))
        if xattr "$file" 2>/dev/null | grep -q "com.apple.quarantine"; then
            QUARANTINED_COUNT=$((QUARANTINED_COUNT + 1))
            echo "[Q] $file"
        fi
    done < <(find "$TARGET" -type f -print0 2>/dev/null)
    
    echo ""
    echo "=== Summary ==="
    echo "Total files scanned: $TOTAL_COUNT"
    echo "Quarantined files: $QUARANTINED_COUNT"
    echo "Non-quarantined files: $((TOTAL_COUNT - QUARANTINED_COUNT))"
    
    if [ $QUARANTINED_COUNT -lt $TOTAL_COUNT ]; then
        echo ""
        echo "⚠ Warning: Some files lack quarantine attributes"
        echo "These files will bypass Gatekeeper security checks"
    fi
fi

echo ""
echo "========================================"
echo "Analysis Complete"
echo "========================================"
