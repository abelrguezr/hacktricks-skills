#!/bin/bash
# Check current UTS namespace information
# Usage: ./check-uts-namespace.sh

set -e

echo "=== Current UTS Namespace ==="
echo ""

# Current namespace
if [ -L /proc/self/ns/uts ]; then
    CURRENT_NS=$(readlink /proc/self/ns/uts)
    echo "Current UTS namespace: $CURRENT_NS"
    
    # Extract namespace ID
    NS_ID=$(echo "$CURRENT_NS" | grep -oP '\[\K[0-9]+')
    echo "Namespace ID: $NS_ID"
    echo ""
    
    # Current hostname
    echo "Current hostname: $(hostname)"
    echo ""
    
    # Compare with PID 1 (usually host namespace)
    if [ -L /proc/1/ns/uts ]; then
        PID1_NS=$(readlink /proc/1/ns/uts)
        echo "PID 1 UTS namespace: $PID1_NS"
        
        if [ "$CURRENT_NS" = "$PID1_NS" ]; then
            echo "⚠️  WARNING: You are in the same UTS namespace as PID 1 (likely host namespace)"
        else
            echo "✓ You are in a different UTS namespace than PID 1"
        fi
    fi
else
    echo "Cannot read /proc/self/ns/uts"
fi

echo ""
echo "=== Processes in same UTS namespace ==="
if [ -n "$NS_ID" ]; then
    echo "Finding processes with UTS namespace $NS_ID..."
    sudo find /proc -maxdepth 3 -type l -name uts -exec ls -l {} \; 2>/dev/null | grep "$NS_ID" | head -20
fi
