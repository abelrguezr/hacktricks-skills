#!/bin/bash
# Check current IPC namespace and compare with host

echo "=== IPC Namespace Check ==="
echo ""

# Current namespace
echo "Current process IPC namespace:"
ls -l /proc/self/ns/ipc 2>/dev/null || echo "Cannot read namespace (permission denied)"
echo ""

# Host namespace (if accessible)
echo "Host namespace (PID 1):"
if [ -r /proc/1/ns/ipc ]; then
    ls -l /proc/1/ns/ipc
else
    echo "Cannot read host namespace (not root or PID 1 not accessible)"
fi
echo ""

# All namespaces on system
echo "All IPC namespaces on system:"
if [ "$EUID" -eq 0 ]; then
    sudo find /proc -maxdepth 3 -type l -name ipc -exec readlink {} \; 2>/dev/null | sort -u | head -20
    echo "... (showing first 20)"
else
    echo "Run as root to see all namespaces"
fi
echo ""

# Check if isolated
echo "Isolation status:"
CURRENT_NS=$(readlink /proc/self/ns/ipc 2>/dev/null)
HOST_NS=$(readlink /proc/1/ns/ipc 2>/dev/null)

if [ -n "$CURRENT_NS" ] && [ -n "$HOST_NS" ]; then
    if [ "$CURRENT_NS" = "$HOST_NS" ]; then
        echo "⚠️  WARNING: You share the host's IPC namespace (potential security issue)"
    else
        echo "✓ You are in an isolated IPC namespace"
    fi
else
    echo "Could not determine isolation status"
fi
