---
name: windows-privilege-escalation
description: Systematic Windows local privilege escalation enumeration and exploitation. Use this skill whenever you need to escalate privileges on a Windows system, perform post-exploitation enumeration, assess Windows security posture, or look for privilege escalation vectors. Trigger this skill for any Windows pentesting, red teaming, or security assessment task involving privilege escalation, even if the user doesn't explicitly mention 'privilege escalation' or 'Windows'.
---

# Windows Privilege Escalation Checklist

This skill provides a systematic approach to enumerating and exploiting Windows privilege escalation vectors. Follow the sections in order, but prioritize based on what you discover.

## Quick Start

1. Run the bundled enumeration script: `./scripts/winpeas-enumerate.ps1`
2. Review the output for high-value findings
3. Follow up on specific vectors using the detailed sections below

## System Information

Gather baseline system information first:

```powershell
# System info
systeminfo
ver
whoami /all
net user
net localgroup administrators

# Check for kernel exploits
Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Name "OSVersion"
```

**Action items:**
- Search for kernel exploits using the version info found
- Use `searchsploit windows <version>` or Google the version number
- Check environment variables for credentials or paths

## Credential Discovery

### PowerShell History
```powershell
Get-Content "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt" -Tail 100
```

### Saved Credentials
```powershell
# Windows Vault
cmdkey /list

# DPAPI credentials
ls "C:\Users\*\AppData\Local\Microsoft\Credentials"

# Browser credentials (Chrome/Edge)
ls "C:\Users\*\AppData\Local\Google\Chrome\User Data\Default\Login Data"

# RDP saved connections
reg query "HKCU\Software\Microsoft\Terminal Server Client\Default"
```

### Registry Credentials
```powershell
# SSH keys
reg query "HKCU\Software\SSHAgent" /s

# AutoLogon
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

# Stored passwords
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\AutoLogon"
```

### File-based Credentials
```powershell
# Unattended install files
ls C:\Windows\System32\Sysprep\unattend.xml
ls C:\Windows\Panther\unattend.xml

# IIS web.config
ls C:\inetpub\wwwroot\web.config -Recurse

# McAfee SiteList
ls C:\ProgramData\McAfee\SiteList.xml

# GPP cached passwords
ls C:\Windows\System32\GroupPolicy\Machine\Preferences\Groups\ -Recurse
```

## Service Enumeration

### Service Permissions
```powershell
# List all services
Get-Service | Select-Object Name, DisplayName, Status

# Check service binary paths
Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\*" -Name "ImagePath" -ErrorAction SilentlyContinue

# Find unquoted paths
Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\*" -Name "ImagePath" -ErrorAction SilentlyContinue | 
  Where-Object { $_.ImagePath -notlike '"*"' }
```

### Service Exploitation
- Can you modify any service binary? Check permissions on the binary path
- Can you modify service registry keys? Check ACLs
- Are there unquoted service paths? Create a DLL/exe with the same name in an earlier path
- Can you trigger service restarts? `Restart-Service <service>`

## DLL Hijacking

```powershell
# Check PATH for writable locations
$env:PATH -split ';' | ForEach-Object { 
  if (Test-Path $_) { 
    $acl = Get-Acl $_
    if ($acl.Access | Where-Object { $_.FileSystemRights -match 'Write' }) { 
      Write-Output "Writable PATH: $_"
    }
  }
}

# Find missing DLLs for services
# Look for services that load DLLs from their directory
```

## Token Privileges

Check for dangerous privileges:

```powershell
whoami /priv

# Key privileges to look for:
# SeImpersonatePrivilege - Token impersonation
# SeAssignPrimaryPrivilege - Assign primary token
# SeTcbPrivilege - Act as part of OS
# SeBackupPrivilege - Backup files
# SeRestorePrivilege - Restore files
# SeCreateTokenPrivilege - Create tokens
# SeLoadDriverPrivilege - Load drivers
# SeTakeOwnershipPrivilege - Take ownership
# SeDebugPrivilege - Debug programs
```

## File and Folder Permissions

```powershell
# Check permissions on critical directories
Get-Acl "C:\Windows\System32" | Select-Object -ExpandProperty Access
Get-Acl "C:\Program Files" | Select-Object -ExpandProperty Access

# Find writable files in Program Files
ls "C:\Program Files" -Recurse -File | ForEach-Object {
  $acl = Get-Acl $_.FullName
  if ($acl.Access | Where-Object { $_.FileSystemRights -match 'Write' }) {
    Write-Output $_.FullName
  }
}
```

## Network Enumeration

```powershell
# Network configuration
ipconfig /all
netstat -ano
route print

# Check for local services
netstat -ano | findstr "127.0.0.1"

# Network shares
net share
net use
```

## Security Controls

### Check Security Features
```powershell
# UAC level
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -v EnableLUA

# AppLocker
Get-AppLockerPolicy -Effective

# Credential Guard
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" -v CredentialGuard

# WDigest
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" -v UseLogonCredential

# LSA Protection
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" -v RunAsPPL
```

### AV/EDR Detection
```powershell
# Check for AV processes
Get-Process | Where-Object { $_.ProcessName -match "(av|antivirus|defender|mcafee|symantec|kaspersky|bitdefender|eset|trend|sophos|crowdstrike|carbonblack|sentinelone|cylance)" -ci }

# Check AV services
Get-Service | Where-Object { $_.DisplayName -match "(av|antivirus|defender|protection|security)" -ci }
```

## Exploitation Vectors

### AlwaysInstallElevated
```powershell
# Check if enabled
reg query "HKCU\SOFTWARE\Policies\Microsoft\Windows\Installer" -v AlwaysInstallElevated
reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\Installer" -v AlwaysInstallElevated

# If enabled, create a malicious MSI and install it
msiexec /i malicious.msi
```

### WSUS Exploitation
```powershell
# Check WSUS configuration
reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"

# Look for WSUS update files
ls "C:\Windows\SoftwareDistribution\Download" -Recurse
```

### Third-party Auto-updaters
```powershell
# Check for auto-updater services
Get-Service | Where-Object { $_.DisplayName -match "(update|updater|auto)" -ci }

# Check for IPC abuse opportunities
Get-Process | Select-Object ProcessName, Id
```

## Memory and Process Analysis

```powershell
# Memory password mining
# Use tools like Mimikatz, LaZagne, or ProcDump

# Dump browser credentials
.

# Check for insecure GUI apps
Get-Process | Where-Object { $_.MainWindowTitle -notlike "*" }
```

## Next Steps

1. **Prioritize findings** - Focus on vectors that require minimal interaction
2. **Test exploitation** - Try the most promising vectors first
3. **Document everything** - Keep track of what works and what doesn't
4. **Use WinPEAS** - Run the full WinPEAS tool for comprehensive enumeration

## Tools to Use

- **WinPEAS** - Primary enumeration tool (https://github.com/carlospolop/privilege-escalation-awesome-scripts-suite/tree/master/winPEAS)
- **Mimikatz** - Credential dumping
- **PowerSploit** - PowerShell post-exploitation
- **LaZagne** - Password recovery
- **ProcDump** - Process dumping

## Important Notes

- Always check for AV/EDR before running tools
- Some vectors require specific conditions (e.g., AlwaysInstallElevated)
- Document all findings for reporting
- Consider the impact of exploitation on the target system
- Follow responsible disclosure practices
