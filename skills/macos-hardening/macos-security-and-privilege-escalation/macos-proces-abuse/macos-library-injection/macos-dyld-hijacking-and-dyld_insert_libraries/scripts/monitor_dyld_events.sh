#!/bin/bash
# macOS Dyld Event Monitor
# Monitors system logs for dylib loading events

set -e

# Default search pattern
PATTERN="dylib"
DURATION=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --pattern|-p)
            PATTERN="$2"
            shift 2
            ;;
        --duration|-d)
            DURATION="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --pattern, -p <str>   Search pattern (default: dylib)"
            echo "  --duration, -d <sec>  Duration to monitor in seconds"
            echo "  --help, -h            Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 -p 'dylib'"
            echo "  $0 -p '[+] injected' -d 60"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "========================================"
echo "Dyld Event Monitor"
echo "Pattern: $PATTERN"
[ -n "$DURATION" ] && echo "Duration: ${DURATION}s" || echo "Duration: unlimited (Ctrl+C to stop)"
echo "========================================"
echo ""
echo "Monitoring for library loading events..."
echo "Press Ctrl+C to stop"
echo ""

# Build the log stream command
if [ -n "$DURATION" ]; then
    # Run for specified duration
    timeout "$DURATION" sudo log stream --style syslog --predicate "eventMessage CONTAINS[c] \"$PATTERN\"" 2>/dev/null || true
else
    # Run indefinitely until interrupted
    sudo log stream --style syslog --predicate "eventMessage CONTAINS[c] \"$PATTERN\"" 2>/dev/null || true
fi

echo ""
echo "[+] Monitoring stopped"
