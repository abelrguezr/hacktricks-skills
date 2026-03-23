#!/bin/bash
# Audio Steganography Triage Script
# Quick inspection of audio files for steganography investigation

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <audio_file> [output_dir]"
    echo "Example: $0 suspicious.wav ./analysis"
    exit 1
fi

AUDIO_FILE="$1"
OUTPUT_DIR="${2:-.}"

if [ ! -f "$AUDIO_FILE" ]; then
    echo "Error: File not found: $AUDIO_FILE"
    exit 1
fi

# Create output directory if needed
mkdir -p "$OUTPUT_DIR"

BASENAME=$(basename "$AUDIO_FILE" .wav .mp3 .flac .ogg .m4a)

echo "=== Audio Steganography Triage ==="
echo "File: $AUDIO_FILE"
echo "Output: $OUTPUT_DIR"
echo ""

# Step 1: File type detection
echo "--- File Type ---"
file "$AUDIO_FILE"
echo ""

# Step 2: FFmpeg inspection
echo "--- FFmpeg Info ---"
ffmpeg -v info -i "$AUDIO_FILE" -f null - 2>&1 | grep -E "(Stream|Duration|bitrate|codec|format)" || true
echo ""

# Step 3: Generate spectrogram
echo "--- Generating Spectrogram ---"
if command -v sox &> /dev/null; then
    sox "$AUDIO_FILE" -n spectrogram -o "$OUTPUT_DIR/${BASENAME}_spectrogram.png" 2>/dev/null && \
        echo "Spectrogram saved: $OUTPUT_DIR/${BASENAME}_spectrogram.png" || \
        echo "Warning: Could not generate spectrogram with sox"
else
    echo "Warning: sox not installed. Install with: apt install sox"
fi
echo ""

# Step 4: Basic statistics
echo "--- File Statistics ---"
ls -lh "$AUDIO_FILE"
echo ""

# Step 5: Check for common stego indicators
echo "--- Stego Indicators ---"

# Check file size vs duration
DURATION=$(ffmpeg -i "$AUDIO_FILE" 2>&1 | grep "Duration" | head -1 | sed 's/.*Duration: //' | sed 's/,.*//')
if [ -n "$DURATION" ]; then
    echo "Duration: $DURATION"
fi

# Check for unusual extensions or naming
if [[ "$AUDIO_FILE" =~ \.wav$ ]] && [[ ! "$AUDIO_FILE" =~ \.wav$ ]]; then
    echo "Warning: File extension mismatch detected"
fi

echo ""
echo "=== Triage Complete ==="
echo "Next steps:"
echo "1. Review spectrogram: $OUTPUT_DIR/${BASENAME}_spectrogram.png"
echo "2. Look for patterns, text, or anomalies"
echo "3. Choose appropriate extraction technique based on findings"
