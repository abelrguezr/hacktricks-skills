---
name: macos-sandbox
description: macOS Sandbox security expert. Use this skill whenever the user asks about macOS sandboxing, sandbox profiles, SBPL, sandbox-exec, container inspection, sandbox extensions, or any macOS security isolation mechanism. Trigger for questions about sandbox bypasses, profile creation, process inspection, or debugging sandboxed applications.
---

# macOS Sandbox Security

A comprehensive guide to understanding, working with, and debugging macOS Sandbox security mechanisms.

## What is macOS Sandbox?

macOS Sandbox (originally called Seatbelt) **limits applications** to only the **allowed actions specified in their Sandbox profile**. This ensures applications access only expected resources.

**Key facts:**
- Any app with entitlement `com.apple.security.app-sandbox` runs inside the sandbox
- All App Store apps have this entitlement
- Apple binaries are usually sandboxed
- Uses MACF (Mandatory Access Control Framework) hooks for most syscalls

## Core Components

| Component | Path | Purpose |
|-----------|------|--------|
| Kernel Extension | `/System/Library/Extensions/Sandbox.kext` | Core sandbox enforcement |
| Private Framework | `/System/Library/PrivateFrameworks/AppSandbox.framework` | Sandbox APIs |
| Daemon | `/usr/libexec/sandboxd` | Userland sandbox manager |
| Containers | `~/Library/Containers` | App-specific isolated directories |

## Understanding Containers

Every sandboxed application has its own container:

```bash
# List all containers
ls -l ~/Library/Containers

# Inspect a specific container
cd ~/Library/Containers/{CFBundleIdentifier}
ls -la
```

**Container structure:**
- `.com.apple.containermanagerd.metadata.plist` - Container configuration
- `Data/` - App data directory (mimics home folder structure)

**Important:** Even with symlinks to Desktop, Downloads, etc., the app needs explicit permissions in the `.plist` file's `RedirectablePaths` to access them.

## Sandbox Profiles (SBPL)

Sandbox profiles use **Sandbox Profile Language (SBPL)**, based on Scheme:

```scheme
(version 1)                    ; Profile version
(deny default)                 ; Default action when no rule matches
(allow network*)               ; Allow all network operations
(allow file-read*              ; Allow file reads from:
    (subpath "/Users/username/")
    (literal "/tmp/afile")
    (regex #"^/private/etc/.*")
)
(allow mach-lookup             ; Allow specific Mach port
    (global-name "com.apple.analyticsd")
)
```

**Common operations:**
- `file*` - All file operations
- `file-read*` - File read operations
- `file-write*` - File write operations
- `process*` - Process execution
- `network*` - Network operations
- `mach-lookup` - Mach port access

## Creating and Testing Sandbox Profiles

### Basic Profile Creation

```bash
# Create a profile file
cat > /tmp/test.sb << 'EOF'
(version 1)
(deny default)
(allow file* (literal "/tmp/test.txt"))
(allow process* (literal "/usr/bin/touch"))
(allow file-read-data (literal "/"))
EOF

# Run command with profile
sandbox-exec -f /tmp/test.sb /usr/bin/touch /tmp/test.txt
```

### Common Profile Patterns

**Minimal network access:**
```scheme
(version 1)
(deny default)
(allow network-client-connect)
(allow file-read* (subpath "~/"))
```

**File server (read-only):**
```scheme
(version 1)
(deny default)
(allow network-server)
(allow file-read* (subpath "/var/www/"))
```

**Development with temp access:**
```scheme
(version 1)
(deny default)
(allow file* (subpath "/tmp/"))
(allow file* (subpath "~/Downloads/"))
(allow process-exec (subpath "/usr/bin/"))
```

## Inspecting Sandboxed Processes

### Using sbtool

```bash
# Check if PID can access a file
sbtool <pid> file /tmp

# Check Mach port access
sbtool <pid> mach

# Full inspection of sandbox state
sbtool <pid> inspect

# Check all permissions
sbtool <pid> all
```

### Using log show

```bash
# View recent sandbox denials
log show --style syslog --predicate 'eventMessage contains[c] "sandbox"' --last 30s

# Filter for specific process
log show --predicate 'processImagePath contains "AppName" and eventMessage contains "sandbox"' --last 1h
```

### Container Configuration

```bash
# Get container metadata (requires FDA)
plutil -convert xml1 ~/Library/Containers/{bundle-id}/.com.apple.containermanagerd.metadata.plist -o -

# Look for:
# - SandboxProfileData (compiled profile)
# - Entitlements (granted permissions)
# - RedirectablePaths (accessible paths)
```

## Sandbox Tracing

### Via Profile

```bash
# Create trace profile
cat > /tmp/trace.sb << 'EOF'
(version 1)
(trace /tmp/trace.out)
EOF

# Run with tracing
sandbox-exec -f /tmp/trace.sb /bin/ls

# View trace output
cat /tmp/trace.out
```

### Via Command Line

```bash
# Inline trace
sandbox-exec -t /tmp/trace.out -p "(version 1)" /bin/ls
```

## System Sandbox Profiles

**Locations:**
- `/usr/share/sandbox/` - System profiles
- `/System/Library/Sandbox/Profiles/` - Application profiles
- `/System/Library/Sandbox/rootless.conf` - SIP platform profile

**Common profiles:**
- `application.sb` - Default App Store app profile
- `platform.sb` - Platform policy (SIP)
- `*.sb` - Various system daemon profiles

## Sandbox Extensions

Extensions grant additional privileges to sandboxed processes:

**Extension types:**
- `sandbox_extension_issue_file` - File access
- `sandbox_extension_issue_mach` - Mach port access
- `sandbox_extension_issue_iokit_user_client_class` - I/O Kit access
- `sandbox_extension_issue_generic` - Generic extension

**Key points:**
- Extensions are usually granted by allowed processes (e.g., `tccd` for photos)
- Extension tokens are long hex strings encoding permissions
- Tokens can be consumed by multiple processes
- Related to entitlements - some entitlements auto-grant extensions

## Debugging Sandbox Issues

### Common Problems and Solutions

**Problem:** Command fails with "deny(1) process-exec*"
**Solution:** Add `(allow process* (literal "/path/to/command"))`

**Problem:** File access denied
**Solution:** Add appropriate file permission:
```scheme
(allow file-read-data (literal "/path/to/file"))
(allow file-write-data (literal "/path/to/file"))
```

**Problem:** Dynamic library loading fails
**Solution:** Add dyld and library paths:
```scheme
(allow file-read-data (literal "/usr/lib/dyld"))
(allow file-read-data (literal "/usr/lib/"))
```

### Debug Workflow

1. **Check the denial:**
   ```bash
   log show --predicate 'eventMessage contains "sandbox"' --last 1m
   ```

2. **Identify the operation:**
   - `process-exec*` - Need process permission
   - `file-read-metadata` - Need file read permission
   - `file-read-data` - Need file data permission

3. **Add minimal permission:**
   Start with `(deny default)` and add only what's needed

4. **Test incrementally:**
   Add one permission at a time to identify what's required

## Security Considerations

### Quarantine Attribute

Files created/modified by sandboxed apps get the quarantine attribute, preventing Gatekeeper bypass:

```bash
# Check quarantine attribute
xattr -l /path/to/file | grep com.apple.quarantine

# Remove quarantine (if needed)
xattr -d com.apple.quarantine /path/to/file
```

### Entitlements

Key entitlements:
- `com.apple.security.app-sandbox` - Enables sandboxing
- `com.apple.security.network.server` - Network server access
- `com.apple.security.temporary-exception.sbpl` - Custom SBPL (Apple-approved only)
- `keychain-access-groups` - Keychain access

### SIP Integration

System Integrity Protection uses sandbox:
- Platform profile in `/System/Library/Sandbox/rootless.conf`
- Protects system directories
- Cannot be disabled without boot flags

## Quick Reference

| Task | Command |
|------|--------|
| Run with profile | `sandbox-exec -f profile.sb /path/to/app` |
| Run with inline profile | `sandbox-exec -p "(version 1)..." /path/to/app` |
| Trace sandbox checks | `sandbox-exec -t trace.out -f profile.sb /path/to/app` |
| Inspect process | `sbtool <pid> inspect` |
| View sandbox logs | `log show --predicate 'eventMessage contains "sandbox"'` |
| List containers | `ls ~/Library/Containers` |
| View container config | `plutil -convert xml1 container/.com.apple.containermanagerd.metadata.plist -o -` |

## Best Practices

1. **Start restrictive:** Begin with `(deny default)` and add permissions as needed
2. **Use literals over wildcards:** More specific = more secure
3. **Test incrementally:** Add one permission at a time
4. **Check logs:** Always verify what's being denied
5. **Document profiles:** Comment your SBPL files
6. **Review extensions:** Understand what extensions your app needs

## References

- [OS Internals Volume III](https://newosxbook.com/home.html)
- [Apple Sandbox Guide](https://reverse.put.as/2011/09/14/apple-sandbox-guide-v1-0/)
- [OSX Sandbox Profiles](https://github.com/s7ephen/OSX-Sandbox--Seatbelt--Profiles)
- [Sandbox Escape Research](https://lapcatsoftware.com/articles/sandbox-escape.html)
