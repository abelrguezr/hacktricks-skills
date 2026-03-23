#!/bin/bash
# macOS Firewall Audit: Monitor Network Extension Filters
# Watches for Network Extension filter crashes and restarts

set -e

echo "=== macOS Network Extension Monitor ==="
echo "Timestamp: $(date)"
echo ""
echo "Monitoring Network Extension logs..."
echo "Press Ctrl+C to stop"
echo ""
echo "=== Live log stream ==="

# Stream Network Extension logs
log stream --predicate 'subsystem == "com.apple.networkextension"' --style syslog 2>/dev/null | \
    grep -E "(crash|restart|error|fail|drop|rule)" | head -100

echo ""
echo "Monitor stopped."
echo ""
echo "=== Summary ==="
echo "Check for patterns like:"
echo "  - Filter crashes followed by restarts"
echo "  - Rule drops or failures"
echo "  - Reconnection loops"
echo ""
echo "If you see repeated crashes, your firewall may be vulnerable to macOS 15 Sequoia instability."
