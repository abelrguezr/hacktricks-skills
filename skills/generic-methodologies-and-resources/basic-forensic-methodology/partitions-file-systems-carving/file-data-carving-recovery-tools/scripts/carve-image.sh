#!/bin/bash
# Forensic Data Carving Script
# Usage: ./carve-image.sh <evidence-file> <output-dir> [tool]
#
# Tools: autopsy, foremost, scalpel, bulk_extractor, photorec, binwalk

set -e

EVIDENCE="$1"
OUTPUT_DIR="$2"
TOOL="${3:-auto}"

if [[ -z "$EVIDENCE" || -z "$OUTPUT_DIR" ]]; then
    echo "Usage: $0 <evidence-file> <output-dir> [tool]"
    echo "Tools: autopsy, foremost, scalpel, bulk_extractor, photorec, binwalk, auto"
    exit 1
fi

if [[ ! -f "$EVIDENCE" ]]; then
    echo "Error: Evidence file not found: $EVIDENCE"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "Starting carving on: $EVIDENCE"
echo "Output directory: $OUTPUT_DIR"
echo "Tool: $TOOL"
echo ""

case "$TOOL" in
    auto)
        # Auto-detect based on file extension
        case "$EVIDENCE" in
            *.bin|*.fw|*.hex)
                TOOL="binwalk"
                ;;
            *.img|*.E01|*.raw|*.dd)
                TOOL="foremost"
                ;;
            *)
                TOOL="foremost"
                ;;
        esac
        echo "Auto-selected tool: $TOOL"
        ;;
esac

case "$TOOL" in
    foremost)
        echo "Running Foremost..."
        foremost -v -i "$EVIDENCE" -o "$OUTPUT_DIR/foremost"
        ;;
    scalpel)
        echo "Running Scalpel..."
        scalpel "$EVIDENCE" -o "$OUTPUT_DIR/scalpel"
        ;;
    binwalk)
        echo "Running Binwalk..."
        binwalk -e "$EVIDENCE" -D "." -o "$OUTPUT_DIR/binwalk"
        ;;
    bulk_extractor)
        echo "Running Bulk Extractor..."
        bulk_extractor -o "$OUTPUT_DIR/bulk_extractor" "$EVIDENCE"
        ;;
    photorec)
        echo "Running PhotoRec (interactive)..."
        photorec "$EVIDENCE"
        ;;
    autopsy)
        echo "Autopsy requires case creation. Use autopsycli directly:"
        echo "  autopsycli case --create MyCase --base /cases"
        echo "  autopsycli ingest MyCase $EVIDENCE --threads 8"
        ;;
    *)
        echo "Unknown tool: $TOOL"
        exit 1
        ;;
esac

echo ""
echo "Carving complete. Results in: $OUTPUT_DIR"
