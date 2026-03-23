---
name: png-forensics
description: How to analyze, validate, and repair PNG files for CTF challenges and digital forensics. Use this skill whenever the user mentions PNG files, image forensics, hidden data in images, corrupted PNGs, CTF image challenges, or needs to extract/embed data from PNG files. Don't wait for explicit requests about "forensics" - if they have a PNG file they're investigating, this skill applies.
---

# PNG Forensics

A skill for analyzing, validating, and recovering data from PNG files in CTF challenges and digital forensics investigations.

## When to Use This Skill

Use this skill when:
- You have a PNG file to investigate in a CTF challenge
- You suspect hidden data in an image file
- A PNG file appears corrupted or won't open
- You need to validate PNG file integrity
- You're analyzing network captures containing PNG data
- You need to extract or embed steganographic data in PNGs

## PNG File Structure Overview

PNG files use lossless compression and have a well-defined structure:

```
[8-byte signature] [IHDR chunk] [data chunks] [IEND chunk]
```

Key chunks to examine:
- **IHDR**: Image header (dimensions, bit depth, color type)
- **IDAT**: Compressed image data
- **tEXt/zTXt/iTXt**: Text metadata (common hiding spot)
- **iCCP**: Color profile
- **gAMA**: Gamma information
- **tIME**: Last modification time

## Analysis Workflow

### Step 1: Validate File Integrity

First, check if the PNG is valid:

```bash
# Check file signature
file image.png

# Validate PNG structure
pngcheck -v image.png

# Check for corruption
pngcheck -s image.png
```

**What to look for:**
- `file` should report "PNG image data"
- `pngcheck` should show no errors
- Checksum mismatches indicate corruption or tampering

### Step 2: Examine Metadata

Extract all metadata from the PNG:

```bash
# Using exiftool (comprehensive)
exiftool image.png

# Using ztxt (PNG-specific)
ztxt -l image.png

# Using pngcheck for chunk listing
pngcheck -v image.png
```

**Common hiding spots:**
- Text chunks (tEXt, zTXt, iTXt)
- Comment chunks (iCCP, gAMA)
- Custom chunks (unknown chunk types)
- Extra bytes after IEND chunk

### Step 3: Analyze Image Data

Look for anomalies in the image itself:

```bash
# Check for hidden data in LSB (least significant bit)
lsb_steg image.png

# Extract raw data streams
pngcrush -verbose image.png output.png

# View hex dump of suspicious areas
xxd image.png | less
```

### Step 4: Network Analysis (if applicable)

If the PNG came from a network capture:

```bash
# Extract PNG from PCAP
wireshark -r capture.pcap
# Or use tshark:
tshark -r capture.pcap -Y "png" -T fields -e frame.number -e data
```

## Common CTF Techniques

### Technique 1: Hidden Text in Chunks

Text can be hidden in PNG metadata chunks:

```bash
# Extract all text chunks
ztxt -l image.png

# Or use strings on the file
strings image.png | grep -i flag
```

### Technique 2: Data After IEND

Data can be appended after the IEND chunk (which should be the last chunk):

```bash
# Check for data after IEND
pngcheck -v image.png

# Extract trailing data
tail -c +$(($(stat -c%s image.png) - $(grep -b 'IEND' image.png | cut -d: -f1) + 4)) image.png
```

### Technique 3: Multiple Images

Multiple images can be concatenated in one PNG:

```bash
# Split concatenated PNGs
pngsplit image.png output_%04d.png

# Or manually split by finding IEND markers
```

### Technique 4: Color Channel Analysis

Hidden data in specific color channels:

```bash
# Extract individual channels
convert image.png -channel R -separate r.png
convert image.png -channel G -separate g.png
convert image.png -channel B -separate b.png
convert image.png -channel A -separate a.png
```

## Repairing Corrupted PNGs

### Using pngcheck

```bash
# Attempt automatic repair
pngcheck -r image.png

# Validate after repair
pngcheck -v image.png
```

### Using Online Services

For severely corrupted files, use [PixRecovery](https://online.officerecovery.com/pixrecovery/):

1. Upload the corrupted PNG
2. Wait for processing
3. Download the repaired file
4. Validate with pngcheck

### Manual Repair

For specific corruption types:

```bash
# Fix CRC errors (use with caution)
pngcrush -fix image.png fixed.png

# Remove problematic chunks
pngcrush -remove all image.png cleaned.png
```

## Tools Reference

| Tool | Purpose | Command |
|------|---------|--------|
| `pngcheck` | Validate PNG structure | `pngcheck -v file.png` |
| `exiftool` | Extract metadata | `exiftool file.png` |
| `ztxt` | List PNG text chunks | `ztxt -l file.png` |
| `pngcrush` | Optimize/repair PNG | `pngcrush input.png output.png` |
| `file` | Identify file type | `file file.png` |
| `xxd` | Hex dump | `xxd file.png` |
| `strings` | Extract readable text | `strings file.png` |
| `wireshark` | Network analysis | `wireshark capture.pcap` |

## Example Workflow

**Scenario:** You receive a PNG file in a CTF challenge

```bash
# 1. Initial inspection
file suspicious.png
# Output: PNG image data, 800 x 600, 8-bit/color RGBA, non-interlaced

# 2. Validate integrity
pngcheck -v suspicious.png
# Check for errors or warnings

# 3. Extract metadata
exiftool suspicious.png
# Look for unusual comments or custom fields

# 4. Search for hidden text
strings suspicious.png | grep -i flag
# Or: ztxt -l suspicious.png

# 5. Check for trailing data
# If pngcheck shows data after IEND, extract it

# 6. If corrupted, attempt repair
pngcheck -r suspicious.png
```

## Tips and Best Practices

1. **Always validate first** - Use pngcheck before attempting any analysis
2. **Check all chunks** - Don't just look at image data; examine metadata
3. **Look for anomalies** - Unusual chunk sizes, unexpected data, or corruption
4. **Try multiple tools** - Different tools may reveal different information
5. **Preserve originals** - Always work on copies of the original file
6. **Document findings** - Keep notes on what you've tried and what you found

## Common Pitfalls

- **Assuming the file is what it claims to be** - Always verify with `file`
- **Missing hidden chunks** - Some tools don't show all chunk types
- **Overlooking trailing data** - Data after IEND is a common hiding spot
- **Ignoring corruption** - Sometimes corruption IS the challenge
- **Not checking color channels** - Hidden data may be in specific channels

## Next Steps

After initial analysis:
- If you find hidden data, extract and decode it
- If the file is corrupted, attempt repair
- If nothing obvious, try steganography tools
- Consider the context of the challenge for hints

Remember: PNG files are versatile hiding spots. Be thorough and methodical in your investigation.
