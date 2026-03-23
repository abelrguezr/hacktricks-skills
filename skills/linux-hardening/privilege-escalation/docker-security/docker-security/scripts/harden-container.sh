#!/bin/bash
# Docker Container Hardening Script
# Generates secure docker run commands with best practices

set -e

IMAGE="${1:-}"
CONTAINER_NAME="${2:-secure-container}"

if [ -z "$IMAGE" ]; then
    echo "Usage: $0 <image-name> [container-name]"
    echo "Example: $0 nginx:latest my-nginx"
    exit 1
fi

echo "=== Docker Container Hardening ==="
echo "Image: $IMAGE"
echo "Container: $CONTAINER_NAME"
echo ""

# Generate hardened run command
cat << EOF
# Hardened Docker Run Command
docker run -d \
  --name $CONTAINER_NAME \
  --read-only \
  --security-opt=no-new-privileges:true \
  --cap-drop=all \
  --cap-add=NET_BIND_SERVICE \
  --user 1000:1000 \
  --memory=512m \
  --memory-swap=512m \
  --cpus=1.0 \
  --pids-limit=100 \
  --shm-size=64m \
  --log-driver json-file \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  --health-cmd "exit 0" \
  --health-interval 30s \
  --health-timeout 10s \
  --health-retries 3 \
  --health-start-period 40s \
  $IMAGE

# For containers that need to write to specific directories:
docker run -d \
  --name $CONTAINER_NAME \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=64m \
  --tmpfs /var/run:rw,noexec,nosuid,size=32m \
  --security-opt=no-new-privileges:true \
  --cap-drop=all \
  --cap-add=NET_BIND_SERVICE \
  --user 1000:1000 \
  --memory=512m \
  --cpus=1.0 \
  --pids-limit=100 \
  $IMAGE
EOF

echo ""
echo "=== Security Features Applied ==="
echo "✓ Read-only filesystem"
echo "✓ No new privileges (prevents privilege escalation)"
echo "✓ All capabilities dropped (add only what's needed)"
echo "✓ Non-root user (UID 1000)"
echo "✓ Memory limit (512MB)"
echo "✓ CPU limit (1 core)"
echo "✓ Process limit (100 pids)"
echo "✓ Health check configured"
echo "✓ Log rotation enabled"
echo ""
echo "=== Customization Notes ==="
echo "1. Adjust --user to match your container's user"
echo "2. Add --cap-add=... for required capabilities"
echo "3. Modify resource limits based on workload"
echo "4. Add --tmpfs for writable directories"
echo "5. Configure --health-cmd for your application"
