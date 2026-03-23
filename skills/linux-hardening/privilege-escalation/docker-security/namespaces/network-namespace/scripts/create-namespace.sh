#!/bin/bash
# Create a new network namespace with optional connectivity
# Usage: ./create-namespace.sh [--connect] [COMMAND]

set -e

CONNECT=false
COMMAND=/bin/bash

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --connect)
            CONNECT=true
            shift
            ;;
        *)
            COMMAND=$1
            shift
            ;;
    esac
done

echo "=== Creating Network Namespace ==="
echo ""

if [ "$CONNECT" = true ]; then
    echo "Creating namespace with veth pair connectivity..."
    
    # Create veth pair
    sudo ip link add veth_host type veth peer name veth_ns
    
    # Get the PID of the new namespace process
    # We'll create the namespace and run a background process to keep it alive
    sudo unshare -n --mount-proc --fork sleep 3600 &
    NS_PID=$!
    
    echo "New namespace PID: $NS_PID"
    
    # Move veth end to new namespace
    sudo ip link set veth_ns netns $NS_PID
    
    # Configure host side
    sudo ip addr add 10.0.0.1/24 dev veth_host
    sudo ip link set veth_host up
    
    # Configure namespace side
    sudo nsenter -t $NS_PID -n -- ip addr add 10.0.0.2/24 dev veth_ns
    sudo nsenter -t $NS_PID -n -- ip link set veth_ns up
    sudo nsenter -t $NS_PID -n -- ip link set lo up
    
    echo ""
    echo "Host interface: veth_host (10.0.0.1/24)"
    echo "Namespace interface: veth_ns (10.0.0.2/24)"
    echo ""
    echo "Test connectivity from host:"
    echo "  ping 10.0.0.2"
    echo ""
    echo "Enter namespace:"
    echo "  sudo nsenter -t $NS_PID -n /bin/bash"
    echo ""
    
    # Cleanup function
    cleanup() {
        echo "Cleaning up..."
        sudo ip link del veth_host 2>/dev/null || true
        sudo kill $NS_PID 2>/dev/null || true
    }
    trap cleanup EXIT
else
    echo "Creating isolated namespace (no connectivity)..."
    
    # Create namespace and run command
    sudo unshare -n --mount-proc --fork $COMMAND
fi
