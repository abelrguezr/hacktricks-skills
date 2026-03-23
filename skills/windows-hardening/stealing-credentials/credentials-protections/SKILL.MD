---
name: windows-credential-protections
description: Check and analyze Windows credential protection mechanisms including WDigest, LSA PPL/PP, Credential Guard, RDP RestrictedAdmin, cached credentials, and Protected Users group. Use this skill whenever the user needs to assess Windows security posture, audit credential storage protections, investigate why credential dumping tools like Mimikatz fail, or understand Windows security features that protect against pass-the-hash and credential theft attacks.
---

# Windows Credential Protections

This skill helps you assess and understand Windows credential protection mechanisms. Use it to audit security configurations, troubleshoot credential dumping failures, or harden Windows systems against credential theft.

## Quick Reference

| Protection | Registry Key | Default Status | Bypass Difficulty |
|------------|--------------|----------------|-------------------|
| WDigest | `HKLM\...\WDigest\UseLogonCredential` | Enabled (XP-8) | Easy (registry) |
| LSA PPL | `HKLM\...\LSA\RunAsPPL` | Disabled | Medium (kernel) |
| Credential Guard | `HKLM\...\LSA\LsaCfgFlags` | Disabled | Hard (VBS required) |
| Cached Logons | `HKLM\...\WINLOGON\CachedLogonsCount` | 10 | Medium (SYSTEM) |
| Protected Users | AD Group | N/A | N/A |

## WDigest Protection

WDigest stores passwords in **plain text** in LSASS memory when enabled. This is a critical security risk.

### Check WDigest Status

```bash
reg query HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest /v UseLogonCredential
```

- **Value = 1**: WDigest is **ENABLED** (plain text passwords in memory)
- **Value = 0 or missing**: WDigest is **DISABLED** (secure)

### Disable WDigest (Recommended)

```bash
reg add HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest /v UseLogonCredential /t REG_DWORD /d 0 /f
reg add HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest /v Negotiate /t REG_DWORD /d 0 /f
```

### Mimikatz Extraction

If WDigest is enabled, credentials can be extracted with:
```bash
sekurlsa::wdigest
```

## LSA Protection (PP & PPL)

Protected Process (PP) and Protected Process Light (PPL) prevent unauthorized access to LSASS.

### Check LSA PPL Status

```bash
reg query HKLM\SYSTEM\CurrentControlSet\Control\LSA /v RunAsPPL
```

- **Value = 1**: LSASS runs as **PPL** (Protected Process Light)
- **Value = 0**: LSASS is **unprotected**

### Understanding PPL Protection Levels

| Signer | Value | Access Rights |
|--------|-------|---------------|
| WinTcb | 0x61/0x62 | Highest - can access all |
| Lsa-Light | 0x41 | LSASS default |
| Antimalware-Light | 0x31 | AV processes |
| Windows-Light | 0x21 | System processes |
| Unprotected | 0x00 | Cannot access PPL |

### PPL Bypass Options

1. **Signed kernel driver** (e.g., Mimikatz + mimidrv.sys) - removes protection flag
2. **BYOVD** (Bring Your Own Vulnerable Driver) - PPLKiller, gdrv-loader, kdmapper
3. **Handle duplication** - steal LSASS handle from AV process (`pypykatz live lsa --method handledup`)
4. **Privileged process abuse** - load code into signed process (PPLdump)

### Create PPL Process (API)

Windows provides documented API to request PPL for child processes:

```c
// Requires properly signed image for the requested signer class
STARTUPINFOEXW si = {0};
PROCESS_INFORMATION pi = {0};
// ... InitializeProcThreadAttributeList ...
DWORD level = PROTECTION_LEVEL_LSA_LIGHT;
UpdateProcThreadAttribute(si.lpAttributeList, 0,
    PROC_THREAD_ATTRIBUTE_PROTECTION_LEVEL, &level, sizeof(level), NULL, NULL);
CreateProcessW(..., EXTENDED_STARTUPINFO_PRESENT, ...);
```

**Note**: The child image must be signed for the requested signer class, or creation fails with `ERROR_INVALID_IMAGE_HASH (577)`.

## Credential Guard

Credential Guard uses Virtualization Based Security (VBS) to isolate credentials in a secure memory space.

### Check Credential Guard Status

```bash
reg query HKLM\System\CurrentControlSet\Control\LSA /v LsaCfgFlags
```

- **Value = 1**: Enabled with **UEFI lock** (most secure)
- **Value = 2**: Enabled **without UEFI lock**
- **Value = 0**: **Disabled** (default)

### Key Facts

- Available only on **Windows 10 Enterprise/Education** and **Windows 11 Enterprise/Education 22H2+**
- Requires **virtualization support** in BIOS/UEFI
- Isolates LSA in a **Virtual Secure Mode (VSM)** trustlet
- Prevents **pass-the-hash** attacks
- Can be bypassed via **custom SSP** injection

## RDP RestrictedAdmin Mode

Restricted Admin mode prevents credential storage on remote RDP targets.

### Usage

```bash
mstsc.exe /RestrictedAdmin
```

### Behavior

- Credentials are **NOT stored** on the remote machine
- Network resource access uses **machine identity**, not user credentials
- Available on **Windows 8.1+** and **Server 2012 R2+**

## Cached Credentials

Windows caches the last 10 domain logins for offline access.

### Check Cached Logons Count

```bash
reg query "HKLM\SOFTWARE\MICROSOFT\WINDOWS NT\CURRENTVERSION\WINLOGON" /v CachedLogonsCount
```

### Default Settings

- **Default**: 10 cached logins
- **Location**: `HKLM\SECURITY\Cache`
- **Access**: SYSTEM only

### Mimikatz Extraction

```bash
lsadump::cache
```

## Protected Users Group

Membership in the **Protected Users** AD group provides enhanced credential protection.

### Protections Applied

| Feature | Protection |
|---------|------------|
| CredSSP | No plain text caching |
| WDigest | No plain text caching (Win8.1+) |
| NTLM | No NTOWF or plain text caching |
| Kerberos | No DES/RC4 keys, no long-term key caching |
| Offline Sign-In | **Not supported** |

### Protected Groups by Server Version

| Server 2003 | Server 2008 R2 | Server 2016 |
|-------------|----------------|-------------|
| Account Operators | Account Operators | Account Operators |
| Administrators | Administrators | Administrators |
| Domain Admins | Domain Admins | Domain Admins |
| Enterprise Admins | Enterprise Admins | Enterprise Admins |
| Krbtgt | Krbtgt | Krbtgt |
| Schema Admins | Schema Admins | Schema Admins |
| - | - | Enterprise Key Admins |
| - | - | Key Admins |

## Troubleshooting Mimikatz Failures

### Error 0x00000005 (Access Denied)

**Cause**: LSASS is running as PPL

**Solution**: Use one of the PPL bypass methods above

### WDigest Returns Nothing

**Cause**: WDigest is disabled (UseLogonCredential = 0)

**Solution**: Enable WDigest (not recommended for security) or use other extraction methods

### Credential Guard Blocks Extraction

**Cause**: LsaCfgFlags = 1 or 2

**Solution**: Requires VSM bypass or custom SSP injection

## Security Recommendations

1. **Disable WDigest** on all systems (UseLogonCredential = 0)
2. **Enable LSA PPL** (RunAsPPL = 1) on Windows 8.1+
3. **Enable Credential Guard** on Enterprise systems where possible
4. **Use RestrictedAdmin mode** for RDP connections
5. **Limit CachedLogonsCount** to minimum necessary
6. **Add privileged accounts** to Protected Users group

## References

- [LSASS RunAsPPL - itm4n](https://itm4n.github.io/lsass-runasppl/)
- [Credential Guard - Microsoft Docs](https://docs.microsoft.com/en-us/windows/security/identity-protection/credential-guard/credential-guard-manage)
- [Protected Users Group - Microsoft Docs](https://docs.microsoft.com/en-us/windows-server/security/credentials-protection-and-management/protected-users-security-group)
- [CreateProcessAsPPL - GitHub](https://github.com/2x7EQ13/CreateProcessAsPPL)
- [Restricted Admin Mode - Blog](https://blog.ahasayen.com/restricted-admin-mode-for-rdp/)
