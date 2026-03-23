#!/bin/bash
# Remove quarantine xattr from files or applications
# Usage: ./quarantine-bypass.sh <path-to-file-or-app>

if [ $# -lt 1 ]; then
    echo "Usage: $0 <path-to-file-or-app>"
    echo "Example: $0 /Applications/MyApp.app"
    echo "Example: $0 /path/to/binary"
    exit 1
fi

TARGET="$1"

# Check if target exists
if [ ! -e "$TARGET" ]; then
    echo "Error: Target does not exist: $TARGET"
    exit 1
fi

# Check current quarantine status
echo "Checking quarantine status..."
xattr -p com.apple.quarantine "$TARGET" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "Quarantine xattr found. Removing..."
    xattr -d com.apple.quarantine "$TARGET"
    if [ $? -eq 0 ]; then
        echo "Successfully removed quarantine xattr from: $TARGET"
    else
        echo "Failed to remove quarantine xattr. Try with sudo:"
        echo "  sudo xattr -d com.apple.quarantine $TARGET"
    fi
else
    echo "No quarantine xattr found on: $TARGET"
fi

# Show all xattrs
echo ""
echo "Current xattrs:"
xattr -l "$TARGET" 2>/dev/null || echo "No xattrs found"
