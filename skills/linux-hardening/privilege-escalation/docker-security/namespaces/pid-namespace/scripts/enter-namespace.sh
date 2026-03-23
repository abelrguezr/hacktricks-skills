#!/bin/bash
# Safely enter a target PID namespace

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <TARGET_PID>"
    echo "  TARGET_PID: The PID of a process in the namespace you want to enter"
    echo ""
    echo "Example: $0 1234"
    echo ""
    echo "Note: You must be root to enter another process's PID namespace"
    exit 1
fi

TARGET_PID=$1

echo "Checking if process $TARGET_PID exists..."
if [ ! -d "/proc/$TARGET_PID" ]; then
    echo "Error: Process $TARGET_PID does not exist"
    exit 1
fi

echo "Target namespace:"
readlink /proc/$TARGET_PID/ns/pid

echo ""
echo "Entering PID namespace of process $TARGET_PID..."
echo "You will be dropped into a bash shell in that namespace."
echo "Press Ctrl+D to exit."
echo ""

if command -v sudo &> /dev/null; then
    sudo nsenter -t $TARGET_PID --pid /bin/bash
else
    echo "Error: nsenter requires root privileges. Try running with sudo."
    exit 1
fi
