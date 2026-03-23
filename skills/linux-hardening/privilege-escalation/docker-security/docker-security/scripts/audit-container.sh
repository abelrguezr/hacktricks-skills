#!/bin/bash
# Docker Container Security Auditor
# Checks a running container for security issues

set -e

CONTAINER="${1:-}"

if [ -z "$CONTAINER" ]; then
    echo "Usage: $0 <container-name-or-id>"
    echo "Example: $0 my-container"
    exit 1
fi

if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "Error: Container '$CONTAINER' not found"
    exit 1
fi

echo "=== Docker Container Security Audit ==="
echo "Container: $CONTAINER"
echo ""

# Get container inspect data
INSPECT=$(docker inspect "$CONTAINER")

# Check 1: Running as root
echo "[1/8] User Check"
USER=$(echo "$INSPECT" | jq -r '.[0].Config.User // "root"')
if [ "$USER" = "root" ] || [ -z "$USER" ]; then
    echo "  ⚠ WARNING: Container running as root"
else
    echo "  ✓ Running as non-root user: $USER"
fi
echo ""

# Check 2: Privileged mode
echo "[2/8] Privileged Mode Check"
PRIVILEGED=$(echo "$INSPECT" | jq -r '.[0].HostConfig.Privileged // false')
if [ "$PRIVILEGED" = "true" ]; then
    echo "  ⚠ WARNING: Container running in privileged mode"
else
    echo "  ✓ Not running in privileged mode"
fi
echo ""

# Check 3: Capabilities
echo "[3/8] Capabilities Check"
CAPS=$(echo "$INSPECT" | jq -r '.[0].HostConfig.CapAdd // [] | join(", ")')
DROPPED=$(echo "$INSPECT" | jq -r '.[0].HostConfig.CapDrop // [] | join(", ")')
if [ -n "$CAPS" ]; then
    echo "  ℹ Added capabilities: $CAPS"
else
    echo "  ✓ No additional capabilities added"
fi
if [ -n "$DROPPED" ]; then
    echo "  ℹ Dropped capabilities: $DROPPED"
else
    echo "  ℹ No capabilities explicitly dropped"
fi
echo ""

# Check 4: Security options
echo "[4/8] Security Options Check"
SECURITY_OPTS=$(echo "$INSPECT" | jq -r '.[0].HostConfig.SecurityOpt // [] | join("; ")')
if echo "$SECURITY_OPTS" | grep -q "no-new-privileges:true"; then
    echo "  ✓ no-new-privileges enabled"
else
    echo "  ⚠ WARNING: no-new-privileges not enabled"
fi
if echo "$SECURITY_OPTS" | grep -q "seccomp=unconfined"; then
    echo "  ⚠ WARNING: Seccomp disabled"
else
    echo "  ✓ Seccomp enabled"
fi
if echo "$SECURITY_OPTS" | grep -q "apparmor=unconfined"; then
    echo "  ⚠ WARNING: AppArmor disabled"
else
    echo "  ✓ AppArmor enabled"
fi
echo ""

# Check 5: Resource limits
echo "[5/8] Resource Limits Check"
MEMORY=$(echo "$INSPECT" | jq -r '.[0].HostConfig.Memory // 0')
CPUS=$(echo "$INSPECT" | jq -r '.[0].HostConfig.NanoCpus // 0')
PIDS=$(echo "$INSPECT" | jq -r '.[0].HostConfig.PidsLimit // 0')
if [ "$MEMORY" -gt 0 ]; then
    echo "  ✓ Memory limit: $((MEMORY / 1024 / 1024)) MB"
else
    echo "  ⚠ WARNING: No memory limit set"
fi
if [ "$CPUS" -gt 0 ]; then
    echo "  ✓ CPU limit: $((CPUS / 1000000000)) cores"
else
    echo "  ⚠ WARNING: No CPU limit set"
fi
if [ "$PIDS" -gt 0 ]; then
    echo "  ✓ PIDs limit: $PIDS"
else
    echo "  ⚠ WARNING: No PIDs limit set"
fi
echo ""

# Check 6: Read-only filesystem
echo "[6/8] Read-Only Filesystem Check"
READONLY=$(echo "$INSPECT" | jq -r '.[0].HostConfig.ReadonlyRootfs // false')
if [ "$READONLY" = "true" ]; then
    echo "  ✓ Read-only filesystem enabled"
else
    echo "  ℹ Read-only filesystem not enabled"
fi
echo ""

# Check 7: Docker socket mount
echo "[7/8] Docker Socket Check"
MOUNTS=$(echo "$INSPECT" | jq -r '.[0].Mounts[] | select(.Source == "/var/run/docker.sock") | .Destination' 2>/dev/null)
if [ -n "$MOUNTS" ]; then
    echo "  ⚠ WARNING: Docker socket mounted at $MOUNTS"
    echo "  ⚠ This allows full host control!"
else
    echo "  ✓ Docker socket not mounted"
fi
echo ""

# Check 8: Network mode
echo "[8/8] Network Mode Check"
NETWORK_MODE=$(echo "$INSPECT" | jq -r '.[0].HostConfig.NetworkMode // "default"')
if [ "$NETWORK_MODE" = "host" ]; then
    echo "  ⚠ WARNING: Using host network mode"
else
    echo "  ✓ Network mode: $NETWORK_MODE"
fi
echo ""

echo "=== Audit Complete ==="
echo ""
echo "Recommendations:"
echo "1. Run containers as non-root user"
echo "2. Avoid --privileged flag"
echo "3. Drop all capabilities, add only needed ones"
echo "4. Enable no-new-privileges"
echo "5. Set resource limits (memory, CPU, pids)"
echo "6. Use read-only filesystem when possible"
echo "7. Never mount Docker socket inside containers"
echo "8. Avoid host network mode"
