---
name: docker-authz-audit
description: Audit Docker authorization plugins and identify security misconfigurations. Use this skill whenever the user mentions Docker security, authorization plugins, container access control, Docker daemon security, authz bypass, or needs to assess Docker plugin configurations. This skill helps security professionals enumerate auth plugin policies, test for common bypass techniques, and identify privilege escalation vectors in Docker environments.
---

# Docker Authorization Plugin Audit

This skill helps you audit Docker authorization plugins and identify security misconfigurations that could lead to privilege escalation. Use this for **authorized security assessments only**.

## Quick Start

```bash
# Check if Docker is accessible
docker version

# List installed authorization plugins
docker plugin list

# Check daemon configuration for auth plugins
cat /etc/docker/daemon.json | grep -i authz
```

## Audit Workflow

### 1. Enumerate Auth Plugin Configuration

First, determine what authorization plugins are installed and how they're configured:

```bash
# Check daemon.json for authz plugins
cat /etc/docker/daemon.json

# Look for plugins in Docker's plugin directory
ls -la /var/lib/docker/plugins/

# Check running plugins
docker plugin ls

# Examine plugin configuration files
find /etc/docker -name "*.json" -exec grep -l authz {} \;
```

### 2. Test Plugin Enforcement

Run test commands to see what the plugin allows or denies:

```bash
# Test basic container creation
docker run --rm ubuntu echo "test"

# Test privileged container (should be denied if plugin is working)
docker run --rm --privileged ubuntu id

# Test volume mounts
docker run --rm -v /:/host ubuntu ls /host

# Test capability additions
docker run --rm --cap-add=SYS_ADMIN ubuntu id
```

### 3. Identify Bypass Opportunities

#### A. Check for Privileged Flag Bypass

If `--privileged` is blocked but `docker exec` is allowed:

```bash
# Start a container without privileged flag
docker run -d --security-opt seccomp=unconfined --security-opt apparmor=unconfined ubuntu sleep 3600

# Get container ID
CONTAINER_ID=$(docker ps -q)

# Try exec with privileged
docker exec -it $CONTAINER_ID --cap-add=SYS_ADMIN bash
```

#### B. Test Writable Mount Points

Check if writable directories can be mounted:

```bash
# Find writable directories on host
find / -writable -type d 2>/dev/null

# Check which support SUID
mount | grep -v "nosuid"

# Test mounting /tmp or other writable paths
docker run -it -v /tmp:/host ubuntu bash
```

#### C. Test API Endpoint Bypass

Some plugins only check certain API endpoints. Test direct API calls:

```bash
# Get Docker API version
API_VERSION=$(docker version --format '{{.Server.APIVersion}}')

# Test container creation via API with Binds
curl --unix-socket /var/run/docker.sock \
  -H "Content-Type: application/json" \
  -d '{"Image": "ubuntu", "Binds":["/:/host"]}' \
  http://localhost/v${API_VERSION}/containers/create

# Test with HostConfig
curl --unix-socket /var/run/docker.sock \
  -H "Content-Type: application/json" \
  -d '{"Image": "ubuntu", "HostConfig":{"Binds":["/:/host"]}}' \
  http://localhost/v${API_VERSION}/containers/create
```

#### D. Test Capability Bypass

Check if specific capabilities are allowed:

```bash
# Test SYS_MODULE capability
curl --unix-socket /var/run/docker.sock \
  -H "Content-Type: application/json" \
  -d '{"Image": "ubuntu", "HostConfig":{"Capabilities":["CAP_SYS_MODULE"]}}' \
  http://localhost/v${API_VERSION}/containers/create
```

#### E. Test Plugin Disable

Check if the plugin can be disabled:

```bash
# List plugins
docker plugin ls

# Try to disable (if you have permission)
docker plugin disable <plugin-name>

# Test if Docker works without plugin
docker run --rm --privileged ubuntu id

# Re-enable after testing
docker plugin enable <plugin-name>
```

## Common Misconfigurations

| Misconfiguration | Risk | Detection |
|-----------------|------|------------|
| `--privileged` blocked but `docker exec` allowed | High | Container escape via exec |
| Writable mounts allowed | High | SUID binary placement |
| API endpoints not fully checked | High | Direct API bypass |
| JSON structure validation incomplete | Medium | Binds/Mounts in wrong location |
| Capabilities not restricted | Medium | SYS_MODULE, SYS_ADMIN abuse |
| Plugin disable not blocked | Critical | Complete bypass |

## Security Recommendations

1. **Use allowlist approach** - Only explicitly allow required actions
2. **Validate JSON structure** - Check both root and HostConfig levels
3. **Restrict docker exec** - Limit exec to specific containers
4. **Block plugin disable** - Ensure plugin cannot be disabled by users
5. **Monitor plugin logs** - Watch for repeated denial attempts
6. **Use seccomp/apparmor** - Defense in depth beyond authz plugins

## Reference Tools

- [docker_auth_profiler](https://github.com/carlospolop/docker_auth_profiler) - Enumerate auth plugin policies
- [authz](https://github.com/twistlock/authz) - Example authz plugin
- [authobot](https://github.com/carlospolop-forks/authobot) - Simple authz plugin tutorial

## Important Notes

- **Authorization plugins only check initial HTTP requests** - Streaming data (exec, logs) is not passed to plugins
- **No credentials are passed** - Only username and auth method, never passwords or tokens
- **Multiple plugins chain together** - All must grant access for the request to succeed
- **Plugin disable requires re-enable** - If you disable a plugin for testing, re-enable it or Docker won't start properly

## When to Use This Skill

Use this skill when:
- You need to audit Docker authorization plugin configurations
- You're performing a security assessment of a Docker environment
- You want to understand how Docker authz plugins work
- You need to identify privilege escalation vectors in Docker
- You're hardening Docker daemon security
- You're investigating Docker container escape scenarios

## Disclaimer

This skill is for **authorized security testing only**. Always have proper authorization before testing Docker security configurations. Unauthorized access to Docker daemons may violate laws and policies.
