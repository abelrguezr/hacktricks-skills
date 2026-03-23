#!/bin/bash
# Detect compression format from magic bytes
# Usage: ./detect_compression.sh <file> or echo "data" | ./detect_compression.sh

if [ $# -eq 0 ]; then
    # Read from stdin, save to temp file
    TMPFILE=$(mktemp)
    cat > "$TMPFILE"
    INPUT="$TMPFILE"
    CLEANUP=1
else
    INPUT="$1"
    CLEANUP=0
fi

if [ ! -f "$INPUT" ]; then
    echo "Error: File not found: $INPUT"
    exit 1
fi

echo "=== Compression Detection ==="
echo "File: $INPUT"
echo ""

# Get first 8 bytes as hex
MAGIC=$(xxd -l 8 -p "$INPUT" 2>/dev/null)
echo "Magic bytes: $MAGIC"
echo ""

# Check for known compression formats
case "$MAGIC" in
    1f8b*)
        echo "✓ gzip detected (1f 8b)"
        echo "  Try: gunzip -c $INPUT"
        ;;
    7801*|789c*|78da*)
        echo "✓ zlib detected (78 01/9c/da)"
        echo "  Try: python3 -c \"import zlib,sys; print(zlib.decompress(open('$INPUT','rb').read()))\""
        ;;
    504b0304*)
        echo "✓ zip detected (50 4b 03 04)"
        echo "  Try: unzip -p $INPUT"
        ;;
    425a68*)
        echo "✓ bzip2 detected (42 5a 68 = BZh)"
        echo "  Try: bunzip2 -c $INPUT"
        ;;
    fd377a585a00*)
        echo "✓ xz detected (fd 37 7a 58 5a 00)"
        echo "  Try: xz -dc $INPUT"
        ;;
    28b52ffd*)
        echo "✓ zstd detected (28 b5 2f fd)"
        echo "  Try: zstd -dc $INPUT"
        ;;
    *)
        echo "✗ No known compression format detected"
        echo "  Try: file $INPUT"
        echo "  Try: CyberChef Raw Deflate/Raw Inflate"
        ;;
esac

# Cleanup temp file if created
if [ $CLEANUP -eq 1 ]; then
    rm -f "$TMPFILE"
fi
