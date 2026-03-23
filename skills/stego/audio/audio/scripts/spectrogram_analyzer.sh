#!/bin/bash
# Spectrogram Analysis Script
# Generates multiple spectrogram views for steganography detection

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <audio_file> [output_dir]"
    echo "Example: $0 suspicious.wav ./spectrograms"
    exit 1
fi

AUDIO_FILE="$1"
OUTPUT_DIR="${2:-.}"

if [ ! -f "$AUDIO_FILE" ]; then
    echo "Error: File not found: $AUDIO_FILE"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

BASENAME=$(basename "$AUDIO_FILE" .wav .mp3 .flac .ogg)

echo "=== Spectrogram Analysis ==="
echo "Input: $AUDIO_FILE"
echo "Output: $OUTPUT_DIR"
echo ""

# Check for sox
if ! command -v sox &> /dev/null; then
    echo "Error: sox not installed"
    echo "Install with: apt install sox"
    exit 1
fi

# Generate multiple spectrogram views
echo "--- Generating Spectrograms ---"

# Standard spectrogram
echo "1. Standard spectrogram..."
sox "$AUDIO_FILE" -n spectrogram -o "$OUTPUT_DIR/${BASENAME}_spec_standard.png" 2>/dev/null && \
    echo "   Saved: $OUTPUT_DIR/${BASENAME}_spec_standard.png"

# High resolution spectrogram
echo "2. High resolution spectrogram..."
sox "$AUDIO_FILE" -n spectrogram -o "$OUTPUT_DIR/${BASENAME}_spec_hires.png" \
    --size 4096 --overlap 0.95 --window 0.95 2>/dev/null && \
    echo "   Saved: $OUTPUT_DIR/${BASENAME}_spec_hires.png"

# Wide frequency range
echo "3. Wide frequency range spectrogram..."
sox "$AUDIO_FILE" -n spectrogram -o "$OUTPUT_DIR/${BASENAME}_spec_wide.png" \
    --size 2048 --overlap 0.9 --window 0.9 --range 120 2>/dev/null && \
    echo "   Saved: $OUTPUT_DIR/${BASENAME}_spec_wide.png"

# Narrow band (for FSK detection)
echo "4. Narrow band spectrogram..."
sox "$AUDIO_FILE" -n spectrogram -o "$OUTPUT_DIR/${BASENAME}_spec_narrow.png" \
    --size 1024 --overlap 0.8 --window 0.8 --range 60 2>/dev/null && \
    echo "   Saved: $OUTPUT_DIR/${BASENAME}_spec_narrow.png"

# Logarithmic frequency scale
echo "5. Logarithmic frequency spectrogram..."
sox "$AUDIO_FILE" -n spectrogram -o "$OUTPUT_DIR/${BASENAME}_spec_log.png" \
    --size 2048 --overlap 0.9 --window 0.9 --log 2>/dev/null && \
    echo "   Saved: $OUTPUT_DIR/${BASENAME}_spec_log.png"

echo ""
echo "=== Analysis Complete ==="
echo ""
echo "Generated spectrograms:"
ls -lh "$OUTPUT_DIR"/${BASENAME}_spec_*.png 2>/dev/null || echo "(none)"
echo ""
echo "Analysis tips:"
echo "- Look for text, QR codes, or patterns in the images"
echo "- Standard view: Good for general inspection"
echo "- High resolution: Better for small details"
echo "- Wide range: Shows full frequency spectrum"
echo "- Narrow band: Good for detecting FSK/modem tones"
echo "- Logarithmic: Better for human hearing perception"
echo ""
echo "Open the images in an image viewer to inspect for hidden data."
