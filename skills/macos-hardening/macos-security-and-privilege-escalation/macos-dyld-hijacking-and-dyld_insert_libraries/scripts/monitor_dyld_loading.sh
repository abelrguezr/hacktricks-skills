#!/bin/bash
# Monitor system logs for dylib loading events

if [ -z "$1" ]; then
    echo "Usage: $0 [search_term]"
    echo "Example: $0 'dylib'"
    echo "         $0 '[+] dylib'"
    echo ""
    echo "If no search term provided, monitors for common dylib injection patterns."
fi

SEARCH_TERM="${1:-\"[+] dylib\"}"

echo "=== Monitoring Dylib Loading Events ==="
echo "Search term: $SEARCH_TERM"
echo "Press Ctrl+C to stop"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "[!] Warning: Running without sudo may miss some events"
    echo "    Consider running with: sudo $0 $SEARCH_TERM"
    echo ""
fi

# Start monitoring
sudo log stream --style syslog --predicate "eventMessage CONTAINS[c] \"$SEARCH_TERM\"" 2>/dev/null || \
    log stream --style syslog --predicate "eventMessage CONTAINS[c] \"$SEARCH_TERM\""
