#!/bin/bash
# Check UID/GID mapping for current process or specified PID
# Usage: ./check-uid-mapping.sh [PID]

PID=${1:-self}

echo "=== UID/GID Mapping Check ==="
echo ""

if [[ "$PID" == "self" ]]; then
    echo "Current process namespace:"
    ls -l /proc/self/ns/user
    echo ""
    echo "UID mapping:"
    cat /proc/self/uid_map 2>/dev/null || echo "Cannot read uid_map"
    echo ""
    echo "GID mapping:"
    cat /proc/self/gid_map 2>/dev/null || echo "Cannot read gid_map"
else
    echo "Process $PID namespace:"
    ls -l /proc/$PID/ns/user 2>/dev/null || echo "Cannot access namespace"
    echo ""
    echo "UID mapping:"
    cat /proc/$PID/uid_map 2>/dev/null || echo "Cannot read uid_map"
    echo ""
    echo "GID mapping:"
    cat /proc/$PID/gid_map 2>/dev/null || echo "Cannot read gid_map"
fi

echo ""
echo "=== Analysis ==="

# Check if root is root on host
if grep -q "^0[[:space:]]*0[[:space:]]" /proc/$PID/uid_map 2>/dev/null; then
    echo "⚠️  WARNING: Root (UID 0) maps to root on host"
    echo "   This namespace has NO user isolation"
else
    echo "✓ Root is remapped - user namespace isolation is active"
fi

echo ""
echo "=== Setgroups status ==="
cat /proc/$PID/setgroups 2>/dev/null || echo "Cannot read setgroups"
