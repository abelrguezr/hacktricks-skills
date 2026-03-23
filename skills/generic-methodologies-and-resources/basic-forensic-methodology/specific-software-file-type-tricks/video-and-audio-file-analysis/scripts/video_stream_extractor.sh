#!/bin/bash
# Video stream extraction and analysis script
# Usage: video_stream_extractor.sh <video_file>

if [ -z "$1" ]; then
    echo "Usage: $0 <video_file>"
    echo "Example: $0 sample.mp4"
    exit 1
fi

FILE="$1"
BASENAME=$(basename "$FILE" | sed 's/\.[^.]*$//')
OUTPUT_DIR="video_analysis_output"
mkdir -p "$OUTPUT_DIR"

echo "=== Video Stream Analysis ==="
echo "File: $FILE"
echo "Output directory: $OUTPUT_DIR"
echo ""

# Check file info
echo "=== File Information ==="
file "$FILE"
ls -lh "$FILE"
echo ""

# List all streams
echo "=== Stream Information ==="
if command -v ffprobe &> /dev/null; then
    ffprobe -v quiet -print_format json -show_streams "$FILE" > "$OUTPUT_DIR/streams.json"
    echo "Stream details saved to: $OUTPUT_DIR/streams.json"
    echo ""
    
    # Count streams
    VIDEO_STREAMS=$(ffprobe -v error -select_streams v -show_entries stream=index -of csv=p=0 "$FILE" | wc -l)
    AUDIO_STREAMS=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$FILE" | wc -l)
    SUBTITLE_STREAMS=$(ffprobe -v error -select_streams s -show_entries stream=index -of csv=p=0 "$FILE" | wc -l)
    DATA_STREAMS=$(ffprobe -v error -select_streams d -show_entries stream=index -of csv=p=0 "$FILE" | wc -l)
    
    echo "Video streams: $VIDEO_STREAMS"
    echo "Audio streams: $AUDIO_STREAMS"
    echo "Subtitle streams: $SUBTITLE_STREAMS"
    echo "Data/attachment streams: $DATA_STREAMS"
else
    echo "ffprobe not installed"
fi
echo ""

# Extract video stream
echo "=== Extracting Video Stream ==="
if command -v ffmpeg &> /dev/null; then
    ffmpeg -y -i "$FILE" -c:v copy -an "$OUTPUT_DIR/${BASENAME}_video.mkv" 2>/dev/null
    if [ -f "$OUTPUT_DIR/${BASENAME}_video.mkv" ]; then
        echo "Created: $OUTPUT_DIR/${BASENAME}_video.mkv"
    fi
else
    echo "ffmpeg not installed - skipping extraction"
fi
echo ""

# Extract audio streams
echo "=== Extracting Audio Streams ==="
if command -v ffmpeg &> /dev/null; then
    for i in $(seq 0 $((AUDIO_STREAMS - 1))); do
        ffmpeg -y -i "$FILE" -map 0:a:$i -c:a copy "$OUTPUT_DIR/${BASENAME}_audio_${i}.aac" 2>/dev/null
        if [ -f "$OUTPUT_DIR/${BASENAME}_audio_${i}.aac" ]; then
            echo "Created: $OUTPUT_DIR/${BASENAME}_audio_${i}.aac"
        fi
    done
fi
echo ""

# Extract subtitle streams
echo "=== Extracting Subtitle Streams ==="
if command -v ffmpeg &> /dev/null; then
    for i in $(seq 0 $((SUBTITLE_STREAMS - 1))); do
        ffmpeg -y -i "$FILE" -map 0:s:$i "$OUTPUT_DIR/${BASENAME}_subtitle_${i}.srt" 2>/dev/null
        if [ -f "$OUTPUT_DIR/${BASENAME}_subtitle_${i}.srt" ]; then
            echo "Created: $OUTPUT_DIR/${BASENAME}_subtitle_${i}.srt"
            echo "Subtitle content preview:"
            head -20 "$OUTPUT_DIR/${BASENAME}_subtitle_${i}.srt"
            echo ""
        fi
    done
fi
echo ""

# Extract data/attachment streams
echo "=== Extracting Data/Attachment Streams ==="
if command -v ffmpeg &> /dev/null; then
    for i in $(seq 0 $((DATA_STREAMS - 1))); do
        ffmpeg -y -i "$FILE" -map 0:d:$i "$OUTPUT_DIR/${BASENAME}_attachment_${i}.bin" 2>/dev/null
        if [ -f "$OUTPUT_DIR/${BASENAME}_attachment_${i}.bin" ]; then
            echo "Created: $OUTPUT_DIR/${BASENAME}_attachment_${i}.bin"
            file "$OUTPUT_DIR/${BASENAME}_attachment_${i}.bin"
        fi
    done
fi
echo ""

# Extract sample frames
echo "=== Extracting Sample Frames ==="
if command -v ffmpeg &> /dev/null; then
    # Extract first 10 frames
    ffmpeg -y -i "$FILE" -vf "select='lt(n\,10)'" -vsync vfr "$OUTPUT_DIR/frame_%03d.png" 2>/dev/null
    FRAME_COUNT=$(ls -1 "$OUTPUT_DIR"/frame_*.png 2>/dev/null | wc -l)
    echo "Extracted $FRAME_COUNT frames"
    
    # Extract frame at 10% mark
    DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$FILE" 2>/dev/null)
    if [ -n "$DURATION" ]; then
        TIME_10=$(echo "$DURATION * 0.1" | bc 2>/dev/null || echo "1")
        ffmpeg -y -i "$FILE" -ss "$TIME_10" -vframes 1 "$OUTPUT_DIR/frame_10percent.png" 2>/dev/null
        if [ -f "$OUTPUT_DIR/frame_10percent.png" ]; then
            echo "Created: $OUTPUT_DIR/frame_10percent.png"
        fi
    fi
fi
echo ""

# Check for hidden strings in video
echo "=== Searching for Hidden Strings ==="
strings "$FILE" 2>/dev/null | grep -iE "flag|secret|hidden|password|key|ctf|solution" | head -10
echo ""

# Check file end
echo "=== File End Analysis ==="
xxd "$FILE" | tail -20
echo ""

echo "=== Video analysis complete ==="
echo "Results in: $OUTPUT_DIR/"
echo ""
echo "Next steps:"
echo "1. Review extracted subtitle files for hidden messages"
echo "2. Check attachment streams for embedded files"
echo "3. Analyze extracted frames for visual steganography"
echo "4. Run audio analysis on extracted audio streams"
