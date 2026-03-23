#!/bin/bash
# Create a new cgroup namespace and start a shell
# Usage: ./create-cgroup-namespace.sh

if [[ $EUID -ne 0 ]]; then
    echo "This script requires root privileges"
    echo "Please run with sudo"
    exit 1
fi

echo "Creating new cgroup namespace..."
echo ""
echo "Your new namespace will have:"
echo "  - Isolated cgroup hierarchy view"
echo "  - Your own cgroup as the root"
echo "  - Isolated /proc filesystem"
echo ""
echo "Current namespace: $(ls -l /proc/self/ns/cgroup)"
echo ""
echo "Starting shell in new cgroup namespace..."
echo "Type 'exit' to return to the host namespace"
echo ""

# Create namespace with fork to prevent PID allocation issues
unshare -fC --mount-proc /bin/bash
