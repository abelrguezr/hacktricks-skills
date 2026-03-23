---
name: docker-privileged-security
description: Analyze Docker --privileged container security implications, check if a container is privileged, and understand available escape vectors. Use this skill whenever the user mentions Docker containers, privileged mode, container security, privilege escalation, container escape, or CTF challenges involving Docker. Make sure to use this skill for any security research, penetration testing, or CTF scenarios involving Docker containers.
---

# Docker Privileged Container Security

This skill helps you understand the security implications of Docker's `--privileged` flag, check if you're running in a privileged container, and identify potential escape vectors for security research and CTF challenges.

## What --privileged Does

When you run a container with `--privileged`, these protections are disabled:

### 1. Device Access (/dev)
All host devices become accessible in `/dev/`. This allows mounting the host disk directly.

**Default container:**
```bash
ls /dev
console  fd  mqueue  ptmx  random  stderr  stdout  urandom  core  full  null  pts  shm  stdin  tty  zero
```

**Privileged container:**
```bash
ls /dev
cachefiles  mapper  port  shm  tty24  tty44  tty7  console  mem  psaux  stderr  tty25  tty45  tty8  core  mqueue  ptmx  stdin  tty26  tty46  tty9  cpu  nbd0  pts  stdout  tty27  tty47  ttyS0
```

### 2. Kernel File Systems
Kernel file systems are mounted read-write instead of read-only, allowing kernel behavior modification.

**Check:**
```bash
# Default container shows (ro) flags
mount | grep '(ro'
sysfs on /sys type sysfs (ro,nosuid,nodev,noexec,relatime)

# Privileged container - no read-only mounts
mount | grep '(ro'
# (empty output)
```

### 3. Proc Masking
tmpfs overlays on sensitive /proc paths are removed, exposing kernel internals.

**Check:**
```bash
# Default container has tmpfs overlays
mount | grep '/proc.*tmpfs'
tmpfs on /proc/acpi type tmpfs (ro,relatime)
tmpfs on /proc/kcore type tmpfs (rw,nosuid,size=65536k,mode=755)

# Privileged container - no overlays
mount | grep '/proc.*tmpfs'
# (empty output)
```

### 4. Linux Capabilities
All capabilities are granted instead of a limited set.

**Check:**
```bash
# Install libcap if needed
apk add -U libcap  # Alpine
apt-get install libcap2-bin  # Debian/Ubuntu

# Check capabilities
capsh --print

# Default container (limited):
# Current: cap_chown,cap_dac_override,cap_fowner,cap_fsetid,cap_kill,cap_setgid,cap_setuid,cap_setpcap,cap_net_bind_service,cap_net_raw,cap_sys_chroot,cap_mknod,cap_audit_write,cap_setfcap=eip

# Privileged container (all capabilities):
# Current: =eip cap_perfmon,cap_bpf,cap_checkpoint_restore-eip
# Bounding set includes: cap_sys_admin,cap_sys_ptrace,cap_sys_module,cap_net_admin,cap_dac_read_search,cap_sys_rawio...
```

### 5. Seccomp
System call filtering is disabled.

**Check:**
```bash
grep Seccomp /proc/1/status

# Default container:
# Seccomp: 2
# Seccomp_filters: 1

# Privileged container:
# Seccomp: 0
# Seccomp_filters: 0
```

### 6. AppArmor
Mandatory access control profiles are disabled.

### 7. SELinux
Security labels are disabled, inheriting container engine labels.

## Quick Privilege Check Script

Run this to quickly determine if you're in a privileged container:

```bash
#!/bin/bash
echo "=== Docker Privilege Check ==="

# Check device count
DEV_COUNT=$(ls /dev 2>/dev/null | wc -l)
echo "Device count: $DEV_COUNT (privileged typically > 50)"

# Check Seccomp
SECCOMP=$(grep Seccomp /proc/1/status 2>/dev/null | awk '{print $2}')
echo "Seccomp: $SECCOMP (0 = disabled/privileged)"

# Check for read-only sysfs
SYSFS_RO=$(mount | grep 'sysfs on /sys' | grep -c 'ro')
echo "Sysfs read-only: $SYSFS_RO (0 = writable/privileged)"

# Check proc tmpfs overlays
PROC_TMPFS=$(mount | grep '/proc.*tmpfs' | wc -l)
echo "Proc tmpfs overlays: $PROC_TMPFS (0 = privileged)"

# Check capabilities if available
if command -v capsh &>/dev/null; then
    CAP_COUNT=$(capsh --print 2>/dev/null | grep 'Bounding set' | tr ',' '\n' | wc -l)
    echo "Capability count: $CAP_COUNT (privileged typically > 30)"
fi

if [ "$SECCOMP" = "0" ] && [ "$SYSFS_RO" = "0" ]; then
    echo "\n⚠️  LIKELY PRIVILEGED CONTAINER"
else
    echo "\n✓ Standard container"
fi
```

## Escape Vectors

### 1. Mount Host Disk

Privileged containers can access host block devices:

```bash
# Find host disk devices
ls /dev | grep -E 'sd[a-z]|nvme[0-9]+n[0-9]'

# Mount host root filesystem
mount /dev/sda1 /mnt/host

# Access host files
cat /mnt/host/etc/shadow
cat /mnt/host/root/.ssh/id_rsa

# Or use fdisk to find partitions
fdisk -l /dev/sda
```

### 2. Access Host Processes

Namespaces are NOT affected by --privileged. Use `--pid=host` flag or capabilities:

```bash
# If --pid=host was set
ps aux

# Otherwise, use ptrace capability to inspect processes
gdb -p <host_pid>
```

### 3. Load Kernel Modules

With `cap_sys_module` capability:

```bash
# Load a kernel module
insmod /path/to/module.ko

# Or use modprobe
modprobe <module_name>
```

### 4. Network Access

With `cap_net_admin` and `cap_net_raw`:

```bash
# Access host network interfaces
ip link show

# Modify routing
ip route add default via 192.168.1.1

# Packet capture
cpdump -i eth0
```

### 5. Ptrace Other Processes

With `cap_sys_ptrace`:

```bash
# Attach to host processes
gdb -p <pid>

# Or use strace
strace -p <pid>
```

## What --privileged Does NOT Affect

### Namespaces
Even privileged containers don't see all host processes by default. To access host namespaces:

```bash
# These flags are separate from --privileged:
--pid=host    # Share host PID namespace
--net=host    # Share host network namespace
--ipc=host    # Share host IPC namespace
--uts=host    # Share host UTS namespace
```

### User Namespace
User namespaces cannot be disabled and enhance security by restricting privileges. Rootless containers require them.

## Security Recommendations

1. **Never use --privileged** unless absolutely necessary
2. **Use specific capabilities** instead:
   ```bash
   docker run --cap-add=SYS_ADMIN --cap-add=NET_ADMIN
   ```
3. **Drop unnecessary capabilities**:
   ```bash
   docker run --cap-drop=ALL --cap-add=CHOWN
   ```
4. **Implement seccomp profiles** to limit system calls
5. **Enable AppArmor/SELinux** for mandatory access control
6. **Use read-only filesystems** where possible
7. **Use user namespaces** for additional isolation

## Manual Security Option Disabling

You can disable individual protections without --privileged:

```bash
# Disable seccomp
--security-opt seccomp=unconfined

# Disable AppArmor
--security-opt apparmor=unconfined

# Disable SELinux
--security-opt label:disable
```

## References

- [Red Hat: Privileged Flag in Container Engines](https://www.redhat.com/sysadmin/privileged-flag-container-engines)
- [Docker Security Documentation](https://docs.docker.com/engine/security/)
- [Linux Capabilities](https://man7.org/linux/man-pages/man7/capabilities.7.html)
- [Seccomp Documentation](https://www.kernel.org/doc/html/latest/userspace-api/seccomp_filter.html)
