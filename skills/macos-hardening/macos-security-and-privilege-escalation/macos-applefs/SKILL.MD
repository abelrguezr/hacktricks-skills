---
name: macos-apfs-analysis
description: Analyze macOS APFS file system for security research, forensics, or privilege escalation. Use this skill whenever the user mentions APFS, Apple File System, macOS volumes, snapshots, firmlinks, diskutil commands, or needs to understand macOS storage architecture. Trigger for any macOS security analysis, forensic investigation, or system administration task involving file systems, volumes, or storage.
---

# macOS APFS Analysis

A skill for analyzing Apple File System (APFS) on macOS for security research, forensics, and system administration.

## When to Use This Skill

Use this skill when:
- Investigating macOS systems for security research or forensics
- Analyzing APFS volumes, snapshots, or clones
- Understanding macOS storage architecture
- Looking for privilege escalation vectors related to file systems
- Working with `diskutil` commands or APFS-specific features
- Examining firmlinks or volume mount points

## APFS Overview

APFS (Apple File System) replaced HFS+ and offers several features relevant to security analysis:

### Key Features

1. **Space Sharing**: Multiple volumes share the same underlying storage pool. Unlike traditional partitions with fixed sizes, APFS volumes dynamically grow and shrink.

2. **Snapshots**: Read-only, point-in-time instances of the file system. Useful for:
   - Finding previous versions of files
   - Understanding system state at specific times
   - Potential forensic evidence

3. **Clones**: Files or directories that share storage until modified. Can reveal relationships between files.

4. **Encryption**: Native full-disk, per-file, and per-directory encryption support.

5. **Crash Protection**: Copy-on-write metadata ensures consistency after crashes.

## Core Commands

### List APFS Volumes

```bash
diskutil list
```

This shows all disks and partitions, including APFS container structure.

### List APFS Container Details

```bash
diskutil apfs list
```

Shows APFS containers, volumes, and their relationships.

### List APFS Snapshots

```bash
diskutil apfs listSnapshots
```

Shows all snapshots on the system. Snapshots can contain valuable forensic data.

### Check Volume Mount Points

```bash
diskutil apfs list | grep -A 5 "Data"
```

The `Data` volume is typically mounted at `/System/Volumes/Data`.

## Firmlinks

Firmlinks are special symlinks that persist across reboots and point to APFS volumes.

### View Firmlinks

```bash
cat /usr/share/firmlinks
```

This file contains the list of firmlinks on the system.

### Check Firmlink Targets

```bash
ls -la /System/Volumes/
```

Shows the actual mount points for APFS volumes.

## Security Considerations

### Snapshot Analysis

Snapshots can contain:
- Previous versions of sensitive files
- Deleted data that hasn't been overwritten
- System state before security updates

To examine snapshots:

```bash
# List all snapshots
diskutil apfs listSnapshots

# Mount a snapshot (requires root)
cd /Volumes/.snapshots/
ls -la
```

### Volume Analysis

Check for:
- Multiple volumes that might contain different data
- Encrypted volumes (look for encryption flags)
- Unusual volume names or mount points

### Firmlink Enumeration

Firmlinks can reveal:
- System volume structure
- Recovery volumes
- Data volume locations

## Common Tasks

### Task 1: Full APFS Enumeration

```bash
# Get complete picture of APFS structure
diskutil list
diskutil apfs list
diskutil apfs listSnapshots
cat /usr/share/firmlinks
```

### Task 2: Find All Snapshots

```bash
diskutil apfs listSnapshots | grep -E "(Volume Name|Snapshot Name)"
```

### Task 3: Check Volume Encryption

```bash
diskutil apfs list | grep -A 10 "Volume"
```

Look for encryption-related fields in the output.

### Task 4: Analyze Volume Relationships

```bash
diskutil apfs list | grep -E "(Container|Volume|Size)"
```

Understand how volumes share storage pools.

## Output Format

When presenting APFS analysis results, use this structure:

```
## APFS Analysis Results

### Container Structure
- Container ID: [ID]
- Physical Store: [device]
- Total Size: [size]

### Volumes
| Volume Name | Mount Point | Size | Encryption |
|-------------|-------------|------|------------|
| [name] | [path] | [size] | [yes/no] |

### Snapshots
| Snapshot Name | Volume | Date | Size |
|---------------|--------|------|------|
| [name] | [volume] | [date] | [size] |

### Firmlinks
- [list of firmlinks and their targets]

### Security Observations
- [notable findings]
```

## Tips

1. **Run as root**: Many APFS commands require elevated privileges
2. **Check permissions**: Some volumes may be read-only or encrypted
3. **Document findings**: APFS structure can be complex; keep notes
4. **Consider timing**: Snapshots may be deleted automatically
5. **Be careful with modifications**: APFS is copy-on-write, but changes can still affect forensic integrity

## References

- Apple APFS documentation
- `man diskutil`
- `/usr/share/firmlinks` for firmlink definitions
