#!/bin/bash
# Docker Authorization Plugin Enumeration Script
# For authorized security assessments only

set -e

echo "=== Docker Auth Plugin Enumeration ==="
echo ""

# Check Docker accessibility
echo "[1] Checking Docker accessibility..."
if docker version > /dev/null 2>&1; then
    echo "✓ Docker is accessible"
    docker version --format "API Version: {{.Server.APIVersion}}"
else
    echo "✗ Docker is not accessible"
    exit 1
fi
echo ""

# List authorization plugins
echo "[2] Checking for authorization plugins..."
if [ -f /etc/docker/daemon.json ]; then
    echo "Daemon config found:"
    cat /etc/docker/daemon.json | grep -i authz || echo "  No authz plugins in daemon.json"
else
    echo "No daemon.json found"
fi
echo ""

# List Docker plugins
echo "[3] Listing Docker plugins..."
docker plugin ls 2>/dev/null || echo "  No plugins found or permission denied"
echo ""

# Check plugin directories
echo "[4] Checking plugin directories..."
if [ -d /var/lib/docker/plugins ]; then
    echo "Plugin directory contents:"
    ls -la /var/lib/docker/plugins/ 2>/dev/null || echo "  Cannot access"
else
    echo "  Plugin directory not found"
fi
echo ""

# Test basic authz enforcement
echo "[5] Testing authz enforcement..."
echo "  Testing basic container run:"
docker run --rm ubuntu echo "test" 2>&1 | head -5 || true
echo ""

echo "  Testing privileged container:"
docker run --rm --privileged ubuntu id 2>&1 | head -5 || true
echo ""

echo "  Testing volume mount:"
docker run --rm -v /tmp:/host ubuntu ls /host 2>&1 | head -5 || true
echo ""

echo "  Testing capability addition:"
docker run --rm --cap-add=SYS_ADMIN ubuntu id 2>&1 | head -5 || true
echo ""

# Extract plugin name from error messages
echo "[6] Extracting plugin information from errors..."
PLUGIN_NAME=$(docker run --rm --privileged ubuntu id 2>&1 | grep -oP 'plugin \K[a-zA-Z0-9_-]+' | head -1)
if [ -n "$PLUGIN_NAME" ]; then
    echo "  Detected plugin: $PLUGIN_NAME"
else
    echo "  No plugin detected in error messages"
fi
echo ""

echo "=== Enumeration Complete ==="
echo ""
echo "Next steps:"
echo "  - Review plugin configuration files"
echo "  - Test specific bypass techniques"
echo "  - Check for writable mount points"
echo "  - Test API endpoint bypasses"
