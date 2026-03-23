#!/bin/bash
# Check current PID namespace and list all namespaces on the system

set -e

echo "=== Current PID Namespace ==="
if [ -e /proc/self/ns/pid ]; then
    readlink /proc/self/ns/pid
else
    echo "Cannot read /proc/self/ns/pid"
fi

echo ""
echo "=== All PID Namespaces on System ==="
if command -v sudo &> /dev/null; then
    sudo find /proc -maxdepth 3 -type l -name pid -exec readlink {} \; 2>/dev/null | sort -u
else
    echo "Note: Run with sudo to see all namespaces"
    find /proc -maxdepth 3 -type l -name pid -exec readlink {} \; 2>/dev/null | sort -u
fi

echo ""
echo "=== Processes in Current Namespace ==="
ps -ef --no-headers | head -20
