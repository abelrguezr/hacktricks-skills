#!/bin/bash
# macOS Port Enumeration Script
# Usage: ./enum_ports.sh [pid]
# Lists Mach ports for a process or launchd

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 [pid]"
    echo "  If no PID provided, lists ports for launchd (PID 1)"
    echo ""
    echo "Examples:"
    echo "  $0              # List launchd ports"
    echo "  $0 1234         # List ports for PID 1234"
    echo "  $0 \$(pgrep -n Safari)  # List ports for Safari"
    exit 0
fi

PID=${1:-1}

echo "=== Port Enumeration for PID $PID ==="
echo ""

# Check if lsmp is available
if command -v lsmp &> /dev/null; then
    echo "--- Using lsmp ---"
    if [ "$PID" -eq 1 ]; then
        sudo lsmp -p $PID 2>/dev/null || echo "lsmp requires sudo for PID 1"
    else
        lsmp -p $PID 2>/dev/null || echo "lsmp failed for PID $PID"
    fi
else
    echo "lsmp not found. Install from: http://newosxbook.com/tools/"
fi

echo ""
echo "--- Process Info ---"
ps -p $PID -o pid,comm,args 2>/dev/null || echo "Process not found"

echo ""
echo "--- Host Special Ports (requires procexp) ---"
if command -v procexp &> /dev/null; then
    procexp all ports 2>/dev/null | grep "HSP" | head -20 || echo "procexp failed or no HSP ports found"
else
    echo "procexp not found. Install from: http://newosxbook.com/tools/"
fi

echo ""
echo "=== Analysis Tips ==="
echo "- Look for ports with 'recv' rights (can receive messages)"
echo "- Ports with '+' indicate multiple tasks connected"
echo "- Send-only ports show the owner (port name + pid)"
echo "- Use 'lsmp -p <pid>' for detailed port information"
