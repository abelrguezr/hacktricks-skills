#!/bin/bash
# macOS Extended Attributes Lister
# Usage: ./list-extended-attributes.sh <file_or_directory>

if [ -z "$1" ]; then
    echo "Usage: $0 <file_or_directory>"
    echo ""
    echo "This script lists extended attributes for files/directories."
    echo ""
    echo "Common extended attributes:"
    echo "  com.apple.quarantine - Gatekeeper quarantine"
    echo "  com.apple.ResourceFork - Alternate data streams"
    echo "  com.apple.decmpfs - Compressed file data"
    echo "  com.apple.FinderInfo - Finder metadata"
    exit 1
fi

TARGET="$1"

echo "=== Extended Attributes for: $TARGET ==="
echo ""

# Check if target exists
if [ ! -e "$TARGET" ]; then
    echo "Error: $TARGET does not exist"
    exit 1
fi

# Show basic file info
ls -l "$TARGET"
echo ""

# List extended attributes
if xattr -l "$TARGET" 2>/dev/null; then
    echo ""
    echo "=== Attribute Details ==="
    
    # Get list of attributes
    ATTRS=$(xattr -l "$TARGET" 2>/dev/null | cut -d: -f1)
    
    for ATTR in $ATTRS; do
        echo ""
        echo "Attribute: $ATTR"
        echo "Value:"
        xattr -p "$ATTR" "$TARGET" 2>/dev/null | head -5
        echo ""
    done
else
    echo "No extended attributes found"
fi

echo "=== Common Attribute Meanings ==="
echo ""
echo "com.apple.quarantine:"
echo "  - Indicates file was downloaded from internet"
echo "  - Gatekeeper will check this file"
echo ""
echo "com.apple.ResourceFork:"
echo "  - Alternate Data Stream (ADS)"
echo "  - Can be accessed via: <file>/..namedfork/rsrc"
echo ""
echo "com.apple.decmpfs:"
echo "  - File is compressed"
echo "  - Actual data stored in this attribute"
echo "  - Use afscexpand to decompress"
echo ""
echo "com.apple.FinderInfo:"
echo "  - Finder-specific metadata"
echo "  - Color tags, custom icons, etc."
