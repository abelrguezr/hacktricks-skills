#!/bin/bash
# Filesystem Extraction Script
# Extracts filesystem from firmware binary

set -e

usage() {
    echo "Usage: $0 <firmware.bin> [options]"
    echo ""
    echo "Options:"
    echo "  -o <offset>    Manual offset (hex or decimal)"
    echo "  -t <type>      Filesystem type: squashfs, cpio, jffs2, ubifs"
    echo "  -a             Auto-detect and extract (default)"
    echo "  -h             Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 firmware.bin -a"
    echo "  $0 firmware.bin -o 0x1A0094 -t squashfs"
    exit 1
}

if [ $# -lt 1 ]; then
    usage
fi

FIRMWARE="$1"
OFFSET=""
FS_TYPE=""
AUTO=false

while getopts "o:t:ah" opt; do
    case $opt in
        o) OFFSET="$OPTARG" ;;
        t) FS_TYPE="$OPTARG" ;;
        a) AUTO=true ;;
        h) usage ;;
        *) usage ;;
    esac
done

if [ ! -f "$FIRMWARE" ]; then
    echo "Error: File not found: $FIRMWARE"
    exit 1
fi

OUTPUT_DIR="extracted_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTPUT_DIR"

echo "=== Filesystem Extraction ==="
echo "Target: $FIRMWARE"
echo "Output: $OUTPUT_DIR"
echo ""

# Auto-detect mode
if [ "$AUTO" = true ]; then
    echo "[Auto] Scanning for filesystems..."
    if command -v binwalk &> /dev/null; then
        binwalk -eM "$FIRMWARE" -D "" -o "$OUTPUT_DIR" 2>&1 || {
            echo "Binwalk extraction failed, trying manual detection..."
        }
        
        # Check what was extracted
        if ls "$OUTPUT_DIR"/*squashfs* 2>/dev/null | head -1 | grep -q .; then
            echo "Found squashfs, extracting..."
            for fs in "$OUTPUT_DIR"/*squashfs*; do
                unsquashfs "$fs" -d "$OUTPUT_DIR/squashfs-root" 2>/dev/null || true
            done
        fi
        
        if ls "$OUTPUT_DIR"/*cpio* 2>/dev/null | head -1 | grep -q .; then
            echo "Found cpio, extracting..."
            for fs in "$OUTPUT_DIR"/*cpio*; do
                mkdir -p "$OUTPUT_DIR/cpio-root"
                cd "$OUTPUT_DIR/cpio-root"
                cpio -idmv < "$fs" 2>/dev/null || true
                cd - > /dev/null
            done
        fi
        
        echo "Auto-extraction complete. Check $OUTPUT_DIR for results."
    else
        echo "Error: binwalk required for auto-detection"
        echo "Install with: pip install binwalk"
        exit 1
    fi
    exit 0
fi

# Manual extraction mode
if [ -z "$OFFSET" ] || [ -z "$FS_TYPE" ]; then
    echo "Error: Both offset (-o) and type (-t) required for manual extraction"
    usage
fi

# Convert hex offset to decimal if needed
if [[ "$OFFSET" == 0x* ]]; then
    OFFSET_DEC=$((OFFSET))
else
    OFFSET_DEC=$OFFSET
fi

echo "[Manual] Carving filesystem at offset $OFFSET_DEC (0x$(printf '%x' $OFFSET_DEC))..."

# Carve the filesystem
CARVED_FS="$OUTPUT_DIR/carved_fs.bin"
dd if="$FIRMWARE" bs=1 skip=$OFFSET_DEC of="$CARVED_FS" 2>&1 | tail -1

echo "Carved filesystem saved to: $CARVED_FS"
echo ""

# Extract based on type
echo "Extracting $FS_TYPE filesystem..."
case $FS_TYPE in
    squashfs)
        unsquashfs "$CARVED_FS" -d "$OUTPUT_DIR/squashfs-root" 2>&1 || {
            echo "Error: Failed to extract squashfs"
            exit 1
        }
        echo "Extracted to: $OUTPUT_DIR/squashfs-root"
        ;;
    cpio)
        mkdir -p "$OUTPUT_DIR/cpio-root"
        cd "$OUTPUT_DIR/cpio-root"
        cpio -idmv < "$CARVED_FS" 2>&1 || {
            echo "Error: Failed to extract cpio"
            exit 1
        }
        cd - > /dev/null
        echo "Extracted to: $OUTPUT_DIR/cpio-root"
        ;;
    jffs2)
        if command -v jefferson &> /dev/null; then
            jefferson "$CARVED_FS" -o "$OUTPUT_DIR/jffs2-root" 2>&1 || {
                echo "Error: Failed to extract jffs2"
                exit 1
            }
            echo "Extracted to: $OUTPUT_DIR/jffs2-root"
        else
            echo "Error: jefferson not installed"
            exit 1
        fi
        ;;
    ubifs)
        if command -v ubireader_extract_images &> /dev/null; then
            ubireader_extract_images -u UBI -s 0 "$CARVED_FS" -o "$OUTPUT_DIR/ubifs-root" 2>&1 || {
                echo "Error: Failed to extract ubifs"
                exit 1
            }
            echo "Extracted to: $OUTPUT_DIR/ubifs-root"
        else
            echo "Error: ubireader not installed"
            exit 1
        fi
        ;;
    *)
        echo "Error: Unknown filesystem type: $FS_TYPE"
        echo "Supported: squashfs, cpio, jffs2, ubifs"
        exit 1
        ;;
esac

echo ""
echo "=== Extraction Complete ==="
echo "Filesystem extracted to: $OUTPUT_DIR"
echo ""
echo "Next steps:"
echo "  - Search for credentials: grep -r 'password' $OUTPUT_DIR/"
echo "  - Check /etc/shadow and /etc/passwd"
echo "  - Analyze binaries with checksec.sh"
