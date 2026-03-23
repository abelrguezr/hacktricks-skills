#!/bin/bash
# Namespace Isolation Check Script
# Run this INSIDE a container to check your namespace isolation

echo "=== Namespace Isolation Check ==="
echo "Running inside container"
echo

# Check PID namespace
echo "PID Namespace:"
PID_NS=$(readlink /proc/self/ns/pid 2>/dev/null || echo "unknown")
echo "  Current PID namespace: $PID_NS"

# Try to see if we can access host processes
echo "  Checking process visibility..."
HOST_PROCS=$(ps aux 2>/dev/null | wc -l)
if [ "$HOST_PROCS" -gt 20 ]; then
    echo "  ⚠️  WARNING: Can see many processes - may not be isolated"
else
    echo "  ✓ Limited process visibility (likely isolated)"
fi
echo

# Check mount namespace
echo "Mount Namespace:"
MNT_NS=$(readlink /proc/self/ns/mnt 2>/dev/null || echo "unknown")
echo "  Current mount namespace: $MNT_NS"

# Check if we can see host mounts
echo "  Checking mount isolation..."
if [ -d "/proc/1/root" ]; then
    HOST_ROOT=$(ls /proc/1/root 2>/dev/null | head -5 | tr '\n' ' ')
    echo "  ℹ️  /proc/1/root accessible: $HOST_ROOT"
    if [ -f "/proc/1/root/etc/passwd" ]; then
        HOST_ROOT_USER=$(grep root /proc/1/root/etc/passwd 2>/dev/null | cut -d: -f1)
        CONTAINER_ROOT_USER=$(grep root /etc/passwd 2>/dev/null | cut -d: -f1)
        if [ "$HOST_ROOT_USER" != "$CONTAINER_ROOT_USER" ]; then
            echo "  ⚠️  WARNING: Host /etc/passwd differs from container"
        fi
    fi
else
    echo "  ✓ /proc/1/root not accessible (good isolation)"
fi
echo

# Check network namespace
echo "Network Namespace:"
NET_NS=$(readlink /proc/self/ns/net 2>/dev/null || echo "unknown")
echo "  Current network namespace: $NET_NS"

# Check network interfaces
echo "  Network interfaces:"
if command -v ip &> /dev/null; then
    ip -brief addr show 2>/dev/null | head -5
elif command -v ifconfig &> /dev/null; then
    ifconfig -a 2>/dev/null | grep "^" | head -5
else
    echo "  ℹ️  No network tools available"
fi
echo

# Check IPC namespace
echo "IPC Namespace:"
IPC_NS=$(readlink /proc/self/ns/ipc 2>/dev/null || echo "unknown")
echo "  Current IPC namespace: $IPC_NS"
echo

# Check UTS namespace
echo "UTS Namespace:"
UTS_NS=$(readlink /proc/self/ns/uts 2>/dev/null || echo "unknown")
echo "  Current UTS namespace: $UTS_NS"
echo "  Hostname: $(hostname 2>/dev/null || echo 'unknown')"
echo

# Check user namespace
echo "User Namespace:"
USER_NS=$(readlink /proc/self/ns/user 2>/dev/null || echo "unknown")
echo "  Current user namespace: $USER_NS"
echo "  Current user: $(id 2>/dev/null || echo 'unknown')"

# Check if we're root
echo "  UID: $(id -u 2>/dev/null || echo 'unknown')"
if [ "$(id -u 2>/dev/null)" = "0" ]; then
    echo "  ⚠️  Running as root inside container"
    echo "  ℹ️  Check if user namespace maps this to non-root on host"
fi
echo

# Check for namespace escape indicators
echo "=== Potential Escape Indicators ==="

# Check for privileged indicators
if [ -d "/dev/kmsg" ]; then
    echo "  ⚠️  /dev/kmsg accessible (kernel messages)"
fi

if [ -d "/dev/mem" ]; then
    echo "  ⚠️  /dev/mem accessible (physical memory)"
fi

if [ -d "/sys/kernel/debug" ]; then
    echo "  ⚠️  Kernel debug accessible"
fi

# Check for Docker socket
if [ -S "/var/run/docker.sock" ]; then
    echo "  ⚠️  Docker socket accessible (can spawn containers)"
fi

echo

echo "=== Summary ==="
echo "If you see multiple WARNING indicators, your container may not be properly isolated."
echo "For security audits, compare these values with the host system."
