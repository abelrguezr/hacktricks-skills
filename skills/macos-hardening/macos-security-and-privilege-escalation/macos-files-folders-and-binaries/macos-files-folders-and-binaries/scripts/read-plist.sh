#!/bin/bash
# macOS Plist Reader
# Usage: ./read-plist.sh <plist_file> [format]
# Format: xml (default), json, or raw

if [ -z "$1" ]; then
    echo "Usage: $0 <plist_file> [format]"
    echo ""
    echo "Format options:"
    echo "  xml  - Output as XML (default)"
    echo "  json - Output as JSON"
    echo "  raw  - Output raw content"
    echo ""
    echo "Examples:"
    echo "  $0 ~/Library/Preferences/com.apple.screensaver.plist"
    echo "  $0 /Library/Preferences/com.apple.*.plist json"
    exit 1
fi

PLIST_FILE="$1"
FORMAT="${2:-xml}"

# Check if file exists
if [ ! -f "$PLIST_FILE" ]; then
    echo "Error: $PLIST_FILE does not exist"
    exit 1
fi

echo "=== Reading: $PLIST_FILE ==="
echo ""

# Check if it's a binary plist
if file "$PLIST_FILE" | grep -q "binary"; then
    echo "Note: This is a binary plist file"
    echo ""
fi

case $FORMAT in
    xml)
        plutil -p "$PLIST_FILE" -o - 2>/dev/null
        ;;
    json)
        plutil -convert json "$PLIST_FILE" -o - 2>/dev/null
        ;;
    raw)
        cat "$PLIST_FILE"
        ;;
    *)
        echo "Unknown format: $FORMAT"
        echo "Use: xml, json, or raw"
        exit 1
        ;;
esac

echo ""
echo "=== File Info ==="
ls -l "$PLIST_FILE"

# Check for extended attributes
if xattr -l "$PLIST_FILE" 2>/dev/null | grep -q "com.apple.quarantine"; then
    echo ""
    echo "Warning: This file has a quarantine attribute (downloaded from internet)"
fi
