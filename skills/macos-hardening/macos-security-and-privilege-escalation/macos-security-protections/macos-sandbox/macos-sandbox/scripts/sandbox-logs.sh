#!/bin/bash
# macOS Sandbox Log Viewer
# Usage: ./sandbox-logs.sh [options]

set -e

TIME_RANGE="30m"
PROCESS_FILTER=""
SHOW_DENIED=true
SHOW_ALLOWED=false

usage() {
    cat << EOF
Usage: $0 [options]

View macOS sandbox logs

Options:
  -t, --time RANGE      Time range (default: 30m)
  -p, --process NAME    Filter by process name
  -a, --allowed         Show allowed operations (default: show denied)
  -h, --help            Show this help

Examples:
  $0 -t 1h -p Safari
  $0 --allowed -t 5m
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--time)
            TIME_RANGE="$2"
            shift 2
            ;;
        -p|--process)
            PROCESS_FILTER="$2"
            shift 2
            ;;
        -a|--allowed)
            SHOW_DENIED=false
            SHOW_ALLOWED=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Build log predicate
PREDICATE='eventMessage contains[c] "sandbox"'

if [ -n "$PROCESS_FILTER" ]; then
    PREDICATE="$PREDICATE and processImagePath contains \"$PROCESS_FILTER\""
fi

if [ "$SHOW_ALLOWED" = true ]; then
    PREDICATE="$PREDICATE and eventMessage contains[c] \"allow\""
else
    PREDICATE="$PREDICATE and eventMessage contains[c] \"deny\""
fi

echo "=== Sandbox Logs (last $TIME_RANGE) ==="
echo "Filter: $PREDICATE"
echo ""

log show --predicate "$PREDICATE" --last "$TIME_RANGE" --style syslog 2>/dev/null | head -50 || echo "No matching logs found"

echo ""
echo "To see more:"
echo "  log show --predicate '$PREDICATE' --last $TIME_RANGE"
