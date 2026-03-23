#!/bin/bash
# Enter a specific UTS namespace
# Usage: ./enter-uts-namespace.sh <target-pid> [shell]
# Example: ./enter-uts-namespace.sh 1234 /bin/bash

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <target-pid> [shell]"
    echo ""
    echo "Enter a UTS namespace by specifying a process ID that's already in it."
    echo ""
    echo "Examples:"
    echo "  $0 1234                    # Enter namespace of PID 1234 with default shell"
    echo "  $0 1234 /bin/bash          # Enter namespace of PID 1234 with bash"
    echo "  $0 1234 /bin/sh            # Enter namespace of PID 1234 with sh"
    echo ""
    echo "To find PIDs in a specific namespace, use:"
    echo "  ./list-uts-namespaces.sh"
    exit 1
fi

TARGET_PID=$1
SHELL=${2:-/bin/bash}

# Check if the target process exists
if [ ! -d "/proc/$TARGET_PID" ]; then
    echo "Error: Process $TARGET_PID does not exist"
    exit 1
fi

# Check if we can access the UTS namespace
if [ ! -L "/proc/$TARGET_PID/ns/uts" ]; then
    echo "Error: Cannot access UTS namespace of process $TARGET_PID"
    echo "You may need root access or appropriate capabilities."
    exit 1
fi

# Show target namespace info
TARGET_NS=$(readlink /proc/$TARGET_PID/ns/uts)
echo "Target UTS namespace: $TARGET_NS"
echo "Target process: $TARGET_PID"
echo "Shell: $SHELL"
echo ""
echo "Entering namespace..."
echo ""

# Enter the namespace
if command -v nsenter &> /dev/null; then
    sudo nsenter -u "$TARGET_PID" --pid "$SHELL"
else
    echo "Error: nsenter not found. Install it with:"
    echo "  apt-get install util-linux  # Debian/Ubuntu"
    echo "  yum install util-linux      # RHEL/CentOS"
    exit 1
fi
