#!/bin/bash
# JAMF Secrets Monitor Script
# Monitors JAMF tmp directory and processes for potential credentials
# Usage: ./jamf-secrets-monitor.sh [duration_seconds]

set -e

DURATION=${1:-60}
TMP_DIR="/Library/Application Support/Jamf/tmp/"

echo "=== JAMF Secrets Monitor ==="
echo "Monitoring for $DURATION seconds..."
echo "Press Ctrl+C to stop"
echo ""

# Check if tmp directory exists
if [ ! -d "$TMP_DIR" ]; then
    echo "[!] JAMF tmp directory not found at $TMP_DIR"
    echo "[+] Will monitor JAMF processes instead"
    
    # Monitor JAMF processes
    for ((i=0; i<DURATION; i++)); do
        echo "[$i] JAMF processes:"
        ps aux | grep -i jamf | grep -v grep || echo "  No JAMF processes"
        sleep 1
    done
    exit 0
fi

# Monitor tmp directory for new files
echo "[+] Monitoring $TMP_DIR for new scripts..."
echo ""

# Get initial file list
INITIAL_FILES=$(ls -la "$TMP_DIR" 2>/dev/null | wc -l)

for ((i=0; i<DURATION; i++)); do
    CURRENT_FILES=$(ls -la "$TMP_DIR" 2>/dev/null | wc -l)
    
    if [ "$CURRENT_FILES" -gt "$INITIAL_FILES" ]; then
        echo "[$i] [!] New files detected in JAMF tmp directory:"
        ls -la "$TMP_DIR" 2>/dev/null
        echo ""
        INITIAL_FILES=$CURRENT_FILES
    fi
    
    # Also check for JAMF processes with arguments
    JAMF_PROCS=$(ps aux | grep -i jamf | grep -v grep)
    if [ -n "$JAMF_PROCS" ]; then
        echo "[$i] JAMF processes:"
        echo "$JAMF_PROCS"
        echo ""
    fi
    
    sleep 1
done

echo "=== Monitoring Complete ==="
