#!/bin/bash
# Container Enumeration Script
# Run this first to understand your container's security posture

echo "=== Docker Container Enumeration ==="
echo ""

echo "[1] User Information"
whoami
id
echo ""

echo "[2] Docker Socket Check"
if [ -f /var/run/docker.sock ]; then
    echo "Docker socket found at /var/run/docker.sock"
    ls -la /var/run/docker.sock
else
    echo "Docker socket not found at /var/run/docker.sock"
    find / -name docker.sock 2>/dev/null
fi
echo ""

echo "[3] Other Runtime Sockets"
for socket in /var/run/dockershim.sock /run/containerd/containerd.sock /var/run/crio/crio.sock; do
    if [ -f "$socket" ]; then
        echo "Found: $socket"
        ls -la "$socket"
    fi
done
echo ""

echo "[4] Container Capabilities"
if command -v capsh &> /dev/null; then
    capsh --print | grep -A 20 "Current"
else
    echo "capsh not available"
    cat /proc/self/status | grep Cap
fi
echo ""

echo "[5] Privileged Mode Indicators"
echo "Checking for privileged indicators..."
if [ -f /proc/self/status ]; then
    cat /proc/self/status | grep CapEff
fi
echo ""

echo "[6] Mounted Volumes"
mount | grep -v -E 'cgroup|proc|sysfs|tmpfs|mqueue|devpts|shm' | head -20
echo ""

echo "[7] Sensitive Mounts Check"
echo "Checking for sensitive files..."
for file in /sys/fs/cgroup/*/release_agent /proc/sys/fs/binfmt_misc/* /proc/sys/kernel/core_pattern /sys/kernel/uevent_helper /proc/sys/kernel/modprobe; do
    if [ -f "$file" ] 2>/dev/null; then
        echo "Found: $file"
    fi
done
echo ""

echo "[8] Namespace Information"
echo "PID namespace:"
ls -la /proc/1/ns/pid 2>/dev/null
echo "Mount namespace:"
ls -la /proc/1/ns/mnt 2>/dev/null
echo "Network namespace:"
ls -la /proc/1/ns/net 2>/dev/null
echo ""

echo "[9] Host Process Access (if hostPID)"
if [ -d /proc/1/root ]; then
    echo "Can access /proc/1/root - possible hostPID or privileged"
    ls -la /proc/1/root/ 2>/dev/null | head -10
fi
echo ""

echo "[10] Seccomp Profile"
if [ -f /proc/self/status ]; then
    cat /proc/self/status | grep Seccomp
fi
echo ""

echo "[11] AppArmor Profile"
if [ -f /proc/self/status ]; then
    cat /proc/self/status | grep AppArmor
fi
echo ""

echo "[12] Cgroup Information"
if [ -d /sys/fs/cgroup ]; then
    echo "Cgroup version:"
    ls /sys/fs/cgroup/ | head -5
    echo ""
    echo "Cgroup controllers:"
    ls /sys/fs/cgroup/ 2>/dev/null
fi
echo ""

echo "=== Enumeration Complete ==="
echo "Review the output above for potential escape vectors"
