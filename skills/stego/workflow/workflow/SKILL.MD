---
name: stego-workflow
description: Steganography analysis workflow for CTF challenges and security investigations. Use this skill whenever the user mentions steganography, hidden data, stego files, image analysis, audio forensics, file carving, or needs to find hidden payloads in files. Trigger for any file analysis task where hidden content might be embedded, including images, audio, documents, or suspicious binaries. Make sure to use this skill when users ask about extracting hidden messages, analyzing suspicious files, or solving steganography CTF challenges.
---

# Steganography Analysis Workflow

A systematic approach to finding hidden data in files. Most steganography problems are solved faster by methodical triage than by trying random tools.

## Core Investigation Flow

### Step 1: Quick Triage

Answer two questions efficiently:
1. What is the real container/format?
2. Is the payload in metadata, appended bytes, embedded files, or content-level stego?

#### Identify the container

```bash
file target
ls -lah target
```

**Key principle**: If `file` and the extension disagree, trust `file`. Treat common formats as containers when appropriate (e.g., OOXML documents are ZIP files).

#### Look for metadata and obvious strings

```bash
exiftool target
strings -n 6 target | head
strings -n 6 target | tail
```

Try multiple encodings:

```bash
strings -e l -n 6 target | head  # little-endian
strings -e b -n 6 target | head  # big-endian
```

#### Check for appended data / embedded files

```bash
binwalk target
binwalk -e target
```

If extraction fails but signatures are reported, manually carve offsets with `dd` and re-run `file` on the carved region.

### Step 2: Format-Specific Analysis

#### If image

- Inspect anomalies: `magick identify -verbose file`
- If PNG/BMP, enumerate bit-planes/LSB: `zsteg -a file.png`
- Validate PNG structure: `pngcheck -v file.png`
- Use visual filters (Stegsolve / StegoVeritas) when content may be revealed by channel/plane transforms

#### If audio

- Spectrogram first (Sonic Visualiser)
- Decode/inspect streams: `ffmpeg -v info -i file -f null -`
- If the audio resembles structured tones, test DTMF decoding

### Step 3: Container-Level Analysis

#### Appended payloads

Many formats ignore trailing bytes. A ZIP/PDF/script can be appended to an image/audio container.

Fast checks:

```bash
binwalk file
tail -c 200 file | xxd
```

If you know an offset, carve with `dd`:

```bash
dd if=file of=carved.bin bs=1 skip=<offset>
file carved.bin
```

#### Magic bytes

When `file` is confused, look for magic bytes with `xxd` and compare to known signatures:

```bash
xxd -g 1 -l 32 file
```

#### Zip-in-disguise

Try `7z` and `unzip` even if the extension doesn't say zip:

```bash
7z l file
unzip -l file
```

## Essential Tools

### Bread-and-butter tools

These catch the high-frequency container-level cases: metadata payloads, appended bytes, and embedded files disguised by extension.

| Tool | Purpose | Command |
|------|---------|---------|
| **binwalk** | Find embedded files | `binwalk file` / `binwalk -e file` |
| **foremost** | Carve embedded files | `foremost -i file` |
| **exiftool** | Read/modify metadata | `exiftool file` |
| **file** | Identify file type | `file file` |
| **strings** | Extract readable text | `strings -n 6 file` |
| **cmp** | Compare files | `cmp original.jpg stego.jpg -b -l` |

### Image-specific tools

| Tool | Purpose |
|------|---------|
| **zsteg** | LSB/bit-plane analysis for PNG/BMP |
| **pngcheck** | Validate PNG structure |
| **Stegsolve** | Visual channel/plane transforms |
| **StegoVeritas** | Visual analysis |
| **ImageMagick** | Inspect anomalies |

### Audio-specific tools

| Tool | Purpose |
|------|---------|
| **Sonic Visualiser** | Spectrogram analysis |
| **ffmpeg** | Stream inspection |

## Near-Stego Patterns

### QR codes from binary

If a blob length is a perfect square, it may be raw pixels for an image/QR.

```python
import math
math.isqrt(2500)  # 50
```

Binary-to-image helper: https://www.dcode.fr/binary-image

### Braille

- https://www.branah.com/braille-translator

## Reference Resources

- [Stego Lists](https://0xrick.github.io/lists/stego/)
- [Stego Toolkit](https://github.com/DominicBreuker/stego-toolkit)

## Investigation Checklist

Use this checklist to ensure thorough analysis:

- [ ] Run `file` and compare to extension
- [ ] Check file size with `ls -lah`
- [ ] Extract metadata with `exiftool`
- [ ] Search for strings with `strings -n 6`
- [ ] Run `binwalk` for embedded files
- [ ] Check last 200 bytes with `tail -c 200 | xxd`
- [ ] Try `7z l` and `unzip -l` regardless of extension
- [ ] Format-specific analysis (image/audio/document)
- [ ] Compare to original if available with `cmp`
- [ ] Check for perfect square blob lengths (QR code)
- [ ] Look for braille patterns in text output

## Common Patterns to Watch For

1. **Extension mismatch**: File says "PNG" but `file` says "ZIP"
2. **Trailing data**: Valid file header with extra bytes appended
3. **Metadata payloads**: Hidden data in EXIF, XMP, or custom tags
4. **LSB steganography**: Data hidden in least significant bits of images
5. **Spectrogram images**: Hidden images visible in audio spectrograms
6. **Polyglot files**: Files that are valid in multiple formats simultaneously
7. **Carved archives**: ZIP/RAR/7z embedded within other containers
