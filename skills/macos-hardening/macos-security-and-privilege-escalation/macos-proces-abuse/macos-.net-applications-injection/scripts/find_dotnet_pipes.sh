#!/bin/bash
# Find .NET debugging pipes on macOS
# Usage: ./find_dotnet_pipes.sh [pid]

set -e

if [ -n "$1" ]; then
    # Check specific PID
    PID=$1
    echo "Checking for .NET debugging pipes for PID: $PID"
    
    # Find pipes in TMPDIR
    echo "\n=== Pipes in $TMPDIR ==="
    ls -la "$TMPDIR" 2>/dev/null | grep -E '\.net|dbg|dotnet' || echo "No .NET pipes found in TMPDIR"
    
    # Search more broadly
    echo "\n=== All named pipes in TMPDIR ==="
    find "$TMPDIR" -type p 2>/dev/null | head -20
    
    # Check process memory layout
    echo "\n=== Memory layout for PID $PID ==="
    if command -v vmmap &> /dev/null; then
        vmmap -pages "$PID" 2>/dev/null | grep -E "rwx|libcoreclr" | head -20
    else
        echo "vmmap not found. Install via: brew install vmmap"
    fi
else
    # Find all .NET processes
    echo "=== .NET Processes ==="
    ps aux | grep -E 'dotnet|mono|pwsh' | grep -v grep || echo "No .NET processes found"
    
    echo "\n=== Pipes in $TMPDIR ==="
    ls -la "$TMPDIR" 2>/dev/null | grep -E '\.net|dbg|dotnet' || echo "No .NET pipes found"
    
    echo "\n=== All named pipes ==="
    find "$TMPDIR" -type p 2>/dev/null | head -20
fi

echo "\n=== Usage ==="
echo "Run with PID: $0 <pid>"
echo "Run without args: $0"
