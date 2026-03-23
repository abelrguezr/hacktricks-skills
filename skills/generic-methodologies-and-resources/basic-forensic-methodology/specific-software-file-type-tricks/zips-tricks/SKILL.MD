---
name: zip-forensics
description: Forensic analysis, repair, and password cracking of ZIP files and APKs. Use this skill whenever the user mentions ZIP files, APK analysis, password-protected archives, corrupted archives, zip bombs, anti-reversing techniques, or any task involving ZIP file forensics, malware analysis, or archive triage. This includes diagnosing why a ZIP won't extract, repairing corrupted archives, cracking passwords, detecting malicious ZIP tricks (fake encryption, overlapping entries, concatenated directories), and analyzing APK anti-reversing obfuscation.
---

# ZIP Forensics Skill

A comprehensive toolkit for forensic analysis, repair, and password cracking of ZIP files and Android APKs. This skill covers everything from basic ZIP utilities to advanced anti-reversing detection and malicious ZIP trick identification.

## When to Use This Skill

Use this skill when the user needs to:
- Diagnose why a ZIP file won't decompress or extract
- Repair corrupted ZIP files
- Crack password-protected ZIP files
- Analyze APK files for anti-reversing tricks
- Detect malicious ZIP techniques (fake encryption, overlapping entries, concatenated directories)
- Perform ZIP file forensics or malware analysis
- Inspect ZIP file structure and metadata

## Core ZIP Utilities

### Basic Inspection Tools

```bash
# List contents without extracting
zipinfo file.zip

# Detailed format analysis (requires zipdetails from Archive::Zip)
zipdetails -v file.zip

# Try to repair corrupted ZIP
zip -F input.zip --out output.zip      # First pass
zip -FF input.zip --out output.zip     # Second pass (more aggressive)
```

### Password Cracking

**fcrackzip** - Brute-force tool effective for passwords up to ~7 characters:

```bash
# Brute force all combinations
fcrackzip -v -D -p abcdefghijklmnopqrstuvwxyz0123456789 file.zip

# Dictionary attack
fcrackzip -v -D -p /path/to/wordlist.txt file.zip

# Known-plaintext attack (if you have an unencrypted copy of a file inside)
fcrackzip -u -D -p wordlist.txt -f known_file.txt file.zip
```

**Important Security Notes:**
- Password-protected ZIP files **do not encrypt filenames or file sizes** - this is a security flaw
- ZIP files using **ZipCrypto** are vulnerable to plaintext attacks if an unencrypted copy exists
- **AES-256 encrypted** ZIP files are immune to plaintext attacks
- RAR and 7z encrypt filenames and sizes, making them more secure

## APK Anti-Reversing Detection

Modern Android malware uses malformed ZIP metadata to break static analysis tools (jadx, apktool, unzip) while remaining installable on-device.

### 1. Fake Encryption (GPBF Bit 0)

**Symptoms:**
- `jadx-gui` fails with `ZipException: invalid CEN header (encrypted entry)`
- `unzip` prompts for passwords on core APK files (`classes*.dex`, `AndroidManifest.xml`, `resources.arsc`)
- APK installs and runs on-device despite appearing encrypted

**Detection:**

```bash
zipdetails -v sample.apk | grep -A5 "General Purpose Flag"
```

Look for bit 0 (Encryption) set on core entries. A telltale value:
```
General Purpose Flag  0A09
  [Bit 0]   1 'Encryption'
```

**Fix:** Clear GPBF bit 0 using the bundled script:

```bash
python3 scripts/gpbf_clear.py obfuscated.apk normalized.apk
```

Then verify:
```bash
zipdetails -v normalized.apk | grep -A2 "General Purpose Flag"
# Should show: General Purpose Flag  0000
```

### 2. Large/Custom Extra Fields

Attackers embed oversized Extra fields with custom IDs (e.g., `0xCAFE`, `0x414A` with markers like `JADXBLOCK`) to confuse parsers.

**Detection:**

```bash
zipdetails -v sample.apk | sed -n '/Extra ID/,+4p' | head -n 50
```

**Heuristics:**
- Alert when Extra fields are unusually large on core entries
- Treat unknown Extra IDs on `classes*.dex`, `AndroidManifest.xml`, `resources.arsc` as suspicious

**Mitigation:** Rebuild the archive after clearing GPBF:

```bash
mkdir /tmp/apk
unzip -qq normalized.apk -d /tmp/apk
(cd /tmp/apk && zip -qr ../clean.apk .)
```

### 3. File/Directory Name Collisions

A ZIP can contain both `X` (file) and `X/` (directory). Some extractors get confused and hide the real file.

**Detection:**

```bash
# List potential collisions
zipinfo -1 sample.apk | awk '{n=$0; sub(/\/$/,"",n); print n}' | sort | uniq -d

# Or use the bundled script
python3 scripts/detect_collisions.py normalized.apk
```

**Safe Extraction:**

```bash
unzip normalized.apk -d outdir
# When prompted for conflicts, choose [r]ename
# replace outdir/classes.dex? [y]es/[n]o/[A]ll/[N]one/[r]ename: r
# new name: unk_classes.dex
```

## Malicious ZIP Tricks (2024-2025)

### Concatenated Central Directories

Phishing campaigns ship a single blob containing **two ZIP files concatenated**. Each has its own End of Central Directory (EOCD). Different extractors parse different directories (7zip reads first, WinRAR reads last), hiding payloads from some tools.

**Detection:**

```bash
# Count EOCD signatures
binwalk -R "PK\x05\x06" suspect.zip

# Dump central-directory offsets
zipdetails -v suspect.zip | grep -n "End Central"
```

If multiple EOCDs appear or "data after payload" warnings exist, split and inspect:

```bash
# Extract second archive (adjust OFF based on binwalk output)
OFF=123456
dd if=suspect.zip bs=1 skip=$OFF of=tail.zip
7z l tail.zip   # List hidden content
```

### Overlapping Entry Bombs

Modern zip bombs reuse a highly compressed kernel via overlapping local headers. Every central directory entry points to the same compressed data, achieving >28M:1 ratios.

**Detection:**

```bash
# Use bundled script
python3 scripts/detect_overlaps.py suspect.zip

# Or manual check
zipdetails -v file.zip | grep -n "Rel Off"
# Offsets should be strictly increasing and unique
```

**Safe Handling:**
- Perform dry-run walk before extraction
- Cap total uncompressed size and entry count
- Extract inside cgroup/VM with CPU+disk limits

## Blue-Team Detection Rules

Flag APKs/ZIPs that exhibit:
1. Local headers mark encryption (GPBF bit 0 = 1) yet install/run
2. Large/unknown Extra fields on core entries (look for markers like `JADXBLOCK`)
3. Path collisions (`X` and `X/`) for `AndroidManifest.xml`, `resources.arsc`, `classes*.dex`
4. Multiple EOCD signatures in a single file
5. Duplicate relative offsets in central directory entries

## Workflow Recommendations

### For Corrupted ZIP Files
1. Try `zip -F` first, then `zip -FF` if needed
2. Use `zipdetails -v` to understand the corruption
3. Check for concatenated directories with `binwalk`

### For Password-Protected ZIPs
1. Check encryption method (ZipCrypto vs AES-256)
2. If ZipCrypto and you have a known plaintext file, use known-plaintext attack
3. Otherwise, use fcrackzip with dictionary or brute-force
4. Note: AES-256 requires different tools (hashcat, john)

### For APK Analysis
1. First check for fake encryption with `zipdetails -v`
2. Clear GPBF bit 0 if needed using `gpbf_clear.py`
3. Check for Extra field anomalies
4. Check for name collisions
5. Rebuild clean archive if needed
6. Then proceed with jadx/apktool

### For Suspicious ZIPs
1. Check for multiple EOCDs (concatenated directories)
2. Check for overlapping entries (zip bombs)
3. Inspect Extra fields for custom markers
4. Never extract unbounded - use limits

## References

- [ZIP File Format Specification (PKWARE APPNOTE.TXT)](https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT)
- [fcrackzip GitHub](https://github.com/hyc/fcrackzip)
- [Known-Plaintext Attack on ZIP](https://www.hackthis.co.uk/articles/known-plaintext-attack-cracking-zip-files)
- [ZIP Attacks Academic Paper](https://www.cs.auckland.ac.nz/~mike/zipattacks.pdf)
- [GodFather APK Anti-Reversing](https://shindan.io/blog/godfather-part-1-a-multistage-dropper)
- [Concatenated ZIP Attack](https://www.tomshardware.com/tech-industry/cyber-security/hackers-bury-malware-in-new-zip-file-attack-combining-multiple-zips-into-one-bypasses-antivirus-protections)
- [Zip Bomb Construction](https://ubos.tech/news/understanding-zip-bombs-construction-risks-and-mitigation-2/)
