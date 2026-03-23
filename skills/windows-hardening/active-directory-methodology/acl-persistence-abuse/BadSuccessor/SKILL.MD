---
name: badsuccessor-ad-dmsa-attack
description: Guide for testing the BadSuccessor vulnerability in Active Directory Delegated Managed Service Accounts (dMSAs). Use this skill when assessing Windows Server 2025 environments for dMSA privilege escalation risks, when you need to understand the msDS-ManagedAccountPrecededByLink attack vector, or when performing authorized penetration testing on AD infrastructure with dMSA objects. This skill covers reconnaissance, exploitation methodology, and credential extraction techniques for the BadSuccessor attack.
---

# BadSuccessor: Active Directory dMSA Privilege Escalation

## Overview

The BadSuccessor vulnerability affects Windows Server 2025's Delegated Managed Service Accounts (dMSAs). By manipulating the `msDS-ManagedAccountPrecededByLink` attribute and `msDS-DelegatedMSAState`, attackers can:

1. **Privilege Escalation**: Force the KDC to issue TGTs with victim SIDs (including Domain Admins)
2. **Credential Extraction**: Extract RC4-HMAC keys (NT hashes) from the KERB-DMSA-KEY-PACKAGE

## Requirements

Before attempting this attack, verify:
- Windows Server 2025 domain controller is present
- You have object creation or attribute write rights on at least one OU
- You can execute PowerShell or Rubeus from a domain-joined host
- You have explicit authorization to test this environment

## Methodology

### Phase 1: Reconnaissance

1. **Check for dMSA support**
   - Verify Windows Server 2025 DC exists
   - Look for existing dMSA objects in AD

2. **Identify writable OUs**
   - Find OUs where you can create objects
   - Check for "Create All Child Objects" permissions

3. **Locate target accounts**
   - Identify high-value users (Domain Admins, Enterprise Admins)
   - Note their DNs for the attack

### Phase 2: Attack Execution

1. **Create attacker-controlled dMSA**
   - Use `New-ADServiceAccount` in a writable OU
   - This gives you full attribute control

2. **Configure the "fake migration"**
   - Set `msDS-ManagedAccountPrecededByLink` to victim DN
   - Set `msDS-DelegatedMSAState` to 2 (completed)

3. **Request TGT with dMSA flag**
   - Use Rubeus with `/dmsa` flag
   - The PAC will include victim SIDs

### Phase 3: Credential Extraction

1. **Extract RC4-HMAC keys**
   - Parse KERB-DMSA-KEY-PACKAGE from TGT
   - These are unsalted NT hashes

2. **Mass enumeration**
   - Link multiple victims to scale credential theft
   - Extract hashes for offline cracking

## Tools

- **BadSuccessor** (Akamai): https://github.com/akamai/BadSuccessor
- **SharpSuccessor**: https://github.com/logangoins/SharpSuccessor
- **Pentest-Tools-Collection**: https://github.com/LuemmelSec/Pentest-Tools-Collection

## Safety & Ethics

⚠️ **CRITICAL**: This skill is for authorized security testing only.

- Obtain written authorization before testing
- Document all findings for remediation
- Never use against systems you don't own or have permission to test
- Report findings to appropriate security teams

## References

- Akamai Security Research: https://www.akamai.com/blog/security-research/abusing-dmsa-for-privilege-escalation-in-active-directory
