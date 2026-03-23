#!/bin/bash
# Enter a cgroup namespace of a target process
# Usage: ./enter-cgroup-namespace.sh <target_pid>

if [[ $EUID -ne 0 ]]; then
    echo "This script requires root privileges"
    echo "Please run with sudo"
    exit 1
fi

if [[ -z "$1" ]]; then
    echo "Usage: $0 <target_pid>"
    echo "Example: $0 1234"
    exit 1
fi

TARGET_PID=$1

# Check if the process exists
if [[ ! -d "/proc/$TARGET_PID" ]]; then
    echo "Error: Process $TARGET_PID does not exist"
    exit 1
fi

# Check if the cgroup namespace exists
if [[ ! -L "/proc/$TARGET_PID/ns/cgroup" ]]; then
    echo "Error: Cannot find cgroup namespace for process $TARGET_PID"
    exit 1
fi

# Show target process info
echo "Target process:"
echo "  PID: $TARGET_PID"
echo "  Command: $(cat /proc/$TARGET_PID/comm 2>/dev/null)"
echo "  CGroup namespace: $(readlink /proc/$TARGET_PID/ns/cgroup)"
echo ""

# Enter the namespace
echo "Entering cgroup namespace of PID $TARGET_PID..."
nsenter -t $TARGET_PID -C -- /bin/bash
