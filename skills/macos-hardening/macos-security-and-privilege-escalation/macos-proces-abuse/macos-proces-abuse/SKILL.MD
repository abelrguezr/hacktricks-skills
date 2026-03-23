---
name: macos-process-abuse
description: macOS process abuse and injection techniques for security research. Use this skill when investigating macOS privilege escalation, analyzing process injection vectors, researching library injection, function hooking, IPC abuse, or application-specific injection methods (Electron, Chromium, Java, .NET, Python, Ruby, Perl). Also use for understanding macOS process/thread internals, credentials/persona system, or when detecting process injection attacks. Make sure to use this skill for any macOS security research involving process manipulation, code injection, or privilege escalation techniques.
---

# macOS Process Abuse Research

This skill provides comprehensive guidance on macOS process abuse techniques for **authorized security research and penetration testing only**. All techniques should only be used on systems you own or have explicit written permission to test.

## Core Concepts

### Process Fundamentals

Processes are containers for running threads, providing memory, descriptors, ports, and permissions. Understanding the process lifecycle is essential:

- **fork()**: Creates an exact copy of the current process
- **execve()**: Loads a new executable in the child process
- **vfork()**: Faster fork without memory copying
- **posix_spawn()**: Combines vfork and execve with flags

### Key posix_spawn Flags

| Flag | Purpose |
|------|--------|
| `POSIX_SPAWN_RESETIDS` | Reset effective IDs to real IDs |
| `POSIX_SPAWN_SETPGROUP` | Set process group affiliation |
| `POSIX_SPAWN_SETSIGDEF` | Set signal default behavior |
| `POSIX_SPAWN_SETSIGMASK` | Set signal mask |
| `POSIX_SPAWN_SETEXEC` | Exec in same process |
| `POSIX_SPAWN_START_SUSPENDED` | Start suspended |
| `_POSIX_SPAWN_DISABLE_ASLR` | Start without ASLR |
| `_POSIX_SPAWN_ALLOW_DATA_EXEC` | Allow rwx on data segments |
| `POSIX_SPAWN_CLOEXEC_DEFAULT` | Close all FDs on exec by default |

### Process Identification

- **PIDs**: 64-bit, monotonically increasing, never wrap (XNU kernel)
- **Process Groups**: Group processes for collective signaling
- **Sessions**: Created via `setsid(2)`, children inherit unless they create their own
- **Coalitions**: Darwin-specific grouping for resource sharing (Leader, XPC service, Extension roles)

### Credentials & Personae

Each process holds credentials identifying its privileges:
- Primary `uid` and `gid` (can belong to multiple groups)
- `setuid/setgid` bits can change user/group IDs
- **`persona` syscall**: Provides alternate credential set

```c
struct kpersona_info {
    uint32_t persona_info_version;
    uid_t    persona_id;      /* overlaps with UID */
    int      persona_type;
    gid_t    persona_gid;
    uint32_t persona_ngroups;
    gid_t    persona_groups[NGROUPS];
    uid_t    persona_gmuid;
    char     persona_name[MAXLOGNAME + 1];
}
```

## Thread Internals

### Thread Creation & Management

1. **POSIX Threads (pthreads)**: Implemented in `/usr/lib/system/libsystem_pthread.dylib`
2. **pthread_create()**: Calls `bsdthread_create()` (XNU-specific syscall)
3. **Default Stack Size**: 512 KB (adjustable via thread attributes)
4. **Thread Initialization**: `__pthread_init()` parses environment variables

### Thread Termination

- **pthread_exit()**: Clean exit with return value
- **pthread_terminate()**: Removes thread structures, deallocates Mach ports
- **bsdthread_terminate**: Syscall removing kernel-level structures

### Synchronization Primitives

| Primitive | Signature | Size | Purpose |
|-----------|-----------|------|--------|
| Regular Mutex | 0x4D555458 | 60 bytes | Standard mutex |
| Fast Mutex | 0x4d55545A | 60 bytes | Optimized mutex |
| Condition Variable | 0x434e4441 | 44 bytes | Wait for conditions |
| Once Variable | 0x4f4e4345 | 12 bytes | Execute once |
| Read-Write Lock | 0x52574c4b | 196 bytes | Multiple readers/single writer |

> **Note**: Last 4 bytes of these objects detect overflows.

### Thread Local Variables (TLV)

```c
__thread int tlv_var;  // Each thread has its own instance
```

Mach-O sections:
- `__DATA.__thread_vars`: Metadata about TLVs
- `__DATA.__thread_bss`: Zero-initialized TLVs
- **`tlv_atexit`**: Register destructors for thread cleanup

### Thread Priorities

#### Nice Values
- Range: -20 (highest) to 19 (lowest)
- Default: 0
- Use `renice` to modify running processes

#### Quality of Service (QoS) Classes

| Class | Priority | Use Case |
|-------|----------|----------|
| User Interactive | Highest | UI responsiveness, animations |
| User Initiated | High | User-triggered computations |
| Utility | Medium | Long-running with progress indicator |
| Background | Lowest | Indexing, syncing, backups |

Use `thread_policy_[set/get]` for scheduling policies.

## Process Abuse Techniques

### 1. Library Injection

Forces a process to load a malicious library, running in the target's context with same permissions.

**Key Environment Variables:**
- `DYLD_INSERT_LIBRARIES`
- `CFNETWORK_LIBRARY_PATH`
- `RAWCAMERA_BUNDLE_PATH`

**Detection:** Monitor these variables and `task_for_pid` calls.

### 2. Function Hooking

Intercepts function calls to modify behavior, observe data, or control execution flow.

**Common Targets:**
- System calls
- Library functions
- Application entry points

### 3. Inter-Process Communication (IPC) Abuse

Misuses IPC mechanisms to:
- Subvert process isolation
- Leak sensitive information
- Perform unauthorized actions

### 4. Electron Application Injection

**Vulnerable Parameters:**
- `--inspect`
- `--inspect-brk`
- `--remote-debugging-port`
- `ELECTRON_RUN_AS_NODE` environment variable

**Attack Vector:** Start Electron apps in debugging mode to inject code.

### 5. Chromium/Browser Injection

**Flags for Man-in-the-Browser Attacks:**
- `--load-extension`: Load malicious extensions
- `--use-fake-ui-for-media-stream`: Bypass media permissions

**Capabilities:**
- Steal keystrokes
- Intercept traffic
- Steal cookies
- Inject scripts into pages

### 6. Dirty NIB

NIB files define UI elements but can execute arbitrary commands.

**Key Points:**
- Gatekeeper doesn't stop modified NIB files in running apps
- Can make arbitrary programs execute arbitrary commands
- Target: `.nib` files in application bundles

### 7. Java Application Injection

**Environment Variable:** `_JAVA_OPTS`

**Capabilities:** Execute arbitrary code/commands through Java configuration.

### 8. .NET Application Injection

**Method:** Abuse .NET debugging functionality

**Note:** Not protected by macOS runtime hardening.

### 9. Perl Injection

Various Perl environment variables and configuration options can execute arbitrary code.

### 10. Ruby Injection

Ruby environment variables can be abused to execute arbitrary scripts.

### 11. Python Injection

**Environment Variables:**
- `PYTHONINSPECT`: Drops to Python CLI on completion
- `PYTHONSTARTUP`: Executes script at interactive session start
- `PYTHONPATH`: Modify import path
- `PYTHONHOME`: Set Python home directory

**Important Notes:**
- `PYTHONSTARTUP` won't execute when `PYTHONINSPECT` creates interactive session
- PyInstaller-compiled executables don't use these environment variables

**Alternative Attack Vector:**
```bash
# Hijack Homebrew Python (writable location)
mv /opt/homebrew/bin/python3 /opt/homebrew/bin/python3.old
cat > /opt/homebrew/bin/python3 <<EOF
#!/bin/bash
# Extra hijack code
/opt/homebrew/bin/python3.old "$@"
EOF
chmod +x /opt/homebrew/bin/python3
```

> **Warning:** Even root will run this code when running Python.

## Detection Methods

### Shield Framework

[Shield](https://theevilbit.github.io/shield/) detects and blocks process injection:

**Monitored Indicators:**
1. **Environment Variables:**
   - `DYLD_INSERT_LIBRARIES`
   - `CFNETWORK_LIBRARY_PATH`
   - `RAWCAMERA_BUNDLE_PATH`
   - `ELECTRON_RUN_AS_NODE`

2. **`task_for_pid` Calls:** Detects processes requesting task ports of others

3. **Electron Debug Parameters:**
   - `--inspect`
   - `--inspect-brk`
   - `--remote-debugging-port`

4. **Symlink/Hardlink Abuse:** Alerts when link creator has different privilege level than target

### Process Self-Detection

Use `task_name_for_pid` to identify processes injecting code:

**Requirements:**
- Same UID as target process, OR
- Root privileges

**Returns:** Information about the injecting process (not injection capability)

## Research Workflow

### Before Testing

1. **Verify Authorization**: Ensure you have explicit written permission
2. **Document Scope**: Define what systems and techniques are in scope
3. **Backup Systems**: Create snapshots before testing
4. **Set Up Isolation**: Use VMs or isolated environments

### During Testing

1. **Start with Reconnaissance**: Understand the target system
2. **Test Detection First**: Verify monitoring is in place
3. **Document Everything**: Log all commands and observations
4. **Test One Technique at a Time**: Isolate effects

### After Testing

1. **Clean Up**: Remove any injected code or modified files
2. **Report Findings**: Document vulnerabilities and remediation
3. **Review Logs**: Check for detection gaps

## Safety Guidelines

**⚠️ CRITICAL: Only use these techniques on systems you own or have explicit written authorization to test.**

- Unauthorized use is illegal and unethical
- These techniques can cause system instability
- Always have a rollback plan
- Test in isolated environments first
- Document all activities for accountability

## References

- [Shield Project](https://theevilbit.github.io/shield/)
- [Shield GitHub](https://github.com/theevilbit/Shield)
- [Detecting Task Modifications](https://knight.sc/reverse%20engineering/2019/04/15/detecting-task-modifications.html)
- [Electron Security](https://medium.com/@metnew/why-electron-apps-cant-store-your-secrets-confidentially-inspect-option-a49950d6d51f)
- [XNU Persona Source](https://github.com/apple/darwin-xnu/blob/main/bsd/sys/persona.h)
