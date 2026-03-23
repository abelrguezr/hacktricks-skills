---
name: windows-token-privilege-escalation
description: Windows privilege escalation using token abuse techniques. Use this skill whenever the user mentions Windows privilege escalation, token privileges, Se* privileges, or needs to escalate from a lower-privileged user to SYSTEM/Administrator. Trigger for any Windows security assessment, penetration testing, or red team engagement where token-based privilege escalation is relevant.
---

# Windows Token Privilege Escalation

A comprehensive guide to escalating privileges on Windows systems by abusing token privileges.

## Quick Start

1. **Check available privileges**: `whoami /priv`
2. **Enable disabled tokens**: Use `EnableAllTokenPrivs.ps1`
3. **Identify exploitable privileges** from the table below
4. **Execute the appropriate technique** for your privilege

## Checking Privileges

```powershell
whoami /priv
```

Note: Both **Enabled** and **Disabled** tokens can be abused. Disabled tokens can be enabled.

### Enable All Token Privileges

```powershell
# Download and run
.\EnableAllTokenPrivs.ps1
whoami /priv
```

Or use the embedded script from [Lee Holmes' post](https://www.leeholmes.com/adjusting-token-privileges-in-powershell/).

## Token Privilege Exploitation

### SeImpersonatePrivilege

Allows impersonation of any token if a handle can be obtained. Exploit by inducing a Windows service (DCOM) to perform NTLM authentication against an exploit.

**Tools:**
- [JuicyPotato](https://github.com/ohpe/juicy-potato)
- [RogueWinRM](https://github.com/antonioCoco/RogueWinRM) (requires WinRM disabled)
- [SweetPotato](https://github.com/CCob/SweetPotato)
- [PrintSpoofer](https://github.com/itm4n/PrintSpoofer)

**Impact:** SYSTEM privileges

### SeAssignPrimaryPrivilege

Similar to SeImpersonatePrivilege. Allows assigning a primary token to a new/suspended process.

**Method:**
1. Acquire privileged impersonation token
2. Derive primary token using `DuplicateTokenEx`
3. Create new process with `CreateProcessAsUser` or set token on suspended process

**Impact:** SYSTEM privileges

### SeTcbPrivilege

Allows using `KERB_S4U_LOGON` to get impersonation tokens for any user without credentials.

**Capabilities:**
- Get impersonation token for any user
- Add arbitrary groups (e.g., Administrators) to token
- Set token integrity level to "medium"
- Assign token to current thread via `SetThreadToken`

**Impact:** SYSTEM/Administrator privileges

### SeBackupPrivilege

Grants read access to any file, useful for reading password hashes from registry.

**Exploitation:**
```powershell
# Read password hashes from registry
# Then use Pass-the-Hash with psexec or wmiexec
```

**Tools:**
- [Acl-FullControl.ps1](https://github.com/Hackplayers/PsCabesha-tools/blob/master/Privesc/Acl-FullControl.ps1)
- [SeBackupPrivilegeCmdLets](https://github.com/giuliano108/SeBackupPrivilege/tree/master/SeBackupPrivilegeCmdLets/bin/Debug)

**Limitations:**
- Fails if Local Administrator account is disabled
- Fails if policy removes admin rights from remote Local Administrators

**Impact:** Read sensitive files, credential theft

### SeRestorePrivilege

Grants write access to any system file regardless of ACL.

**Exploitation:**
- Modify services
- DLL Hijacking
- Set debuggers via Image File Execution Options
- Replace system binaries (e.g., utilman.exe)

**Impact:** SYSTEM/Administrator privileges

### SeCreateTokenPrivilege

Powerful privilege for token impersonation, even without SeImpersonatePrivilege.

**Conditions:**
- Target token must belong to same user
- Target token integrity level ≤ current process integrity level

**Capabilities:**
- Create impersonation tokens
- Add privileged group SIDs to tokens

**Impact:** SYSTEM/Administrator privileges

### SeLoadDriverPrivilege

Allows loading/unloading device drivers via registry entries.

**Registry Path:**
```
\Registry\User\<RID>\System\CurrentControlSet\Services\DriverName
```

**Required Values:**
- `ImagePath`: Path to binary to execute
- `Type`: `SERVICE_KERNEL_DRIVER` (0x00000001)

**Exploitation:**
1. Load buggy kernel driver (e.g., szkg64.sys - CVE-2018-15732)
2. Exploit driver vulnerability
3. Or unload security drivers: `fltMC sysmondrv`

**Impact:** SYSTEM privileges

### SeTakeOwnershipPrivilege

Allows assuming ownership of objects, bypassing DACL requirements.

**Exploitation:**
```powershell
takeown /f 'C:\some\file.txt'
icacls 'C:\some\file.txt' /grant <your_username>:F
```

**Target Files:**
```
%WINDIR%\repair\sam
%WINDIR%\repair\system
%WINDIR%\repair\software
%WINDIR%\repair\security
%WINDIR%\system32\config\security.sav
%WINDIR%\system32\config\software.sav
%WINDIR%\system32\config\system.sav
%WINDIR%\system32\config\SecEvent.Evt
%WINDIR%\system32\config\default.sav
c:\inetpub\wwwwroot\web.config
```

**Impact:** SYSTEM/Administrator privileges

### SeDebugPrivilege

Permits debugging other processes, including memory read/write.

#### Dump LSASS Memory

```powershell
# Using ProcDump from SysInternals
procdump -ma lsass.exe lsass.dmp

# Load in Mimikatz
mimikatz.exe
mimikatz # sekurlsa::minidump lsass.dmp
mimikatz # sekurlsa::logonpasswords
```

#### Get NT SYSTEM Shell

**Tools:**
- [SeDebugPrivilege-Exploit (C++)](https://github.com/bruno-1337/SeDebugPrivilege-Exploit)
- [SeDebugPrivilegePoC (C#)](https://github.com/daem0nc0re/PrivFu/tree/main/PrivilegedOperations/SeDebugPrivilegePoC)
- [psgetsys.ps1](https://raw.githubusercontent.com/decoder-it/psgetsystem/master/psgetsys.ps1)

```powershell
# Using psgetsys
import-module psgetsys.ps1
[MyProcess]::CreateProcessFromParent(<system_pid>,<command_to_execute>)
```

**Impact:** SYSTEM privileges, credential theft

### SeManageVolumePrivilege

Allows opening raw volume device handles for direct disk I/O, bypassing NTFS ACLs.

**Exploitation:**
- Copy bytes of any file by reading underlying blocks
- Exfiltrate machine private keys from `%ProgramData%\Microsoft\Crypto\`
- Read registry hives, SAM/NTDS via VSS
- On CA servers: Exfiltrate CA private key → Golden Certificate

**Impact:** Arbitrary file read, credential theft, certificate forgery

## Privilege Summary Table

| Privilege | Impact | Tool Type | Key Technique |
|-----------|--------|-----------|---------------|
| SeAssignPrimaryToken | Admin | 3rd party | Potato tools (juicy, rotten) |
| SeBackup | Threat | Built-in | `robocopy /b` for sensitive files |
| SeCreateToken | Admin | 3rd party | `NtCreateToken` for arbitrary tokens |
| SeDebug | Admin | PowerShell | Duplicate LSASS token, memory dump |
| SeLoadDriver | Admin | 3rd party | Load buggy driver (szkg64.sys) |
| SeRestore | Admin | PowerShell | Replace utilman.exe with cmd.exe |
| SeTakeOwnership | Admin | Built-in | `takeown` + `icacls` |
| SeTcb | Admin | 3rd party | Token manipulation |

## References

- [Priv2Admin Token Table](https://github.com/gtworek/Priv2Admin)
- [Token Privilege Escalation Paper](https://github.com/hatRiot/token-priv/blob/master/abusing_token_eop_1.0.txt)
- [Microsoft: SeManageVolumePrivilege](https://learn.microsoft.com/previous-versions/windows/it-pro/windows-10/security/threat-protection/security-policy-settings/perform-volume-maintenance-tasks)
- [0xdf: HTB Certificate (SeManageVolumePrivilege)](https://0xdf.gitlab.io/2025/10/04/htb-certificate.html)

## Workflow

1. **Enumerate**: Run `whoami /priv` to see available privileges
2. **Enable**: If tokens are disabled, run `EnableAllTokenPrivs.ps1`
3. **Match**: Find your privilege in the table above
4. **Execute**: Use the recommended tool/technique
5. **Verify**: Confirm privilege escalation with `whoami`

## Important Notes

- Some techniques may be detected by AV software
- Always have an exit strategy before modifying system files
- Document your findings for reporting
- Ensure you have proper authorization before testing
