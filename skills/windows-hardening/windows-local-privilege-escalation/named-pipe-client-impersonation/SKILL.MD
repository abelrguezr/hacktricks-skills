---
name: windows-named-pipe-impersonation
description: Windows local privilege escalation via named pipe client impersonation. Use this skill whenever the user mentions privilege escalation, named pipes, ImpersonateNamedPipeClient, Potato attacks, PrintSpoofer, RoguePotato, JuicyPotato, EFSRPC, or wants to escalate from a privileged user to SYSTEM on Windows. This skill helps generate exploit code, identify coercion triggers, and troubleshoot impersonation issues.
---

# Windows Named Pipe Client Impersonation

This skill helps you perform local privilege escalation on Windows by exploiting named pipe client impersonation. The core technique: create a named pipe, coerce a privileged service to connect, impersonate that client's token, and spawn a SYSTEM process.

## When to use this skill

Use this skill when:
- You need to escalate privileges on Windows from a privileged user to SYSTEM
- You're working with named pipes and want to impersonate a connecting client
- You need to generate exploit code for PrintSpoofer, RoguePotato, JuicyPotato, or similar techniques
- You're troubleshooting `ERROR_CANNOT_IMPERSONATE` (1368) or `ERROR_PRIVILEGE_NOT_HELD` (1314)
- You want to understand how to coerce SYSTEM services to connect to your pipe

## Core technique

The attack flow:
1. Create a named pipe at `\\.\pipe\<random-name>`
2. Wait for a privileged client (SYSTEM service) to connect
3. Read at least one message from the pipe (required before impersonation)
4. Call `ImpersonateNamedPipeClient` to adopt the client's security context
5. Duplicate the impersonation token into a primary token
6. Spawn a process as the client (typically SYSTEM)

## Required privileges

| Privilege | Purpose |
|-----------|----------|
| `SeImpersonatePrivilege` | Required for `ImpersonateNamedPipeClient` and `CreateProcessWithTokenW` |
| `SeAssignPrimaryTokenPrivilege` | May be needed for `CreateProcessAsUser` |
| `SeIncreaseQuotaPrivilege` | May be needed for `CreateProcessAsUser` |

Note: When impersonating SYSTEM, the last two are typically satisfied automatically.

## Generate exploit code

### C implementation

Run the C code generator script to create a minimal named pipe impersonation exploit:

```bash
python scripts/generate_c_exploit.py --pipe-name <name> --output <path>
```

This generates a complete C program with:
- Named pipe creation and connection handling
- Message reading before impersonation
- Token duplication with `DuplicateTokenEx`
- Process spawning with `CreateProcessWithTokenW` or `CreateProcessAsUser`
- Proper cleanup with `RevertToSelf`

### .NET implementation

Run the .NET code generator script:

```bash
python scripts/generate_dotnet_exploit.py --pipe-name <name> --output <path>
```

This generates a C# program using `NamedPipeServerStream.RunAsClient` with P/Invoke for token manipulation.

## Common coercion triggers

To get SYSTEM to connect to your pipe, use one of these triggers:

| Trigger | Tool | Description |
|---------|------|-------------|
| Print Spooler RPC | PrintSpoofer | Coerces spoolsv.exe via RPC |
| DCOM activation | RoguePotato | Uses DCOM/NTLM reflection |
| DCOM variants | JuicyPotato/JuicyPotatoNG | Multiple DCOM interfaces |
| EFSRPC | EfsPotato/SharpEfsPotato | Encrypting File System RPC |
| GodPotato | GodPotato | DCOM with SeImpersonatePrivilege |

### Print Spooler (PrintSpoofer)

Most reliable on modern Windows. The spooler service connects to named pipes during RPC operations.

### DCOM-based (RoguePotato/JuicyPotato)

Works by activating DCOM objects that connect to your pipe. JuicyPotatoNG has the most interface coverage.

### EFSRPC (EfsPotato)

Targets the Encrypting File System RPC interface. Works on systems with EFS enabled.

## Troubleshooting

### ERROR_CANNOT_IMPERSONATE (1368)

**Cause:** You didn't read from the pipe before calling `ImpersonateNamedPipeClient`, or the client restricted impersonation level.

**Fix:**
1. Ensure you call `ReadFile` at least once before `ImpersonateNamedPipeClient`
2. Check the client's impersonation level with `GetTokenInformation(TokenImpersonationLevel)`
3. If the client used `SECURITY_IDENTIFICATION`, you cannot fully impersonate

### ERROR_PRIVILEGE_NOT_HELD (1314)

**Cause:** `CreateProcessWithTokenW` requires `SeImpersonatePrivilege` on the caller.

**Fix:**
1. Enable `SeImpersonatePrivilege` in your process token before calling
2. Or use `CreateProcessAsUser` after you've already impersonated SYSTEM

### Client won't connect

**Cause:** The service doesn't know about your pipe, or ACLs block connection.

**Fix:**
1. Use a coercion trigger (PrintSpoofer, RoguePotato, etc.)
2. Check your pipe's security descriptor allows the target service
3. Default pipes under `\\.\pipe` are accessible per the server's DACL

## Advanced: Named pipe MITM

For hardened services, you can instrument the trusted client:

1. **DLL injection:** Inject a helper DLL into the client process
2. **API hooking:** Detour `ReadFile`/`WriteFile` when `GetFileType` reports `FILE_TYPE_PIPE`
3. **Proxy traffic:** Copy buffers to a control pipe, edit/drop/replay, then resume
4. **PID validation bypass:** Connect from inside the trusted process so the server sees the legitimate PID

Tools like [pipetap](https://sensepost.com/blog/2025/pipetap-a-windows-named-pipe-proxy-tool/) implement this pattern.

## Operational notes

- Named pipes are low-latency; long pauses while editing buffers can deadlock services
- Overlapped/completion-port I/O coverage is partial; expect edge cases
- Injection is noisy and unsigned; treat as lab/exploit-dev helper, not stealth implant
- Use VM snapshots when crash-testing fragile IPC parsers

## References

- [Microsoft: ImpersonateNamedPipeClient](https://learn.microsoft.com/en-us/windows/win32/api/namedpipeapi/nf-namedpipeapi-impersonatenamedpipeclient)
- [ired.team: Windows named pipes privilege escalation](https://ired.team/offensive-security/privilege-escalation/windows-namedpipes-privilege-escalation)
- [pipetap – Windows named pipe proxy tool](https://sensepost.com/blog/2025/pipetap-a-windows-named-pipe-proxy-tool/)
