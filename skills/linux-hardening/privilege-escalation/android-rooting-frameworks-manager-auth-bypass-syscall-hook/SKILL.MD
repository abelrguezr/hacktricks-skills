---
name: android-rooting-framework-security
description: Security analysis skill for Android rooting frameworks (KernelSU, Magisk, APatch, SKRoot). Use this skill when analyzing privilege escalation vulnerabilities in kernel-level rooting solutions, reviewing syscall hook authentication mechanisms, implementing secure manager authentication, or detecting suspicious prctl/syscall patterns on rooted devices. Trigger this skill for any security research, code review, or defensive analysis related to Android kernel modifications, su binaries, or privileged syscall channels.
---

# Android Rooting Framework Security Analysis

A skill for security researchers and defenders to analyze, understand, and mitigate privilege escalation vulnerabilities in Android rooting frameworks like KernelSU, Magisk, APatch, and SKRoot.

## What this skill covers

- Architecture patterns of syscall-hooked manager channels
- Authentication bypass vulnerability classes
- Code review for similar vulnerabilities
- Detection and mitigation strategies
- Secure implementation patterns

## Core vulnerability pattern: FD-based identity spoofing

### The problem

Rooting frameworks often authenticate userspace "manager" apps via a hooked syscall (commonly `prctl`). The authentication may rely on scanning the calling process's file descriptor table to find a matching APK and verify its signature.

**The flaw**: If the check binds to "the first matching APK" found in FD iteration rather than the caller's actual package identity, an attacker can pre-position a legitimately signed APK on a lower-numbered FD to impersonate the manager.

### Why this works

1. **FD scan doesn't bind to caller identity** - Only pattern-matches path strings like `/data/app/*/base.apk`
2. **`open()` returns lowest available FD** - By closing lower FDs first, attackers control ordering
3. **Path filter is naive** - Checks path pattern, not package ownership

## Architecture reference: Syscall-hooked manager channel

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Userspace App  │────▶│  Hooked Syscall  │────▶│  Kernel Handler │
│  (Manager)      │     │  (e.g., prctl)   │     │  (Rooting FW)   │
└─────────────────┘     └──────────────────┘     └─────────────────┘
         │                       │                        │
         │  magic_value          │                        │
         │  command_id           │                        │
         │  arg_ptr/len          │                        │
         │                       │                        │
         └───────────────────────┴────────────────────────┘
                              Protocol
```

**Typical protocol**:
- Magic value to divert to handler (e.g., `0xDEADBEEF`)
- Command IDs: `CMD_BECOME_MANAGER`, `CMD_GRANT_ROOT`, `CMD_SET_SEPOLICY`, etc.
- Once authenticated, privileged commands are accepted from that UID

## Vulnerability analysis checklist

When reviewing rooting framework code, check for:

### Authentication weaknesses

- [ ] Does authentication bind to caller's actual package/UID?
- [ ] Does it rely on FD table scanning for identity?
- [ ] Are path-prefix checks used as identity verification?
- [ ] Is there a race condition window (e.g., post-boot)?
- [ ] Does cached manager identity persist across reboots?

### Code patterns to flag

```c
// ❌ VULNERABLE: FD-based identity
for (fd = 0; fd < max_fd; fd++) {
    if (path_matches(fd, "/data/app/*/base.apk")) {
        verify_signature(fd);  // Not caller's APK!
        break;
    }
}

// ✅ SECURE: UID-based identity
uid_t caller_uid = current_uid();
struct package_info pkg = get_package_by_uid(caller_uid);
verify_signature(pkg.apk_path);
```

## Detection strategies

### Kernel-level monitoring

```bash
# Monitor for suspicious prctl magic values
# (requires kernel telemetry or eBPF)

# Example eBPF filter for prctl with 0xDEADBEEF
bpftrace -e 'tracepoint:syscalls:sys_enter_prctl /args.code == 0xDEADBEEF/ { printf("Suspicious prctl from %s (pid %d)\n", comm, pid); }'
```

### Userspace indicators

- Boot receivers from untrusted packages attempting privileged commands
- Multiple apps opening `/data/app/*/base.apk` paths
- Rapid `prctl` calls with non-standard magic values post-boot
- Unusual FD patterns in manager processes

### Framework presence detection

```bash
# Check for common rooting framework artifacts
ls /su/bin/su 2>/dev/null
ls /data/adb/ 2>/dev/null
ls /data/adb/modules/ 2>/dev/null
getprop ro.kernel.su 2>/dev/null
```

## Mitigation patterns

### For framework developers

1. **Bind to caller identity, not FDs**
   ```c
   // Use task credentials, not file descriptors
   uid_t caller_uid = current_cred()->uid.val;
   struct task_struct *task = current;
   // Verify against PackageManager or stable source
   ```

2. **Use challenge-response authentication**
   - Generate nonce on kernel side
   - Require signed response from manager
   - Invalidate nonce after use

3. **Clear cached identity on key events**
   - Reboot
   - Framework update
   - Manager app update

4. **Prefer binder IPC over syscall hooks**
   - Binder has built-in permission checks
   - More maintainable than syscall multiplexing

### For device defenders

1. **Block untrusted boot receivers**
   ```xml
   <!-- In device policy -->
   <deny-receiver package="!trusted_manager" action="BOOT_COMPLETED" />
   ```

2. **Monitor syscall patterns**
   - Alert on `prctl` with magic values outside standard range
   - Track manager authentication attempts

3. **Keep frameworks updated**
   - KernelSU v0.5.7+ has patches for FD-based auth
   - Magisk has addressed CVE-2024-48336

## Secure implementation example

```c
// Secure manager authentication pattern
int authenticate_manager(struct task_struct *task, const char *data_path) {
    uid_t caller_uid = task_cred_uid(task);
    
    // 1. Verify path ownership
    if (!path_owned_by(data_path, caller_uid)) {
        return -EPERM;
    }
    
    // 2. Get caller's actual package (not from FDs)
    struct package_info pkg = get_package_for_uid(caller_uid);
    if (!pkg.valid) {
        return -EPERM;
    }
    
    // 3. Verify signature against expected manager cert
    if (!verify_apk_signature(pkg.apk_path, EXPECTED_MANAGER_CERT)) {
        return -EPERM;
    }
    
    // 4. Challenge-response (optional but recommended)
    u32 nonce = generate_nonce();
    if (!verify_challenge_response(task, nonce)) {
        return -EPERM;
    }
    
    // 5. Cache with expiration
    cache_manager_uid(caller_uid, get_boot_time() + MANAGER_CACHE_TTL);
    return 0;
}
```

## Related vulnerabilities

| Framework | Issue | Reference |
|-----------|-------|----------|
| KernelSU v0.5.7 | FD-based auth bypass | Zimperium 2024 |
| Magisk | CVE-2024-48336 (MagiskEoP) | canyie/MagiskEoP |
| APatch/SKRoot | Weak password auth | Historical builds |

## Research resources

- [Zimperium – The Rooting of All Evil](https://zimperium.com/blog/the-rooting-of-all-evil-security-holes-that-could-compromise-your-mobile-device)
- [KernelSU source code](https://github.com/tiann/KernelSU)
- [MagiskEoP PoC](https://github.com/canyie/MagiskEoP)

## When to use this skill

- Reviewing rooting framework source code for security issues
- Analyzing privilege escalation on rooted Android devices
- Implementing secure authentication for kernel-userspace channels
- Building detection rules for rooted device monitoring
- Researching syscall hook security patterns
- Auditing Android device security posture

## Limitations

- This skill is for **defensive and educational purposes only**
- Exploitation requires already-rooted devices with vulnerable frameworks
- Most modern frameworks have patched known vulnerabilities
- Always test on your own devices with proper authorization

---

**Note**: This skill helps security professionals understand and defend against rooting framework vulnerabilities. Do not use for unauthorized access or exploitation.
