---
name: kerberos-authentication
description: Kerberos authentication analysis and attack methodology for Active Directory environments. Use this skill whenever the user mentions Kerberos, AD authentication, ticket-based auth, Kerberoasting, AS-REP roasting, delegation abuse, golden tickets, or any Kerberos-related security testing. Trigger for pentesting scenarios, security assessments, or when analyzing AD authentication flows.
---

# Kerberos Authentication

A comprehensive guide to Kerberos authentication in Active Directory environments, including attack methodologies, tooling, and recent security developments.

## Overview

Kerberos is the default authentication protocol in Active Directory. Most lateral movement chains in AD environments will interact with Kerberos at some point. Understanding Kerberos is essential for security assessments and penetration testing.

## Key Concepts

### Authentication Flow
- **TGT (Ticket Granting Ticket)**: Initial ticket obtained from KDC
- **TGS (Ticket Granting Service)**: Service tickets for specific resources
- **PAC (Privilege Attribute Certificate)**: Contains user/group membership info
- **S4U2self/S4U2proxy**: Service for User protocols for delegation

### Attack Vectors

#### Kerberoasting
- Target service accounts with SPNs
- Extract TGS tickets and crack offline
- **Modern approach**: Use AES hashes (RC4 being phased out)

#### AS-REP Roasting
- Target accounts with "Do not require Kerberos preauthentication" enabled
- Capture AS-REP responses and crack offline

#### Golden Ticket Attacks
- Forge TGTs using KRBTGT hash
- **Note**: PAC validation enforcement (April 2025) blocks forged PACs on patched DCs

#### Delegation Abuse
- **RBCD (Resource-Based Constrained Delegation)**: Works across domains/forests
- Write `msDS-AllowedToActOnBehalfOfOtherIdentity` on resource objects
- Chain S4U2self → S4U2proxy for impersonation

## Fresh Attack Notes (2024-2026)

### RC4 Deprecation
- Windows Server 2025 DCs no longer issue RC4 TGTs by default
- Microsoft plans to disable RC4 as default for AD DCs by end of Q2 2026
- Environments re-enabling RC4 for legacy apps create downgrade/fast-crack opportunities
- **Action**: Hunt for RC4-enabled accounts before full deprecation

### PAC Validation Enforcement
- April 2025 updates removed "Compatibility" mode
- Forged PACs/golden tickets rejected on patched DCs when enforcement enabled
- Legacy/unpatched DCs remain abusable

### CVE-2025-26647 (altSecID CBA Mapping)
- Unpatched DCs or Audit mode: certificates chained to non-NTAuth CAs can log on via SKI/altSecID mapping
- Events 45/21 appear when protections trigger

### NTLM Phase-Out
- Future Windows releases ship with NTLM disabled by default (staged through 2026)
- More authentication surface moves to Kerberos
- Expect stricter EPA/CBT in hardened networks

### Cross-Domain RBCD
- Resource-based constrained delegation works across domains/forests
- Writable `msDS-AllowedToActOnBehalfOfOtherIdentity` on resource objects enables S4U2self→S4U2proxy impersonation
- Does not require touching front-end service ACLs

## Tooling

### Rubeus

**Kerberoasting (AES default):**
```powershell
Rubeus.exe kerberoast /user:svc_sql /aes /nowrap /outfile:tgs.txt
```
- Outputs AES hashes
- Plan for GPU cracking or target pre-auth disabled users instead

**RC4 Downgrade Target Hunting:**
```powershell
Get-ADObject -LDAPFilter '(msDS-SupportedEncryptionTypes=4)' -Properties msDS-SupportedEncryptionTypes
```
- Enumerate accounts still advertising RC4
- Locate weak Kerberoast candidates before RC4 is fully disabled

### Additional Tools
- Impacket suite (GetUserSPNs.py, ticketer.py)
- Mimikatz (kerberos::golden, kerberos::list)
- Rubeus (comprehensive Kerberos tooling)

## Detection & Defense

### Monitoring
- Watch for Event IDs 45/21 (CVE-2025-26647 protections)
- Monitor for unusual TGS requests
- Track PAC validation failures

### Hardening
- Disable RC4 encryption types
- Enable PAC validation enforcement
- Patch DCs for CVE-2025-26647
- Audit `msDS-AllowedToActOnBehalfOfOtherIdentity` attributes
- Implement strict SPN management

## References

- [Microsoft – Beyond RC4 for Windows authentication](https://www.microsoft.com/en-us/windows-server/blog/2025/12/03/beyond-rc4-for-windows-authentication)
- [Microsoft Support – Protections for CVE-2025-26647](https://support.microsoft.com/en-gb/topic/protections-for-cve-2025-26647-kerberos-authentication-5f5d753b-4023-4dd3-b7b7-c8b104933d53)
- [Microsoft Support – PAC validation enforcement timeline](https://support.microsoft.com/en-us/topic/how-to-manage-pac-validation-changes-related-to-cve-2024-26248-and-cve-2024-29056-6e661d4f-799a-4217-b948-be0a1943fef1)
- [Microsoft Learn – Kerberos constrained delegation overview](https://learn.microsoft.com/en-us/windows-server/security/kerberos/kerberos-constrained-delegation-overview)
- [Windows Central – NTLM deprecation roadmap](https://www.windowscentral.com/microsoft/windows/microsoft-plans-to-bury-its-ntlm-security-relic-after-30-years)
- [Tarlogic – How Kerberos Works](https://www.tarlogic.com/en/blog/how-kerberos-works/)

## Usage Notes

- This skill is for authorized security testing and educational purposes only
- Always have proper authorization before testing Kerberos in any environment
- Understand the legal and ethical implications of Kerberos attack techniques
- Use in conjunction with proper AD pentesting methodologies
