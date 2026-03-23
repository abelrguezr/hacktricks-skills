---
name: forensic-file-analysis
description: Forensic analysis techniques for specific file types and software. Use this skill whenever the user needs to analyze files for forensic purposes, investigate suspicious files, extract hidden data, deobfuscate content, or examine file structures. Trigger on mentions of: file forensics, artifact analysis, deobfuscation, hidden data extraction, file format analysis, .pyc files, browser artifacts, Office documents, PDFs, images (PNG/SVG), archives (ZIP), video/audio files, Mach-O binaries, or any file type investigation.
---

# Forensic File Analysis

A comprehensive guide to forensic analysis techniques for specific file types and software.

## Quick Reference

| File Type | Key Techniques |
|-----------|----------------|
| .pyc | Bytecode decompilation, string extraction |
| Browser | History, cookies, cache, downloads |
| VBS/CScript | Deobfuscation, string extraction |
| Office | Hidden metadata, embedded objects |
| PDF | Hidden layers, embedded files |
| PNG | Metadata, hidden channels |
| ZIP | Password recovery, hidden entries |
| Video/Audio | Metadata, hidden streams |
| Mach-O | Entitlements, code signing |

---

## Python Compiled Files (.pyc)

### Decompile .pyc Files

```bash
# Using uncompyle6 (works with Python 2.7-3.10)
pip install uncompyle6
uncompyle6 -o output_dir file.pyc

# Using pydc (Python Decompiler)
pip install pydc
pydc file.pyc

# Using decompyle3 (Python 3.6-3.9)
pip install decompyle3
decmpyle3 file.pyc
```

### Extract Strings from .pyc

```bash
# Extract all strings
strings file.pyc | grep -i "password\|api\|key\|token"

# Use pycdc for structured extraction
pip install pycdc
pycdc file.pyc
```

### Analyze .pyc Metadata

```bash
# Check Python version and timestamp
xxd file.pyc | head -20

# The first 4 bytes are the magic number (Python version)
# Bytes 4-7 are the timestamp
```

---

## Browser Artifacts

### Chrome/Chromium Artifacts

```bash
# Location: ~/.config/google-chrome/Default/
# or ~/Library/Application Support/Google/Chrome/Default/ (macOS)

# Analyze history (SQLite)
sqlite3 ~/.config/google-chrome/Default/History \
  "SELECT * FROM urls ORDER BY last_visit_time DESC LIMIT 50;"

# Extract cookies (encrypted)
sqlite3 ~/.config/google-chrome/Default/Cookies \
  "SELECT * FROM cookies;"

# Download history
sqlite3 ~/.config/google-chrome/Default/History \
  "SELECT * FROM downloads;"

# Cache analysis
find ~/.config/google-chrome/Default/Cache -type f -exec file {} \;
```

### Firefox Artifacts

```bash
# Location: ~/.mozilla/firefox/*.default-release/

# History
sqlite3 ~/.mozilla/firefox/*.default-release/places.sqlite \
  "SELECT * FROM moz_historyvisits ORDER BY date DESC LIMIT 50;"

# Cookies
sqlite3 ~/.mozilla/firefox/*.default-release/cookies.sqlite \
  "SELECT * FROM moz_cookies;"

# Downloads
sqlite3 ~/.mozilla/firefox/*.default-release/places.sqlite \
  "SELECT * FROM moz_downloads;"
```

### Safari Artifacts (macOS)

```bash
# Location: ~/Library/Safari/

# History
sqlite3 ~/Library/Safari/History \
  "SELECT * FROM history_visits ORDER BY visited_at DESC LIMIT 50;"

# Cookies
sqlite3 ~/Library/Safari/Cookies/Cookies.db \
  "SELECT * FROM cookies;"
```

---

## VBS/CScript Deobfuscation

### Basic Deobfuscation

```bash
# Extract strings
strings script.vbs | grep -v "^\\s*$"

# Remove comments and empty lines
grep -v "^'" script.vbs | grep -v "^\\s*$" > cleaned.vbs

# Decode Base64 strings
# Look for: str = Base64Decode("...")
# Then decode: echo "BASE64_STRING" | base64 -d
```

### Advanced Deobfuscation

```bash
# Use VBDeobfuscator
pip install vbdeobfuscator
vbdeobfuscator script.vbs

# Use strings with context
strings -n 10 script.vbs | grep -E "(http|https|ftp|cmd|powershell)"

# Look for encoded commands
strings script.vbs | grep -E "^.{20,}$" | head -20
```

### Common Obfuscation Patterns

```
# Eval-based
Eval(StringReplace(...))

# Hex encoding
ChrW(&H41) = "A"

# Base64
Base64Decode("...")

# XOR encoding
For i = 1 To Len(str)
  str = Chr(Asc(Mid(str, i, 1)) Xor key)
Next
```

---

## Office File Analysis

### Document Structure

```bash
# Office files are ZIP archives
unzip -l document.docx
unzip -p document.docx word/document.xml | head -100

# Extract all content
unzip -o document.docx -d extracted/
```

### Hidden Metadata

```bash
# Using exiftool
exiftool document.docx

# Using officeparser
pip install officeparser
officeparser document.docx

# Check for hidden text
unzip -p document.docx word/document.xml | grep -i "w:vanish"
```

### Embedded Objects

```bash
# Find embedded files
unzip -l document.docx | grep -i "embed"

# Extract embedded objects
unzip -p document.docx word/embeddings/embed1.bin > embedded.bin
file embedded.bin
```

### Macros Analysis

```bash
# Extract VBA macros
unzip -p document.docm word/vbaProject.bin > vba.bin

# Use olemview or oletools
pip install oletools
vba_extract.py document.docm
vba_analyze.py extracted_vba/
```

---

## PDF File Analysis

### Basic Analysis

```bash
# Check PDF structure
pdfinfo document.pdf

# Extract text
pdftotext document.pdf - | head -100

# Extract images
pdfimages -list document.pdf
pdfimages -all document.pdf output_
```

### Hidden Content

```bash
# Look for hidden layers
qpdf --show-nesting document.pdf

# Extract all objects
qpdf --object-streams=disable document.pdf cleaned.pdf
strings cleaned.pdf | grep -i "password\|secret\|key"

# Check for embedded files
pdfdetach -list document.pdf
pdfdetach -saveall document.pdf
```

### JavaScript Extraction

```bash
# Extract embedded JavaScript
pdfid document.pdf

# Use pdf-parser
pip install pdf-parser
pdf-parser document.pdf

# Look for JS in objects
strings document.pdf | grep -A 20 "\/JS"
```

### Metadata Analysis

```bash
# Full metadata
exiftool document.pdf

# Check for modification history
pdfinfo -box document.pdf
```

---

## PNG Tricks

### Metadata Extraction

```bash
# Using exiftool
exiftool image.png

# Using ztxt (for text chunks)
ztxt image.png

# Using pngcheck
pngcheck -v image.png
```

### Hidden Data in Chunks

```bash
# List all chunks
pngcheck -v image.png | grep -E "(tEXt|iTXt|zTXt|tIME|pHYs)"

# Extract specific chunks
python3 -c "
import struct
with open('image.png', 'rb') as f:
    f.read(8)  # PNG signature
    while True:
        length = struct.unpack('>I', f.read(4))[0]
        chunk_type = f.read(4)
        data = f.read(length)
        if chunk_type in [b'tEXt', b'iTXt', b'zTXt']:
            print(f'{chunk_type}: {data}')
        f.read(4)  # CRC
        if chunk_type == b'IEND':
            break
"
```

### Steganography Detection

```bash
# Check for hidden data in LSB
zsteg image.png

# Using steghide (if password protected)
steghide extract -sf image.png

# Using stegsolve
java -jar stegsolve.jar
```

### PNG Structure Analysis

```bash
# View raw structure
xxd image.png | head -50

# Check for malformed chunks
pngcheck -v image.png
```

---

## ZIP Tricks

### Basic Analysis

```bash
# List contents
unzip -l archive.zip

# Check for password protection
zipinfo archive.zip

# Extract with password
unzip -P password archive.zip
```

### Hidden Entries

```bash
# Look for hidden files
unzip -l archive.zip | grep -i "\.\|hidden\|secret"

# Check for alternate data streams
zipinfo -v archive.zip

# Extract all including hidden
unzip -o archive.zip -d extracted/
```

### Password Recovery

```bash
# Using fcrackzip
fcrackzip -u -D -p /usr/share/wordlists/rockyou.txt archive.zip

# Using john
zip2john archive.zip > hash.txt
john --wordlist=/usr/share/wordlists/rockyou.txt hash.txt

# Using hashcat
zip2john archive.zip > hash.txt
hashcat -m 13200 hash.txt /usr/share/wordlists/rockyou.txt
```

### Malformed ZIP Detection

```bash
# Check ZIP structure
zipinfo -v archive.zip

# Look for split archives
file archive.zip*

# Check for nested archives
unzip -l archive.zip | grep -i "\.zip\|\.rar\|\.7z"
```

---

## Video and Audio File Analysis

### Metadata Extraction

```bash
# Using exiftool
exiftool video.mp4
exiftool audio.mp3

# Using ffprobe
ffprobe -v quiet -print_format json -show_format -show_streams video.mp4

# Using mediainfo
mediainfo video.mp4
```

### Hidden Streams

```bash
# List all streams
ffprobe video.mp4 | grep -i "stream"

# Extract hidden audio streams
ffmpeg -i video.mp4 -map 0:a:1 hidden_audio.mp3

# Extract hidden video streams
ffmpeg -i video.mp4 -map 0:v:1 hidden_video.mp4
```

### Steganography Detection

```bash
# Check for hidden data in audio
audacity audio.mp3  # Open and inspect waveform

# Using steghide
steghide extract -sf audio.mp3

# Check video for hidden frames
ffmpeg -i video.mp4 -vf "select=eq(pict_type,I)" -vframes 100 frame_%03d.png
```

### Carving Hidden Files

```bash
# Using foremost
foremost -i video.mp4 -t mp3,mp4,png,jpg

# Using photorec
photorec video.mp4
```

---

## Mach-O Entitlements and IPSW Indexing

### Entitlements Extraction

```bash
# Using plutil
plutil -extract entitlements raw binary.app/Contents/MachO/binary > entitlements.plist

# Using otool
otool -l binary.app/Contents/MachO/binary | grep -A 10 "com.apple"

# Using codesign
codesign -d --entitlements :- binary.app
```

### Code Signing Analysis

```bash
# Check signature
codesign -dv binary.app

# Extract signature
codesign -d --verbose=4 binary.app

# Verify signature
codesign -v binary.app
```

### IPSW Analysis

```bash
# Extract IPSW
bsdtar -xf firmware.ipsw

# Analyze manifest
plutil -p BuildManifest.plist

# Check for vulnerabilities
strings BuildManifest.plist | grep -i "vuln\|exploit\|bypass"
```

### Mobile Device Forensics

```bash
# Extract from backup
ibackupextract -b backup_path -o output/

# Analyze SQLite databases
sqlite3 output/*/Manifest.db "SELECT * FROM files;"
```

---

## General Forensic Techniques

### File Carving

```bash
# Using foremost
foremost -i disk_image -t png,jpg,docx,pdf,zip

# Using scalpel
scalpel disk_image -o output/

# Using photorec
photorec disk_image
```

### String Extraction

```bash
# Basic strings
strings file | grep -i "password\|api\|key\|token"

# With context
strings -n 10 file | grep -B 5 -A 5 "sensitive"

# Unicode strings
strings -e l file
```

### Hash Analysis

```bash
# Calculate hashes
md5sum file
sha256sum file

# Check against known databases
urlquery "md5:HASH_VALUE"
```

### Timeline Analysis

```bash
# Extract timestamps
ls -la --time-style=full-iso file

# Using plaso (log2timeline)
plaso --status-view none --output-file timeline.plaso file
psort --output-format timeline timeline.plaso > timeline.txt
```

---

## Best Practices

1. **Always work on copies** - Never analyze original evidence files
2. **Document everything** - Keep detailed notes of all commands and findings
3. **Verify findings** - Cross-reference results with multiple tools
4. **Maintain chain of custody** - Track all file movements and modifications
5. **Use write-blockers** - When analyzing disk images, use hardware or software write-blockers

---

## Tool Installation

```bash
# Core tools
sudo apt install foremost scalpel photorec exiftool

# Python tools
pip install oletools pdf-parser uncompyle6 pydc pycdc

# Forensic frameworks
pip install volatility3 yara-python

# Hash tools
sudo apt install hashcat john
```

---

## Quick Commands Reference

```bash
# File type identification
file filename

# Quick string search
strings filename | grep -i "keyword"

# Check for hidden data
exiftool filename

# Extract from archives
unzip -l archive.zip

# Analyze PDF
pdfinfo document.pdf

# Check image metadata
exiftool image.png
```

---

## When to Use This Skill

Use this skill when:
- Investigating suspicious files
- Extracting hidden data from documents
- Analyzing file structures for forensics
- Deobfuscating scripts or binaries
- Recovering data from corrupted files
- Examining browser or application artifacts
- Performing digital forensics investigations
- Analyzing malware samples
- Extracting metadata from any file type
