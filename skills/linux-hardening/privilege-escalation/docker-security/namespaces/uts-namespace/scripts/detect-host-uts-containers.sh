#!/bin/bash
# Detect Docker containers sharing the host UTS namespace
# Usage: ./detect-host-uts-containers.sh

set -e

echo "=== Containers with Host UTS Namespace ==="
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed or not in PATH"
    exit 1
fi

# Get list of containers
CONTAINERS=$(docker ps -aq 2>/dev/null)

if [ -z "$CONTAINERS" ]; then
    echo "No running containers found"
    exit 0
fi

echo "Container ID          | Name              | UTS Mode"
echo "----------------------|-------------------|----------"

HOST_UTS_COUNT=0

for container in $CONTAINERS; do
    # Get container name
    NAME=$(docker inspect --format '{{.Name}}' "$container" 2>/dev/null | sed 's/^\///')
    
    # Get UTS mode
    UTS_MODE=$(docker inspect --format '{{.HostConfig.UTSMode}}' "$container" 2>/dev/null)
    
    printf "%-20s | %-17s | %s\n" "$container" "$NAME" "$UTS_MODE"
    
    if [ "$UTS_MODE" = "host" ]; then
        HOST_UTS_COUNT=$((HOST_UTS_COUNT + 1))
    fi
done

echo ""
if [ $HOST_UTS_COUNT -gt 0 ]; then
    echo "⚠️  WARNING: $HOST_UTS_COUNT container(s) are sharing the host UTS namespace!"
    echo "These containers can modify the host hostname."
else
    echo "✓ No containers are sharing the host UTS namespace"
fi
