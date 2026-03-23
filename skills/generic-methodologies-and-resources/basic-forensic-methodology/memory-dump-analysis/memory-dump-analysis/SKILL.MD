---
name: memory-dump-analysis
description: Analyze memory dumps for forensic investigations and malware detection. Use this skill whenever the user mentions memory dumps, RAM analysis, forensic investigation, crash dumps, Volatility, or needs to extract processes, passwords, or malware indicators from memory. This includes full memory dumps, mini dump crash reports, and any scenario where you need to investigate what was running on a system.
---

# Memory Dump Analysis

A skill for performing forensic analysis on memory dumps to identify malware, extract artifacts, and understand system state.

## Overview

Memory dump analysis is a critical forensic technique for:
- Detecting malware that may not be visible on disk
- Extracting credentials and sensitive data
- Understanding what processes were running
- Investigating system compromises
- Analyzing crash reports

## Workflow

### Step 1: Identify the Dump Type

First, determine what kind of dump you're working with:

**Full Memory Dump** (typically hundreds of MB to several GB):
- Complete RAM capture
- Use Volatility for comprehensive analysis

**Mini Dump Crash Report** (KB to few MB):
- Contains limited crash information
- Can be opened in Visual Studio for basic info
- Use IDA or Radare2 for deeper inspection

### Step 2: Volatility Analysis

Volatility is the primary tool for memory dump analysis. Follow this systematic approach:

#### 2.1 Identify the Profile

```bash
volatility -f <dump_file> imageinfo
```

This identifies the OS profile needed for subsequent commands. Look for:
- Suggested Profile (e.g., Win10x64, Win7SP1x64)
- Profile count (higher is more confident)
- Architecture (32-bit vs 64-bit)

#### 2.2 Enumerate Processes

```bash
volatility -f <dump_file> --profile=<profile> pslist
volatility -f <dump_file> --profile=<profile> psscan
```

**pslist** shows active processes from the EPROCESS list.
**psscan** scans for process structures - useful for detecting hidden processes.

Compare both outputs to find discrepancies (potential rootkits).

#### 2.3 Find Network Connections

```bash
volatility -f <dump_file> --profile=<profile> netscan
volatility -f <dump_file> --profile=<profile> connscan
```

Look for:
- Unexpected connections
- Connections to suspicious IPs
- Processes with unusual network activity

#### 2.4 Extract DLLs and Modules

```bash
volatility -f <dump_file> --profile=<profile> dlldump -p <pid>
volatility -f <dump_file> --profile=<profile> modules
```

Extract DLLs from suspicious processes for further analysis.

#### 2.5 Search for Passwords and Credentials

```bash
volatility -f <dump_file> --profile=<profile> hashdump
volatility -f <dump_file> --profile=<profile> lsa_secrets
volatility -f <dump_file> --profile=<profile> samdump
```

These extract:
- NTLM hashes
- LSA secrets
- SAM database entries

#### 2.6 Find Malware Indicators

```bash
volatility -f <dump_file> --profile=<profile> malfind
volatility -f <dump_file> --profile=<profile> apihooks
volatility -f <dump_file> --profile=<profile> cmdline
```

**malfind** detects injected code and hidden threads.
**apihooks** finds API hooking (common in rootkits).
**cmdline** shows command line arguments for processes.

#### 2.7 Extract Files and Strings

```bash
volatility -f <dump_file> --profile=<profile> filescan
volatility -f <dump_file> --profile=<profile> strings -p <pid>
```

Search for:
- IP addresses
- URLs
- File paths
- Suspicious strings

### Step 3: Mini Dump Analysis

For mini dump crash reports:

#### 3.1 Visual Studio (Quick Analysis)

If Visual Studio is available:
1. Open the mini dump file
2. View basic information:
   - Process name
   - Architecture
   - Exception information
   - Loaded modules
3. Examine the exception and decompiled instructions

#### 3.2 IDA Pro or Radare2 (Deep Analysis)

For thorough investigation:
- Load the dump in IDA or Radare2
- Analyze the exception context
- Examine memory regions
- Look for malicious code patterns

### Step 4: Cross-Reference with Malware Analysis

Use malware analysis techniques to:
- Analyze extracted binaries
- Check hashes against threat intelligence
- Examine network artifacts
- Correlate with other forensic evidence

## Common Artifacts to Look For

| Artifact | Command | Purpose |
|----------|---------|----------|
| Process list | pslist, psscan | Identify running processes |
| Network connections | netscan, connscan | Find suspicious connections |
| DLLs | dlldump | Extract loaded modules |
| Credentials | hashdump, lsa_secrets | Extract passwords |
| Injected code | malfind | Detect code injection |
| API hooks | apihooks | Find rootkit activity |
| Command lines | cmdline | See process arguments |
| File handles | filescan | Find open files |

## Best Practices

1. **Always start with imageinfo** - Getting the wrong profile leads to incorrect results
2. **Compare pslist and psscan** - Discrepancies indicate hidden processes
3. **Document everything** - Save command outputs for reporting
4. **Use multiple plugins** - Different tools reveal different artifacts
5. **Correlate findings** - Cross-reference network, process, and file data
6. **Preserve the original** - Work on copies, never modify the original dump

## Output Format

When presenting findings, structure them as:

```
## Memory Dump Analysis Results

### Dump Information
- File: <filename>
- Size: <size>
- Profile: <detected_profile>
- Architecture: <32/64-bit>

### Processes Found
- Total processes: <count>
- Suspicious processes: <list>
- Hidden processes: <list>

### Network Activity
- Active connections: <count>
- Suspicious connections: <list>

### Credentials Extracted
- Hashes found: <count>
- Passwords found: <count>

### Malware Indicators
- Injected code: <yes/no>
- API hooks: <yes/no>
- Suspicious modules: <list>

### Recommendations
<actionable next steps>
```

## When to Use This Skill

Use this skill when:
- You have a memory dump file (.dmp, .raw, .mem)
- You need to investigate a compromised system
- You're analyzing a crash report
- You need to extract credentials from memory
- You're looking for malware that may be hidden
- You're performing incident response
- You need to understand what was running on a system

## Limitations

- Requires the correct OS profile for accurate analysis
- Some anti-forensic techniques may hide artifacts
- Mini dumps contain limited information
- Some plugins require specific dump types
- Analysis can be time-consuming for large dumps
