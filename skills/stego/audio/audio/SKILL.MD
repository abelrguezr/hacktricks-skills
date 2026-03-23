---
name: audio-steganography
description: Extract hidden data from audio files using steganography techniques. Use this skill whenever the user mentions audio forensics, hidden messages in audio, spectrogram analysis, WAV file investigation, DTMF tones, modem sounds, or any audio file that might contain concealed data. This includes CTF challenges, security investigations, or any scenario where audio files need to be analyzed for hidden payloads.
---

# Audio Steganography Analysis

A skill for extracting hidden data from audio files using various steganographic techniques.

## Quick Triage

Start here for any audio steganography investigation:

```bash
# Confirm codec/container details
file audio_file

# Inspect audio metadata and format
ffmpeg -v info -i audio_file -f null -

# Generate spectrogram for visual inspection
sox audio_file -n spectrogram -o spectrogram.png
```

**Key indicators to look for:**
- Noise-like content that doesn't match the expected audio type
- Tonal structure or regular patterns in spectrograms
- Unusual codec choices or metadata anomalies
- Files that are larger than expected for their duration

## Spectrogram Steganography

### When to use
- Audio contains noise or unusual tonal patterns
- Spectrogram shows visible text or patterns
- File is flagged as suspicious but sounds normal

### Tools and workflow

**Sonic Visualiser** (primary tool)
- Download: https://www.sonicvisualiser.org/
- Open audio file and enable spectrogram view
- Look for text, QR codes, or patterns in the frequency-time plot
- Adjust frequency range and window size for clarity

**Audacity** (alternative)
- Download: https://www.audacityteam.org/
- View → Spectrogram
- Use filters to enhance visibility
- Export spectrogram image for analysis

**Command-line spectrogram**
```bash
# Generate spectrogram with sox
sox input.wav -n spectrogram -o spectrogram.png

# With specific parameters for better visibility
sox input.wav -n spectrogram -o spectrogram.png \
  --size 2048 --overlap 0.9 --window 0.9
```

### Analysis tips
- Spectrogram stego often hides data in frequency bands that are inaudible or perceived as noise
- Look for sharp edges, text-like patterns, or QR codes in the spectrogram
- Try different window sizes and frequency ranges
- Some implementations use specific frequency bands (e.g., 20-20000 Hz visible range)

## FSK / Modem Decoding

### When to use
- Spectrogram shows alternating single tones
- Audio sounds like modem handshakes or beeps
- Regular frequency shifts visible in spectrogram

### Workflow with minimodem

```bash
# First, visualize to estimate baud rate and frequencies
sox noise.wav -n spectrogram -o spec.png

# Try common baud rates until printable text appears
minimodem -f noise.wav 45
minimodem -f noise.wav 300
minimodem -f noise.wav 1200
minimodem -f noise.wav 2400
minimodem -f noise.wav 4800
minimodem -f noise.wav 9600
```

### Common minimodem options
```bash
# Invert signal if output is garbled
minimodem -f noise.wav 1200 --rx-invert

# Specify sample rate if needed
minimodem -f noise.wav 1200 --samplerate 44100

# Output to file
minimodem -f noise.wav 1200 > decoded.txt

# With verbose output for debugging
minimodem -f noise.wav 1200 --rx-verbose
```

### Baud rate selection guide
- 45 baud: Very slow, old modems
- 300 baud: Common for simple FSK
- 1200 baud: Standard for many CTF challenges
- 2400-9600 baud: Faster modems, more complex audio

## WAV LSB Extraction

### When to use
- Uncompressed PCM WAV files
- Audio sounds normal but file size seems large
- Other techniques haven't revealed anything

### Understanding LSB steganography
- Each audio sample is an integer value
- Modifying low bits changes waveform minimally (inaudible)
- Can hide 1+ bits per sample
- May be interleaved across channels
- May use stride/permutation patterns

### WavSteg extraction

```bash
# Extract 1 bit per sample
python3 WavSteg.py -r -b 1 -s sound.wav -o out.bin

# Extract 2 bits per sample
python3 WavSteg.py -r -b 2 -s sound.wav -o out.bin

# Extract 3 bits per sample
python3 WavSteg.py -r -b 3 -s sound.wav -o out.bin

# Extract 4 bits per sample
python3 WavSteg.py -r -b 4 -s sound.wav -o out.bin
```

### DeepSound tool
- Download: http://jpinsoft.net/deepsound/download.aspx
- GUI-based LSB extraction
- Supports various bit depths and patterns
- Can detect hidden data automatically

### Other audio steganography families
- **Phase coding**: Modifies phase relationships between samples
- **Echo hiding**: Embeds data in echo patterns
- **Spread-spectrum**: Spreads data across frequency spectrum
- **Codec side-channels**: Format-dependent embedding (MP3, AAC, etc.)

## DTMF / Dial Tone Decoding

### When to use
- Audio resembles telephone keypad tones
- Regular dual-frequency beeps
- Sounds like someone dialing a phone

### Online decoders
- https://unframework.github.io/dtmf-detect/
- http://dialabc.com/sound/detect/index.html

### DTMF frequency reference
```
Row 1: 697 Hz, 770 Hz, 852 Hz, 941 Hz
Row 2: 1209 Hz, 1336 Hz, 1477 Hz, 1633 Hz
Row 3: 1770 Hz, 1975 Hz, 2184 Hz, 2400 Hz
```

### DTMF character mapping
```
1: 697+1209    2: 697+1336    3: 697+1477    A: 697+1633
4: 770+1209    5: 770+1336    6: 770+1477    B: 770+1633
7: 852+1209    8: 852+1336    9: 852+1477    C: 852+1633
*: 941+1209    0: 941+1336    #: 941+1477    D: 941+1633
```

## Investigation Workflow

### Step 1: Initial triage
```bash
file audio_file
ffmpeg -v info -i audio_file -f null -
```

### Step 2: Visual inspection
```bash
sox audio_file -n spectrogram -o spectrogram.png
```

### Step 3: Technique selection
- **Visible patterns in spectrogram** → Spectrogram stego
- **Alternating tones** → FSK/modem decoding
- **WAV file, normal audio** → Try LSB extraction
- **Keypad-like tones** → DTMF decoding

### Step 4: Extract and verify
- Run appropriate extraction tool
- Check output for readable content
- Try multiple bit depths/parameters if needed
- Verify extracted data makes sense

## Common Tools Checklist

- [ ] `ffmpeg` - Audio inspection and conversion
- [ ] `sox` - Spectrogram generation and audio processing
- [ ] `minimodem` - FSK/modem decoding
- [ ] `WavSteg.py` - LSB extraction
- [ ] Sonic Visualiser - Spectrogram analysis
- [ ] Audacity - Audio editing and spectrogram view
- [ ] DeepSound - GUI LSB tool
- [ ] Online DTMF decoders - Dial tone analysis

## Tips and Tricks

1. **Always start with triage** - Understanding the file format guides your approach
2. **Generate spectrograms early** - Visual patterns reveal the technique used
3. **Try multiple parameters** - LSB bit depth, baud rates, and window sizes vary
4. **Check file size** - Unusually large files may indicate hidden data
5. **Listen carefully** - Some stego is audible as noise or distortion
6. **Save intermediate outputs** - Spectrograms and decoded data for analysis
7. **Combine techniques** - Some files use multiple steganography methods

## Example Scenarios

### Scenario 1: CTF audio challenge
```
1. file challenge.wav → "RIFF WAV PCM 16-bit"
2. sox challenge.wav -n spectrogram -o spec.png → Shows text pattern
3. Use Sonic Visualiser to read hidden message from spectrogram
```

### Scenario 2: Suspicious audio file
```
1. ffmpeg -v info -i suspicious.mp3 -f null - → Shows unusual metadata
2. sox suspicious.wav -n spectrogram -o spec.png → Shows alternating tones
3. minimodem -f suspicious.wav 1200 → Decodes hidden text
```

### Scenario 3: Normal-sounding WAV with hidden data
```
1. file normal.wav → "RIFF WAV PCM 16-bit"
2. python3 WavSteg.py -r -b 1 -s normal.wav -o out.bin
3. file out.bin → "ASCII text" or "PNG image data"
```

## References

- Sonic Visualiser: https://www.sonicvisualiser.org/
- Audacity: https://www.audacityteam.org/
- WavSteg: https://github.com/ragibson/Steganography#WavSteg
- DeepSound: http://jpinsoft.net/deepsound/download.aspx
- DTMF Decoder: https://unframework.github.io/dtmf-detect/
- Flagvent 2025 examples: https://0xdf.gitlab.io/flagvent2025/medium
