---
name: apparmor-security
description: How to analyze, create, and test AppArmor security profiles on Linux systems. Use this skill whenever the user mentions AppArmor, Linux security profiles, Docker container security, mandatory access control (MAC), or needs to audit/modify program confinement policies. Also trigger when investigating privilege escalation paths, container escapes, or security hardening on Linux systems.
---

# AppArmor Security Analysis

A skill for analyzing, creating, and testing AppArmor security profiles on Linux systems.

## What is AppArmor

AppArmor is a **kernel enhancement that restricts program resources through per-program profiles**, implementing Mandatory Access Control (MAC) by tying access control attributes directly to programs instead of users.

**Key concepts:**
- Profiles are loaded into the kernel (usually at boot)
- Profiles dictate what resources a program can access (network, files, sockets)
- Two modes: **Enforcement** (blocks violations) and **Complain** (logs violations only)

## Quick Status Check

Start by checking what's currently confined:

```bash
sudo aa-status
```

This shows:
- How many profiles are loaded
- Which are in enforce mode vs complain mode
- Which binaries are restricted

**Profile naming convention:** Replace `/` with `.` in the binary path to find the profile file.
- Binary: `/usr/bin/man` → Profile: `/etc/apparmor.d/usr.bin.man`

## Core Commands

### Status and Mode Management

```bash
aa-status          # Check current status
aa-enforce <profile>   # Set profile to enforce mode
aa-complain <profile>  # Set profile to complain mode
```

### Profile Management

```bash
apparmor_parser -a <profile>   # Load profile in enforce mode
apparmor_parser -C <profile>   # Load profile in complain mode
apparmor_parser -r <profile>   # Replace existing profile
apparmor_parser -R <profile>   # Remove profile
```

### Profile Creation Tools

```bash
aa-genprof <binary>    # Interactive profile generation (inspect binary actions)
aa-easyprof <binary>   # Create template profile
aa-logprof             # Review logs and permit detected violations
aa-mergeprof           # Merge policies
```

## Creating Profiles

### Method 1: Interactive Generation (aa-genprof)

This is the most thorough approach - AppArmor inspects actual binary behavior:

1. Start the generator:
   ```bash
   sudo aa-genprof /path/to/binary
   ```

2. In a separate terminal, run the binary with typical operations:
   ```bash
   /path/to/binary -a dosomething
   ```

3. Return to the generator terminal:
   - Press `s` to review recorded actions
   - Use arrow keys to select: allow, deny, or ignore each action
   - Press `f` when finished to create the profile

The profile is saved to `/etc/apparmor.d/path.to.binary`

### Method 2: Template Creation (aa-easyprof)

Quick template generation:

```bash
sudo aa-easyprof /path/to/binary
```

This creates a basic profile structure. **Important:** By default, nothing is allowed - you must explicitly add permissions:

```apparmor
"/path/to/binary" {
  #include <abstractions/base>
  
  /etc/passwd r,           # Allow reading /etc/passwd
  /var/log/myapp.log w,    # Allow writing to log file
  /usr/bin/helper ix,      # Allow executing helper program
}
```

### Access Control Modifiers

| Modifier | Meaning |
|----------|----------|
| `r` | Read |
| `w` | Write |
| `m` | Memory map as executable |
| `k` | File locking |
| `l` | Create hard links |
| `ix` | Execute with policy inheritance |
| `Px` | Execute under another profile (cleaned env) |
| `Cx` | Execute under child profile (cleaned env) |
| `Ux` | Execute unconfined (cleaned env) |

### Profile Variables

Use variables for flexibility:

```apparmor
#include <tunables/global>

"/path/to/binary" {
  @{HOME}/** r,           # Read from user's home directory
  @{PROC}/** r,           # Read from /proc
}
```

## Analyzing Logs

### Audit Log Format

AppArmor violations appear in `/var/log/audit/audit.log`:

```bash
type=AVC msg=audit(1610061880.392:287): apparmor="DENIED" \
operation="open" profile="/bin/rcat" name="/etc/hosts" \
pid=954 comm="service_bin" requested_mask="r" denied_mask="r"
```

**Key fields:**
- `operation`: What action was attempted (open, getattr, etc.)
- `profile`: Which AppArmor profile was active
- `name`: Resource that was accessed
- `requested_mask`: What access was requested (r=read, w=write, etc.)
- `denied_mask`: What was actually denied

### Interactive Log Review

```bash
sudo aa-notify -s 1 -v
```

Shows recent denials in a readable format:

```
Profile: /bin/service_bin
Operation: open
Name: /etc/passwd
Denied: r
Logfile: /var/log/audit/audit.log
```

## AppArmor in Docker

### Default Docker Profile

Docker uses `docker-default` profile by default. Key restrictions:

- ✅ **Allowed:** All networking access
- ❌ **Denied:** Writing to `/proc` files
- ❌ **Denied:** Access to `/proc` and `/sys` subdirectories
- ❌ **Denied:** Mount operations
- ⚠️ **Limited:** Ptrace only on processes with same profile

**Important:** AppArmor blocks capabilities even if granted. Example:

```bash
# This fails - AppArmor blocks /proc write even with SYS_ADMIN
docker run -it --cap-add SYS_ADMIN ubuntu /bin/bash
echo "" > /proc/stat
# sh: 1: cannot create /proc/stat: Permission denied
```

### Running with Custom Profile

```bash
docker run --rm -it --security-opt apparmor:myprofile ubuntu /bin/bash
```

### Disabling AppArmor

```bash
docker run --rm -it --security-opt apparmor=unconfined ubuntu /bin/bash
```

### Finding Container's Profile

```bash
# Check which profile a container uses
docker inspect <container_id> | grep AppArmorProfile

# Find the profile file
find /etc/apparmor.d/ -name "*<profile_name>*" -maxdepth 1 2>/dev/null
```

## Security Testing Considerations

### Common Bypass Patterns

**1. Path-based bypass:** AppArmor is path-based. If `/proc` is protected but `/host/proc` is not:

```bash
# Mount host /proc to different path
docker run -v /proc:/host/proc ubuntu /bin/bash
# /host/proc may not be protected
```

**2. Shebang bypass:** Scripts with shebangs may execute under different profiles:

```bash
#!/usr/bin/perl
use POSIX qw(setuid);
POSIX::setuid(0);
exec "/bin/sh"
```

If you execute this script directly, it may run under the shell's profile, not perl's.

**3. Profile modification:** If you can modify and reload a profile:

```bash
# Edit profile to remove restrictions
sudo vim /etc/apparmor.d/docker-default

# Reload the modified profile
sudo apparmor_parser -r /etc/apparmor.d/docker-default
```

### When Exploits Fail

If you have a privileged capability inside Docker but an exploit isn't working, **AppArmor is likely blocking it**. Check:

```bash
sudo aa-status | grep docker
```

## Workflow Checklist

When analyzing AppArmor on a system:

1. **Check status:** `sudo aa-status`
2. **Identify target binary's profile:** Find in `/etc/apparmor.d/`
3. **Review profile contents:** `cat /etc/apparmor.d/<profile>`
4. **Check for denials:** `sudo aa-notify -s 1 -v`
5. **Test in complain mode:** `sudo aa-complain <profile>` (if you have access)
6. **Review audit logs:** `grep apparmor /var/log/audit/audit.log`

## Troubleshooting

**Profile not loading:**
```bash
# Check for syntax errors
sudo apparmor_parser -C /etc/apparmor.d/<profile>
```

**Binary not confined:**
```bash
# Verify profile is loaded
sudo aa-status | grep <binary_name>

# Check if profile is in complain mode (won't block)
```

**Need to debug:**
```bash
# Switch to complain mode to see what would be blocked
sudo aa-complain <profile>
# Run the binary
# Check logs
sudo aa-notify -s 1 -v
# Switch back to enforce
sudo aa-enforce <profile>
```
