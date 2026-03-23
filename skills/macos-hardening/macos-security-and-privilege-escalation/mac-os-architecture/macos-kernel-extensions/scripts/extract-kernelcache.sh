#!/bin/bash
# Extract kernelcache from IPSW or local system
# Usage: ./extract-kernelcache.sh <ipsw-path|local> [output-dir]

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <ipsw-path|local> [output-dir]"
    echo "  ipsw-path: Path to .ipsw file"
    echo "  local: Search local system for kernelcache"
    exit 1
fi

OUTPUT_DIR="${2:-./kernelcache-output}"
mkdir -p "$OUTPUT_DIR"

if [ "$1" = "local" ]; then
    echo "Searching local system for kernelcache..."
    KC_PATH=$(find / -name "kernelcache" 2>/dev/null | head -1)
    if [ -z "$KC_PATH" ]; then
        echo "ERROR: No kernelcache found on system"
        exit 1
    fi
    echo "Found: $KC_PATH"
    cp "$KC_PATH" "$OUTPUT_DIR/kernelcache"
    echo "Copied to: $OUTPUT_DIR/kernelcache"
else
    IPSW_PATH="$1"
    if [ ! -f "$IPSW_PATH" ]; then
        echo "ERROR: IPSW file not found: $IPSW_PATH"
        exit 1
    fi
    
    echo "Extracting kernelcache from: $IPSW_PATH"
    
    # Check if ipsw tool is available
    if command -v ipsw &> /dev/null; then
        echo "Using ipsw tool..."
        ipsw extract --kernel "$IPSW_PATH" -o "$OUTPUT_DIR"
    else
        echo "ipsw tool not found. Attempting manual extraction..."
        echo "Installing ipsw tool: brew install blacktop/tap/ipsw"
        echo "Then re-run this script."
        exit 1
    fi
    
    # Check for IMG4 payload and extract if needed
    IMG4_FILE=$(find "$OUTPUT_DIR" -name "*.im4p" 2>/dev/null | head -1)
    if [ -n "$IMG4_FILE" ]; then
        echo "Found IMG4 payload: $IMG4_FILE"
        if command -v pyimg4 &> /dev/null; then
            pyimg4 im4p extract -i "$IMG4_FILE" -o "$OUTPUT_DIR/kernelcache.raw"
        elif command -v img4tool &> /dev/null; then
            img4tool -e "$IMG4_FILE" -o "$OUTPUT_DIR/kernelcache.raw"
        else
            echo "WARNING: Neither pyimg4 nor img4tool found. Install one to extract IMG4."
        fi
    fi
fi

echo ""
echo "Extraction complete. Output in: $OUTPUT_DIR"
echo ""
echo "Next steps:"
echo "  Check for symbols: nm -a $OUTPUT_DIR/kernelcache* | wc -l"
echo "  Extract kexts: kextex -l $OUTPUT_DIR/kernelcache*"
