#!/bin/bash
# log-analyzer.sh
# Analyze system logs for security events
# Usage: ./log-analyzer.sh [since] [until] [output_dir]

set -e

SINCE="${1:-"24 hours ago"}"
UNTIL="${2:-}"
OUTPUT_DIR="${3:-./log_analysis}"

mkdir -p "$OUTPUT_DIR"

echo "=== Log Analyzer ==="
echo "Time range: $SINCE to ${UNTIL:-now}"
echo "Output: $OUTPUT_DIR"
echo ""

# Function to run journalctl query
query_journal() {
    local query="$1"
    local output="$2"
    local description="$3"
    
    echo "Querying: $description"
    
    if [ -n "$UNTIL" ]; then
        journalctl --no-pager --since="$SINCE" --until="$UNTIL" $query > "$OUTPUT_DIR/$output" 2>/dev/null || true
    else
        journalctl --no-pager --since="$SINCE" $query > "$OUTPUT_DIR/$output" 2>/dev/null || true
    fi
    
    local count=$(wc -l < "$OUTPUT_DIR/$output" 2>/dev/null || echo "0")
    echo "  -> $count entries"
}

# Authentication failures
echo "=== Authentication Events ==="
query_journal "-u ssh.service | grep -i 'failed\|invalid\|authentication'" "auth_failures.txt" "SSH authentication failures"
query_journal "-u ssh.service | grep -i 'accepted'" "auth_success.txt" "SSH successful logins"

# System errors
echo ""
echo "=== System Errors ==="
query_journal "-p err" "errors.txt" "Error level messages"
query_journal "-p crit" "critical.txt" "Critical messages"
query_journal "-p alert" "alerts.txt" "Alert level messages"
query_journal "-p emerg" "emergencies.txt" "Emergency messages"

# Root user activity
echo ""
echo "=== Root Activity ==="
query_journal "_UID=0" "root_activity.txt" "All root user actions"
query_journal "_UID=0 -p err" "root_errors.txt" "Root user errors"

# Network-related events
echo ""
echo "=== Network Events ==="
query_journal "-u NetworkManager.service" "network_manager.txt" "NetworkManager events"
query_journal "-u systemd-networkd.service" "systemd_network.txt" "systemd-networkd events"

# Service failures
echo ""
echo "=== Service Failures ==="
query_journal "--failed" "failed_services.txt" "Failed services"

# Kernel messages
echo ""
echo "=== Kernel Messages ==="
query_journal "-k" "kernel_messages.txt" "Kernel ring buffer"
query_journal "-k -p err" "kernel_errors.txt" "Kernel errors"

# Firewall/iptables
echo ""
echo "=== Firewall Events ==="
query_journal "| grep -i 'iptables\|firewall\|blocked\|denied'" "firewall_events.txt" "Firewall-related events"

# Process crashes
echo ""
echo "=== Process Crashes ==="
query_journal "| grep -i 'segfault\|core dump\|killed'" "crashes.txt" "Process crashes"

# Generate summary
echo ""
echo "=== Generating Summary ==="

cat > "$OUTPUT_DIR/summary.txt" << EOF
Log Analysis Summary
Generated: $(date)
Time Range: $SINCE to ${UNTIL:-now}

Event Counts:
EOF

for f in "$OUTPUT_DIR"/*.txt; do
    if [ -f "$f" ] && [ "$(basename "$f")" != "summary.txt" ]; then
        count=$(wc -l < "$f")
        echo "  $(basename "$f"): $count" >> "$OUTPUT_DIR/summary.txt"
    fi
done

echo "Summary saved to: $OUTPUT_DIR/summary.txt"
echo ""
echo "=== Analysis Complete ==="
echo ""
echo "Key files to review:"
echo "  - auth_failures.txt: SSH authentication failures (brute force detection)"
echo "  - errors.txt: System errors"
echo "  - root_activity.txt: All root user actions"
echo "  - failed_services.txt: Services that failed to start"
echo "  - kernel_errors.txt: Kernel-level errors"
echo ""
echo "To view in real-time:"
echo "  journalctl -f --since='$SINCE'"
