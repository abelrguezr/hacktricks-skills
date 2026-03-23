#!/bin/bash
# WAV LSB Extraction Script
# Extracts hidden data from WAV files using various bit depths

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <wav_file> [output_prefix]"
    echo "Example: $0 hidden.wav extracted"
    echo ""
    echo "This script tries multiple bit depths (1-4) and saves all outputs."
    exit 1
fi

WAV_FILE="$1"
OUTPUT_PREFIX="${2:-extracted}"

if [ ! -f "$WAV_FILE" ]; then
    echo "Error: File not found: $WAV_FILE"
    exit 1
fi

# Check if it's a WAV file
FILE_TYPE=$(file -b "$WAV_FILE")
if [[ ! "$FILE_TYPE" =~ WAV|RIFF ]]; then
    echo "Warning: File may not be a WAV file: $FILE_TYPE"
    echo "LSB extraction works best with uncompressed PCM WAV files."
fi

BASENAME=$(basename "$WAV_FILE" .wav)

echo "=== WAV LSB Extraction ==="
echo "Input: $WAV_FILE"
echo "Output prefix: $OUTPUT_PREFIX"
echo ""

# Check for WavSteg
if [ -f "WavSteg.py" ]; then
    WAVEG_SCRIPT="WavSteg.py"
elif [ -f "./WavSteg.py" ]; then
    WAVEG_SCRIPT="./WavSteg.py"
else
    echo "Error: WavSteg.py not found in current directory"
    echo "Download from: https://github.com/ragibson/Steganography#WavSteg"
    exit 1
fi

echo "Using: $WAVEG_SCRIPT"
echo ""

# Try different bit depths
for BITS in 1 2 3 4; do
    OUTPUT_FILE="${OUTPUT_PREFIX}_b${BITS}.bin"
    echo "--- Extracting $BITS bit(s) per sample ---"
    
    if python3 "$WAVEG_SCRIPT" -r -b $BITS -s "$WAV_FILE" -o "$OUTPUT_FILE" 2>/dev/null; then
        echo "Extracted: $OUTPUT_FILE"
        
        # Check what type of data was extracted
        if [ -f "$OUTPUT_FILE" ]; then
            FILE_SIZE=$(stat -c%s "$OUTPUT_FILE" 2>/dev/null || stat -f%z "$OUTPUT_FILE" 2>/dev/null || echo "0")
            echo "  Size: $FILE_SIZE bytes"
            
            # Try to identify the file type
            if [ "$FILE_SIZE" -gt 0 ]; then
                EXTRACTED_TYPE=$(file -b "$OUTPUT_FILE" 2>/dev/null || echo "unknown")
                echo "  Type: $EXTRACTED_TYPE"
                
                # If it looks like text, show first few lines
                if [[ "$EXTRACTED_TYPE" =~ text|ASCII ]]; then
                    echo "  Preview:"
                    head -c 200 "$OUTPUT_FILE" 2>/dev/null | cat -v | fold -w 80
                    echo ""
                fi
            fi
        fi
    else
        echo "  Failed to extract at $BITS bits"
    fi
    echo ""
done

echo "=== Extraction Complete ==="
echo "Check the output files for readable content."
echo "If nothing found, try:"
echo "- Different bit depths"
echo "- Other LSB tools (DeepSound)"
echo "- Different steganography techniques"
