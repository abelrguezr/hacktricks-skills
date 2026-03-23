---
name: windows-forensics
description: Perform Windows forensic analysis by extracting and analyzing artifacts from Windows systems. Use this skill whenever the user needs to investigate Windows systems, analyze user activity, track file access, examine registry data, parse event logs, or conduct digital forensics on Windows machines. This includes tasks like finding deleted files, tracking USB devices, analyzing email artifacts, examining program execution history, or investigating security events.
---

# Windows Forensics Analysis

A comprehensive guide for conducting forensic analysis on Windows systems. This skill helps you systematically extract and analyze artifacts to understand user activity, system changes, and potential security incidents.

## Quick Reference: Artifact Locations

| Artifact Type | Primary Location | Key Tools |
|--------------|------------------|----------|
| Notifications | `\Users\<user>\AppData\Local\Microsoft\Windows\Notifications\wpndatabase.db` | SQLite tools |
| Timeline | `\Users\<user>\AppData\Local\ConnectedDevicesPlatform\<id>\ActivitiesCache.db` | WxTCmd, TimeLine Explorer |
| Recycle Bin | `C:\$Recycle.bin` | Rifiuti |
| Shadow Copies | `\System Volume Information` | ShadowCopyView |
| LNK Files | `\Users\<user>\AppData\Roaming\Microsoft\Windows\Recent\` | LinkParser, LECmd |
| Jumplists | `\Users\<user>\AppData\Roaming\Microsoft\Windows\Recent\AutomaticDestinations\` | JumplistExplorer |
| Prefetch | `C:\Windows\Prefetch\` | PECmd |
| Amcache | `C:\Windows\AppCompat\Programs\Amcache.hve` | AmcacheParser |
| Event Logs | `C:\Windows\System32\winevt\Logs\` | EvtxECmd, Event Viewer |
| Registry | `%windir%\System32\Config\` | Registry Explorer, RegRipper |

## Investigation Workflow

### 1. Initial Assessment

Before diving into artifacts, understand the scope:

- **What are you investigating?** (data exfiltration, malware, unauthorized access, etc.)
- **What time period?** (helps prioritize artifacts)
- **What users?** (focus on specific user profiles)
- **What evidence is needed?** (timeline, file access, network activity)

### 2. Artifact Collection Priority

Collect artifacts in this order for most investigations:

1. **Event Logs** - Most volatile, overwritten first
2. **Prefetch/Amcache** - Program execution evidence
3. **LNK Files/Jumplists** - File access history
4. **Registry** - System configuration and user activity
5. **Email/Communication** - User communications
6. **Browser/Network** - Internet activity
7. **Shadow Copies** - File recovery

### 3. Timeline Analysis

Build a chronological view of events:

- Extract timestamps from multiple artifact sources
- Normalize to UTC for comparison
- Look for gaps or anomalies
- Correlate events across different artifact types

## Artifact Analysis Guide

### Windows Notifications

**Location:** `\Users\<username>\AppData\Local\Microsoft\Windows\Notifications\`

**Files:**
- `appdb.dat` (pre-Windows Anniversary)
- `wpndatabase.db` (post-Windows Anniversary)

**What to look for:**
- Notification table contains XML-formatted notifications
- May contain sensitive data, URLs, or application activity
- Timestamps of when notifications were received

**Analysis:**
```bash
# Open with SQLite
sqlite3 wpndatabase.db "SELECT * FROM Notification;"
```

### Timeline (ActivitiesCache.db)

**Location:** `\Users\<username>\AppData\Local\ConnectedDevicesPlatform\<id>\ActivitiesCache.db`

**What it contains:**
- Chronological history of web pages visited
- Edited documents
- Executed applications

**Tools:**
- **WxTCmd** - Generates files for TimeLine Explorer
- **TimeLine Explorer** - Visual timeline analysis

**Analysis:**
```bash
# Use WxTCmd to extract timeline data
WxTCmd.exe -i ActivitiesCache.db -o timeline_output/
```

### Alternate Data Streams (ADS)

**What to look for:**
- `Zone.Identifier` stream indicates download source (intranet, internet, etc.)
- Browsers may store download URLs in ADS

**Analysis:**
```bash
# Check for ADS on a file
streams -s filename.exe

# View ADS content
more < filename.exe:Zone.Identifier
```

### Recycle Bin

**Location:** `C:\$Recycle.bin\`

**Structure:**
- `$I{id}` - File information (deletion date)
- `$R{id}` - File content

**Tools:**
- **Rifiuti** - Extracts original path and deletion date

**Analysis:**
```bash
# Use Rifiuti for Vista-Win10
rifiuti-vista.exe C:\$Recycle.bin\
```

### Volume Shadow Copies

**Location:** `\System Volume Information\`

**What it contains:**
- Backup copies/snapshots of files and volumes
- Can include files that were later deleted

**Tools:**
- **ShadowCopyView** - Inspect and extract from shadow copies
- **ArsenalImageMounter** - Mount forensic images

**Registry:**
- `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\BackupRestore` - Files excluded from backup
- `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\VSS` - Shadow copy configuration

### LNK Files (Recent Documents)

**Locations:**
- Win7-Win10: `C:\Users\<user>\AppData\Roaming\Microsoft\Windows\Recent\`
- Office: `C:\Users\<user>\AppData\Roaming\Microsoft\Office\Recent\`

**What they contain:**
- File or folder type
- MAC times (Modified, Accessed, Created)
- Volume information
- Target folder path
- **Link Created** = First time original file was used
- **Link Modified** = Last time original file was used

**Tools:**
- **LinkParser** - GUI analysis
- **LECmd** - Command-line parsing

**Analysis:**
```bash
# Parse LNK files to CSV
LECmd.exe -d C:\Path\To\LNKs --csv C:\Path\To\Output\
```

**Timestamps:**
- **File timestamps:** Modified, Accessed, Creation (of the target file)
- **Link timestamps:** Modified, Accessed, Creation (of the LNK file itself)

### Jumplists

**Locations:**
- Automatic: `C:\Users\<user>\AppData\Roaming\Microsoft\Windows\Recent\AutomaticDestinations\`
- Custom: `C:\Users\<user>\AppData\Roaming\Microsoft\Windows\Recent\CustomDestinations\`

**Format:** `{id}.automaticDestinations-ms` (ID = application ID)

**What they contain:**
- Recent files per application
- **Created time** = First access
- **Modified time** = Last access
- Custom jumplists indicate important/favorited files

**Tools:**
- **JumplistExplorer** - Parse and analyze jumplists

### USB Device Tracking

**Artifacts to check:**
1. Windows Recent Folder
2. Microsoft Office Recent Folder
3. Jumplists
4. Registry keys (see Registry section)
5. `C:\Windows\inf\setupapi.dev.log` - Search for "Section start"
6. WPDNSE folder (temporary USB file copies)

**Tools:**
- **USBDetective** - Comprehensive USB device analysis

**Plug and Play Cleanup:**
- Location: `C:\Windows\System32\Tasks\Microsoft\Windows\Plug and Play\Plug and Play Cleanup`
- Removes drivers inactive for 30 days
- May delete USB device driver evidence

### Email Artifacts

#### Windows Mail App

**Locations:**
- Emails: `\Users\<user>\AppData\Local\Comms\Unistore\data\3\` (.dat files)
- Metadata/Contacts: `\Users\<user>\AppData\Local\Comms\UnistoreDB\store.vol`

**Analysis:**
- Rename `.vol` to `.edb`
- Use **ESEDatabaseView** to open
- Check `Message` table for emails

#### Microsoft Outlook

**Locations:**
- PST files: `%USERPROFILE%\AppData\Local\Microsoft\Outlook\`
- Registry: `HKEY_CURRENT_USER\Software\Microsoft\WindowsNT\CurrentVersion\Windows Messaging Subsystem\Profiles\Outlook`

**MAPI Headers:**
- `Mapi-Client-Submit-Time` - Send time
- `Mapi-Conversation-Index` - Thread information
- `Mapi-Entry-ID` - Message identifier
- `Mappi-Message-Flags` - Read/unread, responded, etc.

**Tools:**
- **Kernel PST Viewer** - Open PST files
- **Kernel OST Viewer** - Open OST files (IMAP/Exchange)

#### Thunderbird

**Location:** `\Users\%USERNAME%\AppData\Roaming\Thunderbird\Profiles\`

**Format:** MBOX files

#### Email Attachments

**Recovery locations:**
- IE10: `%APPDATA%\Local\Microsoft\Windows\Temporary Internet Files\Content.Outlook`
- IE11+: `%APPDATA%\Local\Microsoft\InetCache\Content.Outlook`

### Thumbnail Cache

**Locations by OS:**
- **XP/8-8.1:** `thumbs.db` in folders
- **7/10 (network):** `thumbs.db` via UNC paths
- **Vista+:** `%userprofile%\AppData\Local\Microsoft\Windows\Explorer\thumbcache_xxx.db`

**Tools:**
- **Thumbsviewer** - View thumbnail cache
- **ThumbCache Viewer** - Extract thumbnails

### Registry Analysis

**Hive Locations:**
- `HKEY_LOCAL_MACHINE`: `%windir%\System32\Config\`
- `HKEY_CURRENT_USER`: `%UserProfile%\NTUSER.DAT`
- **Backups:** `%Windir%\System32\Config\RegBack\` (Vista+)
- **User Class:** `%UserProfile%\AppData\Local\Microsoft\Windows\USERCLASS.DAT`

**Tools:**
- **Registry Editor** - Built-in GUI
- **Registry Explorer** - Load hives, bookmarks for interesting keys
- **RegRipper** - Plugins for automated analysis
- **Windows Registry Recovery** - Extract deleted keys

**Key Artifacts:**
- **SAM** - User accounts, password hashes (requires SYSTEM hive)
- **Last Write Time** - When each key-value was modified
- **Deleted Keys** - Can be recovered until space is reused

### Program Execution Artifacts

#### Prefetch

**Location:** `C:\Windows\Prefetch\`

**Format:** `{program_name}-{hash}.pf`

**What it contains:**
- Program execution evidence (file presence = execution)
- Execution count
- Execution dates
- Files opened by program
- **Layout.ini** - Index of all prefetch files

**Limits:**
- XP/Vista/Win7: 128 files
- Win8/Win10: 1024 files

**Tools:**
- **PECmd** - Parse prefetch files

**Analysis:**
```bash
PECmd.exe -d C:\Path\To\Prefetch --html "C:\Path\To\Output"
```

#### Superprefetch

**Location:** `C:\Windows\Prefetch\Ag*.db`

**What it contains:**
- Program name
- Execution count
- Files opened
- Volume accessed
- Complete path
- Timeframes and timestamps

**Tools:**
- **CrowdResponse** - Parse superprefetch databases

#### SRUM (System Resource Usage Monitor)

**Location:** `C:\Windows\System32\sru\SRUDB.dat`

**What it contains:**
- AppID and Path
- User who executed
- Sent/Received bytes
- Network interface
- Connection duration
- Process duration
- Updated every 60 minutes

**Tools:**
- **srum_dump** - Extract SRUM data

**Analysis:**
```bash
srum_dump.exe -i SRUDB.dat -t SRUM_TEMPLATE.xlsx -o output_folder
```

#### AppCompatCache (ShimCache)

**Registry Locations:**
- XP: `SYSTEM\CurrentControlSet\Control\SessionManager\Appcompatibility\AppcompatCache` (96 entries)
- Win7/8/10: `SYSTEM\CurrentControlSet\Control\SessionManager\AppcompatCache\AppCompatCache` (512-1024 entries)

**What it contains:**
- Full file path
- File size
- Last Modified time
- Last Updated time
- Process Execution Flag

**Tools:**
- **AppCompatCacheParser** - Parse ShimCache

#### Amcache

**Location:** `C:\Windows\AppCompat\Programs\Amcache.hve`

**What it contains:**
- Recently executed processes
- Executable paths
- SHA1 hashes

**Tools:**
- **AmcacheParser** - Parse Amcache.hve

**Analysis:**
```bash
AmcacheParser.exe -f Amcache.hve --csv output_folder
```

**Key Output:** `Amcache_Unassociated file entries` CSV

#### RecentFileCache

**Location:** `C:\Windows\AppCompat\Programs\RecentFileCache.bcf` (Win7 only)

**Tools:**
- **RecentFileCacheParser** - Parse cache file

#### BAM (Background Activity Moderator)

**Location:** `SYSTEM\CurrentControlSet\Services\bam\UserSettings\{SID}`

**What it contains:**
- Applications executed by each user
- Execution timestamps

#### Windows Recent Apps

**Location:** `NTUSER.DAT\Software\Microsoft\Current Version\Search\RecentApps`

**What it contains:**
- Application executed
- Last execution time
- Launch count

### Scheduled Tasks and Services

**Scheduled Tasks:**
- Location: `C:\Windows\Tasks` or `C:\Windows\System32\Tasks`
- Format: XML files
- Can be read directly

**Services:**
- Location: `SYSTEM\ControlSet001\Services`
- Shows what will be executed and when

### Windows Store Applications

**Locations:**
- Installed: `\ProgramData\Microsoft\Windows\AppRepository\StateRepository-Machine.srd`
- Registry Installed: `Software\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Applications\`
- Registry Uninstalled: `Software\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deleted\`

**What to look for:**
- Application ID, PackageNumber, Display Name
- Sequential IDs can reveal uninstalled applications

## Windows Event Logs

### Event Log Locations

- **Pre-Vista:** `C:\Windows\System32\config\` (binary format)
- **Vista+:** `C:\Windows\System32\winevt\Logs\` (XML format, .evtx extension)

**Registry:** `HKLM\SYSTEM\CurrentControlSet\services\EventLog\{Application|System|Security}`

**Tools:**
- **Event Viewer** (`eventvwr.msc`) - Built-in
- **Event Log Explorer** - GUI analysis
- **Evtx Explorer/EvtxECmd** - Command-line parsing

### Security Event IDs

**Location:** `C:\Windows\System32\winevt\Security.evtx`

#### Authentication Events

| Event ID | Description |
|----------|-------------|
| 4624 | Successful logon |
| 4625 | Failed logon |
| 4634/4647 | Logoff |
| 4672 | Administrative privileges |

#### Logon Types (Event 4624/4625)

| Type | Description |
|------|-------------|
| 2 | Interactive (direct login) |
| 3 | Network (shared folders) |
| 4 | Batch (scheduled tasks) |
| 5 | Service |
| 6 | Proxy |
| 7 | Unlock |
| 8 | Network Cleartext (IIS) |
| 9 | New Credentials |
| 10 | Remote Interactive (RDP) |
| 11 | Cache Interactive |
| 12 | Cache Remote Interactive |
| 13 | Cached Unlock |

#### Failed Logon Status Codes (Event 4625)

| Code | Meaning | Investigation |
|------|---------|---------------|
| 0xC0000064 | User doesn't exist | Username enumeration |
| 0xC000006A | Wrong password | Brute force attempt |
| 0xC0000234 | Account locked | After brute force |
| 0xC0000072 | Account disabled | Unauthorized access attempt |
| 0xC000006F | Outside allowed time | Policy violation |
| 0xC0000070 | Workstation restriction | Unauthorized location |
| 0xC0000193 | Account expired | Expired account access |
| 0xC0000071 | Password expired | Outdated password |
| 0xC0000133 | Time sync issue | Pass-the-ticket attack |
| 0xC000015b | Denied logon type | Unauthorized logon type |

#### Critical Events

| Event ID | Description | Significance |
|----------|-------------|--------------|
| 4616 | Time change | Timeline manipulation |
| 6005 | System startup | System timeline |
| 6006 | System shutdown | System timeline |
| 1102 | Log cleared | Evidence destruction |

#### USB Device Events

| Event ID | Description |
|----------|-------------|
| 20001/20003/10000 | USB first connection |
| 10100 | USB driver update |
| 112 | USB insertion time |

### Event Log Recovery

**Best practice:** Power down by unplugging (don't shutdown)

**Tools:**
- **Bulk_extractor** - Recover deleted .evtx files

### Attack Indicators

**Brute Force:**
- Multiple Event 4625 followed by Event 4624

**Time Manipulation:**
- Event 4616 (time change)

**Evidence Destruction:**
- Event 1102 (log cleared)

## Common Investigation Scenarios

### Data Exfiltration

1. Check Prefetch/Amcache for data transfer tools
2. Review SRUM for network activity
3. Examine email artifacts for attachments
4. Check USB device tracking
5. Review event logs for data access

### Malware Investigation

1. Analyze Prefetch for unknown executables
2. Check AppCompatCache for executed files
3. Review scheduled tasks for persistence
4. Examine registry run keys
5. Check BAM for execution history

### Unauthorized Access

1. Review Security.evtx for failed logons (4625)
2. Check successful logons (4624) for unusual types
3. Examine LNK files for accessed resources
4. Review jumplists for accessed files
5. Check USB device events

### User Activity Timeline

1. Extract ActivitiesCache.db timeline
2. Parse LNK file timestamps
3. Review jumplist timestamps
4. Correlate with event log timestamps
5. Build chronological view

## Best Practices

### Evidence Preservation

1. **Create forensic images** before analysis
2. **Work on copies** never originals
3. **Document everything** - tools used, commands run, findings
4. **Maintain chain of custody**
5. **Hash all evidence** before and after analysis

### Analysis Order

1. **Volatile first** - Event logs, RAM
2. **System artifacts** - Registry, prefetch
3. **User artifacts** - LNK, jumplists, browser
4. **File system** - Shadow copies, deleted files

### Correlation

1. **Cross-reference timestamps** across artifacts
2. **Look for patterns** in execution history
3. **Correlate user activity** with system events
4. **Build timelines** from multiple sources

## Tool Summary

| Tool | Purpose | Input |
|------|---------|-------|
| PECmd | Prefetch analysis | .pf files |
| LECmd | LNK file parsing | .lnk files |
| AmcacheParser | Amcache analysis | Amcache.hve |
| srum_dump | SRUM extraction | SRUDB.dat |
| WxTCmd | Timeline extraction | ActivitiesCache.db |
| Rifiuti | Recycle bin analysis | $Recycle.bin |
| ShadowCopyView | Shadow copy inspection | Volume shadow copies |
| EvtxECmd | Event log parsing | .evtx files |
| RegRipper | Registry analysis | Registry hives |
| Bulk_extractor | File carving | Disk images |

## Next Steps

After initial analysis:

1. **Document findings** with timestamps and evidence
2. **Create timeline** of key events
3. **Identify gaps** in evidence
4. **Correlate findings** across artifact types
5. **Prepare report** with supporting evidence

For deeper analysis, consider:
- Memory forensics (if RAM captured)
- Network forensics (if packet captures available)
- Malware analysis (if suspicious executables found)
- Advanced timeline analysis with multiple data sources
