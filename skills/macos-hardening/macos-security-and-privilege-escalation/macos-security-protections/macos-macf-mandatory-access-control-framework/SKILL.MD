---
name: macos-macf-analysis
description: Analyze macOS Mandatory Access Control Framework (MACF) policies, kernel security extensions, and syscall hooks. Use this skill whenever the user mentions macOS security, MACF, kernel policies, sandbox analysis, AMFI, security kexts, or needs to understand how macOS enforces access control at the kernel level. Also trigger for tasks involving xnoop policy dumping, Info.plist security extension discovery, or analyzing XNU kernel source for MACF callouts.
---

# macOS MACF Analysis

A skill for analyzing macOS Mandatory Access Control Framework (MACF) policies, security extensions, and kernel-level access control mechanisms.

## What is MACF?

MACF (Mandatory Access Control Framework) is a security system built into macOS that intercepts kernel operations and delegates access decisions to policy modules (kernel extensions). It doesn't make decisions itself—it calls policy modules like:

- `AppleMobileFileIntegrity.kext` (AMFI)
- `Sandbox.kext`
- `Quarantine.kext`
- `TMSafetyNet.kext`
- `mcxalr.kext`

### Key Concepts

- **Static policies**: Installed at boot, never removed
- **Dynamic policies**: Loaded via kextload, can be unloaded
- **Enforcing policies**: Return non-zero to deny operations
- **Monitoring policies**: Return 0 but piggyback on hooks for logging/analysis

## MACF Flow

1. Process performs syscall/mach trap
2. Kernel function is called
3. Function calls MACF via `MAC_CHECK` macro
4. MACF iterates through registered policy modules
5. Each policy indicates allow/deny
6. Result is aggregated via `mac_error_select()`

## Finding Security Extension Kexts

Security extensions declare `<key>AppleSecurityExtension</key>` in their Info.plist. Find them with:

```bash
cd /System/Library/Extensions
find . -name Info.plist -exec grep -l "AppleSecurityExtension" {} \;
```

Or use the helper script:

```bash
./scripts/find-security-extensions.sh
```

## Analyzing MACF Policies with xnoop

Use xnoop to dump registered policies from memory:

```bash
xnoop offline .
Xn👀p> macp
```

This shows all registered policies with their names and operation vectors. To dump a specific policy's hooks:

```bash
Xn👀p> dump mac_policy_ops@<address>
```

## Understanding MACF Callouts

MACF callouts follow the pattern: `mac_<object>_<opType>_opName`

### Objects
- `bpfdesc`, `cred`, `file`, `proc`, `vnode`, `mount`, `devfs`
- `ifnet`, `inpcb`, `mbuf`, `ipq`, `pipe`
- `socket`, `kext`, `sysv`, `posix`

### Operation Types
- `check`: Allow or deny an action
- `notify`: React to an action (doesn't block)

### Example: mmap Check

```c
#if CONFIG_MACF
error = mac_file_check_mmap(vfs_context_ucred(ctx),
    fp->fp_glob, prot, flags, file_pos + pageoff,
    &maxprot);
if (error) {
    (void)vnode_put(vp);
    goto bad;
}
#endif
```

## MAC_CHECK vs MAC_GRANT

### MAC_CHECK (Deny by Default)
- Iterates all policies
- Any non-zero return = deny
- Used for access control checks

### MAC_GRANT (Grant by Default)
- Iterates all policies
- Any zero return = grant
- Used for privilege granting

## Exposed MACF Syscalls

Userland can interact with MACF via private syscalls:

| Syscall | Purpose |
|---------|--------|
| `__mac_execve` | Execute with custom label |
| `__mac_get_fd` | Get file descriptor label |
| `__mac_get_file` | Get file label |
| `__mac_get_pid` | Get process label |
| `__mac_set_file` | Set file label |
| `__mac_syscall` | Policy-specific ioctl |

## KPI Dependencies

Kexts using MACF must declare `com.apple.kpi.dsep` in Info.plist:

```xml
<key>OSBundleLibraries</key>
<dict>
  <key>com.apple.kpi.dsep</key>
  <string>18.0</string>
  <key>com.apple.kpi.libkern</key>
  <string>18.0</string>
</dict>
```

## Common Analysis Tasks

### 1. List All Security Extensions

```bash
./scripts/find-security-extensions.sh
```

### 2. Check Kext Dependencies

```bash
./scripts/check-kext-kpi.sh <path-to-kext>
```

### 3. Find MACF Callouts in Source

Search XNU source for `#if CONFIG_MACF` blocks to find all MACF integration points.

### 4. Analyze Policy Hooks

Use xnoop to dump `mac_policy_ops` structures and see which hooks each policy implements.

## References

- [XNU Source - security/mac_internal.h](https://github.com/apple-oss-distributions/xnu/security/mac_internal.h)
- [XNU Source - security/mac_policy.h](https://github.com/apple-oss-distributions/xnu/security/mac_policy.h)
- [*OS Internals Volume III](https://newosxbook.com/home.html)

## When to Use This Skill

Use this skill when you need to:
- Understand how macOS enforces security at the kernel level
- Analyze sandbox policies or AMFI behavior
- Debug why a process is being denied access
- Research macOS security mechanisms
- Find security extension kexts on a system
- Analyze XNU kernel source for MACF integration
- Work with xnoop to dump policy information
- Understand syscall filtering and privilege checks
