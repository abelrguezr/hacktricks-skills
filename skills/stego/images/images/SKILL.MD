---
name: image-steganography
description: Analyze images for hidden data using steganography techniques. Use this skill whenever the user mentions image forensics, CTF challenges with images, hidden messages in pictures, PNG/JPEG/GIF analysis, LSB extraction, metadata extraction, or any task involving finding concealed content in image files. Trigger for file extensions like .png, .jpg, .jpeg, .gif, .bmp, .apng, or when users ask about steganography, hidden payloads, or image-based data hiding.
---

# Image Steganography Analysis

A systematic approach to finding hidden data in image files, optimized for CTF challenges and forensic analysis.

## Quick Triage Workflow

Start here for any image steganography task. Run these checks in order:

### 1. Validate and Inspect Structure

```bash
file <image-file>
magick identify -verbose <image-file>
```

For PNG specifically:
```bash
pngcheck -v <image-file>
```

### 2. Extract Metadata and Strings

```bash
exiftool -a -u -g1 <image-file>
strings -n 6 <image-file> | head -50
```

### 3. Check for Embedded Content

```bash
binwalk <image-file>
tail -c 1000 <image-file> | xxd
```

### 4. Branch by File Type

- **PNG/BMP**: Run LSB/bit-plane analysis (see below)
- **JPEG**: Check metadata + DCT-domain tools
- **GIF/APNG**: Extract and analyze frames

## LSB and Bit-Plane Analysis (PNG/BMP)

### Primary Tool: zsteg

```bash
zsteg -a <image-file>
```

This enumerates many extraction patterns automatically. Look for:
- Readable text in output
- Base64-encoded strings
- Hex patterns that decode to ASCII

### Manual Channel Isolation

If zsteg doesn't find anything, try isolating specific channels:

```bash
# Extract red channel LSB
magick <image-file> -channel R -negate -evaluate multiply 128 -channel RGB -negate red_lsb.png

# Extract alpha channel (if present)
magick <image-file> -channel A -separate alpha.png
```

### Common Patterns to Check

1. **Single channel LSB** - payload in R, G, B, or A only
2. **Alpha-only** - completely invisible in RGB view
3. **Compressed payload** - extract then decompress (gzip, zlib, base64)
4. **XOR between planes** - XOR two bit planes together

## PNG Chunk Analysis

PNG files are chunked. Hidden data often lives in:

- Extra bytes after `IEND` chunk
- Non-standard ancillary chunks
- Text chunks: `tEXt`, `iTXt`, `zTXt`
- ICC profile: `iCCP`
- EXIF data: `eXIf`

### Commands

```bash
# Verbose chunk inspection
pngcheck -vp <image-file>

# Check for trailing data
magick identify -verbose <image-file> | grep -i "additional data"

# Extract text chunks
exiftool -a -u -g1 <image-file> | grep -i "text\|comment\|description"
```

### Fixing Corrupted PNGs

If `pngcheck` reports CRC errors:

1. Note the offset from the error message
2. Use a hex editor to inspect the chunk
3. Sometimes removing the corrupted chunk fixes the file
4. Try: `pngfix <image-file>` (ImageMagick tool)

## JPEG Analysis

JPEG uses DCT compression, so LSB techniques don't apply directly.

### Quick Checks

```bash
exiftool <image-file>
strings -n 6 <image-file> | head
binwalk <image-file>
```

### High-Signal Locations

- **EXIF/XMP/IPTC metadata** - often contains hidden text
- **Comment segment (COM)** - check with `exiftool -Comment`
- **APP segments** - vendor data, sometimes payloads

### DCT-Domain Tools

If metadata is clean, try stego tools:

```bash
# OutGuess (requires password if encrypted)
outguess -e <image-file> <output-file>

# Stegseek (for steghide payloads, faster bruteforce)
stegseek <image-file> <wordlist-file>
```

## Animated Images (GIF/APNG)

### Extract Frames

```bash
# Using ffmpeg (works for GIF and APNG)
ffmpeg -i <animated-file> frame_%04d.png

# Using gifsicle (GIF only, faster)
gifsicle --explode <animated-file>
```

### Frame Differencing

Hidden data often appears only when comparing frames:

```bash
# Diff consecutive frames
magick frame_0001.png frame_0002.png -compose difference -composite diff.png

# Or use the script
python scripts/extract_frames.py <animated-file>
python scripts/diff_frames.py
```

### Pixel Count Encoding (APNG)

Some challenges encode each byte as the count of a specific color per frame:

```bash
# Use the bundled script
python scripts/extract_pixel_counts.py <frames-directory> <target-color>
```

Example target colors: `(255, 0, 255)` for magenta, `(0, 255, 0)` for green.

## Password-Protected Embedding

### StegHide

Supports JPEG, BMP, WAV, AU:

```bash
# Check if file has steghide payload
steghide info <image-file>

# Extract with known password
steghide extract -sf <image-file> --passphrase 'password'

# Brute force with wordlist
stegcracker <image-file> <wordlist-file>
```

### StegPy

Supports PNG, BMP, GIF, WebP, WAV:

```bash
stegpy -f <image-file> -w <wordlist-file>
```

## Common Pitfalls

1. **Don't skip triage** - 50%+ of challenges are metadata or trailing bytes
2. **Check all channels** - not just RGB, also alpha
3. **Decompress extracted data** - payloads are often gzip/zlib/base64 encoded
4. **Try multiple tools** - zsteg might miss what manual extraction finds
5. **Look for patterns** - repeated strings, flag formats, base64 blocks

## Tool Installation

```bash
# Core tools
sudo apt install zsteg pngcheck exiftool binwalk ffmpeg gifsicle

# StegHide (Debian/Ubuntu)
sudo apt install steghide

# StegCracker (Python)
pip install stegcracker

# StegPy (Python)
pip install stegpy

# ImageMagick (for magick commands)
sudo apt install imagemagick
```

## Quick Reference by Symptom

| Symptom | Likely Cause | Tool |
|---------|-------------|------|
| Trailing data after IEND | Extra bytes | `tail`, `xxd` |
| CRC errors in PNG | Corrupted chunk | `pngcheck`, hex editor |
| No LSB findings | Metadata or DCT | `exiftool`, `binwalk` |
| Multiple frames | Frame-based hiding | `ffmpeg`, `diff_frames.py` |
| Password prompt | Encrypted embedding | `steghide`, `stegcracker` |
| Clean metadata, clean LSB | DCT-domain | `outguess`, `stegseek` |

## Next Steps After Finding Data

1. **Decode if encoded** - base64, hex, rot13
2. **Decompress if compressed** - gzip, zlib, zip
3. **Check for flag format** - `flag{}`, `CTF{}`, `FLAG{}`
4. **Look for partial data** - might need to combine multiple sources
5. **Verify integrity** - checksums, file headers

## Resources

- PNG specification: https://www.w3.org/TR/PNG/
- File format tricks: https://github.com/corkami/docs
- zsteg: https://github.com/zed-0xff/zsteg
- StegCracker: https://github.com/Paradoxis/StegCracker
- StegPy: https://github.com/dhsdshdhk/stegpy
