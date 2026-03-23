#!/bin/bash
# Audio forensics analysis script
# Usage: audio_analysis.sh <audio_file>

if [ -z "$1" ]; then
    echo "Usage: $0 <audio_file>"
    echo "Example: $0 sample.wav"
    exit 1
fi

FILE="$1"
BASENAME=$(basename "$FILE" | sed 's/\.[^.]*$//')
OUTPUT_DIR="audio_analysis_output"
mkdir -p "$OUTPUT_DIR"

echo "=== Audio Forensics Analysis ==="
echo "File: $FILE"
echo "Output directory: $OUTPUT_DIR"
echo ""

# Check file info
echo "=== File Information ==="
file "$FILE"
ls -lh "$FILE"
echo ""

# Extract metadata
echo "=== Metadata ==="
if command -v exiftool &> /dev/null; then
    exiftool "$FILE" | grep -v "exiftool"
fi
echo ""

# Audio properties
echo "=== Audio Properties ==="
if command -v ffprobe &> /dev/null; then
    ffprobe -v error -show_entries stream=codec_name,sample_rate,channels,bit_rate -of default=noprint_wrappers=1 "$FILE"
fi
echo ""

# Create reversed version
echo "=== Creating Reversed Version ==="
if command -v sox &> /dev/null; then
    sox "$FILE" "$OUTPUT_DIR/${BASENAME}_reversed.wav" reverse
    echo "Created: $OUTPUT_DIR/${BASENAME}_reversed.wav"
else
    echo "sox not installed - skipping reversed version"
fi
echo ""

# Create slowed version (0.5x speed)
echo "=== Creating Slowed Version (0.5x) ==="
if command -v sox &> /dev/null; then
    sox "$FILE" "$OUTPUT_DIR/${BASENAME}_slowed.wav" speed 0.5
    echo "Created: $OUTPUT_DIR/${BASENAME}_slowed.wav"
else
    echo "sox not installed - skipping slowed version"
fi
echo ""

# Create sped up version (2x speed)
echo "=== Creating Sped Up Version (2x) ==="
if command -v sox &> /dev/null; then
    sox "$FILE" "$OUTPUT_DIR/${BASENAME}_spedup.wav" speed 2.0
    echo "Created: $OUTPUT_DIR/${BASENAME}_spedup.wav"
else
    echo "sox not installed - skipping sped up version"
fi
echo ""

# Invert audio
echo "=== Creating Inverted Version ==="
if command -v sox &> /dev/null; then
    sox "$FILE" "$OUTPUT_DIR/${BASENAME}_inverted.wav" vol -1
    echo "Created: $OUTPUT_DIR/${BASENAME}_inverted.wav"
else
    echo "sox not installed - skipping inverted version"
fi
echo ""

# Check for DTMF/Morse if multimon-ng available
echo "=== DTMF/Morse Detection ==="
if command -v multimon-ng &> /dev/null; then
    echo "Testing for DTMF tones..."
    multimon-ng -f 44100 -a DTMF -d "$FILE" 2>/dev/null | head -20
    echo ""
    echo "Testing for Morse code..."
    multimon-ng -f 44100 -a MORSE -d "$FILE" 2>/dev/null | head -20
else
    echo "multimon-ng not installed - skipping tone detection"
fi
echo ""

# Extract strings
echo "=== Embedded Strings ==="
strings "$FILE" 2>/dev/null | grep -iE "flag|secret|hidden|password|key|ctf" | head -10
echo ""

# Check file end for appended data
echo "=== File End Analysis ==="
xxd "$FILE" | tail -20
echo ""

echo "=== Audio analysis complete ==="
echo "Processed files in: $OUTPUT_DIR/"
echo ""
echo "Next steps:"
echo "1. Open original file in Audacity and view spectrogram (View -> Spectrogram)"
echo "2. Listen to reversed/slowed versions for hidden messages"
echo "3. Check spectrogram for visual patterns or text"
echo "4. Use Sonic Visualiser for detailed frequency analysis"
