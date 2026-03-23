---
name: docker-user-namespace
description: How to work with Linux user namespaces for Docker security testing and privilege escalation analysis. Use this skill whenever the user mentions user namespaces, UID/GID mapping, container isolation, Docker security, namespace enumeration, or wants to understand how user namespaces work for privilege escalation. This includes creating namespaces, checking mappings, entering namespaces, and understanding capability implications.
---

# Docker User Namespace Security

A skill for working with Linux user namespaces in Docker security testing and privilege escalation scenarios.

## What User Namespaces Do

User namespaces provide **isolation of user and group ID mappings**, allowing each namespace to have its own set of UIDs/GIDs. This enables:

- Processes in different namespaces to have different privileges despite sharing the same numeric IDs
- Containers to run with root-like capabilities (UID 0) inside the namespace without full root on the host
- Fine-grained control over privileges through restricted ID mapping ranges

## Key Commands

### Create a User Namespace

```bash
# Basic user namespace with bash
sudo unshare -U /bin/bash

# With mounted /proc for accurate process view
sudo unshare -U --mount-proc /bin/bash

# With fork (prevents PID allocation errors)
sudo unshare -fU /bin/bash

# With user mapping to nobody
sudo unshare -U --map-user=nobody /bin/bash

# With current user mapping
sudo unshare -U --map-current-user /bin/bash
```

### Check Your Current Namespace

```bash
# See which user namespace you're in
ls -l /proc/self/ns/user
# Output: user:[4026531837]

# Check UID mappings from inside container
cat /proc/self/uid_map
# Format: container_uid host_uid count
# Example: 0 0 4294967295  --> Root is root on host
# Example: 0 231072 65536  --> Root maps to 231072 on host

# Check from host for a specific process
cat /proc/<pid>/uid_map
```

### Find All User Namespaces on Host

```bash
# List all unique user namespaces
sudo find /proc -maxdepth 3 -type l -name user -exec readlink {} \; 2>/dev/null | sort -u

# Find processes in a specific namespace
sudo find /proc -maxdepth 3 -type l -name user -exec ls -l {} \; 2>/dev/null | grep <ns-number>
```

### Enter Another User Namespace

```bash
# Enter namespace of target process (requires root)
nsenter -U <TARGET_PID> --pid /bin/bash

# Alternative with namespace file descriptor
nsenter --user /proc/<pid>/ns/user --pid /bin/bash
```

### Docker User Namespace Configuration

```bash
# Run container with volume mount
docker run -ti --name ubuntu1 -v /usr:/ubuntu1 ubuntu bash

# Enable user namespace remapping in Docker daemon
# Edit /etc/default/docker and add:
DOCKER_OPTS="--userns-remap=default"
sudo service docker restart
```

## Security Implications

### Capability Recovery

When entering a new user namespace, **you regain all capabilities** (CapEff: 000001ffffffffff) **within that namespace**. However:

- You can only use capabilities **related to the namespace** (e.g., mount filesystems)
- You **cannot** use capabilities that affect the host or other namespaces
- This alone is **not sufficient** for Docker container escape

### ID-Mapped Mounts

ID-mapped mounts attach user namespace mappings to mounts, remapping file ownership when accessed through that mount:

- **Does not change on-disk ownership**
- Makes files appear owned by your mapped UID/GID within the namespace
- Requires `CAP_SYS_ADMIN` in your user namespace
- Useful for rootless containers to share host paths without recursive `chown`

### Unprivileged UID/GID Mapping Rules

When writing to `uid_map`/`gid_map` **without CAP_SETUID/CAP_SETGID** in the parent namespace:

1. Only a **single mapping** is allowed for the caller's effective UID/GID
2. For `gid_map`, you **must first disable `setgroups(2)`**:

```bash
# Check setgroups status
cat /proc/self/setgroups  # Returns: allow|deny

# Disable setgroups for unprivileged gid_map writes
echo deny > /proc/self/setgroups
```

## Common Patterns

### Pattern 1: Enumerate Namespaces

```bash
# Quick namespace enumeration
for ns in $(find /proc -maxdepth 3 -type l -name user 2>/dev/null); do
  readlink "$ns"
  echo "---"
done | sort -u
```

### Pattern 2: Check Namespace Isolation

```bash
# Inside container: check if root is root on host
cat /proc/self/uid_map | grep "^0[[:space:]]*0[[:space:]]"
# If found: root is root on host (no isolation)
# If not found: root is remapped (isolated)
```

### Pattern 3: Test Capability Scope

```bash
# Enter namespace and test capabilities
unshare -U --mount-proc /bin/bash

# Check effective capabilities
cat /proc/self/status | grep Cap

# Try operations that require specific capabilities
# (e.g., mount, create devices) - will work only if namespace-scoped
```

## Troubleshooting

### "Cannot allocate memory" Error

When `unshare` fails with `bash: fork: Cannot allocate memory`:

**Cause**: The process creating the namespace doesn't enter it; only children do. When PID 1 exits, the namespace cleans up and disables PID allocation.

**Solution**: Use the `-f` flag to fork after creating the namespace:

```bash
# Wrong (may fail)
unshare -p /bin/bash

# Correct
unshare -fp /bin/bash
```

### Cannot Enter Namespace

**Requirements**:
- You must be **root** to enter another process's namespace
- You need a **descriptor** pointing to the namespace (e.g., `/proc/self/ns/user`)

## References

- [Linux User Namespaces Manual](https://man7.org/linux/man-pages/man7/user_namespaces.7.html)
- [mount_setattr Manual](https://man7.org/linux/man-pages/man2/mount_setattr.2.html)

## When to Use This Skill

Use this skill when:
- Testing Docker container security or isolation
- Analyzing privilege escalation paths through namespaces
- Understanding UID/GID mapping in containers
- Enumerating namespaces on a Linux system
- Working with user namespace capabilities and limitations
- Troubleshooting namespace-related errors
