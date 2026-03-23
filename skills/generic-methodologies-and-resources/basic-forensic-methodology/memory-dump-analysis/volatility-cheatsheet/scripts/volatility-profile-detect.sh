#!/bin/bash
# Volatility Profile Detection Script
# Automatically identifies the correct profile for a memory dump

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <memory_dump_file> [volatility_version]"
    echo "  volatility_version: '2' or '3' (default: 3)"
    exit 1
fi

DUMP_FILE="$1"
VOL_VERSION="${2:-3}"

if [ ! -f "$DUMP_FILE" ]; then
    echo "Error: File not found: $DUMP_FILE"
    exit 1
fi

echo "=== Volatility Profile Detection ==="
echo "Memory dump: $DUMP_FILE"
echo "Volatility version: $VOL_VERSION"
echo ""

if [ "$VOL_VERSION" = "3" ]; then
    echo "--- Volatility3 Analysis ---"
    
    # Try Windows
    echo "Checking Windows profile..."
    if vol.py -f "$DUMP_FILE" windows.info.Info 2>/dev/null; then
        echo "Windows profile detected"
    else
        echo "Windows profile not found or error"
    fi
    
    # Try Linux
    echo ""
    echo "Checking Linux profile..."
    if vol.py -f "$DUMP_FILE" linux.info.Info 2>/dev/null; then
        echo "Linux profile detected"
    else
        echo "Linux profile not found or error"
    fi
    
else
    echo "--- Volatility2 Analysis ---"
    
    # imageinfo for profile suggestions
    echo "Running imageinfo..."
    volatility imageinfo -f "$DUMP_FILE" 2>/dev/null || echo "imageinfo failed"
    
    echo ""
    echo "Running kdbgscan..."
    volatility kdbgscan -f "$DUMP_FILE" 2>/dev/null || echo "kdbgscan failed"
    
    echo ""
    echo "=== Profile Selection Guide ==="
    echo "Look for profiles with non-zero process counts in kdbgscan output"
    echo "Example of valid profile:"
    echo "  PsActiveProcessHead: 0x... (37 processes) <- GOOD"
    echo "  PsActiveProcessHead: 0x... (0 processes) <- BAD"
fi

echo ""
echo "=== Next Steps ==="
echo "1. Select the profile with the highest process count"
echo "2. Run: vol.py -f <dump> windows.pslist.PsList (Volatility3)"
echo "   or: volatility --profile=PROFILE pslist -f <dump> (Volatility2)"
