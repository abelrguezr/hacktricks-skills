#!/bin/bash
# Docker Hardening Checklist Generator
# Creates a customized hardening checklist based on your environment

set -e

echo "=== Docker Hardening Checklist ==="
echo ""
echo "Generated: $(date)"
echo ""

# Create checklist file
CHECKLIST_FILE="/tmp/docker-hardening-checklist-$(date +%Y%m%d-%H%M%S).md"

cat > "$CHECKLIST_FILE" << 'EOF'
# Docker Hardening Checklist

## Pre-Deployment Security

### Docker Daemon Configuration
- [ ] Run Docker daemon with `--userns-remap=default` for user namespace remapping
- [ ] Enable AppArmor: `--userns-remap=default --security-opt apparmor=docker-default`
- [ ] Enable Seccomp: `--security-opt seccomp=default`
- [ ] Restrict socket permissions: `chmod 660 /var/run/docker.sock`
- [ ] Set socket ownership: `chown root:docker /var/run/docker.sock`
- [ ] Disable legacy API: `--api-cors-header=""`
- [ ] Use TLS for Docker daemon: `--tlsverify --tlscacert --tlscert --tlskey`

### Container Runtime Security
- [ ] Run containers as non-root: `--user 1000:1000`
- [ ] Drop all capabilities: `--cap-drop=ALL`
- [ ] Add only required capabilities: `--cap-add=NET_BIND_SERVICE` (example)
- [ ] Use read-only root filesystem: `--read-only`
- [ ] Disable privilege escalation: `--security-opt no-new-privileges`
- [ ] Don't share host namespaces: Avoid `--pid=host`, `--uts=host`, `--userns=host`
- [ ] Use security profiles: `--security-opt apparmor=docker-default`
- [ ] Set resource limits: `--memory=512m --cpus=1.0 --pids-limit=100`

### Network Security
- [ ] Use custom networks instead of bridge: `--network custom-network`
- [ ] Restrict port exposure: Use `--publish` only for required ports
- [ ] Enable network policies: Use Kubernetes NetworkPolicies or similar
- [ ] Use DNS filtering: Configure DNS to block malicious domains
- [ ] Implement network segmentation: Separate production and development networks

### Image Security
- [ ] Use minimal base images: Alpine, distroless, or scratch
- [ ] Scan images for vulnerabilities: Use Trivy, Clair, or similar
- [ ] Sign images: Use Docker Content Trust or Cosign
- [ ] Pin image versions: Use specific tags, not `latest`
- [ ] Verify image signatures: `--disable-content-trust=false`
- [ ] Use private registries: Avoid public registries for production

### Mount Security
- [ ] Avoid mounting host root: Never use `-v /:/host`
- [ ] Mount only required directories: Minimize volume mounts
- [ ] Use read-only mounts: `-v /path:/path:ro`
- [ ] Don't mount sensitive files: Avoid `/etc/shadow`, `/etc/passwd`
- [ ] Use tmpfs for temporary data: `--tmpfs /tmp:rw,noexec,nosuid,size=100m`
- [ ] Restrict Docker socket access: Never mount `/var/run/docker.sock` unless required

## Runtime Monitoring

### Logging & Auditing
- [ ] Enable Docker logging: Configure json-file or syslog logging
- [ ] Monitor container events: `docker events`
- [ ] Log privileged operations: Track `docker run --privileged`
- [ ] Monitor socket access: Track `/var/run/docker.sock` access
- [ ] Set up alerting: Alert on suspicious container activity
- [ ] Retain logs: Keep logs for compliance requirements

### Intrusion Detection
- [ ] Deploy Falco: Container runtime security monitoring
- [ ] Enable audit logging: Track system calls
- [ ] Monitor for container escape: Watch for suspicious processes
- [ ] Track capability changes: Alert on capability additions
- [ ] Monitor mount operations: Track new volume mounts
- [ ] Watch for namespace changes: Alert on namespace sharing

### Resource Monitoring
- [ ] Monitor CPU usage: Alert on high CPU consumption
- [ ] Monitor memory usage: Alert on memory exhaustion
- [ ] Monitor network traffic: Detect unusual network patterns
- [ ] Monitor disk I/O: Track disk usage and I/O operations
- [ ] Set resource limits: Prevent resource exhaustion attacks

## Incident Response

### Detection Procedures
- [ ] Regular security scans: Schedule automated vulnerability scans
- [ ] Log analysis: Review logs for suspicious activity
- [ ] Container inspection: Regularly inspect running containers
- [ ] Network monitoring: Monitor for unusual network traffic
- [ ] File integrity monitoring: Track changes to critical files

### Response Procedures
- [ ] Isolate compromised containers: Stop and quarantine affected containers
- [ ] Preserve evidence: Save container logs and state
- [ ] Identify attack vector: Determine how the compromise occurred
- [ ] Assess impact: Evaluate what data or systems were affected
- [ ] Remediate: Fix the vulnerability and rebuild containers
- [ ] Document: Create incident report for future reference

## Compliance & Governance

### Policy Enforcement
- [ ] Define security policies: Document acceptable container configurations
- [ ] Implement policy as code: Use OPA, Kyverno, or similar
- [ ] Enforce image policies: Only allow approved images
- [ ] Enforce runtime policies: Block non-compliant containers
- [ ] Regular audits: Conduct periodic security audits
- [ ] Training: Train team on container security best practices

### Documentation
- [ ] Maintain inventory: Track all containers and their purposes
- [ ] Document configurations: Record security configurations
- [ ] Update runbooks: Keep incident response procedures current
- [ ] Track vulnerabilities: Maintain vulnerability management process
- [ ] Review policies: Regularly review and update security policies

## Quick Reference Commands

```bash
# Check Docker socket permissions
ls -la /var/run/docker.sock

# List running containers with security info
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Inspect container security settings
docker inspect <container_id>

# Check for privileged containers
docker ps --filter "label=com.docker.compose.project" --format "{{.Names}}"

# Monitor Docker events
docker events --filter "type=container"

# Scan images for vulnerabilities
trivy image <image_name>

# Check container capabilities
cat /proc/self/status | grep Cap
```

## Additional Resources

- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [Container Security Checklist](https://github.com/docker/docker.github.io/blob/master/security.md)
- [OWASP Container Security](https://owasp.org/www-project-container-security/)

---
*Generated by Docker Hardening Checklist Script*
*Remember: Security is a process, not a product. Regularly review and update your security posture.*
EOF

echo "✓ Checklist generated: $CHECKLIST_FILE"
echo ""
echo "To view the checklist:"
echo "  cat $CHECKLIST_FILE"
echo ""
echo "To open in your editor:"
echo "  $EDITOR $CHECKLIST_FILE"
echo ""
echo "To convert to HTML:"
echo "  pandoc $CHECKLIST_FILE -o docker-hardening-checklist.html"
