---
name: windows-tapi-rce-research
description: Research and analyze Windows Telephony (TapiSrv) service vulnerabilities, specifically CVE-2026-20931 arbitrary DWORD write to RCE. Use this skill when investigating Windows privilege escalation, analyzing TAPI server configurations, researching MSRPC named pipe vulnerabilities, or hardening Windows systems against telephony service attacks. Trigger for any questions about Windows Telephony service security, TAPI server mode exploitation, mailslot path confusion attacks, or NETWORK SERVICE privilege escalation.
---

# Windows Telephony (TapiSrv) RCE Research Skill

This skill helps security researchers analyze and understand the Windows Telephony service vulnerability (CVE-2026-20931) that allows arbitrary DWORD writes leading to RCE as NETWORK SERVICE.

## When to Use This Skill

Use this skill when:
- Investigating Windows privilege escalation vectors
- Analyzing TAPI server configurations for security assessments
- Researching MSRPC named pipe vulnerabilities
- Hardening Windows systems against telephony service attacks
- Understanding mailslot path confusion attack patterns
- Reviewing NETWORK SERVICE account security

## Vulnerability Overview

### Attack Surface

The Windows Telephony service (`TapiSrv`, `tapisrv.dll`) exposes the `tapsrv` MSRPC interface over SMB named pipe when configured as a TAPI server:

- **Registry check**: `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Telephony\Server\DisableSharing`
- **Interface**: MS-TRP (`tapsrv`) over `\pipe\tapsrv`
- **Service account**: `NETWORK SERVICE` (manual start, on-demand)
- **Default state**: Local-only (not exposed remotely)

### Core Primitive: Mailslot Path Confusion

The vulnerability stems from improper validation in `ClientAttach`:

```c
CreateFileW(pszDomainUser, GENERIC_WRITE, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
```

The service accepts **any existing filesystem path** writable by `NETWORK SERVICE`, not just mailslot paths (`\\*\MAILSLOT\...`).

### Attack Chain

1. **Arbitrary DWORD Write**: Write 4 bytes to any `NETWORK SERVICE`-writable file
2. **Grant Admin Access**: Modify `C:\Windows\TAPI\tsec.ini` to add attacker to `[TapiAdministrators]`
3. **Admin DLL Load**: Use `GetUIDllName` to load arbitrary DLL as `NETWORK SERVICE`
4. **RCE**: Execute code in DLL export `TSPI_providerUIIdentify`

## Detection and Enumeration

### Check TAPI Server Configuration

```powershell
# Check if TAPI server mode is enabled
Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Telephony\Server" -Name "DisableSharing" -ErrorAction SilentlyContinue

# Check TAPI service status
Get-Service -Name "TapiSrv"

# Check for TAPI admin entries
Get-Content "C:\Windows\TAPI\tsec.ini" -ErrorAction SilentlyContinue | Select-String "TapiAdministrators"
```

### Identify NETWORK SERVICE Writable Files

Common writable locations for the DWORD write primitive:

- `C:\Windows\System32\catroot2\dberr.txt`
- `C:\Windows\ServiceProfiles\NetworkService\AppData\Local\Temp\MpCmdRun.log`
- `C:\Windows\ServiceProfiles\NetworkService\AppData\Local\Temp\MpSigStub.log`
- `C:\Windows\TAPI\tsec.ini` (if writable)

### RPC Interface Enumeration

```powershell
# Check for tapsrv named pipe
Get-ChildItem "\\.\pipe\" -ErrorAction SilentlyContinue | Select-String "tapsrv"

# Check TAPI registry keys
Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Telephony" -Recurse -ErrorAction SilentlyContinue
```

## Hardening Recommendations

### Disable TAPI Server Mode

```powershell
# Disable TAPI server sharing
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Telephony\Server" -Name "DisableSharing" -Value "1" -PropertyType DWORD -Force

# Stop and disable the service
Stop-Service -Name "TapiSrv" -ErrorAction SilentlyContinue
Set-Service -Name "TapiSrv" -StartupType Disabled
```

### Lock Down File Permissions

```powershell
# Secure tsec.ini
$acl = Get-Acl "C:\Windows\TAPI\tsec.ini"
$acl.SetAccessRuleProtection($true, $false)
$acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule("SYSTEM", "FullControl", "Allow")))
$acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators", "FullControl", "Allow")))
Set-Acl "C:\Windows\TAPI\tsec.ini" $acl

# Monitor for changes
New-ScheduledTaskAction -Execute "powershell.exe" -Argument "Get-FileHash C:\Windows\TAPI\tsec.ini"
```

### Network-Level Controls

- Block remote SMB access to `\pipe\tapsrv`
- Implement SMB signing requirements
- Restrict NETWORK SERVICE account permissions
- Monitor for `LoadLibrary` calls from `tapisrv.dll`

## Detection Signatures

### Registry Monitoring

```powershell
# Alert on TAPI admin list changes
New-EventSubscriber -EventName "Modified" -SourceIdentifier "TapiAdminChange" -Action {
    Write-EventLog -LogName "Security" -Source "TapiSrv" -EventID 1001 -EntryType Warning -Message "TAPI admin list modified"
}
```

### Process Monitoring

Monitor for:
- `tapisrv.dll` loading non-default DLLs
- `LoadLibrary` calls from `TapiSrv` service
- Named pipe connections to `\pipe\tapsrv` from remote hosts
- File modifications to `C:\Windows\TAPI\tsec.ini`

### EDR Detection Rules

```yaml
# Sigma rule for TAPI admin modification
title: TAPI Administrator List Modification
description: Detects modifications to TAPI administrator configuration
logsource:
  category: file_event
  product: windows
  service: file
detection:
  selection:
    TargetFilename: 'C:\Windows\TAPI\tsec.ini'
  condition: selection
falsepositives:
  - Legitimate TAPI configuration changes
level: high
```

## Research References

- [Who's on the line? Exploiting RCE in Windows Telephony Service (CVE-2026-20931)](https://swarm.ptsecurity.com/whos-on-the-line-exploiting-rce-in-windows-telephony-service/)
- Microsoft Security Advisory: Windows Telephony Service Vulnerability
- MS-TRP Protocol Specification

## Important Notes

- **Remote exposure only when enabled**: By default, `tapsrv` is local-only
- **Valid SMB auth required**: Attacker needs authenticated SMB access
- **File must exist**: The primitive uses `OPEN_EXISTING`, target files must pre-exist
- **UNC path limitations**: Some SMB servers block guest logons for DLL loading
- **Service state**: `TapiSrv` is manual start, may need to be triggered

## Related Vulnerabilities

- Mailslot path confusion patterns in other Windows services
- MSRPC named pipe authentication bypasses
- NETWORK SERVICE privilege escalation vectors
- DLL search order hijacking in Windows services
