#!/bin/bash
# Docker/Kubernetes Hardening Report Generator
# Generates security recommendations based on current configuration

set -e

OUTPUT_FILE="${1:-hardening-report.md}"

cat > "$OUTPUT_FILE" << 'EOF'
# Container Security Hardening Report

## Executive Summary

This report provides security hardening recommendations for Docker and Kubernetes container deployments based on current best practices and known vulnerabilities.

## Critical Security Controls

### 1. Mount Security

#### Never Mount These Paths to Untrusted Containers

| Path | Risk Level | Impact |
|------|------------|--------|
| `/proc` | CRITICAL | Kernel parameter modification, RCE |
| `/sys` | CRITICAL | Kernel interface access, DoS |
| `/var` | CRITICAL | Container pivot, credential theft |
| `/run/containerd/containerd.sock` | CRITICAL | Full container runtime control |
| `/var/run/kubelet.sock` | CRITICAL | Kubernetes cluster compromise |
| `/sys/fs/cgroup` | HIGH | CVE-2022-0492 exploitation |
| `/dev` | HIGH | Device access, potential escape |

#### Safe Mount Practices

```bash
# Always mount sensitive paths as read-only
docker run -v /host/path:/container/path:ro my-image

# Add mount options for extra security
docker run -v /host/path:/container/path:ro,nosuid,nodev,noexec my-image

# Use tmpfs for temporary directories
docker run --tmpfs /tmp:rw,noexec,nosuid,size=64m my-image
```

### 2. Capability Management

#### Drop All Capabilities by Default

```bash
# Start with no capabilities
docker run --cap-drop=ALL my-image

# Add only required capabilities
docker run --cap-drop=ALL --cap-add=NET_BIND_SERVICE my-image
```

#### Dangerous Capabilities to Avoid

- `CAP_SYS_ADMIN` - Container escape via namespaces, cgroups
- `CAP_SYS_MODULE` - Kernel module loading
- `CAP_SYS_RAWIO` - Raw I/O port access
- `CAP_NET_ADMIN` - Network configuration changes
- `CAP_DAC_OVERRIDE` - Bypass file permission checks

### 3. User and Privilege Management

#### Run as Non-Root

```dockerfile
# In Dockerfile
USER 1000:1000
```

```bash
# At runtime
docker run --user 1000:1000 my-image
```

#### Disable Privilege Escalation

```bash
docker run --security-opt=no-new-privileges:true my-image
```

### 4. Read-Only Filesystem

```bash
# Make root filesystem read-only
docker run --read-only my-image

# With writable tmpfs for temp files
docker run --read-only --tmpfs /tmp:rw,noexec,nosuid my-image
```

### 5. Seccomp and AppArmor

#### Seccomp Profile

```bash
# Use default seccomp profile (Docker 1.10+)
docker run --security-opt seccomp=default my-image

# Use custom profile
docker run --security-opt seccomp=/path/to/profile.json my-image
```

#### AppArmor Profile

```bash
# Use default AppArmor profile
docker run --security-opt apparmor=default my-image

# Use custom profile
docker run --security-opt apparmor=my-profile my-image
```

## Kubernetes-Specific Hardening

### Pod Security Context

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
```

### Pod Security Standards

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: secure-namespace
  labels:
    # Enforce restricted profile (most secure)
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### Network Policies

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: secure-namespace
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

## Runtime Security Tools

### Recommended Tools

1. **Docker Bench for Security** - CIS Docker benchmark testing
2. **Kube-bench** - CIS Kubernetes benchmark testing
3. **Falco** - Runtime security monitoring
4. **Trivy** - Container vulnerability scanning
5. **Clair** - Static analysis for vulnerabilities

### Example: Docker Bench

```bash
# Install and run
curl -L https://raw.githubusercontent.com/docker/docker-bench-security/master/scripts/docker-bench-security.sh | sh
```

## Known CVEs and Mitigations

| CVE | Component | Mitigation |
|-----|-----------|------------|
| CVE-2024-21626 | runc ≤ 1.1.11 | Upgrade to runc ≥ 1.1.12 |
| CVE-2024-23651 | BuildKit < 0.12.5 | Upgrade to BuildKit ≥ 0.12.5 |
| CVE-2024-1753 | Buildah ≤ 1.35.0 | Upgrade to Buildah ≥ 1.35.1 |
| CVE-2024-40635 | containerd < 1.7.27 | Upgrade to containerd ≥ 1.7.27 |
| CVE-2022-0492 | cgroup v1 | Patch kernel or use cgroup v2 |

## Version Requirements

### Minimum Secure Versions (2025)

- **Docker**: ≥ 25.0.3
- **runc**: ≥ 1.1.12
- **containerd**: ≥ 1.7.27
- **BuildKit**: ≥ 0.12.5
- **Buildah**: ≥ 1.35.1
- **Podman**: ≥ 4.9.4
- **Kubernetes**: ≥ 1.28 (with Pod Security Admission)

## Quick Reference: Safe Container Run Command

```bash
docker run \
  --name secure-container \
  --read-only \
  --cap-drop=ALL \
  --cap-add=NET_BIND_SERVICE \
  --security-opt=no-new-privileges:true \
  --security-opt seccomp=default \
  --tmpfs /tmp:rw,noexec,nosuid,size=64m \
  --user 1000:1000 \
  --mount type=bind,src=/safe/path,dst=/app,readonly \
  my-secure-image:latest
```

## References

- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [0xn3va Container Escape Cheat Sheet](https://0xn3va.gitbook.io/cheat-sheets/container/escaping/sensitive-mounts)
- [NCC Group Container Security](https://research.nccgroup.com/wp-content/uploads/2020/07/ncc_group_understanding_hardening_linux_containers-1-1.pdf)

---
*Generated by Docker Sensitive Mounts Security Scanner*
EOF

echo "Hardening report generated: $OUTPUT_FILE"
echo ""
echo "Key recommendations:"
echo "1. Never mount /proc, /sys, /var to untrusted containers"
echo "2. Run containers as non-root with --cap-drop=ALL"
echo "3. Use read-only root filesystem with --read-only"
echo "4. Add --security-opt=no-new-privileges:true"
echo "5. Keep container runtimes updated (runc ≥ 1.1.12, containerd ≥ 1.7.27)"
