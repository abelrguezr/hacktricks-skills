---
name: anti-forensic-detection
description: How to detect and investigate anti-forensic techniques used by attackers. Use this skill whenever you need to identify timestamp manipulation, data hiding, log tampering, EDR evasion, or other anti-forensic activity during incident response, threat hunting, or forensic investigations. Make sure to use this skill when analyzing suspicious systems, investigating potential compromises, or reviewing artifacts that may have been tampered with.
---

# Anti-Forensic Detection and Investigation

This skill helps security professionals detect and investigate anti-forensic techniques that attackers use to evade detection. It covers Windows and Linux systems, focusing on identifying tampering rather than performing it.

## Investigation Workflow

1. **Gather evidence** - Collect relevant artifacts (disk images, memory dumps, logs)
2. **Identify anomalies** - Look for mismatches, gaps, and suspicious patterns
3. **Correlate findings** - Cross-reference multiple data sources
4. **Document timeline** - Reconstruct events despite tampering attempts

---

## Timestamp Manipulation Detection

### NTFS Timestamp Analysis

Attackers often modify file timestamps to hide their activity. Detect this by:

**Check for MACE attribute mismatches:**
- `$STANDARD_INFORMATION` vs `$FILE_NAME` timestamps should match
- Tools like `TimeStomp` only modify `$STANDARD_INFORMATION`, leaving `$FILE_NAME` unchanged
- Use forensic tools to compare both attributes

**Look for suspicious timestamp precision:**
- NTFS timestamps have 100-nanosecond precision
- Round timestamps (e.g., `2010-10-10 10:10:00.00000000`) are highly suspicious
- Attackers often set clean, round times that don't occur naturally

**Investigation commands:**
```powershell
# PowerShell - Check file timestamps
Get-Item "C:\path\to\file" | Select-Object Name, CreationTime, LastWriteTime, LastAccessTime

# Look for files with suspiciously round timestamps
Get-ChildItem -Recurse | Where-Object { $_.LastWriteTime.Second -eq 0 -and $_.LastWriteTime.Millisecond -eq 0 }
```

### USN Journal Analysis

The USN Journal tracks all NTFS volume changes and cannot be easily tampered with:

**Use UsnJrnl2Csv to examine changes:**
```powershell
# Parse USN Journal (requires admin)
# Download from: https://github.com/jschicht/UsnJrnl2Csv
UsnJrnl2Csv.exe -d C: -o usn_output.csv
```

**What to look for:**
- Timestamp modifications recorded in the journal
- File creation/deletion events that don't match current timestamps
- Bulk operations that suggest automated tampering

### $LogFile Analysis

The `$LogFile` contains write-ahead logging of all metadata changes:

**Use LogFileParser:**
```powershell
# Download from: https://github.com/jschicht/LogFileParser
LogFileParser.exe -d C: -o logfile_output.csv
```

**Key indicators:**
- CTIME: File creation time
- ATIME: File access time  
- MTIME: File modification time
- RTIME: MFT registry modification time

Look for entries showing timestamp modifications after the fact.

---

## Data Hiding Detection

### Slack Space Analysis

NTFS uses clusters; unused space within a cluster (slack space) can hide data:

**Detection methods:**
1. Use FTK Imager to extract slack space
2. Analyze `$LogFile` and `$UsnJrnl` for evidence of data addition
3. Look for files with unusual cluster allocations

**Tools:**
- FTK Imager (forensic imaging)
- Slacker (slack space analysis)
- Autopsy (open-source forensic suite)

### Alternate Data Streams (ADS)

Attackers hide payloads in ADS to evade traditional scanners:

**Detection commands:**
```powershell
# PowerShell - Enumerate all streams
Get-ChildItem -Recurse -Force | Get-Item -Stream * | Select-Object FullName, Stream, Length

# Command line
streams64.exe -s C:\path\to\directory

# Dir with stream listing
dir /R C:\path\to\directory
```

**What to look for:**
- Files with streams larger than expected
- Executable content in streams of document files
- Streams with suspicious names (e.g., `win32res.dll`)

**Recovery:**
- Copying to FAT/exFAT or via SMB strips ADS
- Use `streams64.exe -d` to delete streams (forensic cleanup)

---

## Windows Logging Tampering Detection

### UserAssist Registry Analysis

UserAssist tracks executable run times:

**Registry locations:**
```
HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\UserAssist
```

**Detection indicators:**
- `Start_TrackProgs` and `Start_TrackEnabled` set to 0 (disabled)
- Missing or cleared UserAssist subkeys
- Timestamps that don't match other artifacts

### Prefetch Analysis

Prefetch stores application execution data:

**Detection indicators:**
- `EnablePrefetcher` and `EnableSuperfetch` set to 0
- Missing `.pf` files for commonly used applications
- Prefetch files with creation times that don't match execution history

**Registry check:**
```powershell
Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\SessionManager\Memory Management\PrefetchParameters" | Select-Object EnablePrefetcher, EnableSuperfetch
```

### Last Access Time

**Detection:**
```powershell
# Check if last access time is disabled
Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" | Select-Object NtfsDisableLastAccessUpdate
```

Value of `1` means last access time updates are disabled.

### USB History Tampering

**Registry locations:**
```
HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\USBSTOR
```

**Detection indicators:**
- Missing USBSTOR entries when USB devices were used
- `setupapi.dev.log` in `C:\Windows\INF` has been deleted or modified
- USBDeview shows gaps in device history

### Shadow Copies

**Check for shadow copies:**
```powershell
vssadmin list shadowstorage
vssadmin list shadows
```

**Detection indicators:**
- Shadow copies deleted (`vssadmin delete shadows`)
- Volume Shadow Copy service disabled
- Registry key `HKLM\SYSTEM\CurrentControlSet\Control\BackupRestore\FilesNotToSnapshot` modified

### Event Log Tampering

**Detection indicators:**
- Event logs cleared (check for Event ID 1102 in Security log)
- Event log service disabled
- `wevtutil.exe cl` or `Clear-EventLog` commands in PowerShell history

**Check for log clearing:**
```powershell
# Look for log clearing events
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=1102} | Select-Object TimeCreated, Message

# Check event log service status
Get-Service -Name EventLog
```

### USN Journal Deletion

**Detection:**
```powershell
# Check if USN journal exists
fsutil usn queryjournal D:  # Replace D: with target drive
```

If the journal is missing or very small, it may have been deleted with:
```cmd
fsutil usn deletejournal /d C:
```

---

## Advanced Evasion Detection (2023-2025)

### PowerShell ScriptBlock/Module Logging

**Detection indicators:**
- Registry keys disabled:
  - `HKLM:\SOFTWARE\Microsoft\PowerShell\3\PowerShellEngine\EnableScriptBlockLogging`
  - `HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging\EnableModuleLogging`
- Event ID 4104/4105/4106 missing from `Microsoft-Windows-PowerShell/Operational`
- Bulk removal of PowerShell events

**Hunting query:**
```powershell
# Check logging status
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\PowerShell\3\PowerShellEngine" -ErrorAction SilentlyContinue | Select-Object EnableScriptBlockLogging

# Look for PowerShell log clearing
Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-PowerShell/Operational'} | Where-Object { $_.Id -eq 4104 } | Measure-Object
```

### ETW Patching Detection

Attackers patch `ntdll!EtwEventWrite` to suppress EDR events:

**Detection methods:**
1. Compare `ntdll.dll` in memory vs. on disk
2. Hook ETW calls before user-mode execution
3. Monitor for `WriteProcessMemory` to `ntdll.dll`

**Indicators:**
- Memory-resident `ntdll.dll` differs from disk version
- `0xC3` (RET) instruction at `EtwEventWrite` entry point
- Process-local patches that don't persist across restarts

### BYOVD (Bring-Your-Own-Vulnerable-Driver)

**Detection indicators:**
- Vulnerable signed drivers loaded (e.g., `procexp152.sys`)
- EDR processes terminated unexpectedly
- Kernel service creation from user-writable paths

**Hunting:**
```powershell
# List loaded drivers
Get-WindowsDriver -Online | Select-Object Name, Path, DriverVersion

# Check for vulnerable drivers
Get-Process | Select-Object ProcessName, Id | Where-Object { $_.ProcessName -like "*defender*" -or $_.ProcessName -like "*crowd*" }
```

**Mitigations:**
- Enable HVCI/SAC (Hypervisor-Protected Code Integrity)
- Microsoft vulnerable-driver blocklist
- Alert on kernel service creation from suspicious paths

---

## Linux Anti-Forensic Detection

### Self-Patching Detection

Attackers patch services to hide exploitation while maintaining access:

**Detection methods:**
```bash
# Debian/Ubuntu - Verify package integrity
dpkg -V activemq

# RHEL/CentOS - Verify package integrity
rpm -Va 'activemq*'

# Find files not owned by package manager
find /opt/activemq/lib -type f -name "*.jar" | while read f; do dpkg -S "$f" 2>/dev/null || echo "Unowned: $f"; done
```

**What to look for:**
- JAR/binary versions not matching package manager records
- Symbolic links updated out-of-band
- Files downloaded from artifact repositories (Maven Central, etc.)
- Service restarts without corresponding change management

**Timeline analysis:**
```bash
# Find recently modified files in service directories
find /opt/activemq -type f -printf '%TY-%Tm-%Td %TH:%TM %p\n' | sort

# Look for curl/wget to artifact repositories
grep -r "repo1.maven.org\|jcenter.bintray.com" /var/log/ /root/.bash_history 2>/dev/null
```

### Persistence Detection

**Cron/Anacron:**
```bash
# Check for suspicious cron entries
for d in /etc/cron.*; do [ -f "$d/0anacron" ] && stat -c '%n %y %s' "$d/0anacron"; done

# Search for suspicious commands in cron
grep -R --line-number -E 'curl|wget|python|/bin/sh' /etc/cron.*/* 2>/dev/null
```

**SSH Configuration:**
```bash
# Check for root login enablement
grep -E '^\s*PermitRootLogin' /etc/ssh/sshd_config

# Check for suspicious shells on system accounts
awk -F: '($7 ~ /bin\/(sh|bash|zsh)/ && $1 ~ /^(games|lp|sync|shutdown|halt|mail|operator)$/) {print}' /etc/passwd
```

**Random beacon artifacts:**
```bash
# Find short, random-named files
find / -maxdepth 3 -type f -regextype posix-extended -regex '.*/[A-Za-z]{8}$' -exec stat -c '%n %s %y' {} \; 2>/dev/null | sort
```

### Cloud C2 Detection

**Dropbox C2 indicators:**
- Network: `api.dropboxapi.com` / `content.dropboxapi.com` with Bearer tokens
- Hunt in proxy/NetFlow/Zeek/Suricata logs
- Outbound HTTPS to Dropbox from server workloads

**Cloudflare Tunnel indicators:**
- `cloudflared` processes or systemd units
- Config files at `~/.cloudflared/*.json`
- Outbound 443 to Cloudflare edge IPs

**PyInstaller artifacts:**
- `strings` hits: `PyInstaller`, `pyi-archive`, `PYZ-00.pyz`, `MEIPASS`
- Runtime extraction to `/tmp/_MEI*` or custom `--runtime-tmpdir` paths

---

## Investigation Best Practices

### Evidence Collection

1. **Create forensic images** before analysis
2. **Calculate hashes** (SHA-256) for all evidence
3. **Document chain of custody**
4. **Work on copies**, never original evidence

### Correlation Strategy

- Cross-reference multiple artifact sources
- Look for inconsistencies between data sources
- Build timeline from multiple independent sources
- Use USN Journal and $LogFile as ground truth for NTFS

### Documentation

- Record all commands executed during investigation
- Save tool outputs with timestamps
- Note any anomalies or suspicious findings
- Maintain clear audit trail

---

## Quick Reference Commands

### Windows
```powershell
# Event log clearing detection
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=1102}

# PowerShell logging status
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\PowerShell\3\PowerShellEngine" | Select-Object EnableScriptBlockLogging

# ADS enumeration
Get-ChildItem -Recurse -Force | Get-Item -Stream *

# Shadow copies
vssadmin list shadows
```

### Linux
```bash
# Package integrity
dpkg -V <package>  # Debian
rpm -Va <package>  # RHEL

# Recent file changes
find /path -type f -printf '%TY-%Tm-%Td %TH:%TM %p\n' | sort

# Suspicious cron
grep -r 'curl\|wget\|python' /etc/cron.* 2>/dev/null

# Random artifacts
find / -maxdepth 3 -type f -regex '.*/[A-Za-z]{8}$' 2>/dev/null
```

---

## References

- Sophos X-Ops – "AuKill: A Weaponized Vulnerable Driver for Disabling EDR" (March 2023)
- Red Canary – "Patching EtwEventWrite for Stealth: Detection & Hunting" (June 2024)
- Red Canary – "Patching for persistence: How DripDropper Linux malware moves through the cloud"
- CVE-2023-46604 – Apache ActiveMQ OpenWire RCE

**Tools:**
- UsnJrnl2Csv: https://github.com/jschicht/UsnJrnl2Csv
- LogFileParser: https://github.com/jschicht/LogFileParser
- USBDeview: https://www.nirsoft.net/utils/usb_devices_view.html
