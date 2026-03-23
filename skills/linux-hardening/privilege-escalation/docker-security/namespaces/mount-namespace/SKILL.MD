---
name: mount-namespace
description: How to work with Linux mount namespaces for file system isolation and privilege escalation. Use this skill whenever the user mentions mount namespaces, namespace isolation, file system isolation, container security, or needs to create/enter/inspect mount namespaces. Also use when debugging namespace-related errors like "Cannot allocate memory" with unshare. Make sure to use this skill for any Linux security research involving namespaces, container escape scenarios, or when the user wants to understand how processes can have different views of the file system.
---

# Mount Namespace Operations

Mount namespaces provide isolation of file system mount points between processes. Each namespace has its own view of the file system hierarchy, and changes in one namespace don't affect others.

## When to Use This Skill

Use this skill when:
- You need to create isolated file system views for security testing
- You're researching container escape or privilege escalation techniques
- You need to understand how processes can have different file system views
- You're debugging namespace-related errors
- You want to isolate sensitive mounts from the host system

## Core Concepts

### How Mount Namespaces Work

1. **Inheritance**: New namespaces start with a copy of the parent's mount points
2. **Isolation**: Mount/unmount operations are local to the namespace
3. **Shared Resources**: File descriptors and inodes are shared across namespaces
4. **Movement**: Processes can move between namespaces using `setns()`, `unshare()`, or `clone()`

### Key System Calls

- `unshare()` - Create a new namespace
- `setns()` - Move to an existing namespace
- `clone()` with `CLONE_NEWNS` - Create namespace with new process

## Creating Mount Namespaces

### Using unshare (CLI)

```bash
# Basic mount namespace
sudo unshare -m /bin/bash

# With isolated /proc filesystem (recommended)
sudo unshare -m --mount-proc /bin/bash

# With fork to avoid PID allocation errors
sudo unshare -mf /bin/bash
```

**Important**: Use `-f` flag when creating namespaces to fork a new process. Without it, you may encounter "Cannot allocate memory" errors because the unshare process doesn't enter the new namespace, and when PID 1 exits, the namespace cleans up and disables PID allocation.

### Using Docker

```bash
docker run -ti --name container-name -v /host/path:/container/path ubuntu bash
```

## Inspecting Namespaces

### Check Current Namespace

```bash
# View your process's mount namespace
ls -l /proc/self/ns/mnt
# Output: mnt:[4026531841]
```

### Find All Mount Namespaces

```bash
# List all unique mount namespaces
sudo find /proc -maxdepth 3 -type l -name mnt -exec readlink {} \; 2>/dev/null | sort -u

# Find processes in a specific namespace (replace <ns-number>)
sudo find /proc -maxdepth 3 -type l -name mnt -exec ls -l {} \; 2>/dev/null | grep <ns-number>

# Alternative: list all mounts
findmnt
```

## Entering Mount Namespaces

### Using nsenter

```bash
# Enter a namespace by target PID
nsenter -m TARGET_PID --pid /bin/bash

# Or using the namespace file descriptor
nsenter -t /proc/TARGET_PID/ns/mnt -m /bin/bash
```

**Requirements**:
- You must be root to enter another process's namespace
- You need a descriptor pointing to the namespace (like `/proc/self/ns/mnt`)

## Mounting in Namespaces

### Create and Mount in Isolated Namespace

```bash
# Generate new mount namespace
unshare -m /bin/bash

# Create mount point
mkdir /tmp/mount_ns_example

# Mount a filesystem (only visible in this namespace)
mount -t tmpfs tmpfs /tmp/mount_ns_example

# Verify mount
mount | grep tmpfs
# Output: tmpfs on /tmp/mount_ns_example

# Create test file
echo test > /tmp/mount_ns_example/test
ls /tmp/mount_ns_example/test
```

### Verify Isolation from Host

```bash
# From the host (outside the namespace)
mount | grep tmpfs
# Output: (empty - cannot see the mount)

ls /tmp/mount_ns_example/test
# Output: ls: cannot access '/tmp/mount_ns_example/test': No such file or directory
```

### Bind Mount Example

```bash
# In new namespace
unshare --mount
mount --bind /usr/bin/ /mnt/
ls /mnt/cp
# Output: /mnt/cp

# Exit namespace
exit

# Back on host
ls /mnt/cp
# Output: ls: cannot access '/mnt/cp': No such file or directory
```

## Security Considerations

### Why This Matters for Privilege Escalation

1. **Hidden Mounts**: A namespace can contain sensitive information only accessible from within it
2. **File Descriptor Sharing**: Open file descriptors can be passed between namespaces, allowing access to files even if the path doesn't exist in your namespace
3. **Container Escape**: Understanding mount namespaces is crucial for container escape research
4. **Isolation Testing**: Verify that containers properly isolate their file systems

### Common Attack Vectors

- Finding processes in different mount namespaces with sensitive mounts
- Using file descriptor passing to access files across namespaces
- Exploiting improper namespace isolation in containers
- Leveraging namespace entry to access hidden filesystems

## Troubleshooting

### "Cannot allocate memory" Error

**Problem**: When running `unshare -p /bin/bash` without `-f` flag

**Cause**: The unshare process doesn't enter the new PID namespace. When the first child (PID 1) exits, the namespace cleans up and disables PID allocation.

**Solution**: Use the `-f` flag to fork:
```bash
unshare -fp /bin/bash
```

### Permission Denied

**Problem**: Cannot enter another namespace

**Cause**: You need root privileges to enter another process's namespace

**Solution**: Run with sudo or ensure you have appropriate capabilities

### Namespace Not Found

**Problem**: Cannot find namespace descriptor

**Cause**: The namespace file doesn't exist or the process has exited

**Solution**: Verify the target process is still running:
```bash
ls -l /proc/TARGET_PID/ns/mnt
```

## Practical Use Cases

### 1. Testing Container Isolation

```bash
# Create isolated environment
unshare -m --mount-proc /bin/bash

# Verify isolation
mount | grep tmpfs
# Should only show mounts from this namespace
```

### 2. Accessing Hidden Files

```bash
# Find processes with different mount namespaces
sudo find /proc -maxdepth 3 -type l -name mnt -exec readlink {} \; 2>/dev/null | sort -u

# Enter a namespace that might have sensitive mounts
nsenter -m TARGET_PID --pid /bin/bash

# Explore the file system
ls -la /
```

### 3. Creating Secure Environments

```bash
# Create namespace with clean mount view
unshare -m --mount-proc /bin/bash

# Mount only necessary filesystems
mount -t proc proc /proc
mount -t sysfs sysfs /sys

# Your process now has minimal file system access
```

## References

- [Understanding mount namespaces - Unix StackExchange](https://unix.stackexchange.com/questions/464033/understanding-how-mount-namespaces-work-in-linux)
- [unshare fork error - StackOverflow](https://stackoverflow.com/questions/44666700/unshare-pid-bin-bash-fork-cannot-allocate-memory)
- [Linux Namespaces Documentation](https://man7.org/linux/man-pages/man7/namespaces.7.html)
