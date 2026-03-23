#!/bin/bash
# Network Process Enumeration Script
# Identifies processes with network activity on macOS

set -e

DURATION=${1:-10}
OUTPUT_FILE="${2:-network_procs_$(date +%Y%m%d_%H%M%S).txt}"

echo "=== Network Process Enumeration ==="
echo "Duration: ${DURATION} seconds"
echo "Output: $OUTPUT_FILE"
echo ""
echo "Monitoring network activity... Press Ctrl+C to stop early."
echo ""

# Create temp file for dtrace output
DTRACE_LOG=$(mktemp)
trap "rm -f $DTRACE_LOG" EXIT

# Run dtrace to capture network syscalls
echo "[*] Capturing recv/accept syscalls..."
sudo dtrace -n -q "
syscall::recv*:entry
{
    printf(\"%s (pid=%d)\\n\", execname, pid);
}
syscall::accept*:entry
{
    printf(\"%s (pid=%d)\\n\", execname, pid);
}" &
DTRACE_PID=$!

# Let it run for the specified duration
sleep "$DURATION"

# Stop dtrace
kill $DTRACE_PID 2>/dev/null || true
wait $DTRACE_PID 2>/dev/null || true

echo ""
echo "[*] Processing results..."
echo ""

# Get unique processes
echo "=== Processes with Network Activity ==="
sort -u "$DTRACE_LOG" | tee "$OUTPUT_FILE"
echo ""

# Count occurrences
echo "=== Process Frequency ==="
sort "$DTRACE_LOG" | uniq -c | sort -rn | head -20
echo ""

# Get detailed info for top processes
echo "=== Top 5 Processes (detailed) ==="
sort "$DTRACE_LOG" | uniq -c | sort -rn | head -5 | while read -r count proc_line; do
    PROC_NAME=$(echo "$proc_line" | awk '{print $1}')
    echo ""
    echo "Process: $PROC_NAME"
    echo "Network events: $count"
    
    # Get PIDs
    PIDS=$(ps -eo pid,comm | grep "$PROC_NAME" | awk '{print $1}' | tr '\n' ' ')
    echo "PIDs: $PIDS"
    
    # Get network connections
    echo "Connections:"
    lsof -i -P -n 2>/dev/null | grep "$PROC_NAME" | head -5 || echo "  (none or no permission)"
done
echo ""

# Alternative: netstat approach
echo "=== Listening Ports ==="
netstat -an | grep LISTEN | head -20
echo ""

echo "=== Established Connections ==="
netstat -an | grep ESTABLISHED | head -20
echo ""

echo "=== Results Saved ==="
echo "Full output: $OUTPUT_FILE"
echo ""
echo "Next steps:"
echo "  - Investigate suspicious processes with: lsof -i -P -n | grep <process>"
echo "  - Monitor specific process: sudo dtruss -p <pid>"
echo "  - Check process details: ps -axo pid,ppid,comm,args | grep <process>"
