---
name: video-audio-forensics
description: How to analyze video and audio files for hidden data, steganography, and forensic evidence. Use this skill whenever the user mentions audio files, video files, CTF forensics challenges, steganography, hidden messages, spectrograms, metadata analysis, or any task involving extracting secrets from media files. This includes .mp3, .wav, .mp4, .avi, .mkv, .flac, .ogg, and similar formats.
---

# Video and Audio File Forensics

This skill guides you through analyzing audio and video files to uncover hidden data, steganographic content, and forensic evidence. Common in CTF challenges and digital forensics investigations.

## Quick Start Workflow

When presented with an audio or video file to analyze:

1. **Check file metadata** - Use `exiftool` or `mediainfo` to inspect headers and embedded data
2. **Examine file structure** - Look for appended data, unusual file sizes, or multiple streams
3. **Analyze audio content** - Use spectrograms, waveform analysis, and audio manipulation
4. **Check video streams** - De-multiplex containers, examine individual tracks
5. **Look for steganography** - Test LSB manipulation, hidden channels, encoded tones

## Step 1: Metadata Analysis

Start by extracting all metadata from the file. This often reveals hidden information, creation timestamps, or embedded data.

### Using exiftool

```bash
# Full metadata dump
exiftool <filename>

# Specific fields
exiftool -Comment -Description -Author <filename>

# Binary/hex dump of metadata
exiftool -b -Comment <filename>
```

### Using mediainfo

```bash
# Complete technical report
mediainfo <filename>

# Compact output
mediainfo --Output=Text <filename>

# JSON format for parsing
mediainfo --Output=JSON <filename>
```

**What to look for:**
- Unusual or suspicious comments/descriptions
- Multiple authors or conflicting metadata
- Hidden text in metadata fields
- File creation/modification timestamps that don't match content
- Embedded thumbnails or attachments

## Step 2: File Structure Examination

Check if the file contains appended data or unusual structure.

### Check for appended data

```bash
# Look at end of file
xxd <filename> | tail -100

# Check file size vs expected
file <filename>

# Look for multiple file signatures
strings <filename> | grep -i "PK\|RIFF\|ID3\|FLAC"
```

### Extract appended files

If you find data after the main file ends:

```bash
# Find where the actual file ends
# Then extract everything after
```

### Check for steganography containers

```bash
# Look for hidden files inside
binwalk <filename>

# Extract embedded files
binwalk -e <filename>
```

## Step 3: Audio Analysis

### Spectrogram Analysis

Spectrograms reveal visual patterns in audio that may contain hidden text or images.

**Using Audacity:**
1. Open the audio file
2. Select the track
3. Go to View → Spectrogram
4. Look for text, QR codes, or unusual patterns
5. Try different spectrogram settings (FFT size, window type)

**Using Sonic Visualiser:**
1. Load the audio file
2. Add Spectrogram view (View → Add Spectrogram)
3. Adjust frequency range and time scale
4. Look for hidden visual data

**What to look for:**
- Text embedded in frequency patterns
- QR codes or barcodes
- Unusual frequency spikes
- Patterns that appear at specific times

### Audio Manipulation

Sometimes hidden messages require audio transformation to reveal.

**Using Audacity:**
- **Reverse** the track (Effect → Reverse)
- **Slow down** playback (Track → Track Speed/Tempo)
- **Change pitch** (Effect → Change Pitch)
- **Invert** the waveform (Effect → Invert)

**Using Sox (command-line):**

```bash
# Reverse audio
sox input.wav output.wav reverse

# Slow down (0.5 = half speed)
sox input.wav output.wav speed 0.5

# Change pitch
sox input.wav output.wav pitch -12

# Convert to different format
sox input.wav output.mp3
```

### DTMF and Morse Code Detection

Hidden messages may be encoded as tones.

**Using Multimon-ng:**

```bash
# Decode DTMF tones
multimon-ng -f 44100 -a DTMF -d input.wav

# Decode Morse code
multimon-ng -f 44100 -a MORSE -d input.wav

# Decode multiple protocols
multimon-ng -f 44100 -a DTMF,MORSE,POCSAG -d input.wav
```

**Using SoX for tone analysis:**

```bash
# Generate spectrogram image
sox input.wav -n spectrogram -o spectrogram.png
```

## Step 4: Video Analysis

### Container Analysis

Video files often contain multiple streams (video, audio, subtitles, metadata).

**Using FFmpeg:**

```bash
# List all streams in the file
ffmpeg -i <filename>

# Show detailed stream information
ffprobe -v error -show_streams <filename>

# Extract stream information as JSON
ffprobe -v quiet -print_format json -show_streams <filename>
```

### Stream Extraction

```bash
# Extract video stream only
ffmpeg -i input.mp4 -c:v copy -an output.mkv

# Extract audio stream only
ffmpeg -i input.mp4 -c:a copy -vn output.aac

# Extract specific stream by index
ffmpeg -i input.mp4 -map 0:1 output_audio.aac

# Extract all streams separately
ffmpeg -i input.mp4 -map 0:v video.mkv -map 0:a audio.aac
```

### Video Frame Analysis

Hidden data may be in individual frames or between frames.

```bash
# Extract all frames as images
ffmpeg -i input.mp4 frame_%04d.png

# Extract specific frame
ffmpeg -i input.mp4 -vf "select=eq(n\,100)" frame_100.png

# Extract frames at specific intervals
ffmpeg -i input.mp4 -vf "select='not(mod(n\,100))'" frame_%04d.png
```

### Check for Hidden Streams

```bash
# Look for subtitle streams
ffprobe -v error -select_streams s -show_streams <filename>

# Look for attachment streams (fonts, images)
ffprobe -v error -select_streams d -show_streams <filename>
```

## Step 5: Steganography Detection

### LSB (Least Significant Bit) Analysis

LSB steganography hides data in the least significant bits of audio/video samples.

**For audio files:**

```bash
# Check for LSB anomalies
# Look for unusual patterns in low bits
```

**For video files:**

```bash
# Extract and analyze individual color channels
ffmpeg -i input.mp4 -vf "split[a][b];[a]channelsplit=channels=r:red.png;[b]channelsplit=channels=g:green.png" -q:v 2
```

### Common Steganography Tools

```bash
# Steghide (for images, sometimes works with audio)
steghide extract -sf <filename>

# Zsteg (for PNG images)
zsteg <filename>

# OpenStego (GUI tool)
```

## Step 6: Advanced Analysis

### Python with ffmpy

For programmatic analysis:

```python
from ffmpy import FFmpeg

# Extract audio from video
ff = FFmpeg(
    inputs={'input.mp4': None},
    outputs={'output.aac': '-vn -acodec copy'}
)
ff.run()

# Get stream info
import subprocess
result = subprocess.run(
    ['ffprobe', '-v', 'quiet', '-print_format', 'json', '-show_streams', 'input.mp4'],
    capture_output=True, text=True
)
import json
streams = json.loads(result.stdout)
```

### Automated Analysis Script

Create a script to run common checks:

```bash
#!/bin/bash
# forensic_analysis.sh

FILE="$1"

echo "=== Metadata ==="
exiftool "$FILE"

echo "=== File Structure ==="
file "$FILE"
binwalk "$FILE"

echo "=== Stream Info ==="
ffprobe -v error -show_streams "$FILE"

echo "=== Strings ==="
strings "$FILE" | grep -i "flag\|secret\|hidden\|password"
```

## Common Patterns and What to Look For

### Audio Files
- **Spectrogram text**: Hidden messages visible in frequency visualization
- **Reversed audio**: Messages played backwards
- **Slow/fast audio**: Messages at unusual speeds
- **DTMF tones**: Phone keypad tones encoding data
- **Morse code**: Audio beeps encoding text
- **Metadata**: Hidden text in ID3 tags or comments
- **Appended data**: Files attached after audio ends

### Video Files
- **Multiple streams**: Hidden audio or subtitle tracks
- **Frame anomalies**: Individual frames with hidden data
- **Metadata**: Embedded text or files
- **Container tricks**: Data in container headers
- **Color channel manipulation**: Hidden data in RGB channels
- **Subtitle streams**: Text hidden in subtitle tracks

## Troubleshooting

### File won't open
- Try `file <filename>` to check actual file type
- Check for magic bytes: `xxd <filename> | head -1`
- Try different players or tools

### No obvious hidden data
- Check all metadata fields thoroughly
- Try reversing/slowing audio
- Look at spectrograms with different settings
- Check for appended data at end of file
- Use `binwalk` to find embedded files

### Large file, slow analysis
- Extract specific streams first
- Sample frames rather than extracting all
- Use `ffprobe` for quick inspection before full analysis

## References

- [Trail of Bits CTF Forensics](https://trailofbits.github.io/ctf/forensics/)
- [MediaInfo](https://mediaarea.net/en/MediaInfo)
- [Audacity](http://www.audacityteam.org/)
- [Sonic Visualiser](http://www.sonicvisualiser.org/)
- [FFmpeg](http://ffmpeg.org/)
- [SoX](http://sox.sourceforge.net/)
- [Multimon-ng](http://tools.kali.org/wireless-attacks/multimon-ng)
