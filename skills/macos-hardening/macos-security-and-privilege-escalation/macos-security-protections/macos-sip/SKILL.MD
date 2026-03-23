---
name: macos-sip-analysis
description: Analyze macOS System Integrity Protection (SIP) status, identify potential bypass vectors, and assess system security posture. Use this skill whenever the user mentions macOS security, SIP, System Integrity Protection, privilege escalation on macOS, checking system protections, analyzing SIP bypasses, or needs to understand macOS security mechanisms. Trigger for any macOS security assessment, penetration testing, or system hardening tasks.
---

# macOS SIP Analysis Skill

This skill helps analyze macOS System Integrity Protection (SIP) configurations, identify potential security gaps, and understand bypass vectors for security assessments.

## When to Use This Skill

Use this skill when:
- Assessing macOS system security posture
- Checking SIP status and configuration
- Identifying potential SIP bypass vectors
- Understanding macOS privilege escalation paths
- Analyzing Sealed System Snapshots
- Performing macOS penetration testing
- Reviewing system hardening requirements

## Core Concepts

### What is SIP?

System Integrity Protection (SIP) is a macOS security mechanism that prevents even root users from modifying protected system files and directories. Key protected paths include:

- `/System`
- `/bin`
- `/sbin`
- `/usr`

SIP rules are defined in `/System/Library/Sandbox/rootless.conf`. Paths prefixed with `*` are exceptions where modifications are allowed.

### SIP Status Commands

```bash
# Check if SIP is enabled
csrutil status

# Check authenticated root status (for sealed snapshots)
csrutil authenticated-root status

# Check mount status (read-only sealed volumes)
mount | grep -E "(sealed|read-only)"
```

### Identifying SIP Protection

Use `ls -lOd` to check for protection flags:

```bash
# Check directory protection status
ls -lOd /usr/libexec/cups
ls -lOd /usr/libexec
```

**Flag meanings:**
- `restricted`: Directory is SIP-protected (no create/modify/delete)
- `sunlnk`: Directory cannot be deleted, but files inside can be modified
- `com.apple.rootless` extended attribute: File is SIP-protected

## SIP Bypass Vectors

### 1. Installer Package Bypasses

Apple-signed installer packages can bypass SIP protections. Notable vulnerabilities:

- **CVE-2019-8561**: Package swap after signature verification
- **CVE-2020-9854**: Arbitrary binary execution from mounted images
- **CVE-2021-30892 (Shrootless)**: `/etc/zshenv` execution via `system_installd`
- **CVE-2022-22583**: Virtual image mounting in `/tmp` for post-install scripts
- **CVE-2023-42860**: Symlink-based file unrestricting

### 2. Entitlement-Based Bypasses

Key SIP-bypassing entitlements:

- `com.apple.rootless.install.heritable`: Child processes inherit SIP bypass
- `com.apple.rootless.install`: Direct SIP bypass
- `com.apple.rootless.xpc.bootstrap`: Control launchd
- `com.apple.rootless.internal.installer-equivalent`: Unfettered filesystem access

### 3. File System Manipulation

- **Inexistent files**: Files listed in `rootless.conf` but not present can be created
- **Mount over protected folders**: Mount filesystems over SIP-protected paths
- **fsck_cs vulnerability**: Symbolic link corruption of `Info.plist`

### 4. Environment Variable Exploitation

- **`/etc/zshenv`**: Executed by `zsh` in non-interactive mode
- **`~/.zshenv`**: User-level persistence and privilege escalation
- **`BASH_ENV`**: Bash environment variable exploitation
- **`PERL5OPT`**: Perl script injection

## Sealed System Snapshots

Introduced in macOS Big Sur (11.0), Sealed System Snapshots provide additional protection:

### Key Features

1. **Immutable System**: System volume cannot be modified
2. **Safe Updates**: New snapshots created for each update
3. **Data Separation**: Data stored on separate volume

### Checking Snapshots

```bash
# List APFS volumes and snapshots
diskutil apfs list

# Check for sealed status
mount | grep "sealed"

# Verify authenticated root
csrutil authenticated-root status
```

### Important Paths

- System volume: `/` (sealed, read-only)
- Data volume: `/System/Volumes/Data` (user-accessible)
- Update mount: `/System/Volumes/Update/mnt1`

## Security Assessment Checklist

When assessing macOS SIP security:

1. **Check SIP Status**
   - Run `csrutil status`
   - Verify `csrutil authenticated-root status`

2. **Analyze Protected Paths**
   - Check `/System/Library/Sandbox/rootless.conf` for exceptions
   - Identify `restricted` and `sunlnk` flags on key directories

3. **Identify Bypass Opportunities**
   - Check for Apple-signed packages that could be exploited
   - Look for `/etc/zshenv` or `~/.zshenv` files
   - Verify no symbolic links to protected files

4. **Review Entitlements**
   - Check for processes with `com.apple.rootless.*` entitlements
   - Identify XPC services with SIP-bypassing capabilities

5. **Assess Snapshot Integrity**
   - Verify snapshots are sealed
   - Check mount status for read-only protection

## Common Commands Reference

```bash
# SIP Status
csrutil status
csrutil authenticated-root status

# Directory Protection
ls -lOd /usr/libexec
ls -lOd /System/Library/Sandbox/rootless.conf

# Snapshot Analysis
diskutil apfs list
mount | grep -E "(sealed|read-only)"

# Check for zshenv files
ls -la /etc/zshenv
ls -la ~/.zshenv

# Check extended attributes
xattr -l /path/to/file | grep rootless
```

## Important Notes

- **SIP cannot be disabled without recovery mode**: Requires `Command+R` at boot, then `csrutil disable`
- **Sealed snapshots prevent boot if modified**: OS won't boot if sealed snapshot is tampered with
- **Partial SIP disabling**: `csrutil enable --without debug` keeps SIP but removes debugging protections
- **Sandbox hooks**: `hook_vnode_check_setextattr` prevents modification of `com.apple.rootless` attribute

## When NOT to Use This Skill

- For general macOS troubleshooting unrelated to security
- For user data recovery tasks
- For application installation guidance
- For non-security-related system configuration

## Related Security Concepts

- **TCC (Transparency, Consent, and Control)**: macOS privacy database that can be manipulated via SIP bypass
- **Kernel Extensions**: SIP prevents loading unsigned kexts
- **NVRAM Variables**: SIP restricts modification of boot-related variables
- **Task Ports**: SIP prevents getting task-ports for Apple-signed processes
