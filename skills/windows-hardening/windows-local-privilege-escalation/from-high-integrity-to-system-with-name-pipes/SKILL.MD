---
name: windows-privilege-escalation-name-pipes
description: Windows privilege escalation from high integrity to SYSTEM using named pipes. Use this skill whenever the user mentions Windows privilege escalation, gaining SYSTEM access, named pipe exploitation, high integrity to SYSTEM, service-based privilege escalation, or any Windows security testing scenario where you need to escalate privileges. This is especially relevant for penetration testing, red teaming, or security assessments on Windows systems where you already have high integrity but need SYSTEM.
---

# Windows Privilege Escalation: High Integrity to SYSTEM via Named Pipes

This skill teaches you how to escalate from a high integrity process to SYSTEM using Windows named pipes and service impersonation.

## When to Use This Technique

Use this approach when:
- You have a high integrity process (e.g., from a vulnerable service running as Administrator)
- You need SYSTEM privileges for further operations
- The target is a Windows system (Windows 7 through Windows 11)
- You can create and start services on the target system

## Prerequisites

- High integrity process (not just medium/low integrity)
- Ability to create Windows services (requires `SeCreateGlobalPrivilege` or similar)
- No AppLocker or similar restrictions blocking service creation
- The target system must allow named pipe connections

## How It Works

The exploit follows this flow:

1. **Create a named pipe** - Your process creates a named pipe server
2. **Create a service** - A new service is created that will connect to your pipe
3. **Service executes PowerShell** - The service connects to the pipe and sends data
4. **Impersonate the connection** - Your process calls `ImpersonateNamedPipeClient()` to steal the service's SYSTEM token
5. **Spawn SYSTEM shell** - Use the stolen token to launch `cmd.exe` as SYSTEM

## Usage

### Step 1: Compile the Exploit

```bash
# On Windows with MinGW or Visual Studio
gcc -o priv_esc.exe priv_esc_named_pipes.c -ladvapi32 -lkernel32

# Or with Visual Studio
class priv_esc_named_pipes.c /link advapi32.lib kernel32.lib
```

### Step 2: Run from High Integrity Context

```cmd
priv_esc.exe
```

If successful, a new `cmd.exe` window will open running as SYSTEM.

### Step 3: Verify Privileges

In the new command prompt:
```cmd
whoami
```

Should return: `nt authority\system`

## The Exploit Code

The compiled exploit is available at `scripts/priv_esc_named_pipes.c`. Key components:

- **ServiceGo()**: Creates and starts a service that connects to the named pipe
- **main()**: Creates the pipe, waits for connection, impersonates the client, spawns SYSTEM shell

## Important Warnings

> **WARNING**: If you don't have sufficient privileges, the exploit may hang indefinitely. The `ConnectNamedPipe()` call will block waiting for a connection that may never come.

> **WARNING**: This is an offensive security technique. Only use on systems you own or have explicit authorization to test.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Exploit hangs | You likely don't have high integrity. Check with `whoami /groups` |
| Service creation fails | You need `SeCreateGlobalPrivilege` or run as Administrator |
| Pipe connection fails | Check firewall rules and ensure no other process is using the pipe name |
| SYSTEM shell doesn't spawn | Check Event Viewer for service errors |

## Alternative Approaches

If this technique doesn't work, consider:
- **Token manipulation** - If you can find a SYSTEM token in memory
- **Service binary replacement** - If you can modify a service's executable path
- **DLL hijacking** - If a service loads from an insecure path
- **Unquoted service paths** - If services have unquoted installation paths

## References

- [HackTricks - Windows Privilege Escalation](https://book.hacktricks.xyz/windows/windows-local-privilege-escalation/from-high-integrity-to-system-with-name-pipes)
- [MSDN - ImpersonateNamedPipeClient](https://docs.microsoft.com/en-us/windows/win32/api/NamedPipes/nf-namedpipes-impersonatenamedpipeclient)
- [MSDN - CreateProcessWithTokenW](https://docs.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-createprocesswithtokenw)
