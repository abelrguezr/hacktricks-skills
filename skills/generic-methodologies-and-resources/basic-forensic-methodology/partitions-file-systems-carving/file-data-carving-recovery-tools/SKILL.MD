---
name: forensic-data-carving
description: How to perform file and data carving on disk images, firmware, and binary files using forensic tools like Autopsy, Binwalk, Foremost, Scalpel, Bulk Extractor, and PhotoRec. Use this skill whenever the user needs to recover deleted files, extract embedded content from binaries, analyze disk images, carve data from firmware, or perform digital forensics on any storage media. Trigger on mentions of: data recovery, file carving, disk image analysis, firmware extraction, deleted file recovery, forensic analysis, embedded content extraction, or any scenario where hidden or deleted data needs to be recovered from files or images.
---

# Forensic Data Carving & Recovery

This skill covers tools and techniques for extracting files and data from disk images, firmware, and binary files. Use the appropriate tool based on your evidence type and recovery goals.

## Quick Decision Guide

| Scenario | Recommended Tool |
|----------|------------------|
| Full disk image analysis | **Autopsy** (GUI + CLI) |
| Firmware/embedded content | **Binwalk** |
| Simple file carving | **Foremost** or **Scalpel** |
| Network artifacts + parallel scanning | **Bulk Extractor** |
| Maximum file type coverage | **PhotoRec** |
| Failing/unstable drives | **ddrescue** (image first) |
| EXT3/4 deleted files | **extundelete** / **ext4magic** |
| Visual binary analysis | **binvis** |
| Classify carved artifacts | **YARA-X** |

---

## Tool Selection & Usage

### Autopsy (Full-featured forensic platform)

**Best for:** Complete disk image analysis with GUI and CLI support.

**Installation:**
```bash
# Download from https://www.autopsy.com/download/
# Or via package manager on supported systems
```

**CLI workflow (Autopsy ≥4.21):**
```bash
# Create a case
autopsycli case --create MyCase --base /cases

# Ingest evidence with data-carve module (8 parallel threads)
autopsycli ingest MyCase /evidence/disk01.E01 --threads 8
```

**Key features:**
- Supports disk images and various evidence formats
- Built-in carving module (SleuthKit v4.13+)
- Parallel extraction on multi-core systems
- Scriptable via CLI for CI/CD or batch processing

---

### Binwalk (Firmware & embedded content)

**Best for:** Finding and extracting embedded files from firmware binaries.

**Installation:**
```bash
sudo apt install binwalk
```

**Common commands:**
```bash
# Display embedded data
binwalk firmware.bin

# Extract recognized objects (safe default)
binwalk -e firmware.bin

# Extract everything (use with caution)
binwalk --dd ".*" firmware.bin
```

**⚠️ Security warning:** Versions ≤2.3.3 have a Path Traversal vulnerability (CVE-2022-4510). Upgrade before analyzing untrusted samples.

---

### Foremost (Simple file carving)

**Best for:** Quick extraction of known file types from images.

**Installation:**
```bash
sudo apt-get install foremost
```

**Usage:**
```bash
# Carve with default file types
foremost -v -i file.img -o output

# Files appear in the "output" directory
```

**Configuration:** Edit `/etc/foremost.conf` to enable/disable specific file types.

---

### Scalpel (Configurable file carving)

**Best for:** Custom file type extraction with detailed configuration.

**Installation:**
```bash
sudo apt-get install scalpel
```

**Usage:**
```bash
scalpel file.img -o output
```

**Configuration:** Edit `/etc/scalpel/scalpel.conf` to uncomment desired file types.

---

### Bulk Extractor (Network artifacts & parallel scanning)

**Best for:** Extracting network artifacts (URLs, emails, IPs, MACs) and carving in parallel.

**Installation (v2.1.1+):**
```bash
git clone https://github.com/simsong/bulk_extractor.git && cd bulk_extractor
mkdir build && cd build && cmake .. && make -j$(nproc) && sudo make install
```

**Usage:**
```bash
# Run all scanners with aggressive JPEG carving
bulk_extractor -o out_folder -S jpeg_carve_mode=2 -S write_bodyfile=y /evidence/disk.img
```

**Post-processing:**
- `bulk_diff` - Compare artifacts between images
- `bulk_extractor_reader.py` - Convert results to JSON for SIEM

---

### PhotoRec (Maximum file type coverage)

**Best for:** Recovering the widest range of file types.

**Download:** https://www.cgsecurity.org/wiki/TestDisk_Download

**Features:**
- GUI and CLI versions available
- Select specific file types to search for
- Works on raw images and physical drives

---

### ddrescue (Imaging failing drives)

**Best for:** Creating reliable images from unstable or failing drives.

**Installation:**
```bash
sudo apt install gddrescue ddrescueview
```

**Workflow:**
```bash
# First pass - quick copy without retries
sudo ddrescue -f -n /dev/sdX suspect.img suspect.log

# Second pass - aggressive recovery with 3 retries
sudo ddrescue -d -r3 /dev/sdX suspect.img suspect.log

# Visualize status (green=good, red=bad)
ddrescueview suspect.log
```

**Note:** Version 1.28+ supports `--cluster-size` for high-capacity SSDs.

---

### EXT3/4 Recovery (Filesystem-specific)

**Best for:** Recovering deleted files from Linux EXT filesystems without full carving.

**extundelete (journal-based):**
```bash
extundelete disk.img --restore-all
```

**ext4magic (directory scan):**
```bash
ext4magic disk.img -M -f '*.jpg' -d ./recovered
```

**⚠️ Note:** If the filesystem was mounted after deletion, data blocks may be overwritten. Use carving tools (Foremost/Scalpel) as fallback.

---

### binvis (Visual binary analysis)

**Best for:** Understanding unknown binaries, spotting patterns, identifying packers/steganography.

**Access:**
- Web tool: https://binvis.io/#/
- Source: https://code.google.com/archive/p/binvis/

**Features:**
- Visual structure viewer
- String and resource extraction (PE/ELF)
- Pattern detection for cryptanalysis
- Steganography identification
- Binary diffing

---

### YARA-X (Artifact classification)

**Best for:** Rapidly classifying thousands of carved objects.

**Installation:** https://github.com/VirusTotal/yara-x

**Usage:**
```bash
# Scan carved objects with YARA rules
yarax -r rules/index.yar out_folder/ --threads 8 --print-meta
```

**Performance:** 10-30× faster than classic YARA.

---

## Complementary Tools

| Tool | Purpose |
|------|--------|
| **viu** | View images in terminal |
| **pdftotext** | Extract text from PDFs |
| **FindAES** | Search for AES keys (TrueCrypt/BitLocker) |

---

## Recommended Workflow

### 1. Image the evidence first
```bash
# For stable drives
dd if=/dev/sdX of=evidence.img bs=4M status=progress

# For failing drives (see ddrescue section)
```

### 2. Choose carving approach
- **Full analysis:** Autopsy
- **Quick extraction:** Foremost/Scalpel
- **Firmware:** Binwalk
- **Network artifacts:** Bulk Extractor

### 3. Classify results
```bash
yarax -r rules/index.yar carved_output/ --threads 8
```

### 4. Review and document
- Use `ddrescueview` for imaging status
- Use `viu` for quick image preview
- Export results to JSON for SIEM if needed

---

## Security Considerations

1. **Always work on copies** - Never carve directly from original evidence
2. **Use read-only mounts** - Mount images with `-o ro` flag
3. **Isolate untrusted samples** - Run carving in containers or VMs
4. **Keep tools updated** - Especially Binwalk (CVE-2022-4510)
5. **Document chain of custody** - Log all operations with timestamps

---

## References

- Autopsy 4.21 release notes: https://github.com/sleuthkit/autopsy/releases/tag/autopsy-4.21
- Awesome Data Recovery: https://github.com/Claudio-C/awesome-datarecovery
- Bulk Extractor: https://github.com/simsong/bulk_extractor
- YARA-X: https://github.com/VirusTotal/yara-x
