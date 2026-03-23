---
name: windows-seimpersonate-privilege-escalation
description: Windows privilege escalation technique using SeImpersonate to escalate from High Integrity to SYSTEM. Use this skill when the user needs to escalate privileges on Windows, mentions token impersonation, SeImpersonate, or wants to run commands as SYSTEM from a High Integrity context. Also trigger when the user has administrative access and wants to impersonate process tokens like winlogon.exe or svchost.exe.
---

# Windows SeImpersonate Privilege Escalation

This skill helps you escalate from High Integrity to SYSTEM on Windows using token impersonation via the SeImpersonate technique.

## When to Use This Technique

Use this approach when:
- You have High Integrity (Administrator) access on Windows
- You need SYSTEM-level privileges
- You can identify a process running as SYSTEM (like `winlogon.exe`, `wininit.exe`)
- You have `SeDebugPrivilege` or can enable it

## Prerequisites

1. **High Integrity Context**: You must be running as an Administrator with High Integrity level
2. **SeDebugPrivilege**: Required to open and manipulate process tokens
3. **Target Process**: A SYSTEM-owned process with appropriate permissions (winlogon.exe is ideal)

## How It Works

The technique exploits Windows token manipulation:

1. Enable `SeDebugPrivilege` on your current process
2. Open the target process (e.g., winlogon.exe) with `PROCESS_QUERY_LIMITED_INFORMATION`
3. Open the process's access token with `MAXIMUM_ALLOWED` access
4. Impersonate the logged-on user from that token
5. Duplicate the token to create a primary token
6. Spawn a new process (cmd.exe) using the duplicated SYSTEM token

## Usage

### Step 1: Find a Suitable Target Process

Identify a process running as SYSTEM that Administrators can impersonate:

```powershell
# Find winlogon.exe PID (usually safe to impersonate)
Get-Process winlogon | Select-Object Id, ProcessName

# Alternative: Check svchost.exe processes
Get-Process svchost | Select-Object Id, ProcessName
```

**Important**: Not all SYSTEM processes can be impersonated. `winlogon.exe` is typically the best target because Administrators have "Read Memory" and "Read Permissions" privileges on it.

### Step 2: Compile the Impersonation Tool

Use the provided C++ code (see `scripts/impersonateuser.cpp`) or compile it:

```powershell
# Using Visual Studio Developer Command Prompt
cl /EHsc impersonateuser.cpp /link advapi32.lib

# Or using MinGW
x86_64-w64-mingw32-g++ -o impersonateuser.exe impersonateuser.cpp -ladvapi32
```

### Step 3: Run the Impersonation

```powershell
# Replace 1234 with the actual PID of winlogon.exe
impersonateuser.exe 1234
```

If successful, a new `cmd.exe` will spawn running as SYSTEM.

### Step 4: Verify SYSTEM Access

In the spawned command prompt:

```powershell
whoami
# Should return: NT AUTHORITY\SYSTEM
```

## Troubleshooting

### Error 5 (Access Denied)

If you see:
```
[-] ImpersonatedLoggedOnUser() Error: 5
[-] DuplicateTokenEx() Error: 5
```

This means you don't have sufficient permissions on the target process.

**Solution**: Check process permissions:
1. Open Process Explorer
2. Right-click the target process → Properties
3. Go to Security tab → Permissions → Advanced
4. Check what privileges "Administrators" have

**Good targets** have "Read Memory" and "Read Permissions" for Administrators.

### Error 1326 (Logon Failure)

```
[-] CreateProcessWithTokenW Error: 1326
```

This indicates the token couldn't be used to create a new process.

**Solutions**:
- Try a different target process (winlogon.exe is most reliable)
- Ensure you're running with High Integrity (not just Administrator)
- Check if UAC is interfering

### OpenProcess Fails

```
[-] OpenProcess() Error: 5
```

**Solution**: Ensure `SeDebugPrivilege` is enabled. The code does this automatically, but verify you're running as Administrator.

## Alternative: PowerShell One-Liner

For quick testing without compilation, use this PowerShell approach:

```powershell
# Enable SeDebugPrivilege
$token = [System.Security.Principal.WindowsIdentity]::GetCurrent().Token
$privilege = New-Object System.Security.AccessControl.TokenPrivilege "SeDebugPrivilege"
$token.AdjustPrivileges($privilege, $true)

# Get winlogon PID
$pid = (Get-Process winlogon).Id

# Use a compiled tool or alternative method
```

Note: Full token impersonation requires native code; PowerShell alone cannot complete the impersonation.

## Security Considerations

- **Authorized Use Only**: This technique should only be used on systems you own or have explicit permission to test
- **Detection**: This activity may be logged and detected by EDR solutions
- **Persistence**: The spawned cmd.exe is temporary; use it to establish persistence if needed

## Related Techniques

- **Token Theft**: Stealing tokens from memory
- **Process Injection**: Injecting code into SYSTEM processes
- **Named Pipe Impersonation**: Using named pipes for token theft

## References

- [Understanding and Abusing Access Tokens - Part II](https://securitytimes.medium.com/understanding-and-abusing-access-tokens-part-ii-b9069f432962)
- [HackTricks - Windows Privilege Escalation](https://book.hacktricks.xyz/windows/windows-local-privilege-escalation/seimpersonate-from-high-to-system)
