#!/bin/bash
# List all network namespaces and their associated processes
# Usage: ./list-namespaces.sh

set -e

echo "=== Network Namespace Enumeration ==="
echo ""

# Find all unique network namespaces
namespaces=$(sudo find /proc -maxdepth 3 -type l -name net -exec readlink {} \; 2>/dev/null | sort -u | grep "net:" || true)

if [ -z "$namespaces" ]; then
    echo "No network namespaces found (or insufficient permissions)"
    exit 1
fi

echo "Found $(echo "$namespaces" | wc -l) network namespace(s):"
echo ""

for ns in $namespaces; do
    echo "=== $ns ==="
    
    # Find processes in this namespace
    pids=$(sudo find /proc -maxdepth 3 -type l -name net -exec ls -l {} \; 2>/dev/null | grep "$ns" | awk '{print $9}' | xargs -I {} basename {} 2>/dev/null | sort -u || true)
    
    if [ -n "$pids" ]; then
        echo "Processes:"
        for pid in $pids; do
            if [ -d "/proc/$pid" ]; then
                cmd=$(cat /proc/$pid/cmdline 2>/dev/null | tr '\0' ' ' || echo "<unknown>")
                user=$(stat -c '%U' /proc/$pid 2>/dev/null || echo "<unknown>")
                echo "  PID $pid ($user): $cmd"
            fi
        done
    else
        echo "  No processes found"
    fi
    
    echo ""
done

echo "=== Current Process Namespace ==="
ls -l /proc/self/ns/net 2>/dev/null || echo "Cannot access current namespace"
