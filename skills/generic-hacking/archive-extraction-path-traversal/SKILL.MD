---
name: archive-extraction-path-traversal
description: Security skill for detecting, testing, and mitigating archive extraction path traversal vulnerabilities (Zip-Slip, CVE-2025-8088, etc.). Use this skill whenever the user mentions archives (ZIP, RAR, TAR, 7-ZIP), file extraction, path traversal, zip-slip, archive security, or wants to test archive handling code. Also trigger when users ask about secure archive extraction, vulnerable code patterns, or creating security test cases for archive utilities.
---

# Archive Extraction Path Traversal Security

A comprehensive skill for understanding, detecting, and mitigating archive extraction path traversal vulnerabilities (commonly called "Zip-Slip").

## What This Skill Does

- **Detect** vulnerable archive extraction code patterns
- **Create** PoC archives for security testing
- **Analyze** archive entries for suspicious paths
- **Implement** secure extraction patterns
- **Understand** real-world exploitation cases

## Core Concepts

### The Vulnerability

Archive formats (ZIP, RAR, TAR, 7-ZIP) allow each entry to carry its own **internal path**. When extraction utilities blindly trust these paths, crafted filenames containing `..` or absolute paths can write files outside the intended directory.

**Attack flow:**
1. Attacker creates archive with malicious entry paths (`../evil.exe` or `C:\Windows\payload.exe`)
2. Victim extracts with vulnerable tool
3. File writes to attacker-controlled location
4. If location is auto-run (Startup folder, cron), achieves **RCE**

### Common Vulnerable Patterns

#### .NET Path.Combine + ZipArchive

```csharp
// VULNERABLE - don't do this
using (var zip = ZipFile.OpenRead(zipPath))
{
    foreach (var entry in zip.Entries)
    {
        var dest = Path.Combine(@"C:\samples\queue\", entry.FullName);
        entry.ExtractToFile(dest); // Path traversal if entry.FullName contains ..\ or is absolute
    }
}
```

**Why it fails:**
- `Path.Combine` discards the left component if the right is absolute
- No path canonicalization before write
- `..\` sequences traverse outside destination

#### Go archiver.Unarchive()

```go
// VULNERABLE - archiver <= 3.5.1
archiver.Unarchive("exploit.zip", "/tmp/safe")
// exploit.zip holds ../../../../home/user/.ssh/authorized_keys
```

#### Python zipfile

```python
# VULNERABLE - no path validation
import zipfile
with zipfile.ZipFile('archive.zip', 'r') as zf:
    zf.extractall('/tmp/dest')  # Can extract outside if entries have ../
```

## Creating Test Archives

### Python: Create ZIP with Path Traversal

Use `scripts/create_traversal_zip.py` to generate test archives:

```bash
# Create ZIP with ../ traversal
python scripts/create_traversal_zip.py \
  --output test_traversal.zip \
  --entry "../evil/payload.txt" \
  --content "malicious content"

# Create ZIP with absolute path
python scripts/create_traversal_zip.py \
  --output test_absolute.zip \
  --entry "C:\\Windows\\System32\\evil.dll" \
  --content "payload"

# Create ZIP with symlink (Unix)
python scripts/create_traversal_zip.py \
  --output test_symlink.zip \
  --symlink "/etc/passwd" \
  --linkname "evil_link"
```

### Bash: Create RAR with Path Traversal

```bash
# Requires rar >= 6.x
mkdir -p "evil/../../../Users/Public/AppData/Roaming/Microsoft/Windows/Start Menu/Programs/Startup"
cp payload.exe "evil/../../../Users/Public/AppData/Roaming/Microsoft/Windows/Start Menu/Programs/Startup/"
rar a -ep evil.rar evil/*
```

The `-ep` flag preserves exact paths (doesn't prune leading `./`).

### Bash: Create ZIP with Symlink

```bash
mkdir -p out
ln -s /etc/cron.d evil
zip -y exploit.zip evil  # -y preserves symlinks
```

## Detection & Analysis

### Analyze Archive Entries

Use `scripts/analyze_archive.py` to scan for suspicious entries:

```bash
# Check ZIP file for traversal patterns
python scripts/analyze_archive.py --file suspicious.zip

# Check all archives in directory
python scripts/analyze_archive.py --directory ./downloads/

# Verbose output with line numbers
python scripts/analyze_archive.py --file archive.zip --verbose
```

**What it detects:**
- `../` or `..\\` sequences
- Absolute paths (`/`, `C:`, `\\\\`)
- Symlink entries pointing outside destination
- Null bytes or other obfuscation

### Manual Detection Checklist

When reviewing archive extraction code, check for:

1. **Path canonicalization** - Does code call `realpath()`, `PathCanonicalize()`, or equivalent before write?
2. **Destination validation** - After canonicalization, does the path still start with the intended destination?
3. **Symlink handling** - Are symlinks extracted safely or blocked?
4. **Absolute path rejection** - Are absolute paths in entries rejected?
5. **Sandbox extraction** - Is extraction done in a disposable/sandboxed directory?

## Secure Extraction Patterns

### Python: Safe ZIP Extraction

```python
import zipfile
import os
from pathlib import Path

def safe_extract(zip_path, dest_dir):
    dest_dir = Path(dest_dir).resolve()
    
    with zipfile.ZipFile(zip_path, 'r') as zf:
        for entry in zf.infolist():
            # Check for path traversal
            target_path = (dest_dir / entry.filename).resolve()
            
            # Reject if outside destination
            if not str(target_path).startswith(str(dest_dir)):
                raise ValueError(f"Unsafe path: {entry.filename}")
            
            # Reject symlinks
            if entry.external_attr >> 16 & 0xA000:
                raise ValueError(f"Symlink not allowed: {entry.filename}")
            
            zf.extract(entry, dest_dir)
```

### Go: Safe Extraction Pattern

```go
import (
    "path/filepath"
    "os"
)

func safeExtractEntry(destDir, entryName string) error {
    // Canonicalize destination
    destDir, err := filepath.Abs(destDir)
    if err != nil {
        return err
    }
    
    // Join and canonicalize
    targetPath := filepath.Join(destDir, entryName)
    targetPath, err = filepath.Abs(targetPath)
    if err != nil {
        return err
    }
    
    // Verify still under destination
    if !strings.HasPrefix(targetPath, destDir+string(os.PathSeparator)) {
        return fmt.Errorf("path escapes destination: %s", entryName)
    }
    
    // Safe to extract
    return extractToFile(targetPath, entry)
}
```

### .NET: Safe Extraction Pattern

```csharp
using System.IO;
using System.IO.Compression;

public static void SafeExtract(string zipPath, string destDir)
{
    var dest = Path.GetFullPath(destDir);
    
    using (var zip = ZipFile.OpenRead(zipPath))
    {
        foreach (var entry in zip.Entries)
        {
            var target = Path.GetFullPath(Path.Combine(dest, entry.FullName));
            
            // Reject if outside destination
            if (!target.StartsWith(dest, StringComparison.OrdinalIgnoreCase))
            {
                throw new SecurityException($"Path traversal detected: {entry.FullName}");
            }
            
            entry.ExtractToFile(target, true);
        }
    }
}
```

## Real-World Cases

### CVE-2025-8088: WinRAR ≤ 7.12

**Impact:** RCE via Startup folder

WinRAR failed to validate filenames during extraction. A malicious RAR with entry:
```
..\..\..\Users\victim\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\payload.exe
```

Would extract to the Startup folder, executing on next login.

**Exploitation in the wild:** RomCom (Storm-0978/UNC2596) used this for spear-phishing campaigns.

**Fix:** Update to WinRAR 7.13+

### CVE-2025-11001: 7-Zip Symlink Traversal

**Impact:** RCE via cron/service locations

7-Zip 21.02–24.09 dereferenced symlinks during extraction, allowing escape from destination directory.

**Fix:** Update to 7-Zip 25.00+

### CVE-2025-3445: Go mholt/archiver

**Impact:** Arbitrary file write

`archiver.Unarchive()` followed `../` and symlinked entries.

**Fix:** Switch to `mholt/archives` ≥ 0.1.0 or implement canonical-path checks.

## Mitigation Strategies

### 1. Update Extractors

| Tool | Vulnerable | Fixed In |
|------|------------|----------|
| WinRAR | ≤ 7.12 | 7.13+ |
| 7-Zip | 21.02–24.09 | 25.00+ |
| Go archiver | ≤ 3.5.1 | Use mholt/archives ≥ 0.1.0 |

### 2. Safe Extraction Options

- **7-Zip:** Use `-aoa` (always overwrite) with path validation
- **bsdtar:** Use `--safe --xattrs --no-same-owner`
- **Unzip:** Use `-o` with pre-validation

### 3. Sandboxing

- **Unix:** Extract in chroot/namespace, drop privileges
- **Windows:** Use AppContainer or sandbox
- **General:** Extract to disposable directory, verify paths, then move

### 4. Code Review Checklist

- [ ] Path canonicalization before write
- [ ] Destination validation after canonicalization
- [ ] Symlink rejection or safe handling
- [ ] Absolute path rejection
- [ ] No trust of user-controlled archive entries

## References

- [Trend Micro ZDI-25-949 – 7-Zip symlink traversal](https://www.zerodayinitiative.com/advisories/ZDI-25-949/)
- [JFrog Research – mholt/archiver Zip-Slip](https://research.jfrog.com/vulnerabilities/archiver-zip-slip/)
- [Meziantou – Prevent Zip Slip in .NET](https://www.meziantou.net/prevent-zip-slip-in-dotnet.htm)
- [0xdf – HTB Bruno ZipSlip → DLL hijack](https://0xdf.gitlab.io/2026/02/24/htb-bruno.html)
- [Snyk – Zip-Slip Advisory (2018)](https://snyk.io/research/zip-slip-vulnerability)
