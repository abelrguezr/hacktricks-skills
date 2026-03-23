#!/bin/bash
# Enumerate all user namespaces on the system
# Usage: ./enumerate-namespaces.sh

if [[ $EUID -ne 0 ]]; then
    echo "This script requires root privileges"
    echo "Run with: sudo $0"
    exit 1
fi

echo "=== User Namespace Enumeration ==="
echo ""

# Find all unique user namespaces
echo "Unique user namespaces:"
find /proc -maxdepth 3 -type l -name user -exec readlink {} \; 2>/dev/null | sort -u

echo ""
echo "=== Processes per namespace ==="

# Group processes by namespace
for ns in $(find /proc -maxdepth 3 -type l -name user -exec readlink {} \; 2>/dev/null | sort -u); do
    ns_id=$(echo "$ns" | grep -oP '\[\K[0-9]+')
    count=$(find /proc -maxdepth 3 -type l -name user -exec readlink {} \; 2>/dev/null | grep -c "$ns_id")
    echo "$ns: $count processes"
done

echo ""
echo "=== Current namespace ==="
ls -l /proc/self/ns/user
