#!/bin/bash
# Inspect network configuration of a namespace
# Usage: ./inspect-namespace.sh <PID|NS_NAME>

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <PID|NS_NAME>"
    echo ""
    echo "Examples:"
    echo "  $0 1234                    # Inspect namespace of PID 1234"
    echo "  $0 net:[4026531840]        # Inspect by namespace name"
    exit 1
fi

TARGET=$1

# Find PID if namespace name provided
if [[ ! "$TARGET" =~ ^[0-9]+$ ]]; then
    PID=$(sudo find /proc -maxdepth 3 -type l -name net -exec ls -l {} \; 2>/dev/null | grep "$TARGET" | head -1 | awk '{print $9}' | xargs -I {} basename {} 2>/dev/null || true)
    
    if [ -z "$PID" ]; then
        echo "Error: No process found in namespace $TARGET"
        exit 1
    fi
    TARGET=$PID
fi

echo "=== Network Namespace Inspection ==="
echo "Target PID: $TARGET"
echo "Namespace: $(readlink /proc/$TARGET/ns/net 2>/dev/null || echo 'unknown')"
echo ""

# Run inspection commands in the namespace
sudo nsenter -t $TARGET -n -- bash -c '
    echo "=== Network Interfaces ==="
    ip -a 2>/dev/null || echo "Cannot access interfaces"
    echo ""
    
    echo "=== Routing Table ==="
    ip route 2>/dev/null || echo "Cannot access routing"
    echo ""
    
    echo "=== ARP/Neighbor Cache ==="
    ip neigh 2>/dev/null || echo "Cannot access ARP"
    echo ""
    
    echo "=== DNS Configuration ==="
    if [ -f /etc/resolv.conf ]; then
        cat /etc/resolv.conf
    else
        echo "No /etc/resolv.conf found"
    fi
    echo ""
    
    echo "=== Firewall Rules (iptables) ==="
    if command -v iptables &> /dev/null; then
        iptables -L -n 2>/dev/null || echo "No iptables access (need root)"
    else
        echo "iptables not available"
    fi
    echo ""
    
    echo "=== Listening Ports ==="
    if command -v ss &> /dev/null; then
        ss -tlnp 2>/dev/null || echo "Cannot access socket stats"
    elif command -v netstat &> /dev/null; then
        netstat -tlnp 2>/dev/null || echo "Cannot access netstat"
    else
        echo "No port inspection tool available"
    fi
'

echo ""
echo "=== Processes in Namespace ==="
sudo find /proc -maxdepth 3 -type l -name net -exec ls -l {} \; 2>/dev/null | grep "$(readlink /proc/$TARGET/ns/net 2>/dev/null)" | awk '{print $9}' | xargs -I {} basename {} 2>/dev/null | while read pid; do
    if [ -d "/proc/$pid" ]; then
        cmd=$(cat /proc/$pid/cmdline 2>/dev/null | tr '\0' ' ' || echo "<unknown>")
        echo "  PID $pid: $cmd"
    fi
done
