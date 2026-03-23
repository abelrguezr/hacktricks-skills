#!/bin/bash
# macOS Process Information Analyzer
# For authorized security research only

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <PID>"
    echo "Example: $0 1234"
    exit 1
fi

PID=$1

echo "=== Process Information for PID $PID ==="
echo ""

# Basic process info
if command -v ps &> /dev/null; then
    echo "--- Basic Info ---"
    ps -p $PID -o pid,ppid,user,group,comm,args 2>/dev/null || echo "Process not found or insufficient permissions"
    echo ""
fi

# Process tree
if command -v ps &> /dev/null; then
    echo "--- Process Tree ---"
    ps -axo pid,ppid,comm | grep -E "^\s*$PID\s|^\s*1\s" | head -20 || echo "Unable to retrieve process tree"
    echo ""
fi

# Open files and descriptors
if command -v lsof &> /dev/null; then
    echo "--- Open Files (first 20) ---"
    lsof -p $PID 2>/dev/null | head -20 || echo "Unable to retrieve open files (may need elevated privileges)"
    echo ""
fi

# Memory mappings
if command -v vmmap &> /dev/null; then
    echo "--- Memory Mappings (first 30 lines) ---"
    vmmap $PID 2>/dev/null | head -30 || echo "vmmap not available or insufficient permissions"
    echo ""
elif command -v procmap &> /dev/null; then
    echo "--- Memory Mappings (first 30 lines) ---"
    procmap $PID 2>/dev/null | head -30 || echo "procmap not available or insufficient permissions"
    echo ""
fi

# Thread information
if command -v ps &> /dev/null; then
    echo "--- Thread Count ---"
    ps -p $PID -o pid,nlwp,comm 2>/dev/null || echo "Unable to retrieve thread count"
    echo ""
fi

# Check for suspicious environment variables
if command -v ps &> /dev/null; then
    echo "--- Environment Variables ---"
    if [ -r "/proc/$PID/environ" ]; then
        cat "/proc/$PID/environ" 2>/dev/null | tr '\0' '\n' | grep -E "(DYLD|JAVA|PYTHON|ELECTRON)" || echo "No suspicious env vars found"
    else
        echo "Cannot read environment (may need elevated privileges)"
    fi
    echo ""
fi

echo "=== Analysis Complete ==="
echo "Remember: This tool is for authorized security research only."
