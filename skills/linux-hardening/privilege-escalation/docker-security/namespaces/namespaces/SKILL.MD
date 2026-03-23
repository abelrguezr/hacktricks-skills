---
name: docker-namespace-security
description: How to understand, test, and harden Docker namespace isolation for security. Use this skill whenever the user mentions Docker security, container isolation, namespace escapes, privilege escalation, container breakout, or needs to audit namespace configurations. This skill covers PID, Mount, Network, IPC, UTS, Time, and User namespaces.
---

# Docker Namespace Security

This skill helps you understand and secure Docker container namespace isolation. Namespaces are a Linux kernel feature that provides process isolation, and Docker uses them extensively to isolate containers from the host and from each other.

## What are Namespaces?

Namespaces wrap a global system resource in an abstraction that makes it appear to the processes within the namespace that they have their own isolated instance of that resource. Docker uses six main namespace types:

- **PID** - Process ID isolation
- **Mount** - Filesystem mount point isolation
- **Network** - Network stack isolation
- **IPC** - Inter-process communication isolation
- **UTS** - Hostname and domain name isolation
- **User** - User and group ID isolation

## Quick Reference

### Check Your Current Namespaces

```bash
# List all namespaces for current process
ls -la /proc/self/ns/

# Check specific namespace inode (compare with host to detect escapes)
readlink /proc/self/ns/pid
readlink /proc/self/ns/mnt
readlink /proc/self/ns/net
```

### Inspect Container Namespace Configuration

```bash
# From host - check container namespace settings
docker inspect <container_id> | grep -A 20 Namespaces

# Check if container shares host namespaces
docker inspect <container_id> | grep -i "hostpid\|hostnetwork\|hostipc"
```

## Namespace Types Deep Dive

### PID Namespace

**Purpose**: Isolates process IDs so containers see their own process tree.

**Security Implications**:
- Without PID namespace isolation, containers can see and potentially signal host processes
- PID namespace escapes can lead to full container breakout

**Hardening**:
```bash
# Default: container gets its own PID namespace
# Avoid: --pid=host (shares host PID namespace)

# Check if container shares host PID namespace
docker inspect <container> | grep -i "pidmode"
```

**Testing for PID Namespace Escape**:
```bash
# Inside container - check if you can see host processes
ps aux  # Should only show container processes

# Try to access host PID namespace
ls /proc/1/root  # If this shows host filesystem, you may have escaped
```

### Mount Namespace

**Purpose**: Isolates filesystem mount points.

**Security Implications**:
- Mount namespace isolation prevents containers from seeing host mounts
- Improperly configured volumes can expose sensitive host paths
- Mount namespace escapes are a common privilege escalation vector

**Hardening**:
```bash
# Default: container gets isolated mount namespace
# Avoid: --privileged (disables mount namespace security)
# Avoid: mounting sensitive host paths like /, /etc, /proc, /sys

# Use read-only mounts where possible
-v /host/path:/container/path:ro

# Check mount configuration
docker inspect <container> | grep -A 50 Mounts
```

**Testing for Mount Namespace Issues**:
```bash
# Inside container - check what's mounted
mount | grep -v "cgroup\|tmpfs"

# Check if sensitive paths are accessible
ls -la /proc/1/root 2>/dev/null
ls -la /etc/passwd  # Should be container's, not host's
```

### Network Namespace

**Purpose**: Isolates network stack (interfaces, routing tables, ports).

**Security Implications**:
- Network namespace isolation prevents containers from directly accessing host network
- `--network=host` shares the host network namespace (high risk)
- Network namespace escapes can enable lateral movement

**Hardening**:
```bash
# Default: container gets isolated network namespace
# Avoid: --network=host (shares host network namespace)

# Use bridge or custom networks instead
docker network create mynetwork
docker run --network=mynetwork ...

# Check network configuration
docker inspect <container> | grep -i "networkmode"
```

**Testing for Network Namespace Issues**:
```bash
# Inside container - check network interfaces
ip addr show  # Should show container interfaces, not host

# Check if you can access host network
ping <host_internal_ip>  # Should fail if properly isolated
```

### IPC Namespace

**Purpose**: Isolates inter-process communication (shared memory, semaphores).

**Security Implications**:
- IPC namespace isolation prevents containers from sharing memory with host
- `--ipc=host` shares host IPC namespace (can leak sensitive data)

**Hardening**:
```bash
# Default: container gets isolated IPC namespace
# Avoid: --ipc=host (shares host IPC namespace)

# Check IPC configuration
docker inspect <container> | grep -i "ipcmode"
```

### UTS Namespace

**Purpose**: Isolates hostname and domain name.

**Security Implications**:
- UTS namespace isolation prevents containers from changing host hostname
- `--uts=host` shares host UTS namespace (can cause confusion in logging)

**Hardening**:
```bash
# Default: container gets isolated UTS namespace
# Avoid: --uts=host

# Check UTS configuration
docker inspect <container> | grep -i "utsmode"
```

### User Namespace

**Purpose**: Isolates user and group IDs, allowing root in container to map to non-root on host.

**Security Implications**:
- User namespace isolation is CRITICAL for security
- Without it, root in container = root on host
- Many Docker security features depend on user namespaces

**Hardening**:
```bash
# Enable user namespaces on Docker daemon
# In /etc/docker/daemon.json:
{
  "userns-remap": "default"
}

# Or run with user namespace mapping
--userns=host  # Avoid this - shares host user namespace

# Check user namespace configuration
docker inspect <container> | grep -i "userns"

# Verify root in container is not root on host
id  # Inside container
# Then check from host what UID that maps to
```

**Testing for User Namespace Issues**:
```bash
# Inside container
id  # Check your UID/GID

# If UID 0 inside container maps to UID 0 on host, you have no user namespace isolation
# This is a critical security issue
```

## Common Namespace Escape Vectors

### 1. Privileged Containers
```bash
# DANGEROUS: --privileged disables all namespace security
docker run --privileged ...

# Instead, grant specific capabilities
docker run --cap-add=NET_ADMIN ...
```

### 2. Host Namespace Sharing
```bash
# DANGEROUS: These share host namespaces
docker run --pid=host ...
docker run --network=host ...
docker run --ipc=host ...
docker run --uts=host ...

# Check for these in your containers
docker inspect <container> | grep -E "pidmode|networkmode|ipcmode|utsmode"
```

### 3. Sensitive Volume Mounts
```bash
# DANGEROUS: Mounting sensitive host paths
-v /:/host
docker run -v /etc:/etc ...
docker run -v /proc:/proc ...

# Instead, mount only what's needed and read-only
-v /specific/path:/container/path:ro
```

### 4. Capabilities Abuse
```bash
# DANGEROUS: All capabilities
docker run --cap-add=ALL ...

# Instead, drop all and add only what's needed
docker run --cap-drop=ALL --cap-add=NET_BIND_SERVICE ...
```

## Security Checklist

Use this checklist when auditing Docker containers:

- [ ] Container does NOT use `--privileged`
- [ ] Container does NOT share host PID namespace (`--pid=host`)
- [ ] Container does NOT share host network namespace (`--network=host`)
- [ ] Container does NOT share host IPC namespace (`--ipc=host`)
- [ ] Container does NOT share host UTS namespace (`--uts=host`)
- [ ] User namespaces are enabled (check Docker daemon config)
- [ ] No sensitive host paths are mounted (`/`, `/etc`, `/proc`, `/sys`)
- [ ] Volumes are mounted read-only where possible
- [ ] Unnecessary capabilities are dropped
- [ ] Container runs as non-root user when possible

## Quick Audit Script

Run this on the host to check container namespace security:

```bash
#!/bin/bash
# docker-namespace-audit.sh

echo "=== Docker Namespace Security Audit ==="
echo

for container in $(docker ps -aq); do
    echo "Container: $container"
    
    # Check for privileged mode
    if docker inspect $container | grep -q '"Privileged": true'; then
        echo "  ⚠️  PRIVILEGED MODE ENABLED"
    fi
    
    # Check namespace sharing
    if docker inspect $container | grep -q '"PidMode": "host"'; then
        echo "  ⚠️  Shares host PID namespace"
    fi
    
    if docker inspect $container | grep -q '"NetworkMode": "host"'; then
        echo "  ⚠️  Shares host network namespace"
    fi
    
    if docker inspect $container | grep -q '"IpcMode": "host"'; then
        echo "  ⚠️  Shares host IPC namespace"
    fi
    
    # Check for sensitive mounts
    if docker inspect $container | grep -E '"Source": "/|"Source": "/etc|"Source": "/proc|"Source": "/sys"' | grep -v '"Mode": "ro"'; then
        echo "  ⚠️  Sensitive host path mounted"
    fi
    
    echo
done
```

## When to Use This Skill

Use this skill when you need to:

1. **Audit container security** - Check if containers are properly isolated
2. **Understand namespace escapes** - Learn how attackers might break out of containers
3. **Harden Docker configurations** - Apply security best practices
4. **Debug namespace issues** - Troubleshoot container isolation problems
5. **Design secure container architectures** - Plan namespace isolation for new deployments

## Related Topics

- Docker capabilities (`--cap-add`, `--cap-drop`)
- Seccomp profiles for syscall filtering
- AppArmor/SELinux for mandatory access control
- Docker security scanning (Trivy, Clair, Docker Scan)
- Runtime security (Falco, Sysdig)
