---
name: forensic-analysis
description: Digital forensic analysis skill for investigating disk images, memory dumps, PCAPs, malware, and system artifacts. Use this skill whenever the user needs to perform forensic analysis on any digital evidence including disk images, memory dumps, network captures, suspicious files, or when investigating security incidents. Trigger this skill for any forensic investigation, incident response, malware analysis, or digital evidence examination tasks.
---

# Digital Forensic Analysis

A comprehensive skill for performing digital forensic investigations across multiple evidence types and platforms.

## When to Use This Skill

Use this skill when you need to:
- Analyze disk images or file system artifacts
- Investigate memory dumps for malicious activity
- Examine network captures (PCAP files)
- Perform malware analysis on suspicious files
- Conduct incident response investigations
- Recover deleted or hidden files
- Analyze browser artifacts and user activity
- Detect anti-forensic techniques
- Perform threat hunting and file integrity monitoring

## Forensic Investigation Workflow

Follow this systematic approach for forensic investigations:

### 1. Evidence Acquisition and Preservation

**Before analysis begins:**
- Create forensic copies (never work on original evidence)
- Calculate and document hash values (MD5, SHA1, SHA256)
- Maintain chain of custody documentation
- Use write-blockers when acquiring disk images

**Image acquisition commands:**
```bash
# Create forensic image with dd
dd if=/dev/sdX of=image.img bs=4M status=progress

# Verify image integrity
md5sum image.img
sha256sum image.img

# Create sparse image
dd if=/dev/sdX of=image.sparse.img bs=4M conv=sparse
```

### 2. Initial Image Inspection

**Identify file system and partitions:**
```bash
# Examine disk structure
fdisk -l image.img

# Identify file system type
file image.img

# List partitions
parted image.img print

# Mount read-only (critical!)
mount -o ro,loop image.img /mnt/forensics
```

**File system analysis:**
```bash
# For ext file systems
ddrescue image.img recovered.img
extundelete image.img --restore-all

# For NTFS
tools/ntfs-3g mount -o ro image.img /mnt/forensics

# File carving (recover deleted files)
foremost -i image.img -o ./recovered/
scalpel -c /etc/scalpel/scalpel.conf image.img
```

### 3. Platform-Specific Artifact Analysis

**Windows Forensics:**
- Registry hives (SAM, SYSTEM, SOFTWARE, NTUSER.DAT)
- Event logs (Security, System, Application)
- Prefetch files (program execution history)
- Shellbags (folder access history)
- USN Journal (NTFS change tracking)
- Browser artifacts (history, cookies, cache)
- Windows Event Forwarding logs

**Linux Forensics:**
- /var/log/ (auth.log, syslog, kern.log)
- /var/lib/dpkg/status (installed packages)
- /var/log/apt/history.log (package changes)
- Bash history files (.bash_history)
- Cron jobs and scheduled tasks
- SSH keys and authorized_keys
- Docker container artifacts

**iOS Forensics:**
- iTunes backup analysis
- SQLite database extraction
- Keychain analysis
- App sandbox examination

### 4. Malware Analysis

**Static Analysis:**
```bash
# File identification
file suspicious_file
strings suspicious_file | grep -i "http"

# Hash calculation
md5sum suspicious_file
sha256sum suspicious_file

# PE header analysis (Windows executables)
pefile suspicious.exe

# Extract embedded resources
extract_strings.exe suspicious.exe
```

**Dynamic Analysis (in isolated environment):**
- Monitor process creation
- Track file system changes
- Log network connections
- Capture registry modifications
- Analyze memory behavior

### 5. Memory Dump Analysis

**Extract and analyze memory:**
```bash
# Volatility framework
volatility -f memory.dump imageinfo
volatility -f memory.dump --profile=Win7SP1x64 pslist
volatility -f memory.dump --profile=Win7SP1x64 netscan
volatility -f memory.dump --profile=Win7SP1x64 malfind

# Extract processes
volatility -f memory.dump --profile=Win7SP1x64 dumpmap -p <PID>

# Find injected code
volatility -f memory.dump --profile=Win7SP1x64 scansmem
```

**Key memory artifacts:**
- Process lists and parent-child relationships
- Network connections and sockets
- Loaded modules and DLLs
- Command line arguments
- Clipboard contents
- Encrypted keys and credentials

### 6. Network Capture (PCAP) Analysis

**Examine network traffic:**
```bash
# Basic statistics
tshark -r capture.pcap -q -z io,phs

# Filter by protocol
tshark -r capture.pcap -Y "http"
tshark -r capture.pcap -Y "dns"

# Extract files from HTTP
tshark -r capture.pcap -Y "http.file_data" -T fields -e http.file_data > extracted_files

# Analyze DNS queries
tshark -r capture.pcap -Y "dns.qry.name" -T fields -e dns.qry.name | sort | uniq -c | sort -rn

# Find suspicious connections
tshark -r capture.pcap -Y "tcp.flags.syn==1" -T fields -e ip.dst -e tcp.dstport
```

**Key network artifacts:**
- DNS queries and responses
- HTTP requests and responses
- Malicious IP addresses and domains
- Data exfiltration patterns
- Command and control communications

### 7. Anti-Forensic Detection

**Watch for these techniques:**
- File carving to recover deleted data
- Slack space analysis for hidden content
- Timestamp manipulation detection
- Log file tampering indicators
- Encryption and steganography detection
- Rootkit and driver analysis
- Memory-only malware detection

**Detection commands:**
```bash
# Check for timestamp anomalies
touch -r reference_file target_file

# Analyze slack space
dd if=image.img bs=512 skip=100 count=1 | xxd

# Detect hidden partitions
fdisk -l image.img | grep -i "hidden"
```

### 8. Threat Hunting and File Integrity

**Monitor for suspicious activity:**
```bash
# File integrity monitoring
aide --check
tripwire --check

# Find recently modified files
find / -type f -mtime -7 -ls

# Find suspicious executables
find / -type f -perm -4000 -ls  # SUID files

# Monitor process activity
auditctl -w /etc/passwd -p wa -k passwd_changes
```

## Browser Artifact Analysis

**Chrome/Chromium:**
```bash
# Location: ~/.config/google-chrome/Default/
# Key files: History, Cookies, Web Data, Local Storage

# Extract browsing history
sqlite3 ~/.config/google-chrome/Default/History \
  "SELECT url, title, last_visit_time FROM urls ORDER BY last_visit_time DESC LIMIT 100;"

# Extract cookies
sqlite3 ~/.config/google-chrome/Default/Cookies \
  "SELECT host_key, name, encrypted_value FROM cookies;"
```

**Firefox:**
```bash
# Location: ~/.mozilla/firefox/*.default/
# Key files: places.sqlite, cookies.sqlite, formhistory.sqlite

# Extract browsing history
sqlite3 ~/.mozilla/firefox/*.default/places.sqlite \
  "SELECT url, title, visit_count FROM moz_places ORDER BY last_visit_date DESC LIMIT 100;"
```

## Reporting and Documentation

**Always document:**
1. Evidence collection methods and timestamps
2. Hash values for all evidence files
3. Tools and versions used
4. Commands executed and their output
5. Findings and conclusions
6. Chain of custody records

**Report structure:**
```
# Forensic Investigation Report

## Executive Summary
- Brief overview of investigation
- Key findings
- Recommendations

## Methodology
- Tools used
- Procedures followed
- Timeline of analysis

## Evidence Analysis
- Detailed findings by category
- Supporting artifacts
- Screenshots and logs

## Conclusions
- Summary of findings
- Confidence levels
- Next steps

## Appendices
- Hash values
- Raw data extracts
- Tool outputs
```

## Best Practices

1. **Never modify original evidence** - Always work on copies
2. **Document everything** - Maintain detailed logs of all actions
3. **Verify tool integrity** - Hash all forensic tools before use
4. **Use write-blockers** - Prevent accidental evidence modification
5. **Validate findings** - Cross-reference multiple data sources
6. **Maintain chain of custody** - Track evidence handling
7. **Follow legal requirements** - Ensure proper authorization
8. **Preserve timestamps** - Use UTC and document time zones

## Common Tools Reference

| Category | Tools |
|----------|-------|
| Disk Imaging | dd, ddrescue, FTK Imager |
| File System | extundelete, photorec, foremost |
| Memory Analysis | Volatility, Rekall |
| Network Analysis | Wireshark, tshark, tcpdump |
| Malware Analysis | Ghidra, IDA Pro, PEStudio |
| Windows Forensics | Eric Zimmerman's tools, Plaso |
| Linux Forensics | Autopsy, Sleuth Kit |
| Hashing | md5sum, sha256sum, hashdeep |

## Quick Reference Commands

```bash
# Hash verification
md5sum -c hashes.txt

# File type identification
file -b suspicious_file

# String extraction
strings suspicious_file | grep -i "password"

# Hex dump
xxd -l 512 image.img

# Find specific patterns
grep -r "suspicious_pattern" /mnt/forensics/

# Extract emails from text
grep -oE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' file.txt

# Extract IP addresses
grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' file.txt
```

## Safety Warnings

⚠️ **Critical Reminders:**
- Always mount forensic images as read-only
- Never run unknown executables on your analysis system
- Use isolated environments for malware analysis
- Verify tool integrity before use
- Follow organizational policies and legal requirements
- Maintain proper authorization documentation
