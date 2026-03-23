#!/bin/bash
# Find Node.js and CEF processes with debugging enabled
# Usage: ./find-inspect-processes.sh

echo "=== Checking for Node.js processes with debugging enabled ==="
echo ""

if command -v ps &> /dev/null; then
    node_processes=$(ps aux 2>/dev/null | grep -E 'node.*inspect|node.*debugging' | grep -v grep)
    if [ -n "$node_processes" ]; then
        echo "$node_processes"
    else
        echo "No Node.js processes with debugging found."
    fi
else
    echo "ps command not available."
fi

echo ""
echo "=== Checking for CEF/Chromium processes with debugging ==="
echo ""

if command -v ps &> /dev/null; then
    cef_processes=$(ps aux 2>/dev/null | grep -E 'cef|chromium|electron' | grep -E 'remote-debugging|inspect' | grep -v grep)
    if [ -n "$cef_processes" ]; then
        echo "$cef_processes"
    else
        echo "No CEF/Chromium processes with debugging found."
    fi
else
    echo "ps command not available."
fi

echo ""
echo "Done."
