#!/bin/bash
# Docker Sensitive Mounts Security Scanner
# Scans running containers for dangerous mount configurations

set -e

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "========================================"
echo "Docker Sensitive Mounts Security Scanner"
echo "========================================"
echo ""

# Check if docker is available
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed or not in PATH${NC}"
    exit 1
fi

# Critical paths to check
CRITICAL_PATHS=(
    "/proc"
    "/sys"
    "/var"
    "/run"
    "/dev"
    "/etc/kubernetes"
    "/etc/docker"
    "/var/lib/docker"
    "/var/run/docker.sock"
    "/run/containerd/containerd.sock"
    "/var/run/crio/crio.sock"
    "/run/podman/podman.sock"
    "/var/run/kubelet.sock"
    "/sys/fs/cgroup"
)

# Get all running containers
CONTAINERS=$(docker ps -q 2>/dev/null || echo "")

if [ -z "$CONTAINERS" ]; then
    echo -e "${YELLOW}No running containers found${NC}"
    exit 0
fi

echo "Scanning $(echo $CONTAINERS | wc -w) running container(s)..."
echo ""

VULNERABILITY_COUNT=0
WARNING_COUNT=0

for CONTAINER_ID in $CONTAINERS; do
    CONTAINER_NAME=$(docker inspect --format='{{.Name}}' "$CONTAINER_ID" 2>/dev/null | sed 's/^\///')
    echo "----------------------------------------"
    echo "Container: $CONTAINER_NAME ($CONTAINER_ID)"
    echo "----------------------------------------"
    
    # Get mount information
    MOUNTS=$(docker inspect --format='{{json .Mounts}}' "$CONTAINER_ID" 2>/dev/null)
    
    # Check each critical path
    for PATH in "${CRITICAL_PATHS[@]}"; do
        if echo "$MOUNTS" | grep -q "\"Source\": *\"$PATH\""; then
            # Get mount details
            MOUNT_DETAILS=$(echo "$MOUNTS" | grep -A5 "\"Source\": *\"$PATH\"" | head -10)
            READONLY=$(echo "$MOUNTS" | grep -A5 "\"Source\": *\"$PATH\"" | grep -o '"ReadOnly": *true' || echo "false")
            
            if [ "$READONLY" = "false" ] || [ -z "$READONLY" ]; then
                echo -e "${RED}CRITICAL: $PATH mounted (read-write)${NC}"
                echo "  Risk: Container escape, host compromise"
                VULNERABILITY_COUNT=$((VULNERABILITY_COUNT + 1))
            else
                echo -e "${YELLOW}WARNING: $PATH mounted (read-only)${NC}"
                echo "  Risk: Information disclosure"
                WARNING_COUNT=$((WARNING_COUNT + 1))
            fi
        fi
    done
    
    # Check for privileged mode
    PRIVILEGED=$(docker inspect --format='{{.HostConfig.Privileged}}' "$CONTAINER_ID" 2>/dev/null)
    if [ "$PRIVILEGED" = "true" ]; then
        echo -e "${RED}CRITICAL: Container running in privileged mode${NC}"
        echo "  Risk: Full host access"
        VULNERABILITY_COUNT=$((VULNERABILITY_COUNT + 1))
    fi
    
    # Check for host network
    NETWORK_MODE=$(docker inspect --format='{{.HostConfig.NetworkMode}}' "$CONTAINER_ID" 2>/dev/null)
    if [ "$NETWORK_MODE" = "host" ]; then
        echo -e "${YELLOW}WARNING: Container using host network${NC}"
        WARNING_COUNT=$((WARNING_COUNT + 1))
    fi
    
    # Check capabilities
    CAPS=$(docker inspect --format='{{json .HostConfig.CapAdd}}' "$CONTAINER_ID" 2>/dev/null)
    if echo "$CAPS" | grep -q "SYS_ADMIN"; then
        echo -e "${RED}CRITICAL: CAP_SYS_ADMIN capability added${NC}"
        echo "  Risk: Container escape via cgroups, namespaces"
        VULNERABILITY_COUNT=$((VULNERABILITY_COUNT + 1))
    fi
    
    # Check for pid=host
    PID_MODE=$(docker inspect --format='{{.HostConfig.PidMode}}' "$CONTAINER_ID" 2>/dev/null)
    if [ "$PID_MODE" = "host" ]; then
        echo -e "${YELLOW}WARNING: Container using host PID namespace${NC}"
        WARNING_COUNT=$((WARNING_COUNT + 1))
    fi
    
    echo ""
done

echo "========================================"
echo "Scan Complete"
echo "========================================"
echo -e "${RED}Critical Vulnerabilities: $VULNERABILITY_COUNT${NC}"
echo -e "${YELLOW}Warnings: $WARNING_COUNT${NC}"
echo ""

if [ $VULNERABILITY_COUNT -gt 0 ]; then
    echo -e "${RED}ACTION REQUIRED: Review and remediate critical vulnerabilities${NC}"
    echo ""
    echo "Recommended actions:"
    echo "1. Remove sensitive path mounts or mount as read-only"
    echo "2. Disable privileged mode"
    echo "3. Drop unnecessary capabilities (use --cap-drop=ALL)"
    echo "4. Use read-only root filesystem (--read-only)"
    echo "5. Add --security-opt=no-new-privileges:true"
    exit 1
else
    echo -e "${GREEN}No critical vulnerabilities found${NC}"
    if [ $WARNING_COUNT -gt 0 ]; then
        echo -e "${YELLOW}Consider addressing $WARNING_COUNT warnings for improved security${NC}"
    fi
    exit 0
fi
