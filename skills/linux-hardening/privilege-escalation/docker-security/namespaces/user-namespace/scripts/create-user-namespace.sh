#!/bin/bash
# Create and enter a user namespace with various options
# Usage: ./create-user-namespace.sh [OPTIONS]
#
# Options:
#   --map-user=<uid|name>  Map to specific user
#   --map-current-user     Map current user
#   --mount-proc           Mount new /proc
#   --fork                 Fork after creating namespace
#   --help                 Show this help

if [[ $EUID -ne 0 ]]; then
    echo "This script requires root privileges"
    echo "Run with: sudo $0"
    exit 1
fi

MAP_USER=""
MAP_CURRENT=""
MOUNT_PROC=""
FORK=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --map-user=*)
            MAP_USER="${1#*=}"
            shift
            ;;
        --map-current-user)
            MAP_CURRENT="--map-current-user"
            shift
            ;;
        --mount-proc)
            MOUNT_PROC="--mount-proc"
            shift
            ;;
        --fork)
            FORK="-f"
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --map-user=<uid|name>  Map to specific user (e.g., --map-user=nobody)"
            echo "  --map-current-user     Map current user to namespace"
            echo "  --mount-proc           Mount new /proc filesystem"
            echo "  --fork                 Fork after creating namespace (prevents PID errors)"
            echo "  --help                 Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Build command
CMD="sudo unshare $FORK -U"

if [[ -n "$MOUNT_PROC" ]]; then
    CMD="$CMD $MOUNT_PROC"
fi

if [[ -n "$MAP_USER" ]]; then
    CMD="$CMD --map-user=$MAP_USER"
fi

if [[ -n "$MAP_CURRENT" ]]; then
    CMD="$CMD $MAP_CURRENT"
fi

CMD="$CMD /bin/bash"

echo "Creating user namespace..."
echo "Command: $CMD"
echo ""
echo "Entering namespace. Type 'exit' to return."
echo ""

# Execute
$CMD
