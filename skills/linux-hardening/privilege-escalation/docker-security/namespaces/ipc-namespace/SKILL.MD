---
name: ipc-namespace
description: How to work with Linux IPC (Inter-Process Communication) namespaces for security isolation and privilege escalation analysis. Use this skill whenever the user needs to understand IPC namespace isolation, create isolated IPC environments, inspect IPC objects across namespaces, or analyze IPC namespace configurations for security hardening. Make sure to use this skill when the user mentions IPC namespaces, shared memory isolation, System V IPC objects, process isolation, or namespace security.
---

# IPC Namespace Security

This skill helps you work with Linux IPC (Inter-Process Communication) namespaces to understand isolation boundaries, create secure IPC environments, and analyze namespace configurations for security hardening.

## What IPC Namespaces Do

IPC namespaces provide **isolation** of System V IPC objects (message queues, shared memory segments, semaphores). Processes in different IPC namespaces cannot directly access each other's IPC objects, adding a security layer between process groups.

### Key behaviors:

1. **Complete isolation**: New IPC namespaces start with isolated System V IPC objects
2. **Namespace-local visibility**: IPC objects are only visible to processes within the same namespace
3. **Unique keys per namespace**: Same key values in different namespaces refer to different objects

## Common Operations

### Check your current IPC namespace

```bash
ls -l /proc/self/ns/ipc
# Output: ipc:[4026531839]
```

The number in brackets is your namespace identifier. Compare this across processes to see if they share the same IPC namespace.

### Find all IPC namespaces on the system

```bash
sudo find /proc -maxdepth 3 -type l -name ipc -exec readlink {} \; 2>/dev/null | sort -u
```

This lists all unique IPC namespace IDs currently in use.

### Find processes in a specific namespace

```bash
sudo find /proc -maxdepth 3 -type l -name ipc -exec ls -l {} \; 2>/dev/null | grep <ns-number>
```

Replace `<ns-number>` with the namespace ID you want to investigate.

### Create an isolated IPC namespace

```bash
# Basic isolation
sudo unshare -i /bin/bash

# With isolated /proc view (recommended for debugging)
sudo unshare -i --mount-proc /bin/bash

# Force fork to avoid PID namespace issues
sudo unshare -fi /bin/bash
```

**Why `--mount-proc` matters**: Mounting a new `/proc` instance gives you an accurate view of processes specific to that namespace, not the host's process tree.

**Why `-f` matters**: The `-f` flag forces `unshare` to fork, preventing "Cannot allocate memory" errors when PID namespaces are involved. Without it, the namespace may be cleaned up prematurely.

### Enter an existing IPC namespace

```bash
nsenter -i TARGET_PID --pid /bin/bash
```

**Requirements**:
- You must be root (or have appropriate capabilities)
- You need a descriptor to the namespace (like `/proc/<pid>/ns/ipc`)

### Create and verify IPC objects

```bash
# Inside isolated namespace
sudo unshare -i /bin/bash
ipcmk -M 100
ipcs -m

# From host (should see nothing)
ipcs -m
```

This demonstrates isolation: shared memory created in the namespace is invisible from the host.

## Security Analysis Patterns

### Verify container isolation

When auditing containers or isolated environments:

1. Check if the container has its own IPC namespace:
   ```bash
   ls -l /proc/self/ns/ipc
   ```

2. Compare with host namespace:
   ```bash
   # From host
   ls -l /proc/1/ns/ipc
   ```

3. If IDs match, the container shares the host's IPC namespace (potential security issue)

### Detect namespace escape opportunities

If you can `nsenter` into another namespace, you may be able to:
- Access IPC objects from other processes
- Create shared memory that other processes can see
- Potentially escalate privileges if namespace boundaries are misconfigured

### Docker IPC namespace behavior

```bash
docker run -ti --name ubuntu1 -v /usr:/ubuntu1 ubuntu bash
```

By default, Docker containers get their own IPC namespace. Verify with:
```bash
ls -l /proc/self/ns/ipc
```

## Troubleshooting

### "Cannot allocate memory" error

**Cause**: PID namespace cleanup when PID 1 exits prematurely.

**Solution**: Use `-f` flag:
```bash
sudo unshare -fi /bin/bash
```

### Cannot enter namespace

**Cause**: Missing root privileges or no namespace descriptor.

**Solution**: 
- Ensure you're root or have `CAP_SYS_ADMIN`
- Use a valid namespace path like `/proc/<pid>/ns/ipc`

## References

- [Linux Namespaces Documentation](https://man7.org/linux/man-pages/man7/namespaces.7.html)
- [unshare man page](https://man7.org/linux/man-pages/man2/unshare.2.html)
- [nsenter man page](https://man7.org/linux/man-pages/man1/nsenter.1.html)
