#!/bin/bash
# FSK/Modem Audio Decoder Script
# Brute-forces common baud rates to decode hidden messages

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <audio_file> [output_prefix]"
    echo "Example: $0 modem_noise.wav decoded"
    exit 1
fi

AUDIO_FILE="$1"
OUTPUT_PREFIX="${2:-decoded}"

if [ ! -f "$AUDIO_FILE" ]; then
    echo "Error: File not found: $AUDIO_FILE"
    exit 1
fi

# Check for minimodem
if ! command -v minimodem &> /dev/null; then
    echo "Error: minimodem not installed"
    echo "Install with: apt install minimodem"
    exit 1
fi

BASENAME=$(basename "$AUDIO_FILE")

echo "=== FSK/Modem Decoder ==="
echo "Input: $AUDIO_FILE"
echo "Output prefix: $OUTPUT_PREFIX"
echo ""

# Common baud rates to try
BAUD_RATES=(45 75 110 150 300 600 1200 2400 4800 9600 19200)

echo "Trying baud rates: ${BAUD_RATES[*]}"
echo ""

SUCCESS_COUNT=0

for BAUD in "${BAUD_RATES[@]}"; do
    OUTPUT_FILE="${OUTPUT_PREFIX}_baud${BAUD}.txt"
    
    echo "--- Testing ${BAUD} baud ---"
    
    # Try normal decoding
    if minimodem -f "$AUDIO_FILE" $BAUD > "$OUTPUT_FILE" 2>/dev/null; then
        # Check if output contains printable text
        PRINTABLE=$(grep -o '[A-Za-z0-9 ]' "$OUTPUT_FILE" 2>/dev/null | wc -l)
        TOTAL=$(wc -c < "$OUTPUT_FILE" 2>/dev/null || echo "0")
        
        if [ "$TOTAL" -gt 0 ]; then
            PERCENTAGE=$((PRINTABLE * 100 / TOTAL))
            echo "  Output: $OUTPUT_FILE ($TOTAL bytes, ~$PERCENTAGE% printable)"
            
            # Show preview if it looks promising
            if [ "$PERCENTAGE" -gt 30 ]; then
                echo "  Preview:"
                head -c 150 "$OUTPUT_FILE" 2>/dev/null | cat -v | fold -w 80
                echo ""
                SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            fi
        fi
    else
        echo "  Failed at ${BAUD} baud"
    fi
    
    # Also try with inverted signal
    OUTPUT_FILE_INV="${OUTPUT_PREFIX}_baud${BAUD}_inv.txt"
    if minimodem -f "$AUDIO_FILE" $BAUD --rx-invert > "$OUTPUT_FILE_INV" 2>/dev/null; then
        PRINTABLE=$(grep -o '[A-Za-z0-9 ]' "$OUTPUT_FILE_INV" 2>/dev/null | wc -l)
        TOTAL=$(wc -c < "$OUTPUT_FILE_INV" 2>/dev/null || echo "0")
        
        if [ "$TOTAL" -gt 0 ]; then
            PERCENTAGE=$((PRINTABLE * 100 / TOTAL))
            if [ "$PERCENTAGE" -gt 30 ]; then
                echo "  Inverted output: $OUTPUT_FILE_INV (~$PERCENTAGE% printable)"
                echo "  Preview:"
                head -c 150 "$OUTPUT_FILE_INV" 2>/dev/null | cat -v | fold -w 80
                echo ""
                SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            fi
        fi
    fi
done

echo "=== Decoding Complete ==="
if [ $SUCCESS_COUNT -gt 0 ]; then
    echo "Found $SUCCESS_COUNT promising outputs. Review them for readable content."
else
    echo "No clear results found. Try:"
    echo "- Checking spectrogram for frequency patterns"
    echo "- Converting audio to WAV if it's in another format"
    echo "- Using different modem software (kuiv3er, etc.)"
fi
