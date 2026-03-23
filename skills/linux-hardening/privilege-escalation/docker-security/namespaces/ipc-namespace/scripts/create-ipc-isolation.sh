#!/bin/bash
# Create an isolated IPC namespace and optionally enter it

set -e

USAGE="Usage: $0 [OPTIONS]

Options:
  -e, --enter    Enter the namespace with a shell (default: bash)
  -c, --cmd CMD  Execute a command in the isolated namespace
  -h, --help     Show this help

Examples:
  $0                    # Create and enter with bash
  $0 --enter zsh        # Create and enter with zsh
  $0 --cmd 'ipcs -m'    # Run command and exit
"

ENTER=false
CMD=""
SHELL="/bin/bash"

while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--enter)
            ENTER=true
            if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                SHELL="$2"
                shift
            fi
            shift
            ;;
        -c|--cmd)
            CMD="$2"
            shift 2
            ;;
        -h|--help)
            echo "$USAGE"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "$USAGE"
            exit 1
            ;;
    esac
done

if [ "$EUID" -ne 0 ]; then
    echo "This script requires root privileges"
    exec sudo "$0" "$@"
fi

echo "=== Creating IPC Namespace Isolation ==="
echo ""

# Show current namespace
echo "Current IPC namespace:"
ls -l /proc/self/ns/ipc
echo ""

if [ -n "$CMD" ]; then
    # Execute command in isolated namespace
    echo "Running command in isolated IPC namespace: $CMD"
    sudo unshare -i --mount-proc -f bash -c "$CMD"
    echo ""
    echo "Command completed"
elif [ "$ENTER" = true ]; then
    # Enter interactive shell
    echo "Entering isolated IPC namespace with $SHELL"
    echo "Type 'exit' to leave the namespace"
    echo ""
    sudo unshare -i --mount-proc -f "$SHELL"
else
    # Just show what would happen
    echo "To enter an isolated IPC namespace, run:"
    echo "  sudo unshare -i --mount-proc -f /bin/bash"
    echo ""
    echo "To run a command in isolation:"
    echo "  sudo unshare -i --mount-proc -f bash -c 'your-command'"
fi
