---
name: ntlm-hardening
description: Guide for understanding NTLM authentication, configuring NTLM security settings, and hardening Windows environments against NTLM-based attacks. Use this skill whenever the user asks about NTLM authentication, LM/NTLMv1/NTLMv2 protocols, Pass-the-Hash attacks, NTLM relay attacks, configuring LMCompatibilityLevel, or Windows authentication security. Also use when users need to parse NTLM challenges from network captures, understand NTLM reflection attacks, or harden systems against credential theft.
---

# NTLM Hardening Guide

A comprehensive guide for understanding NTLM authentication, configuring security settings, and hardening Windows environments against NTLM-based attacks.

## When to Use This Skill

Use this skill when you need to:
- Understand NTLM authentication protocols (LM, NTLMv1, NTLMv2)
- Configure NTLM security settings on Windows systems
- Parse NTLM challenges from network captures
- Understand NTLM-based attack vectors for defensive purposes
- Harden systems against Pass-the-Hash and NTLM relay attacks
- Investigate NTLM reflection vulnerabilities

## Basic NTLM Information

### Authentication Protocol Hierarchy

- **Kerberos** is the default authentication method in Active Directory environments
- **NTLM** is used when:
  - No Active Directory is present
  - The domain doesn't exist
  - Kerberos is misconfigured
  - Connections use IP addresses instead of hostnames

### Identifying NTLM Traffic

Look for the **"NTLMSSP"** header in network packets to identify NTLM authentication.

### Protocol Support

LM, NTLMv1, and NTLMv2 are supported by: `%windir%\System32\msv1_0.dll`

### LM Hash Indicators

- LM hashes are vulnerable and easily compromised
- The hash `AAD3B435B51404EEAAD3B435B51404EE` indicates LM is **not** in use (empty string hash)

## NTLM Protocol Versions

### LM (Lan Manager)
- Used in Windows XP and Server 2003
- Highly vulnerable, should be disabled

### NTLMv1
- **Challenge**: 8 bytes
- **Response**: 24 bytes
- **Vulnerabilities**:
  - NT hash split into 3 parts of 7 bytes each (last part padded with zeros)
  - DES encryption is crackable
  - Same challenge produces same response (enables rainbow table attacks)
  - Challenge `1122334455667788` is commonly used for rainbow table attacks

### NTLMv2
- **Challenge**: 8 bytes
- **Responses**: Two responses (24 bytes + variable length)
- **First response**: HMAC_MD5 of client+domain using MD4(NT hash) as key, then HMAC_MD5 of challenge, plus 8-byte client challenge
- **Second response**: Includes timestamp to prevent replay attacks
- Much more secure than NTLMv1

## Configuring NTLM Security Settings

### GUI Method

1. Run `secpol.msc`
2. Navigate to: Local Policies → Security Options → Network Security: LAN Manager authentication level
3. Select appropriate level (0-5)

### Registry Method

Set LMCompatibilityLevel via registry:

```powershell
reg add HKLM\SYSTEM\CurrentControlSet\Control\Lsa\ /v lmcompatibilitylevel /t REG_DWORD /d 5 /f
```

### LMCompatibilityLevel Values

| Level | Behavior |
|-------|----------|
| 0 | Send LM & NTLM responses |
| 1 | Send LM & NTLM responses, use NTLMv2 session security if negotiated |
| 2 | Send NTLM response only |
| 3 | Send NTLMv2 response only |
| 4 | Send NTLMv2 response only, refuse LM |
| 5 | Send NTLMv2 response only, refuse LM & NTLM (RECOMMENDED) |

**Recommendation**: Set to level 5 for maximum security.

## NTLM Authentication Flow

### Domain Authentication

1. User provides credentials
2. Client sends authentication request with domain name and username
3. Server sends challenge
4. Client encrypts challenge using password hash and sends response
5. Server forwards domain name, username, challenge, and response to Domain Controller
6. Domain Controller validates and responds

### Local Authentication

Same as domain authentication, but the server checks credentials locally against the SAM file instead of contacting a Domain Controller.

## Security Hardening Recommendations

### Disable Weak Protocols

1. Set LMCompatibilityLevel to 5
2. Configure NTLMMinClientSec to require NTLMv2
3. Enable RestrictSendingNTLMTraffic

### Monitor for Attacks

Watch for:
- NTLMSSP_NEGOTIATE_LOCAL_CALL flags in network captures
- Event 4624/4648 SYSTEM logons followed by remote SMB writes
- DNS records with base64-encoded marshalled SPNs
- Kerberos AP-REQ with subsession keys matching hostname principals

### Mitigate Reflection Attacks

- Apply KB patch for CVE-2025-33073
- Enforce SMB signing
- Monitor DNS for suspicious records
- Block coercion vectors (PetitPotam, DFSCoerce, AuthIP)

## Parsing NTLM Challenges

Use [NTLMRawUnHide](https://github.com/mlgualtieri/NTLMRawUnHide) to extract NTLM challenges from network captures.

## Understanding Attack Vectors (For Defensive Purposes)

### Pass-the-Hash

Attackers can use captured NTLM hashes to impersonate users without knowing plaintext passwords. Defense:
- Use NTLMv2 only
- Implement Credential Guard
- Monitor for unusual authentication patterns

### NTLM Relay

Attackers can relay NTLM authentication to gain unauthorized access. Defense:
- Enable SMB signing
- Use NTLMv2 with extended security
- Implement network segmentation

### Internal Monologue Attack

Stealthy credential extraction that doesn't interact directly with LSASS. Defense:
- Enforce NTLMv2
- Monitor for local NTLM authentication anomalies
- Keep systems patched

### NTLM Reflection (CVE-2025-33073)

Bypasses reflection protections using serialized SPNs. Defense:
- Apply CVE-2025-33073 patch
- Monitor DNS for marshalled SPN patterns
- Enforce SMB signing

## References

- [NTLM Reflection Analysis](https://www.synacktiv.com/en/publications/la-reflexion-ntlm-est-morte-vive-la-reflexion-ntlm-analyse-approfondie-de-la-cve-2025.html)
- [MSRC CVE-2025-33073](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2025-33073)
- [Internal Monologue PoC](https://github.com/eladshamir/Internal-Monologue)
- [NTLMRawUnHide](https://github.com/mlgualtieri/NTLMRawUnHide)
