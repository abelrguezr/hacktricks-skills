#!/bin/bash
# Find all processes in a specific IPC namespace

if [ -z "$1" ]; then
    echo "Usage: $0 <namespace-id>"
    echo "Example: $0 4026531839"
    echo ""
    echo "To find namespace IDs:"
    echo "  sudo find /proc -maxdepth 3 -type l -name ipc -exec readlink {} \\; 2>/dev/null | sort -u"
    exit 1
fi

NS_ID="$1"

echo "=== Processes in IPC namespace: $NS_ID ==="
echo ""

if [ "$EUID" -ne 0 ]; then
    echo "This script requires root privileges"
    exec sudo "$0" "$NS_ID"
fi

# Find processes with this namespace
sudo find /proc -maxdepth 3 -type l -name ipc -exec ls -l {} \; 2>/dev/null | grep "$NS_ID" | while read line; do
    PROC_PATH=$(echo "$line" | awk '{print $NF}')
    PID=$(echo "$PROC_PATH" | sed 's|.*/proc/||' | sed 's|/ns/ipc||')
    
    if [ -f "/proc/$PID/comm" ]; then
        COMM=$(cat "/proc/$PID/comm" 2>/dev/null || echo "<unknown>")
        echo "PID $PID: $COMM"
    fi
done

echo ""
echo "Total processes found: $(sudo find /proc -maxdepth 3 -type l -name ipc -exec ls -l {} \; 2>/dev/null | grep -c "$NS_ID")"
