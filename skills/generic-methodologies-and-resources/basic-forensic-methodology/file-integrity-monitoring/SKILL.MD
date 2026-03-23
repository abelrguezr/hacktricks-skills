---
name: file-integrity-monitoring
description: How to set up file integrity monitoring (FIM) to detect unauthorized changes to files, systems, and configurations. Use this skill whenever the user needs to create file baselines, detect file modifications, monitor system changes, investigate potential compromises, or set up security monitoring. Trigger this skill for any request involving file hashing, change detection, system baselining, or security auditing—even if they don't explicitly mention "file integrity monitoring" or "FIM".
---

# File Integrity Monitoring (FIM)

File Integrity Monitoring is a critical security technique that protects IT environments by tracking changes in files and system configurations. This skill helps you establish baselines, detect modifications, and monitor for unauthorized changes.

## Core Concepts

### What is FIM?

FIM involves two key steps:

1. **Baseline Creation**: Capture a snapshot of file attributes or cryptographic checksums (MD5, SHA-256) for future comparison
2. **Change Detection**: Compare current state against the baseline to identify modifications, additions, or deletions

### Why Use FIM?

- Detect unauthorized file modifications
- Identify potential security compromises
- Track configuration drift
- Meet compliance requirements
- Investigate security incidents

## Creating a Baseline

### Quick Baseline with `create-baseline.sh`

Use the bundled script to quickly create a baseline:

```bash
./scripts/create-baseline.sh /path/to/monitor baseline.txt
```

This creates a SHA-256 hash of all files in the specified directory.

### Manual Baseline Creation

For more control, use these commands:

**Linux/Unix:**
```bash
# Hash all files in a directory
find /path/to/monitor -type f -exec sha256sum {} \; > baseline.txt

# Include file permissions and timestamps
find /path/to/monitor -type f -exec ls -la {} \; > baseline.txt
```

**Windows (PowerShell):**
```powershell
# Hash all files
Get-ChildItem -Path "C:\path\to\monitor" -Recurse -File | Get-FileHash -Algorithm SHA256 | Export-Csv baseline.csv
```

### What to Baseline

Focus on critical system areas:

- **System binaries**: `/bin`, `/sbin`, `/usr/bin`, `/usr/sbin`
- **Configuration files**: `/etc`, `/etc/ssh`, `/etc/nginx`
- **Application directories**: Web roots, application folders
- **User accounts**: `/etc/passwd`, `/etc/shadow`, `/etc/group`
- **Running processes**: `ps aux` output
- **Services**: `systemctl list-units --type=service`
- **Network connections**: `netstat -tulpn` or `ss -tulpn`

## Detecting Changes

### Quick Comparison with `compare-baseline.sh`

```bash
./scripts/compare-baseline.sh baseline.txt /path/to/monitor
```

This compares current file hashes against your baseline and reports:
- Modified files (hash changed)
- New files (not in baseline)
- Deleted files (in baseline but missing)

### Manual Comparison

```bash
# Generate current hashes
find /path/to/monitor -type f -exec sha256sum {} \; > current.txt

# Compare with baseline
diff baseline.txt current.txt
```

### Automated Monitoring

For continuous monitoring, use the bundled script:

```bash
./scripts/monitor-changes.sh baseline.txt /path/to/monitor --interval 60
```

This checks every 60 seconds and alerts on changes.

## Tools and Resources

### Built-in Tools

- **Linux**: `sha256sum`, `md5sum`, `find`, `diff`
- **Windows**: `Get-FileHash`, `certutil -hashfile`
- **macOS**: `shasum`, `md5`
