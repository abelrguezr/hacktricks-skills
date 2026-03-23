#!/bin/bash
# Docker Security Audit Script
# Run this script to audit Docker security configurations

set -e

echo "=== Docker Security Audit ==="
echo ""

# Check Docker socket permissions
echo "[1/8] Checking Docker socket permissions..."
if [ -S /var/run/docker.sock ]; then
    SOCKET_PERMS=$(stat -c '%a' /var/run/docker.sock 2>/dev/null || echo "unknown")
    SOCKET_OWNER=$(stat -c '%U:%G' /var/run/docker.sock 2>/dev/null || echo "unknown")
    echo "  Socket permissions: $SOCKET_PERMS (should be 660)"
    echo "  Socket owner: $SOCKET_OWNER (should be root:docker)"
    if [ "$SOCKET_PERMS" != "660" ]; then
        echo "  ⚠️ WARNING: Socket permissions are too permissive!"
    fi
else
    echo "  ℹ️ Docker socket not found (Docker may not be running)"
fi
echo ""

# Check for privileged containers
echo "[2/8] Checking for privileged containers..."
PRIVILEGED=$(docker ps --format '{{.Names}}' 2>/dev/null | while read name; do
    if docker inspect --format '{{.HostConfig.Privileged}}' "$name" 2>/dev/null | grep -q "true"; then
        echo "$name"
    fi
done)
if [ -n "$PRIVILEGED" ]; then
    echo "  ⚠️ WARNING: Privileged containers found:"
    echo "$PRIVILEGED" | sed 's/^/    - /'
else
    echo "  ✓ No privileged containers found"
fi
echo ""

# Check for host namespace sharing
echo "[3/8] Checking for host namespace sharing..."
NAMESPACE_ISSUES=$(docker ps --format '{{.Names}}' 2>/dev/null | while read name; do
    INSPECT=$(docker inspect "$name" 2>/dev/null)
    if echo "$INSPECT" | grep -q '"PidMode": "host"'; then
        echo "$name (PID namespace)"
    fi
    if echo "$INSPECT" | grep -q '"UtsMode": "host"'; then
        echo "$name (UTS namespace)"
    fi
    if echo "$INSPECT" | grep -q '"UsernsMode": "host"'; then
        echo "$name (User namespace)"
    fi
done)
if [ -n "$NAMESPACE_ISSUES" ]; then
    echo "  ⚠️ WARNING: Host namespace sharing detected:"
    echo "$NAMESPACE_ISSUES" | sed 's/^/    - /'
else
    echo "  ✓ No host namespace sharing found"
fi
echo ""

# Check for dangerous capabilities
echo "[4/8] Checking for dangerous capabilities..."
DANGEROUS_CAPS=$(docker ps --format '{{.Names}}' 2>/dev/null | while read name; do
    CAPS=$(docker inspect --format '{{range .HostConfig.CapAdd}}{{.}} {{end}}' "$name" 2>/dev/null)
    if echo "$CAPS" | grep -qE "(SYS_ADMIN|NET_ADMIN|ALL)"; then
        echo "$name: $CAPS"
    fi
done)
if [ -n "$DANGEROUS_CAPS" ]; then
    echo "  ⚠️ WARNING: Dangerous capabilities detected:"
    echo "$DANGEROUS_CAPS" | sed 's/^/    - /'
else
    echo "  ✓ No dangerous capabilities found"
fi
echo ""

# Check for host filesystem mounts
echo "[5/8] Checking for host filesystem mounts..."
HOST_MOUNTS=$(docker ps --format '{{.Names}}' 2>/dev/null | while read name; do
    MOUNTS=$(docker inspect --format '{{range .Mounts}}{{.Source}}:{{.Destination}} {{end}}' "$name" 2>/dev/null)
    if echo "$MOUNTS" | grep -qE "^/:|^/etc:|^/var:|^/root:"; then
        echo "$name: $MOUNTS"
    fi
done)
if [ -n "$HOST_MOUNTS" ]; then
    echo "  ⚠️ WARNING: Host filesystem mounts detected:"
    echo "$HOST_MOUNTS" | sed 's/^/    - /'
else
    echo "  ✓ No dangerous host mounts found"
fi
echo ""

# Check for disabled security options
echo "[6/8] Checking for disabled security options..."
SECURITY_ISSUES=$(docker ps --format '{{.Names}}' 2>/dev/null | while read name; do
    INSPECT=$(docker inspect "$name" 2>/dev/null)
    if echo "$INSPECT" | grep -q '"AppArmorProfile": "unconfined"'; then
        echo "$name (AppArmor disabled)"
    fi
    if echo "$INSPECT" | grep -q '"SeccompProfile": "unconfined"'; then
        echo "$name (Seccomp disabled)"
    fi
    if echo "$INSPECT" | grep -q '"LabelDisable": true'; then
        echo "$name (SELinux labels disabled)"
    fi
done)
if [ -n "$SECURITY_ISSUES" ]; then
    echo "  ⚠️ WARNING: Security options disabled:"
    echo "$SECURITY_ISSUES" | sed 's/^/    - /'
else
    echo "  ✓ Security options appear to be enabled"
fi
echo ""

# Check for root user containers
echo "[7/8] Checking for root user containers..."
ROOT_CONTAINERS=$(docker ps --format '{{.Names}}' 2>/dev/null | while read name; do
    USER=$(docker inspect --format '{{.Config.User}}' "$name" 2>/dev/null)
    if [ -z "$USER" ] || [ "$USER" = "0" ] || [ "$USER" = "root" ]; then
        echo "$name"
    fi
done)
if [ -n "$ROOT_CONTAINERS" ]; then
    echo "  ⚠️ WARNING: Containers running as root:"
    echo "$ROOT_CONTAINERS" | sed 's/^/    - /'
else
    echo "  ✓ No containers running as root"
fi
echo ""

# Check for device access
echo "[8/8] Checking for device access..."
DEVICE_ACCESS=$(docker ps --format '{{.Names}}' 2>/dev/null | while read name; do
    DEVICES=$(docker inspect --format '{{range .HostConfig.Devices}}{{.PathOnHost}} {{end}}' "$name" 2>/dev/null)
    if [ -n "$DEVICES" ]; then
        echo "$name: $DEVICES"
    fi
done)
if [ -n "$DEVICE_ACCESS" ]; then
    echo "  ℹ️ Device access detected:"
    echo "$DEVICE_ACCESS" | sed 's/^/    - /'
else
    echo "  ✓ No device access found"
fi
echo ""

echo "=== Audit Complete ==="
echo ""
echo "Recommendations:"
echo "1. Restrict Docker socket permissions to 660"
echo "2. Avoid running privileged containers"
echo "3. Don't share host namespaces unless necessary"
echo "4. Drop unnecessary capabilities"
echo "5. Avoid mounting sensitive host directories"
echo "6. Keep security profiles enabled"
echo "7. Run containers as non-root users"
echo "8. Limit device access"
