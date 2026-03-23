---
name: volatility-memory-forensics
description: Analyze memory dumps using Volatility2 or Volatility3 for forensic investigation. Use this skill whenever the user mentions memory dumps, RAM analysis, forensic investigation, process analysis, malware detection in memory, credential extraction from memory, or any memory forensics task. This skill covers Windows, Linux, and macOS memory analysis with comprehensive plugin guidance.
---

# Volatility Memory Forensics Skill

A comprehensive guide for analyzing memory dumps using Volatility2 and Volatility3 for forensic investigations.

## Quick Start

### Installation

**Volatility3 (recommended for new work):**
```bash
git clone https://github.com/volatilityfoundation/volatility3.git
cd volatility3
python3 setup.py install
python3 vol.py --help
```

**Volatility2 (legacy, still useful for some plugins):**
```bash
git clone https://github.com/volatilityfoundation/volatility.git
cd volatility
python setup.py install
```

### Automated Scanning Tools

For parallel plugin execution, consider these tools:

**autoVolatility3:**
```bash
# Full scan (all plugins)
python3 autovol3.py -f MEMFILE -o OUT_DIR -s full

# Normal scan (balanced)
python3 autovol3.py -f MEMFILE -o OUT_DIR -s normal

# Minimal scan (limited plugins)
python3 autovol3.py -f MEMFILE -o OUT_DIR -s minimal
```

**autoVolatility (fast, parallel):**
```bash
python autoVolatility.py -f MEMFILE -d OUT_DIRECTORY -e /path/to/vol.py
```

## Profile Identification

### Step 1: Identify the OS Profile

**Volatility3:**
```bash
./vol.py -f file.dmp windows.info.Info
./vol.py -f file.dmp linux.info.Info
```

**Volatility2:**
```bash
volatility imageinfo -f file.dmp
volatility kdbgscan -f file.dmp
```

**Important:** Always check `kdbgscan` output for process count. Valid profiles show processes:
- **GOOD:** `PsActiveProcessHead: 0x... (37 processes)`
- **BAD:** `PsActiveProcessHead: 0x... (0 processes)`

### Step 2: Download Symbol Tables (Volatility3)

Place symbol tables in `volatility3/volatility/symbols/`:
- Windows: https://downloads.volatilityfoundation.org/volatility3/symbols/windows.zip
- Linux: https://downloads.volatilityfoundation.org/volatility3/symbols/linux.zip
- macOS: https://downloads.volatilityfoundation.org/volatility3/symbols/mac.zip

### Step 3: External Profiles (Volatility2)

```bash
# List available profiles
./volatility_2.6_lin64_standalone --info | grep "Profile"

# Use custom profile
./vol -f file.dmp --plugins=/path/to/plugins --profile=ProfileName plugin_name
```

## Core Analysis Workflow

### 1. Process Analysis

**List processes (compare pslist vs psscan to find hidden processes):**

**Volatility3:**
```bash
# Process tree (visible processes)
python3 vol.py -f file.dmp windows.pstree.PsTree

# Process list from EPROCESS structures
python3 vol.py -f file.dmp windows.pslist.PsList

# Scan for hidden processes (malware detection)
python3 vol.py -f file.dmp windows.psscan.PsScan
```

**Volatility2:**
```bash
volatility --profile=PROFILE pstree -f file.dmp
volatility --profile=PROFILE pslist -f file.dmp
volatility --profile=PROFILE psscan -f file.dmp
volatility --profile=PROFILE psxview -f file.dmp
```

**What to look for:**
- Suspicious process names
- Unexpected parent-child relationships (e.g., cmd.exe spawned by iexplorer.exe)
- Processes in psscan but not in pslist (hidden processes)

### 2. Credential Extraction

**Extract hashes and secrets:**

**Volatility3:**
```bash
# SAM + SYSTEM hashes
./vol.py -f file.dmp windows.hashdump.Hashdump

# Domain cached credentials
./vol.py -f file.dmp windows.cachedump.Cachedump

# LSA secrets
./vol.py -f file.dmp windows.lsadump.Lsadump
```

**Volatility2:**
```bash
volatility --profile=PROFILE hashdump -f file.dmp
volatility --profile=PROFILE cachedump -f file.dmp
volatility --profile=PROFILE lsadump -f file.dmp
```

### 3. Command Line History

**Recover executed commands:**

**Volatility3:**
```bash
python3 vol.py -f file.dmp windows.cmdline.CmdLine
```

**Volatility2:**
```bash
volatility --profile=PROFILE cmdline -f file.dmp
volatility --profile=PROFILE consoles -f file.dmp
```

**Note:** If cmd.exe was terminated, check conhost.exe memory for command history.

### 4. Network Analysis

**Volatility3:**
```bash
./vol.py -f file.dmp windows.netscan.NetScan
```

**Volatility2:**
```bash
# Windows
volatility --profile=PROFILE netscan -f file.dmp
volatility --profile=PROFILE connscan -f file.dmp
volatility --profile=PROFILE sockets -f file.dmp

# Linux
volatility --profile=PROFILE linux_netstat -f file.dmp
volatility --profile=PROFILE linux_ifconfig -f file.dmp
volatility --profile=PROFILE linux_arp -f file.dmp
```

### 5. Malware Detection

**Volatility3:**
```bash
# Find hidden/injected code (dump suspicious sections)
./vol.py -f file.dmp windows.malfind.Malfind --dump

# Driver IRP hook detection
./vol.py -f file.dmp windows.driverirp.DriverIrp

# SSDT hook detection
./vol.py -f file.dmp windows.ssdt.SSDT

# Linux-specific checks
./vol.py -f file.dmp linux.check_syscall.Check_syscall
./vol.py -f file.dmp linux.check_idt.Check_idt
./vol.py -f file.dmp linux.check_modules.Check_modules
```

**Volatility2:**
```bash
volatility --profile=PROFILE malfind -f file.dmp [-D /tmp]
volatility --profile=PROFILE apihooks -f file.dmp
volatility --profile=PROFILE ssdt -f file.dmp
volatility --profile=PROFILE driverirp -f file.dmp
```

### 6. YARA Scanning

**Download malware rules:**
```bash
wget https://gist.githubusercontent.com/andreafortuna/29c6ea48adf3d45a979a78763cdc7ce9/raw/malware_yara_rules.py
mkdir rules
python malware_yara_rules.py
```

**Scan memory:**

**Volatility3:**
```bash
# Windows-specific
./vol.py -f file.dmp windows.vadyarascan.VadYaraScan --yara-file /tmp/malware_rules.yar

# All processes
./vol.py -f file.dmp yarascan.YaraScan --yara-file /tmp/malware_rules.yar
```

**Volatility2:**
```bash
volatility --profile=PROFILE yarascan -y malware_rules.yar -f file.dmp
```

## Advanced Analysis

### Process Details

**Environment variables:**
```bash
# Volatility3
python3 vol.py -f file.dmp windows.envars.Envars [--pid <pid>]

# Volatility2
volatility --profile=PROFILE envars -f file.dmp [--pid <pid>]
```

**Privileges:**
```bash
# Volatility3
python3 vol.py -f file.dmp windows.privileges.Privs [--pid <pid>]

# Check for dangerous privileges
python3 vol.py -f file.dmp windows.privileges.Privs | grep "SeImpersonatePrivilege\|SeDebugPrivilege\|SeBackupPrivilege"
```

**Handles:**
```bash
# Volatility3
vol.py -f file.dmp windows.handles.Handles [--pid <pid>]

# Volatility2
volatility --profile=PROFILE handles -f file.dmp [--pid=<pid>]
```

**DLLs:**
```bash
# Volatility3
./vol.py -f file.dmp windows.dlllist.DllList [--pid <pid>]

# Volatility2
volatility --profile=PROFILE dlllist --pid=PID -f file.dmp
```

### File System Analysis

**Volatility3:**
```bash
# Scan for files
./vol.py -f file.dmp windows.filescan.FileScan

# Dump specific file
./vol.py -f file.dmp windows.dumpfiles.DumpFiles --physaddr <OFFSET>
```

**Volatility2:**
```bash
volatility --profile=PROFILE filescan -f file.dmp
volatility --profile=PROFILE dumpfiles -n --dump-dir=/tmp -f file.dmp
```

### Registry Analysis

**Volatility3:**
```bash
# List hives
./vol.py -f file.dmp windows.registry.hivelist.HiveList

# Print key
./vol.py -f file.dmp windows.registry.printkey.PrintKey --key "Software\Microsoft\Windows NT\CurrentVersion"

# UserAssist (program execution history)
./vol.py -f file.dmp windows.registry.userassist.UserAssist
```

**Volatility2:**
```bash
volatility --profile=PROFILE hivelist -f file.dmp
volatility --profile=PROFILE printkey -K "Key\Path" -f file.dmp
volatility --profile=PROFILE userassist -f file.dmp
```

### Dump Artifacts

**Process dump:**
```bash
# Volatility3
./vol.py -f file.dmp windows.dumpfiles.DumpFiles --pid <pid>

# Volatility2
volatility --profile=PROFILE procdump --pid=PID -n --dump-dir=. -f file.dmp
```

**Registry hives:**
```bash
volatility --profile=PROFILE hivedump -f file.dmp
```

## Linux-Specific Plugins

**Volatility3:**
```bash
./vol.py -f file.dmp linux.bash.Bash
./vol.py -f file.dmp linux.pslist.PsList
./vol.py -f file.dmp linux.psscan.PsScan
./vol.py -f file.dmp linux.lsof.Lsof
./vol.py -f file.dmp linux.envars.Envars
```

**Volatility2:**
```bash
volatility --profile=PROFILE linux_pslist -f file.dmp
volatility --profile=PROFILE linux_psscan -f file.dmp
volatility --profile=PROFILE linux_bash -f file.dmp
volatility --profile=PROFILE linux_lsof -f file.dmp
```

## External Plugins

**Volatility3:**
```bash
./vol.py --plugin-dirs "/path/to/plugins/" [plugin_options]
```

**Volatility2:**
```bash
volatility --plugins="/path/to/plugins/" [plugin_options]
```

**Popular external plugins:**
- Autoruns: https://github.com/tomchop/volatility-autoruns

## Common Investigation Patterns

### Pattern 1: Initial Triage
1. Run `imageinfo`/`kdbgscan` to identify profile
2. Run `pslist` and `psscan` to compare process lists
3. Run `netscan` to check network connections
4. Run `malfind` to detect injected code

### Pattern 2: Credential Theft Investigation
1. Run `hashdump`, `cachedump`, `lsadump`
2. Check `cmdline` for credential dumping tools
3. Check `dlllist` for suspicious DLLs
4. Run `malfind` to find injected credential stealers

### Pattern 3: Persistence Investigation
1. Run `userassist` for program execution history
2. Check registry `Run` keys
3. Run `svcscan` for services
4. Check `mutantscan` for mutexes

### Pattern 4: Malware Analysis
1. Run `malfind --dump` to extract suspicious code
2. Run `yarascan` with malware rules
3. Check `ssdt` and `driverirp` for hooks
4. Run `apihooks` for API hooking detection

## Tips and Best Practices

1. **Always compare pslist vs psscan** - Hidden processes appear in psscan but not pslist
2. **Check kdbgscan process count** - Valid profiles show actual process counts
3. **Dump before analysis** - Work on copies of memory dumps
4. **Use both Volatility2 and Volatility3** - Some plugins only exist in one version
5. **Document findings** - Save plugin outputs for reporting
6. **Check timestamps** - Use `timeliner` to correlate events
7. **Look for anomalies** - Unexpected parent-child relationships, unusual privileges, hidden processes

## Reference

- Volatility3: https://github.com/volatilityfoundation/volatility3
- Volatility2: https://github.com/volatilityfoundation/volatility
- Command Reference: https://github.com/volatilityfoundation/volatility/wiki/Command-Reference
- Symbol Tables: https://downloads.volatilityfoundation.org/volatility3/symbols/
