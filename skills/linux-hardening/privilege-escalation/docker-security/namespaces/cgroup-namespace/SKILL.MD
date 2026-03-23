---
name: cgroup-namespace
description: How to work with Linux CGroup namespaces for process isolation and security analysis. Use this skill whenever the user mentions cgroup namespaces, container isolation, process hierarchy inspection, namespace enumeration, or needs to understand how cgroups virtualize resource views. Also trigger when investigating privilege escalation paths, container escape scenarios, or analyzing process isolation boundaries.
---

# CGroup Namespace Operations

This skill helps you work with Linux CGroup namespaces for process isolation, security analysis, and understanding container boundaries.

## What are CGroup Namespaces?

CGroup namespaces provide **isolation of cgroup hierarchies** for processes. They virtualize the view of the cgroup hierarchy so that processes within a namespace see only their own cgroup subtree, with their own cgroup appearing as the root.

**Key points:**
- Cgroup namespaces isolate the *view* of the hierarchy, not the resources themselves
- Resource control is still enforced by cgroup subsystems (CPU, memory, I/O)
- Processes see their own cgroup as the root of the hierarchy
- They cannot see or access cgroups outside their subtree

## When to Use This Skill

Use this skill when you need to:
- Create or enter cgroup namespaces
- Enumerate cgroup namespaces on a system
- Check which namespace a process belongs to
- Investigate container isolation boundaries
- Analyze privilege escalation paths involving namespaces
- Understand process isolation in containerized environments

## Creating CGroup Namespaces

### Using unshare (CLI)

```bash
# Create a new cgroup namespace with isolated /proc view
sudo unshare -C --mount-proc /bin/bash

# Create with fork (prevents PID allocation errors)
sudo unshare -fC --mount-proc /bin/bash
```

**Important:** Use the `-f` flag to fork a new process. Without it, you may encounter "Cannot allocate memory" errors because the unshare process doesn't enter the new namespace, and when PID 1 exits, the namespace gets cleaned up.

### Using Docker

```bash
docker run -ti --name ubuntu1 -v /usr:/ubuntu1 ubuntu bash
```

Docker containers automatically create cgroup namespaces for isolation.

## Inspecting CGroup Namespaces

### Check your current namespace

```bash
ls -l /proc/self/ns/cgroup
# Output: cgroup:[4026531835]
```

The number in brackets is your cgroup namespace identifier.

### Find all cgroup namespaces on the system

```bash
sudo find /proc -maxdepth 3 -type l -name cgroup -exec readlink {} \; 2>/dev/null | sort -u
```

### Find processes in a specific namespace

```bash
# Replace <ns-number> with the namespace ID
sudo find /proc -maxdepth 3 -type l -name cgroup -exec ls -l {} \; 2>/dev/null | grep <ns-number>
```

## Entering CGroup Namespaces

```bash
# Enter another process's cgroup namespace
nsenter -C TARGET_PID --pid /bin/bash
```

**Requirements:**
- You must be root to enter another process's namespace
- You need a descriptor pointing to the namespace (like `/proc/self/ns/cgroup`)

## Security Considerations

### Privilege Escalation Context

CGroup namespaces can be relevant for privilege escalation because:

1. **Namespace enumeration** can reveal container boundaries and isolation gaps
2. **Namespace entry** (if you have root) allows you to inspect processes in different isolation contexts
3. **Understanding cgroup views** helps identify what resources a process can see and potentially manipulate

### Common Investigation Patterns

1. **Map namespace boundaries**: Find all cgroup namespaces and their associated processes
2. **Check isolation**: Verify that containers are properly isolated from the host
3. **Identify escape vectors**: Look for processes that can enter namespaces they shouldn't
4. **Analyze resource visibility**: Understand what cgroup hierarchies processes can see

## Troubleshooting

### "Cannot allocate memory" error with unshare

**Cause:** The unshare process doesn't enter the new namespace, and when PID 1 exits, the namespace is cleaned up.

**Solution:** Use the `-f` flag to fork:
```bash
sudo unshare -fC --mount-proc /bin/bash
```

### Cannot enter namespace

**Cause:** You're not root, or you don't have a namespace descriptor.

**Solution:** 
- Ensure you have root privileges
- Use a valid namespace path like `/proc/<pid>/ns/cgroup`

## Quick Reference

| Task | Command |
|------|--------|
| Create cgroup namespace | `sudo unshare -fC --mount-proc /bin/bash` |
| Check current namespace | `ls -l /proc/self/ns/cgroup` |
| List all namespaces | `sudo find /proc -maxdepth 3 -type l -name cgroup -exec readlink {} \; 2>/dev/null \| sort -u` |
| Find processes in namespace | `sudo find /proc -maxdepth 3 -type l -name cgroup -exec ls -l {} \; 2>/dev/null \| grep <ns-id>` |
| Enter namespace | `nsenter -C TARGET_PID --pid /bin/bash` |

## Next Steps

After working with cgroup namespaces, you may want to:
- Investigate other namespace types (PID, mount, network, user)
- Analyze cgroup resource limits and controls
- Examine container escape techniques
- Review process isolation boundaries

For more information on cgroups themselves, see the cgroups documentation.
