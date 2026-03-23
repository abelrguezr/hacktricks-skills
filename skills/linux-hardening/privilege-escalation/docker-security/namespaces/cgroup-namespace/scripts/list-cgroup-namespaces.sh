#!/bin/bash
# List all cgroup namespaces on the system
# Usage: ./list-cgroup-namespaces.sh

if [[ $EUID -ne 0 ]]; then
    echo "This script requires root privileges"
    echo "Please run with sudo"
    exit 1
fi

echo "=== All CGroup Namespaces ==="
echo ""

# Find all unique cgroup namespace IDs
namespaces=$(find /proc -maxdepth 3 -type l -name cgroup -exec readlink {} \; 2>/dev/null | sort -u)

if [[ -z "$namespaces" ]]; then
    echo "No cgroup namespaces found"
    exit 0
fi

for ns in $namespaces; do
    ns_id=$(echo "$ns" | grep -oP '\[\K[0-9]+')
    echo "Namespace: $ns"
    echo "Processes in this namespace:"
    
    # Find processes in this namespace
    find /proc -maxdepth 3 -type l -name cgroup -exec ls -l {} \; 2>/dev/null | grep "$ns_id" | while read line; do
        proc_path=$(echo "$line" | awk '{print $NF}')
        proc_id=$(echo "$proc_path" | sed 's|.*/proc/||' | sed 's|/ns/cgroup||')
        if [[ -f "/proc/$proc_id/comm" ]]; then
            comm=$(cat "/proc/$proc_id/comm" 2>/dev/null)
            echo "  PID $proc_id: $comm"
        fi
    done
    echo ""
done

echo "=== Current Process Namespace ==="
ls -l /proc/self/ns/cgroup
