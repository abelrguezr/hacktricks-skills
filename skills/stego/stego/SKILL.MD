---
name: stego-analysis
description: Steganography analysis and hidden data extraction. Use this skill whenever the user needs to find or extract hidden data from files (images, audio, video, documents, archives) or text-based steganography. Trigger on requests involving: hidden messages, steganography, LSB extraction, metadata analysis, file forensics, embedded files, spectrogram analysis, or any task where data might be concealed within another file. Make sure to use this skill for CTF challenges, security audits, or any investigation where hidden content is suspected.
---

# Steganography Analysis

A structured approach to finding and extracting hidden data from files and text. This skill treats steganography as a forensics problem: identify the real container, enumerate high-signal locations, then apply content-level extraction techniques.

## Workflow & Triage

Follow this prioritized workflow for any steganography investigation:

### 1. Container Identification

First, determine what you're actually working with:

```bash
# Check actual file type vs extension
file <filename>
file -b <filename>

# Check magic bytes
xxd <filename> | head -20

# Verify extension matches content
python3 scripts/check_file_type.py <filename>
```

**Why this matters**: Many stego challenges use mismatched extensions (e.g., a PNG disguised as a JPG). The actual file format determines which tools and techniques apply.

### 2. Metadata & String Inspection

Extract all metadata and readable strings before diving into content analysis:

```bash
# Extract metadata from all supported formats
python3 scripts/extract_metadata.py <filename>

# Extract printable strings
strings <filename> > strings.txt
strings -n 10 <filename> | grep -iE "(flag|secret|hidden|ctf|password|key)"

# Look for appended data (common in stego)
tail -c 10000 <filename> | strings
```

**Why this matters**: Hidden data often appears in metadata fields, appended after the file's actual content, or as readable strings. This is the fastest way to find low-hanging fruit.

### 3. Format-Specific Analysis

Based on the file type, apply targeted techniques:

---

## Image Steganography

Images are the most common stego container. Prioritize these checks:

### Quick Wins

```bash
# Check for appended data
binwalk -e <image>
foremost -i <image>

# Extract all chunks (PNG)
zcat <(pngcheck -v <image>) 2>&1 | grep -A5 "chunk"

# Check for multiple images
file <image>
strings <image> | grep -i "PNG\|JFIF\|GIF"
```

### LSB & Bit-Plane Analysis

For PNG/BMP files, check for Least Significant Bit manipulation:

```bash
# Extract LSB from image
python3 scripts/extract_lsb.py <image> --bits 1-4 --output lsb_output/

# Visualize bit planes
python3 scripts/visualize_bitplanes.py <image>

# Check for stego signatures
steghide extract -sf <image>  # if password-protected
zsteg <image>  # comprehensive PNG stego scanner
```

### JPEG-Specific

```bash
# Check for hidden data in JPEG
exiftool <image>
jpeginfo <image>

# Extract from JPEG comments
exiftool -Comment <image>
```

### GIF Multi-Frame

```bash
# Extract all frames from GIF
convert <gif> -coalesce frames/frame_%03d.png

# Check for hidden data in frames
file frames/*.png
```

---

## Audio Steganography

Audio files hide data in samples, spectrograms, or as DTMF tones.

### Spectrogram Analysis

```bash
# Generate spectrogram (hidden messages often visible)
sox <audio> -n spectrogram spectrogram.png

# Alternative with ffmpeg
ffmpeg -i <audio> -filter_complex "spectrumpic" spectrogram.png
```

**Look for**: Text, QR codes, or images visible in the frequency spectrum.

### Sample-Level Analysis

```bash
# Extract LSB from audio samples
python3 scripts/extract_audio_lsb.py <audio> --bits 1-2

# Check for hidden data in silence
sox <audio> silence -v -d 0.5 -t 0.1 silence_analysis.txt
```

### DTMF Tones

```bash
# Detect telephone keypad tones
sox <audio> -n stat -V 3 2>&1 | grep -i "tone\|frequency"

# Visualize to spot DTMF patterns
sox <audio> -n spectrogram dtmf_spectrogram.png
```

---

## Text Steganography

Text that renders normally but contains hidden data through encoding tricks.

### Unicode & Zero-Width Characters

```bash
# Detect zero-width characters
python3 scripts/detect_zwc.py <textfile>

# Remove zero-width characters
python3 scripts/remove_zwc.py <textfile> > cleaned.txt

# Check for homoglyphs (lookalike characters)
python3 scripts/check_homoglyphs.py <textfile>
```

### Whitespace Encoding

```bash
# Detect whitespace-based encoding
python3 scripts/decode_whitespace.py <textfile>

# Check for trailing spaces
cat -A <textfile> | grep -E "\s\$"
```

### Base64 & Encoded Strings

```bash
# Find base64 strings
strings <textfile> | grep -E "^[A-Za-z0-9+/]{20,}={0,2}$" | base64 -d 2>/dev/null

# Check for hex encoding
strings <textfile> | grep -E "^[0-9a-fA-F]{20,}$" | xxd -r -p
```

---

## Document Steganography

PDFs and Office files are containers first. Focus on embedded content.

### PDF Analysis

```bash
# Extract all embedded files
pdftk <pdf> cat output extracted/

# Check for hidden layers/annotations
qpdf --show-npages <pdf>
qpdf --json <pdf> | python3 -m json.tool

# Extract streams and objects
python3 scripts/extract_pdf_streams.py <pdf>

# Look for hidden text
pdftotext <pdf> -layout text.txt
strings <pdf> | grep -iE "(flag|secret|hidden)"
```

### Office Files (DOCX, XLSX, PPTX)

```bash
# Office files are ZIP archives
unzip -l <file>
unzip <file> -d extracted/

# Check relationships and embedded objects
cat extracted/_rels/*.rels
cat extracted/[Content_Types].xml

# Extract embedded files
find extracted/ -name "*.png" -o -name "*.jpg" -o -name "*.pdf"
```

### ZIP Archives

```bash
# Check for hidden entries
zipinfo -l <archive>

# Extract and check all files
unzip -o <archive> -d extracted/
file extracted/*

# Look for password-protected entries
zip2john <archive>  # if password needed
```

---

## Malware & Delivery Steganography

Payloads hidden in valid-looking files with marker-delimited text.

### Common Patterns

```bash
# Check for text payloads in images
strings <image> | grep -A5 -B5 "BEGIN\|END\|PAYLOAD\|DATA"

# Look for base64 blocks
strings <image> | grep -E "^[A-Za-z0-9+/]{50,}={0,2}$"

# Check for shellcode or encoded commands
xxd <image> | grep -E "(\x90{10,}|\x00{10,})"
```

### Network-Based Steganography

```bash
# Analyze PCAP files
tshark -r <pcap> -Y "http" -T fields -e http.file_data

# Extract HTTP payloads
tshark -r <pcap> -Y "http.request" -T fields -e http.request.full_uri
```

---

## Common Tools Reference

### Installation

```bash
# Core tools
sudo apt install binwalk foremost zsteg steghide exiftool
sudo apt install sox ffmpeg qpdf pdftk

# Python tools
pip install pillow pydub pycryptodome
```

### Quick Reference

| Tool | Purpose |
|------|---------|
| `binwalk` | Find embedded files in containers |
| `foremost` | Carve files from raw data |
| `zsteg` | PNG steganography scanner |
| `steghide` | Extract hidden data (password-protected) |
| `exiftool` | Read/modify metadata |
| `sox` | Audio analysis and spectrogram |
| `strings` | Extract readable text from binaries |
| `file` | Identify file type by magic bytes |

---

## Debugging & Verification

### When Nothing Works

1. **Re-check the file type**: `file <filename>` - is it what you think?
2. **Look at raw bytes**: `xxd <filename> | head -50` - any obvious patterns?
3. **Check file size**: `ls -la` - is it suspiciously large for its type?
4. **Try multiple tools**: Different tools detect different patterns
5. **Check for compression**: `file <filename>` might show "compressed data"

### Verify Extraction

```bash
# Check if extracted data is valid
file extracted_file
strings extracted_file | head -20

# For images
file extracted_image && identify extracted_image

# For text
file extracted_text && head -20 extracted_text
```

---

## Tips for Success

1. **Start simple**: Metadata and strings often reveal the answer before complex analysis
2. **Document everything**: Keep notes on what you've tried and what you found
3. **Check file sizes**: Unusually large files often contain appended data
4. **Look for patterns**: Repeated bytes, unusual sequences, or obvious markers
5. **Combine techniques**: Sometimes you need to extract, then analyze the extracted content
6. **Don't ignore the obvious**: Sometimes the hidden data is in plain sight (comments, metadata)

---

## Next Steps

After initial analysis:

1. If you found embedded files, analyze them recursively
2. If you extracted encoded data, decode it and check for more hidden content
3. If spectrogram shows text, transcribe it and check for encoding
4. If you found a password-protected container, try common CTF passwords or brute force

Remember: steganography is often layered. What you extract might contain more hidden data.
