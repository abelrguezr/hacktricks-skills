---
name: windows-uiaccess-bypass
description: Windows UIAccess privilege escalation research and testing. Use this skill when investigating Admin Protection bypasses, UIAccess token manipulation, integrity level escalation, or secure directory validation weaknesses. Trigger for any Windows security research involving AppInfo service, RAiLaunchAdminProcess, UIPI bypasses, or High IL process injection techniques. Also use when enumerating writable paths in protected directories or analyzing signed UIAccess binary vulnerabilities.
---

# Windows UIAccess Admin Protection Bypass Research

A skill for security researchers investigating Windows UIAccess-based privilege escalation techniques, Admin Protection bypasses, and related integrity level manipulation vulnerabilities.

## Overview

Windows AppInfo exposes `RAiLaunchAdminProcess` to spawn UIAccess processes intended for accessibility software. UIAccess bypasses most User Interface Privilege Isolation (UIPI) message filtering, allowing accessibility tools to drive higher-IL UI. This skill covers the attack surface, bypass techniques, and defensive considerations.

## Core Mechanism

### AppInfo Service Checks

The AppInfo service performs three checks on a target binary before setting UIAccess:

1. **Embedded manifest** contains `uiAccess="true"`
2. **Signed** by any certificate trusted by the Local Machine root store (no EKU/Microsoft requirement)
3. **Located** in an administrator-only path on the system drive:
   - `C:\Windows`
   - `C:\Windows\System32`
   - `C:\Program Files`
   - `C:\Program Files (x86)`
   - Excludes specific writable subpaths

**Key insight**: `RAiLaunchAdminProcess` performs **no consent prompt** for UIAccess launches, otherwise accessibility tooling could not drive the prompt itself.

### Token Shaping and Integrity Levels

When checks succeed, AppInfo copies the caller token, enables UIAccess, and bumps Integrity Level (IL):

| Caller Context | Resulting IL |
|----------------|-------------|
| Limited admin (filtered) | **High IL** |
| Non-admin user | IL increased by **+16 levels** (capped at High) |
| Already has UIAccess | IL unchanged |

**Ratchet trick**: A UIAccess process can disable UIAccess on itself, relaunch via `RAiLaunchAdminProcess`, and gain another +16 IL increment. Medium➜High takes 255 relaunches (noisy but functional).

## Why UIAccess Enables Admin Protection Escape

UIAccess allows lower-IL processes to send window messages to higher-IL windows (bypassing UIPI filters). At **equal IL**, classic UI primitives like `SetWindowsHookEx` **do allow code injection/DLL loading** into any process that owns a window, including **message-only windows** used by COM.

Admin Protection launches the UIAccess process under the **limited user's identity** but at **High IL**, silently. Once arbitrary code runs inside that High-IL UIAccess process, the attacker can inject into other High-IL processes on the desktop (even belonging to different users), breaking the intended separation.

## HWND-to-Process Handle Primitive

### `GetProcessHandleFromHwnd` / `NtUserGetWindowProcessHandle`

On Windows 10 1803+, the API moved into Win32k (`NtUserGetWindowProcessHandle`) and can open a process handle using a caller-supplied `DesiredAccess`. The kernel path uses `ObOpenObjectByPointer(..., KernelMode, ...)`, which bypasses normal user-mode access checks.

**Preconditions in practice**:
- Target window must be on the same desktop
- UIPI checks must pass
- Historically, UIAccess could bypass UIPI failure and still get a kernel-mode handle (fixed as CVE-2023-41772)

**Impact**: A window handle becomes a **capability** to obtain powerful process handles (`PROCESS_DUP_HANDLE`, `PROCESS_VM_READ`, `PROCESS_VM_WRITE`, `PROCESS_VM_OPERATION`) that the caller could not normally open. This enables cross-sandbox access and can break Protected Process/PPL boundaries if the target exposes any window.

**Practical abuse flow**:
1. Enumerate or locate HWNDs (`EnumWindows`/`FindWindowEx`)
2. Resolve owning PID (`GetWindowThreadProcessId`)
3. Call `GetProcessHandleFromHwnd`
4. Use returned handle for memory read/write or code-hijack primitives

**Post-fix behavior**: UIAccess no longer grants kernel-mode opens on UIPI failure; allowed access rights restricted to legacy hook set. Windows 11 24H2 adds process-protection checks and feature-flagged safer paths.

## Secure Directory Validation Weaknesses

AppInfo resolves the supplied path via `GetFinalPathNameByHandle` and applies **string allow/deny checks** against hardcoded roots/exclusions. Multiple bypass classes stem from this simplistic validation:

### Bypass Classes

| Technique | Description |
|-----------|-------------|
| **Directory named streams** | Excluded writable directories (e.g., `C:\Windows\tracing`) bypassed with named stream on directory itself: `C:\Windows\tracing:file.exe`. String checks see `C:\Windows\` and miss excluded subpath. |
| **Writable file in allowed root** | `CreateProcessAsUser` does **not require `.exe` extension**. Overwriting any writable file under allowed root with executable payload works, or copying signed `uiAccess="true"` EXE into writable subdirectory (e.g., `Tasks_Migrated` when present). |
| **MSIX into WindowsApps** (fixed) | Non-admins could install signed MSIX packages landing in `WindowsApps` (not excluded). Packaging UIAccess binary inside MSIX then launching via `RAiLaunchAdminProcess` yielded **promptless High-IL UIAccess process**. Microsoft mitigated by excluding this path. |

## Attack Workflow (High IL Without Prompt)

1. **Obtain/build** a signed UIAccess binary (manifest `uiAccess="true"`)
2. **Place** where AppInfo's allowlist accepts it (or abuse path-validation edge case/writable artifact)
3. **Call** `RAiLaunchAdminProcess` to spawn silently with UIAccess + elevated IL
4. **From High-IL foothold**, target another High-IL process on desktop using window hooks/DLL injection or other same-IL primitives to fully compromise admin context

## Defensive Considerations

### Detection Indicators

- Unexpected `RAiLaunchAdminProcess` calls from non-accessibility applications
- New signed binaries in protected directories with `uiAccess="true"` manifests
- Unusual integrity level transitions in process creation events
- Named stream usage in `C:\Windows` or `C:\Program Files` paths
- High-IL processes spawning from low-IL parent contexts

### Mitigation Strategies

1. **Restrict code signing certificate usage** - Limit which binaries can be signed with trusted certificates
2. **Monitor protected directory writes** - Alert on modifications to `C:\Windows`, `C:\Program Files`
3. **Enable UIPI enforcement** - Ensure `EnforceUIPI=1` (disabling weakens protections)
4. **Audit AppInfo service activity** - Monitor for unusual `RAiLaunchAdminProcess` invocations
5. **Apply latest patches** - CVE-2023-41772 and subsequent fixes address specific bypass vectors
6. **Restrict named stream creation** - Block named streams in protected directories via policy

## Research and Testing

### Enumerating Candidate Writable Paths

Use the provided PowerShell helper to discover writable/overwritable objects inside nominally secure roots from the perspective of a chosen token:

```powershell
$paths = "C:\Windows","C:\Program Files","C:\Program Files (x86)"
Get-AccessibleFile -Win32Path $paths -Access Execute,WriteData `
  -DirectoryAccess AddFile -Recurse -ProcessId <PID>
```

- Run as Administrator for broader visibility
- Set `-ProcessId` to a low-priv process to mirror that token's access
- Filter manually to exclude known disallowed subdirectories before using candidates

### Script Usage

See `scripts/` directory for:
- `enumerate-writable-paths.ps1` - Path enumeration helper
- `analyze-uiaccess-manifest.py` - Manifest extraction and validation

## References

- [Bypassing Administrator Protection by Abusing UI Access](https://projectzero.google/2026/02/windows-administrator-protection.html)
- [GetProcessHandleFromHwnd (GPHFH) Deep Dive](https://projectzero.google/2026/02/gphfh-deep-dive.html)
- [Windows UI Access](https://learn.microsoft.com/en-us/windows/win32/winauto/uiauto)
- [User Interface Privilege Isolation](https://learn.microsoft.com/en-us/windows/win32/wtsapi/ui-pi)

## Important Notes

- This skill is for **defensive security research and authorized testing only**
- Always obtain proper authorization before testing on systems
- UIAccess bypasses require specific conditions (signed binary, protected path, manifest)
- Modern Windows versions have patched many of these vectors
- Focus on detection and hardening rather than exploitation
