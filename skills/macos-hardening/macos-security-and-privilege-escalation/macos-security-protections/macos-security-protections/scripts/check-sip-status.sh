#!/bin/bash
# SIP Status Check Script
# Note: Full SIP status requires Recovery Mode

set -e

echo "=== SIP Status Check ==="
echo ""

# Method 1: Check via csrutil (requires Recovery Mode)
echo "1. Recovery Mode Check (requires reboot to Recovery)"
echo "   Run in Recovery Mode: csrutil status"
echo ""

# Method 2: Check protected files
echo "2. Protected File Check"
echo "   Testing write access to protected locations..."

protected_paths=(
    "/System/Library/CoreServices/SystemVersion.plist"
    "/usr/bin/ls"
    "/bin/echo"
)

for path in "${protected_paths[@]}"; do
    if [ -f "$path" ]; then
        if [ -w "$path" ]; then
            echo "   $path: WRITABLE (SIP may be disabled)"
        else
            echo "   $path: Protected (SIP likely enabled)"
        fi
    else
        echo "   $path: Not found"
    fi
done
echo ""

# Method 3: Check via system profiler
echo "3. System Profiler Check"
if command -v system_profiler &> /dev/null; then
    echo "   Running system_profiler SPHardwareDataType..."
    system_profiler SPHardwareDataType 2>/dev/null | grep -E "(Model Identifier|Processor)" | head -2 || echo "   Unable to retrieve"
else
    echo "   system_profiler not available"
fi
echo ""

echo "=== Notes ==="
echo "- Full SIP status requires booting into Recovery Mode"
echo "- In Recovery: csrutil status"
echo "- To disable SIP (not recommended): csrutil disable"
echo "- To enable SIP: csrutil enable"
echo ""
echo "Always re-enable SIP after testing for system security."
