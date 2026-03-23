---
name: macos-memory-dumping
description: How to dump and analyze macOS memory for forensic investigation. Use this skill whenever the user needs to extract memory from a macOS system, investigate memory artifacts, analyze swap files, hibernate images, or perform macOS forensics, even if they don't explicitly mention 'memory dumping' or 'forensics'.
---

# macOS Memory Dumping

A skill for extracting and analyzing memory from macOS systems for forensic investigation.

## When to Use This Skill

Use this skill when:
- You need to dump physical memory from a macOS system
- You're investigating macOS security incidents or privilege escalation
- You need to analyze memory artifacts like swap files or hibernate images
- You're performing macOS forensics or incident response
- The user mentions macOS memory, RAM extraction, or system forensics

## Memory Artifacts to Investigate

### Swap Files

Swap files serve as caches when physical memory is full. When there's no more room in physical memory, data is transferred to swap files and brought back as needed.

**Location:** `/private/var/vm/swapfile0`, `/private/var/vm/swapfile1`, etc.

**What to look for:**
- Multiple swap files may exist (swapfile0, swapfile1, etc.)
- Contains cached data from physical memory
- May contain sensitive information that was swapped out

### Hibernate Image

The hibernate file stores memory data when macOS enters hibernation mode. Upon waking, the system retrieves memory data from this file.

**Location:** `/private/var/vm/sleepimage`

**Important notes:**
- On modern macOS systems, this file is typically encrypted
- Recovery may be difficult due to encryption
- To check if encryption is enabled:
  ```bash
  sysctl vm.swapusage
  ```

### Memory Pressure Logs

Memory pressure logs contain detailed information about system memory usage and pressure events.

**Location:** `/var/log/`

**Use cases:**
- Diagnosing memory-related issues
- Understanding how the system manages memory over time
- Identifying memory pressure events during investigation

## Dumping Memory with osxpmem

### Tool Information

**osxpmem** is a memory dumping tool for macOS systems.

- **Download:** https://github.com/google/rekall/releases/download/v1.5.1/osxpmem-2.1.post4.zip
- **Architecture:** Intel only (last release was 2017, before Apple Silicon)
- **Status:** Archived, but still functional for Intel Macs

### Quick Dump (Recommended)

Use the bundled script for a one-command memory dump:

```bash
./scripts/osxpmem-dump.sh
```

This script will:
1. Download osxpmem to `/tmp/`
2. Set proper permissions on the kext
3. Load the kernel extension
4. Dump memory to `/tmp/dump_mem`

### Manual Dump Process

If you need more control, follow these steps:

**Step 1: Download and extract**
```bash
cd /tmp
wget https://github.com/google/rekall/releases/download/v1.5.1/osxpmem-2.1.post4.zip
unzip osxpmem-2.1.post4.zip
```

**Step 2: Dump memory (raw format)**
```bash
sudo osxpmem.app/osxpmem --format raw -o /tmp/dump_mem
```

**Step 3: Dump memory (AFF4 format)**
```bash
sudo osxpmem.app/osxpmem -o /tmp/dump_mem.aff4
```

### Troubleshooting Common Errors

#### Kext Authentication Failure

**Error:** `osxpmem.app/MacPmem.kext failed to load - (libkern/kext) authentication failure`

**Solution:**
```bash
sudo cp -r osxpmem.app/MacPmem.kext "/tmp/"
sudo kextutil "/tmp/MacPmem.kext"
# Allow the kext in "System Settings --> Privacy & Security --> General"
sudo osxpmem.app/osxpmem --format raw -o /tmp/dump_mem
```

#### Kext Load Blocked

**Issue:** macOS blocks the kext from loading

**Solution:**
1. Go to **System Settings** → **Privacy & Security** → **General**
2. Look for a message about a kernel extension being blocked
3. Click **Allow** to permit the kext to load
4. Retry the memory dump command

## Output Formats

### Raw Format
- **Command:** `--format raw`
- **Output:** `/tmp/dump_mem`
- **Use case:** Direct memory dump for analysis with tools like Volatility

### AFF4 Format
- **Command:** (default)
- **Output:** `/tmp/dump_mem.aff4`
- **Use case:** Advanced Forensic Format for structured analysis

## Post-Dump Analysis

After dumping memory, you can:

1. **Analyze with Volatility:**
   ```bash
   volatility -f /tmp/dump_mem imageinfo
   volatility -f /tmp/dump_mem --profile=MacOS64_10_15 pslist
   ```

2. **Search for artifacts:**
   - Look for credentials in memory
   - Find running processes
   - Identify network connections
   - Extract browser data

3. **Examine swap files:**
   ```bash
   ls -la /private/var/vm/swapfile*
   ```

## Important Considerations

- **Intel vs Apple Silicon:** osxpmem only works on Intel Macs. For Apple Silicon (M1/M2/M3), you'll need alternative approaches or compiled binaries.
- **Root access required:** All memory dumping operations require `sudo`
- **System impact:** Memory dumping may temporarily impact system performance
- **Legal considerations:** Ensure you have proper authorization before dumping memory from systems you don't own

## Quick Reference

| Task | Command |
|------|--------|
| Check swap encryption | `sysctl vm.swapusage` |
| Quick memory dump | `./scripts/osxpmem-dump.sh` |
| Manual raw dump | `sudo osxpmem.app/osxpmem --format raw -o /tmp/dump_mem` |
| Manual AFF4 dump | `sudo osxpmem.app/osxpmem -o /tmp/dump_mem.aff4` |
| Load kext manually | `sudo kextutil /tmp/MacPmem.kext` |
