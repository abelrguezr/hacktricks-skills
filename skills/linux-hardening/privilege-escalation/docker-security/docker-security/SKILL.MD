---
name: docker-security-hardening
description: Use this skill whenever you need to secure Docker containers, audit Docker configurations, scan for vulnerabilities, or harden Docker deployments. Trigger this for any Docker security questions, container hardening, vulnerability scanning, reviewing Dockerfiles for security issues, or when you need to understand Docker security features like namespaces, capabilities, seccomp, or AppArmor.
---

# Docker Security Hardening

A comprehensive guide to securing Docker containers and deployments.

## Quick Start

### Immediate Security Checklist

When deploying any container, apply these security measures:

```bash
# Essential security flags
docker run \
  --read-only \
  --security-opt=no-new-privileges:true \
  --cap-drop=all \
  --cap-add=NET_BIND_SERVICE \
  --user 1000:1000 \
  --memory=512m \
  --cpus=1 \
  --pids-limit=100 \
  --name secure-container \
  your-image
```

### Security Features Reference

| Feature | Purpose | Default | Recommended |
|---------|---------|---------|-------------|
| `--read-only` | Prevents filesystem writes | Disabled | Enable |
| `--security-opt=no-new-privileges:true` | Blocks privilege escalation | Disabled | Enable |
| `--cap-drop=all` | Drops all Linux capabilities | Partial drop | Drop all, add only needed |
| `--user` | Run as non-root | Root | Non-root user |
| `--memory` | Memory limit | Unlimited | Set appropriate limit |
| `--cpus` | CPU limit | Unlimited | Set appropriate limit |
| `--pids-limit` | Process limit | Unlimited | Set to prevent fork bombs |

## Container Security Features

### Namespaces

Docker uses Linux namespaces for isolation:

- **PID namespace**: Process isolation
- **Mount namespace**: Filesystem isolation
- **Network namespace**: Network stack isolation
- **IPC namespace**: Inter-process communication isolation
- **UTS namespace**: Hostname isolation

**Security implication**: Namespaces provide isolation but are not foolproof. Combined with other mechanisms, they form a defense-in-depth strategy.

### Capabilities

Capabilities provide fine-grained privilege control. When a container starts, Docker drops sensitive capabilities by default.

**Remaining capabilities by default**:
```
cap_chown,cap_dac_override,cap_fowner,cap_fsetid,cap_kill,cap_setgid,cap_setuid,cap_setpcap,cap_net_bind_service,cap_net_raw,cap_sys_chroot,cap_mknod,cap_audit_write,cap_setfcap
```

**Best practice**: Drop all capabilities and add only what's needed:
```bash
--cap-drop=all --cap-add=NET_BIND_SERVICE --cap-add=CHOWN
```

### Seccomp

Seccomp (Secure Computing Mode) restricts syscalls available to containers.

- **Default**: Docker uses a default seccomp profile
- **Location**: `profiles/seccomp/default.json`
- **Disable (not recommended)**: `--security-opt seccomp=unconfined`
- **Custom profile**: `--security-opt seccomp=/path/to/profile.json`

### AppArmor

AppArmor confines containers to limited resources with per-program profiles.

- **Default**: Docker has a built-in AppArmor template
- **Disable (not recommended)**: `--security-opt apparmor=unconfined`
- **Custom profile**: `--security-opt apparmor=custom-profile-name`

### SELinux

SELinux provides mandatory access control through labeling:

- **Container processes**: Labeled as `container_t`
- **Container files**: Labeled as `container_file_t`
- **Policy**: `container_t` can only interact with `container_file_t`
- **Disable (not recommended)**: `--security-opt label:disable`

## Vulnerability Scanning

### Built-in Docker Scan

```bash
docker scan <image-name>
```

### Trivy (Recommended)

```bash
# Scan image
trivy image <image-name>:<tag>

# JSON output for CI/CD
trivy image --format json --output results.json <image-name>:<tag>

# Scan with severity threshold
trivy image --severity HIGH,CRITICAL <image-name>:<tag>
```

### Snyk

```bash
snyk container test <image> --json-file-output=results.json --severity-threshold=high
```

### Clair Scanner

```bash
clair-scanner -w config.yaml --ip YOUR_LOCAL_IP <image-name>:<tag>
```

## Secret Management

### ❌ Don't Do This

```dockerfile
# Bad: Secrets in environment variables
ENV API_KEY=secret123

# Bad: Secrets in image layers
RUN echo "password123" > /app/config.txt
```

### ✅ Do This Instead

**Option 1: Docker Secrets (Swarm)**
```yaml
version: "3.7"
services:
  my_service:
    image: myapp:latest
    secrets:
      - my_secret
secrets:
  my_secret:
    file: ./my_secret_file.txt
```

**Option 2: BuildKit Build-time Secrets**
```bash
export DOCKER_BUILDKIT=1
docker build --secret id=my_key,src=./secret.txt .
```

**Dockerfile with BuildKit secrets**:
```dockerfile
FROM node:18
RUN --mount=type=secret,id=my_key \
  cp /run/secrets/my_key /app/config/key.txt
```

**Option 3: Runtime Volume Mount**
```bash
docker run -v /path/to/secrets:/run/secrets:ro myapp
```

## Dockerfile Security Best Practices

### Secure Dockerfile Template

```dockerfile
# Use specific version, not 'latest'
FROM node:18-alpine AS builder

# Don't run as root
USER node

# Install only production dependencies
COPY package*.json ./
RUN npm ci --only=production

# Copy application code
COPY --chown=node:node . .

# Use COPY instead of ADD (ADD can fetch URLs and extract archives)
# COPY is safer and more predictable

# Multi-stage builds reduce attack surface
FROM node:18-alpine
WORKDIR /app
COPY --from=builder --chown=node:node /app .

# Non-root user
USER node

# Health check
HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

EXPOSE 3000
CMD ["node", "server.js"]
```

### Security Anti-Patterns to Avoid

| Anti-Pattern | Risk | Fix |
|--------------|------|-----|
| `FROM image:latest` | Unpredictable builds | Pin specific version |
| `USER root` | Full container compromise | Use non-root user |
| `ADD http://...` | Supply chain attack | Use COPY |
| `ENV SECRET=...` | Secrets in image | Use secrets management |
| `--privileged` | Host escape | Remove flag |
| No resource limits | DoS attacks | Set memory/CPU limits |
| No health check | Zombie containers | Add HEALTHCHECK |

## Hardening Checklist

### Pre-Deployment

- [ ] Scan image for vulnerabilities
- [ ] Use minimal base image (alpine, distroless)
- [ ] Remove unnecessary packages
- [ ] Set non-root user
- [ ] Drop all capabilities, add only needed
- [ ] Enable read-only filesystem
- [ ] Set resource limits (memory, CPU, pids)
- [ ] Enable no-new-privileges
- [ ] Configure seccomp/AppArmor/SELinux
- [ ] Remove secrets from image
- [ ] Add health checks
- [ ] Sign images (Docker Content Trust)

### Runtime

- [ ] Don't mount Docker socket inside containers
- [ ] Don't use --privileged flag
- [ ] Monitor container behavior
- [ ] Keep base images updated
- [ ] Use network policies
- [ ] Implement secret rotation
- [ ] Enable audit logging

### Infrastructure

- [ ] Use HTTPS for Docker daemon
- [ ] Implement TLS mutual authentication
- [ ] Use private registries
- [ ] Enable image signing verification
- [ ] Implement RBAC
- [ ] Regular security audits
- [ ] Run docker-bench-security

## Common Security Commands

### Check Container Security

```bash
# View container capabilities
docker inspect <container> | grep -A 20 "EffectiveCaps"

# Check if running as root
docker exec <container> id

# View mounted volumes
docker inspect <container> | grep -A 10 "Mounts"

# Check security options
docker inspect <container> | grep -A 10 "SecurityOpt"
```

### Run Security Audit

```bash
# Install docker-bench-security
git clone https://github.com/docker/docker-bench-security
cd docker-bench-security
./docker-bench-security.sh
```

### Image Signing

```bash
# Enable Docker Content Trust
export DOCKER_CONTENT_TRUST=1

# Pull only signed images
docker pull <image>

# Backup signing keys
tar -zcvf private_keys_backup.tar.gz ~/.docker/trust/private
```

## Security Options Reference

### --security-opt Options

```bash
# Prevent privilege escalation
--security-opt=no-new-privileges:true

# Disable seccomp (not recommended)
--security-opt seccomp=unconfined

# Custom seccomp profile
--security-opt seccomp=/path/to/profile.json

# Disable AppArmor (not recommended)
--security-opt apparmor=unconfined

# Custom AppArmor profile
--security-opt apparmor=custom-profile

# Disable SELinux (not recommended)
--security-opt label:disable

# Custom SELinux label
--security-opt label=level:s0:c100,c200
```

### Capability Management

```bash
# Drop all capabilities
--cap-drop=all

# Add specific capabilities
--cap-add=NET_BIND_SERVICE
--cap-add=CHOWN
--cap-add=SETUID

# Drop specific capabilities
--cap-drop=NET_RAW
--cap-drop=SYS_ADMIN
```

## Alternative Runtimes

### gVisor

Provides stronger isolation between application and host kernel:

```bash
# Install runsc
# Use with Docker
docker run --runtime=runsc <image>
```

### Kata Containers

Uses lightweight VMs for stronger isolation:

```bash
# Install kata-runtime
# Use with Docker
docker run --runtime=kata <image>
```

## Troubleshooting

### Container Won't Start

```bash
# Check for capability issues
docker inspect <container> | grep -i cap

# Check for seccomp violations
docker logs <container>

# Check AppArmor/SELinux denials
dmesg | grep -i apparmor
dmesg | grep -i avc
```

### Performance Issues

```bash
# Check resource limits
docker stats <container>

# Check cgroup limits
cat /sys/fs/cgroup/memory/docker/<container-id>/memory.limit_in_bytes
```

## References

- [Docker Security Documentation](https://docs.docker.com/engine/security/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker/)
- [Docker Bench Security](https://github.com/docker/docker-bench-security)
- [Trivy](https://github.com/aquasecurity/trivy)
- [gVisor](https://github.com/google/gvisor)
- [Kata Containers](https://katacontainers.io/)
