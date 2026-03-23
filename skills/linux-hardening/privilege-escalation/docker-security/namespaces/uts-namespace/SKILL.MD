---
name: uts-namespace-security
description: Use this skill whenever you need to work with Linux UTS namespaces for security testing, privilege escalation, or container security analysis. This includes checking which UTS namespace you're in, finding all UTS namespaces on a system, entering UTS namespaces, detecting containers that share the host UTS namespace, or understanding UTS namespace security implications. Trigger this skill for any task involving hostname isolation, NIS domain names, container UTS configuration, or UTS-based privilege escalation scenarios.
---

# UTS Namespace Security

A skill for working with Linux UTS (UNIX Time-Sharing System) namespaces in security testing and container security analysis.

## What is a UTS Namespace?

A UTS namespace provides isolation of two system identifiers:
- **Hostname** - The system's network name
- **NIS domain name** - Network Information Service domain

Each UTS namespace has its own independent hostname and NIS domain name, which is critical for containerization where each container should appear as a separate system.

## Key Concepts

### How UTS Namespaces Work

1. **Inheritance**: When created, a new UTS namespace copies the hostname and NIS domain name from its parent
2. **Isolation**: Changes to hostname/NIS domain within a namespace don't affect other namespaces
3. **Modification**: Use `sethostname()` and `setdomainname()` system calls to change identifiers
4. **Movement**: Use `setns()`, `unshare()`, or `clone()` with `CLONE_NEWUTS` flag to create/enter namespaces

### Security Implications

When a container shares the host UTS namespace (`--uts=host`), it can:
- Change the host hostname (tampering with logs/alerts)
- Confuse cluster discovery mechanisms
- Break TLS/SSH configurations that pin the hostname

## Quick Actions

### Check Your Current UTS Namespace

```bash
ls -l /proc/self/ns/uts
# Output: uts:[4026531838]
```

The number in brackets is your UTS namespace ID. Compare this with other processes to see if you share a namespace.

### Find All UTS Namespaces on the System

```bash
sudo find /proc -maxdepth 3 -type l -name uts -exec readlink {} \; 2>/dev/null | sort -u
```

This lists all unique UTS namespaces. Each unique ID represents a separate namespace.

### Find Processes in a Specific UTS Namespace

```bash
sudo find /proc -maxdepth 3 -type l -name uts -exec ls -l {} \; 2>/dev/null | grep <ns-number>
```

Replace `<ns-number>` with the namespace ID you want to investigate.

### Enter a UTS Namespace

```bash
nsenter -u TARGET_PID --pid /bin/bash
```

Replace `TARGET_PID` with a process ID that's already in the target UTS namespace.

### Create a New UTS Namespace

```bash
sudo unshare -u --mount-proc /bin/bash
```

The `--mount-proc` flag mounts a new `/proc` instance for accurate process information in the new namespace.

## Container Security

### Detect Containers Sharing Host UTS

```bash
docker ps -aq | xargs -r docker inspect --format '{{.Id}} UTSMode={{.HostConfig.UTSMode}}'
```

Look for containers showing `UTSMode=host` - these can modify the host hostname.

### Test UTS Namespace Isolation

```bash
# In a container with --uts=host and SYS_ADMIN capability
docker run --rm -it --uts=host --cap-add SYS_ADMIN alpine sh -c "hostname hacked-host && exec sh"
```

**Warning**: This will change the host hostname. Only use in controlled environments.

## Helper Scripts

Use the bundled scripts for common tasks:

| Script | Purpose |
|--------|--------|
| `check-uts-namespace.sh` | Display current UTS namespace info |
| `list-uts-namespaces.sh` | List all UTS namespaces with process counts |
| `detect-host-uts-containers.sh` | Find containers sharing host UTS |
| `enter-uts-namespace.sh` | Helper to enter a specific UTS namespace |

Run them from the skill's `scripts/` directory or source them in your workflow.

## Common Scenarios

### Scenario 1: You're in a container and want to check UTS isolation

1. Check your current namespace: `ls -l /proc/self/ns/uts`
2. Compare with host namespace: `ls -l /proc/1/ns/uts`
3. If they match, you're sharing the host UTS namespace

### Scenario 2: You found a container with host UTS access

1. Verify the container can change hostname: `hostname`
2. Check capabilities: `cat /proc/self/status | grep Cap`
3. If `SYS_ADMIN` is present, the container can modify host hostname
4. Document this as a potential privilege escalation vector

### Scenario 3: You need to pivot to another UTS namespace

1. Find a process in the target namespace: `list-uts-namespaces.sh`
2. Note the PID of a process in that namespace
3. Enter it: `nsenter -u <PID> --pid /bin/bash`
4. Verify: `ls -l /proc/self/ns/uts`

## Troubleshooting

### "Cannot allocate memory" with unshare

This happens when creating a new PID namespace without the `-f` flag. The solution:

```bash
# Wrong - may cause memory allocation errors
unshare -p /bin/bash

# Correct - forks a new process
unshare -fp /bin/bash
```

The `-f` flag ensures `unshare` itself becomes PID 1 in the new namespace, preventing premature namespace cleanup.

### Permission denied when entering namespaces

You need appropriate capabilities or root access:
- `CAP_SYS_ADMIN` capability, or
- Root user, or
- The namespace must be accessible via `/proc/<pid>/ns/uts`

## Best Practices

1. **Always verify namespace isolation** before assuming containers are isolated
2. **Check for host UTS sharing** in container security audits
3. **Document namespace relationships** when investigating privilege escalation
4. **Use helper scripts** for consistent, repeatable checks
5. **Test in controlled environments** before running UTS modification commands

## References

- Linux man pages: `unshare(1)`, `nsenter(1)`, `sethostname(2)`
- Kernel documentation: `Documentation/admin-guide/cgroup-v2.rst`
- Docker documentation: Container namespaces
