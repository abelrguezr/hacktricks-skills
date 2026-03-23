---
name: pid-namespace-security
description: How to work with Linux PID namespaces for container security, process isolation, and privilege escalation analysis. Use this skill whenever the user mentions containers, Docker, namespaces, process isolation, PID namespace, container escape, privilege escalation, runc, unshare, nsenter, or any security analysis involving Linux process namespaces. This skill helps create, inspect, and audit PID namespaces, understand exploitation techniques, and harden container security.
---

# PID Namespace Security

A skill for working with Linux PID (Process IDentifier) namespaces for container security, process isolation, and privilege escalation analysis.

## What PID Namespaces Do

PID namespaces provide process isolation by giving each namespace its own set of unique PIDs. When a new PID namespace is created:

- The first process becomes PID 1 (the "init" process) of that namespace
- Processes can only see other processes in the same namespace
- When the namespace's init process exits, all processes in that namespace are terminated
- The kernel maintains PID mappings between namespaces for signal translation

## Creating PID Namespaces

### Using unshare (CLI)

```bash
# Create a new PID namespace with fork and mount new /proc
sudo unshare -pf --mount-proc /bin/bash
```

**Important**: Always use `-f` (fork) flag. Without it, you'll get "Cannot allocate memory" errors because the namespace's PID 1 exits prematurely.

### Using Docker

```bash
docker run -ti --name ubuntu1 -v /usr:/ubuntu1 ubuntu bash
```

## Inspecting Namespaces

### Check your current PID namespace

```bash
ls -l /proc/self/ns/pid
# Output: pid:[4026532412]
```

### Find all PID namespaces on the system

```bash
sudo find /proc -maxdepth 3 -type l -name pid -exec readlink {} \; 2>/dev/null | sort -u
```

Note: Root in the default namespace can see all processes across all namespaces.

### Enter a PID namespace

```bash
nsenter -t TARGET_PID --pid /bin/bash
```

**Requirements**:
- You must be root to enter another process's PID namespace
- You need a descriptor pointing to the namespace (like `/proc/self/ns/pid`)
- When entering from the default namespace, you can still see all processes

## Security Considerations

### CVE-2025-31133: maskedPaths Abuse

runc ≤1.2.7 had a race condition where attackers could replace `/dev/null` with a symlink to host paths before the runtime masked sensitive procfs entries. This allowed container processes to access host-global procfs knobs.

**Audit a container bundle**:

```bash
jq '.linux.maskedPaths' config.json | tr -d '"'
```

If expected masking entries are missing, the container may have host PID visibility.

### Namespace Injection with insject

NCC Group's `insject` tool uses LD_PRELOAD to hook programs and issue `setns()` calls after `execve()`, allowing attachment to victim PID namespaces after runtime initialization.

**Example**:

```bash
sudo insject -S -p $(pidof containerd-shim) -- bash -lc 'readlink /proc/self/ns/pid && ps -ef'
```

**Defense considerations**:
- Use `-S/--strict` to abort if namespace joins fail
- Never attach tools with writable host file descriptors without joining the mount namespace
- Processes inside the PID namespace can ptrace helpers and reuse descriptors

## Common Tasks

### Task: Create an isolated process environment

1. Use `unshare -pf --mount-proc` to create a new PID namespace
2. Verify isolation by running `ps` inside the namespace
3. Remember: the namespace is destroyed when PID 1 exits

### Task: Audit container PID namespace security

1. Check the container's config.json for `maskedPaths` entries
2. Verify all sensitive procfs paths are masked
3. Ensure runc is updated to ≥1.2.8
4. Consider using `insject` with `-S` flag for strict validation

### Task: Debug a container from the host

1. Find the container's PID: `docker inspect -f '{{.State.Pid}}' <container>`
2. Enter the namespace: `nsenter -t <PID> --pid /bin/bash`
3. Run diagnostic commands while maintaining namespace isolation

## Scripts

Use the bundled scripts for common operations:

- `scripts/check-namespace.sh` - Check current namespace and list all namespaces
- `scripts/enter-namespace.sh` - Safely enter a target PID namespace
- `scripts/audit-container.sh` - Audit container config for PID namespace security

## References

- [unshare PID namespace memory allocation issue](https://stackoverflow.com/questions/44666700/unshare-pid-bin-bash-fork-cannot-allocate-memory)
- [runc maskedPaths security advisory](https://github.com/opencontainers/runc/security/advisories/GHSA-9493-h29p-rfm2)
- [insject: Linux Namespace Injector](https://www.nccgroup.com/us/research-blog/tool-release-insject-a-linux-namespace-injector/)
