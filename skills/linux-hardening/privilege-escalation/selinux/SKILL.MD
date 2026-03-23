---
name: selinux-container-security
description: How to understand and configure SELinux for container security. Use this skill whenever the user mentions SELinux, container security, container escape prevention, podman, docker security, or needs to harden container environments with mandatory access controls.
---

# SELinux Container Security

A skill for understanding and configuring SELinux to secure container environments.

## What SELinux Does for Containers

SELinux is a **labeling system** that provides mandatory access control. Every process and file system object has a label. SELinux policies define rules about what a process label is allowed to do with all other labels on the system.

### Container Labeling

Container engines launch container processes with a single confined SELinux label, usually `container_t`, and set the container filesystem to be labeled `container_file_t`. The SELinux policy rules say that `container_t` processes can only read/write/execute files labeled `container_file_t`.

**Why this matters:** If a container process escapes the container and attempts to write to content on the host, the Linux kernel denies access and only allows the container process to write to content labeled `container_file_t`.

### Check Container SELinux Labels

```shell
# Run a container
$ podman run -d fedora sleep 100
d4194babf6b877c7100e79de92cd6717166f7302113018686cea650ea40bd7cb

# Check the SELinux label on the container process
$ podman top -l label
LABEL
system_u:system_r:container_t:s0:c647,c780
```

### SELinux Users

There are SELinux users in addition to regular Linux users. SELinux users are part of an SELinux policy. Each Linux user is mapped to a SELinux user as part of the policy. This allows Linux users to inherit the restrictions and security rules and mechanisms placed on SELinux users.

## Quick Reference

### Check SELinux Status

```shell
# Check if SELinux is enforcing
$ getenforce
Enforcing

# Check SELinux mode (Enforcing, Permissive, or Disabled)
$ sestatus
```

### Verify Container Labels

```shell
# List containers with their SELinux labels
$ podman top -l label

# Check file labels in container
$ podman exec <container_id> ls -Z /path/to/file
```

### Key Concepts

- **`container_t`**: The SELinux type label for container processes
- **`container_file_t`**: The SELinux type label for container filesystem content
- **Mandatory Access Control**: SELinux enforces rules regardless of user permissions
- **Process confinement**: Container processes are restricted to their labeled namespace

## When to Use This Skill

Use this skill when:
- You need to understand how SELinux protects containers from escape attacks
- You're troubleshooting container access issues related to SELinux
- You want to verify SELinux is properly configured for container security
- You're hardening container environments and need to understand mandatory access controls
- You're investigating container security policies and labels

## Further Reading

- [Red Hat: Privileged flag in container engines](https://www.redhat.com/sysadmin/privileged-flag-container-engines)
- [Red Hat: Latest container exploit runc can be blocked by SELinux](https://www.redhat.com/en/blog/latest-container-exploit-runc-can-be-blocked-selinux)
