#!/bin/bash
# macOS File Flags Checker
# Usage: ./check-file-flags.sh <file_or_directory>

if [ -z "$1" ]; then
    echo "Usage: $0 <file_or_directory>"
    echo ""
    echo "This script checks file flags on macOS."
    echo ""
    echo "Common flags:"
    echo "  uchg (uchange) - File may not be changed"
    echo "  restricted - Protected by SIP"
    echo "  sticky - Only owner/root can delete files in directory"
    exit 1
fi

TARGET="$1"

echo "=== File Flags for: $TARGET ==="
echo ""

# Check if target exists
if [ ! -e "$TARGET" ]; then
    echo "Error: $TARGET does not exist"
    exit 1
fi

# Show detailed flags
ls -lO "$TARGET"

echo ""
echo "=== Flag Interpretation ==="

# Get flags
FLAGS=$(ls -lO "$TARGET" | awk '{print $1}' | grep -oE '[a-z]+')

if [ -n "$FLAGS" ]; then
    for FLAG in $FLAGS; do
        case $FLAG in
            uchg)
                echo "  uchg: File is immutable (cannot be modified/deleted)"
                echo "        Remove with: chflags nouchg $TARGET"
                ;;
            restricted)
                echo "  restricted: Protected by System Integrity Protection (SIP)"
                echo "              Cannot be modified even by root without SIP bypass"
                ;;
            schg)
                echo "  schg: System immutable (superuser cannot change)"
                echo "        Remove with: chflags noschg $TARGET (requires root)"
                ;;
            append)
                echo "  append: File can only be appended to, not modified"
                ;;
            nodump)
                echo "  nodump: File excluded from backups"
                ;;
            hidden)
                echo "  hidden: File should be hidden from GUI"
                ;;
            compressed)
                echo "  compressed: File is compressed (decmpfs)"
                echo "              Use afscexpand to decompress"
                ;;
            *)
                echo "  $FLAG: Unknown or system flag"
                ;;
        esac
    done
else
    echo "  No special flags set"
fi

echo ""
echo "=== Extended Attributes ==="
xattr -l "$TARGET" 2>/dev/null || echo "  No extended attributes"

echo ""
echo "=== ACLs ==="
if ls -lde "$TARGET" 2>/dev/null | grep -q "^[0-9]"; then
    ls -lde "$TARGET"
else
    echo "  No ACLs set"
fi
