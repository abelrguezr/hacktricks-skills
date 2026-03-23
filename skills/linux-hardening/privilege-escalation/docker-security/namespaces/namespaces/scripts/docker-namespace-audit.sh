#!/bin/bash
# Docker Namespace Security Audit Script
# Usage: ./docker-namespace-audit.sh [container_id]
# If no container specified, audits all running containers

set -e

CONTAINER_ID="${1:-}"

if [ -z "$CONTAINER_ID" ]; then
    echo "=== Docker Namespace Security Audit ==="
    echo "Auditing all running containers..."
    echo
    
    CONTAINERS=$(docker ps -aq 2>/dev/null || echo "")
    
    if [ -z "$CONTAINERS" ]; then
        echo "No running containers found."
        exit 0
    fi
else
    echo "=== Docker Namespace Security Audit ==="
    echo "Auditing container: $CONTAINER_ID"
    echo
    CONTAINERS="$CONTAINER_ID"
fi

for container in $CONTAINERS; do
    echo "Container: $container"
    echo "----------------------------------------"
    
    # Get container name
    NAME=$(docker inspect --format='{{.Name}}' $container 2>/dev/null | sed 's/^\///')
    echo "Name: $NAME"
    
    # Check for privileged mode
    PRIVILEGED=$(docker inspect --format='{{.HostConfig.Privileged}}' $container 2>/dev/null)
    if [ "$PRIVILEGED" = "true" ]; then
        echo "  ⚠️  CRITICAL: Privileged mode enabled"
    else
        echo "  ✓ Not privileged"
    fi
    
    # Check PID namespace
    PIDMODE=$(docker inspect --format='{{.HostConfig.PidMode}}' $container 2>/dev/null)
    if [ "$PIDMODE" = "host" ]; then
        echo "  ⚠️  WARNING: Shares host PID namespace"
    else
        echo "  ✓ PID namespace isolated"
    fi
    
    # Check network namespace
    NETMODE=$(docker inspect --format='{{.HostConfig.NetworkMode}}' $container 2>/dev/null)
    if [ "$NETMODE" = "host" ]; then
        echo "  ⚠️  WARNING: Shares host network namespace"
    else
        echo "  ✓ Network namespace isolated"
    fi
    
    # Check IPC namespace
    IPCMODE=$(docker inspect --format='{{.HostConfig.IpcMode}}' $container 2>/dev/null)
    if [ "$IPCMODE" = "host" ]; then
        echo "  ⚠️  WARNING: Shares host IPC namespace"
    else
        echo "  ✓ IPC namespace isolated"
    fi
    
    # Check UTS namespace
    UTSMODE=$(docker inspect --format='{{.HostConfig.UTSMode}}' $container 2>/dev/null)
    if [ "$UTSMODE" = "host" ]; then
        echo "  ⚠️  WARNING: Shares host UTS namespace"
    else
        echo "  ✓ UTS namespace isolated"
    fi
    
    # Check user namespace
    USERNS=$(docker inspect --format='{{.HostConfig.UsernsMode}}' $container 2>/dev/null)
    if [ "$USERNS" = "host" ]; then
        echo "  ⚠️  WARNING: Shares host user namespace"
    elif [ -n "$USERNS" ]; then
        echo "  ✓ User namespace configured: $USERNS"
    else
        echo "  ℹ️  User namespace: default"
    fi
    
    # Check for sensitive mounts
    echo
    echo "  Checking mounts..."
    MOUNTS=$(docker inspect --format='{{json .Mounts}}' $container 2>/dev/null)
    
    SENSITIVE_PATHS=("/" "/etc" "/proc" "/sys" "/var/run/docker.sock" "/root")
    FOUND_SENSITIVE=false
    
    for path in "${SENSITIVE_PATHS[@]}"; do
        if echo "$MOUNTS" | grep -q "\"Source\":\"$path\""; then
            # Check if read-only
            if echo "$MOUNTS" | grep -A5 "\"Source\":\"$path\"" | grep -q '"Mode": "ro"'; then
                echo "    ℹ️  $path mounted (read-only)"
            else
                echo "    ⚠️  CRITICAL: $path mounted (read-write)"
                FOUND_SENSITIVE=true
            fi
        fi
    done
    
    if [ "$FOUND_SENSITIVE" = false ]; then
        echo "    ✓ No sensitive paths mounted"
    fi
    
    # Check capabilities
    echo
    echo "  Checking capabilities..."
    CAP_ADD=$(docker inspect --format='{{json .HostConfig.CapAdd}}' $container 2>/dev/null)
    CAP_DROP=$(docker inspect --format='{{json .HostConfig.CapDrop}}' $container 2>/dev/null)
    
    if echo "$CAP_ADD" | grep -q "ALL"; then
        echo "    ⚠️  WARNING: All capabilities added"
    elif [ "$CAP_ADD" != "null" ] && [ "$CAP_ADD" != "[]" ]; then
        echo "    ℹ️  Capabilities added: $CAP_ADD"
    else
        echo "    ✓ No extra capabilities added"
    fi
    
    if [ "$CAP_DROP" = "null" ] || [ "$CAP_DROP" = "[]" ]; then
        echo "    ℹ️  No capabilities dropped"
    else
        echo "    ✓ Capabilities dropped: $CAP_DROP"
    fi
    
    # Check if running as root
    USER=$(docker inspect --format='{{.Config.User}}' $container 2>/dev/null)
    if [ -z "$USER" ] || [ "$USER" = "root" ] || [ "$USER" = "0" ]; then
        echo "  ⚠️  WARNING: Container runs as root"
    else
        echo "  ✓ Container runs as: $USER"
    fi
    
    echo
    echo "----------------------------------------"
    echo
done

echo "Audit complete."
