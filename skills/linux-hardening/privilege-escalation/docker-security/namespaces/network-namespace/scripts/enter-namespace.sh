#!/bin/bash
# Enter a network namespace by PID or namespace name
# Usage: ./enter-namespace.sh <PID|NS_NAME> [COMMAND]

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <PID|NS_NAME> [COMMAND]"
    echo ""
    echo "Examples:"
    echo "  $0 1234                    # Enter namespace of PID 1234"
    echo "  $0 1234 /bin/bash          # Enter namespace with custom shell"
    echo "  $0 net:[4026531840]        # Enter by namespace name"
    exit 1
fi

TARGET=$1
COMMAND=${2:-/bin/bash}

echo "Attempting to enter network namespace: $TARGET"
echo ""

# Check if target is a PID or namespace name
if [[ "$TARGET" =~ ^[0-9]+$ ]]; then
    # It's a PID
    if [ ! -d "/proc/$TARGET" ]; then
        echo "Error: Process $TARGET does not exist"
        exit 1
    fi
    
    NS_PATH="/proc/$TARGET/ns/net"
    echo "Target PID: $TARGET"
    echo "Namespace: $(readlink $NS_PATH 2>/dev/null || echo 'unknown')"
    
    # Enter the namespace
    sudo nsenter -t $TARGET -n -- $COMMAND
else
    # It's a namespace name (e.g., net:[4026531840])
    # Find a process in this namespace
    PID=$(sudo find /proc -maxdepth 3 -type l -name net -exec ls -l {} \; 2>/dev/null | grep "$TARGET" | head -1 | awk '{print $9}' | xargs -I {} basename {} 2>/dev/null || true)
    
    if [ -z "$PID" ]; then
        echo "Error: No process found in namespace $TARGET"
        exit 1
    fi
    
    echo "Found process $PID in namespace $TARGET"
    sudo nsenter -t $PID -n -- $COMMAND
fi
