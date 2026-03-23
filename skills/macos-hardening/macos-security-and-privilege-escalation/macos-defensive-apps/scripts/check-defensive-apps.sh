#!/bin/bash
# macOS Defensive Apps Checker
# Checks which defensive security tools are installed and provides installation guidance

set -e

echo "========================================"
echo "macOS Defensive Apps Status Checker"
echo "========================================"
echo ""

# Function to check if a tool is installed
check_tool() {
    local name=$1
    local check_path=$2
    local download_url=$3
    
    if [ -e "$check_path" ]; then
        echo "✓ $name: INSTALLED"
        return 0
    else
        echo "✗ $name: NOT INSTALLED"
        echo "  Download: $download_url"
        return 1
    fi
}

echo "=== FIREWALLS ==="
echo ""

# Check Little Snitch
if [ -d "/Library/Application Support/Little Snitch" ] || [ -e "/Applications/Little Snitch.app" ]; then
    echo "✓ Little Snitch: INSTALLED"
else
    echo "✗ Little Snitch: NOT INSTALLED"
    echo "  Download: https://www.obdev.at/products/littlesnitch/index.html"
    echo "  Note: Paid software with free trial"
fi
echo ""

# Check LuLu
if [ -e "/Applications/LuLu.app" ]; then
    echo "✓ LuLu: INSTALLED"
else
    echo "✗ LuLu: NOT INSTALLED"
    echo "  Download: https://objective-see.org/products/lulu.html"
    echo "  Note: Free and open-source"
fi
echo ""

echo "=== PERSISTENCE DETECTION ==="
echo ""

# Check KnockKnock
if [ -e "/Applications/KnockKnock.app" ]; then
    echo "✓ KnockKnock: INSTALLED"
else
    echo "✗ KnockKnock: NOT INSTALLED"
    echo "  Download: https://objective-see.org/products/knockknock.html"
    echo "  Note: Free, one-shot scanner (no installation required)"
fi
echo ""

# Check BlockBlock
if [ -e "/Applications/BlockBlock.app" ]; then
    echo "✓ BlockBlock: INSTALLED"
else
    echo "✗ BlockBlock: NOT INSTALLED"
    echo "  Download: https://objective-see.org/products/blockblock.html"
    echo "  Note: Free, continuous monitoring"
fi
echo ""

echo "=== KEYLOGGER DETECTION ==="
echo ""

# Check ReiKey
if [ -e "/Applications/ReiKey.app" ]; then
    echo "✓ ReiKey: INSTALLED"
else
    echo "✗ ReiKey: NOT INSTALLED"
    echo "  Download: https://objective-see.org/products/reikey.html"
    echo "  Note: Free, on-demand scanner"
fi
echo ""

echo "========================================"
echo "RECOMMENDATIONS"
echo "========================================"
echo ""
echo "For comprehensive protection, consider installing:"
echo "  1. LuLu (free firewall) or Little Snitch (paid, more features)"
echo "  2. BlockBlock (continuous persistence monitoring)"
echo "  3. KnockKnock (periodic persistence scanning)"
echo "  4. ReiKey (keylogger detection when needed)"
echo ""
echo "All Objective-See tools are free and from:"
echo "  https://objective-see.org/"
echo ""

# Optional: Check running status of installed tools
echo "=== RUNNING STATUS ==="
echo ""

if [ -e "/Applications/LuLu.app" ]; then
    if pgrep -x "LuLu" > /dev/null 2>&1; then
        echo "✓ LuLu: RUNNING"
    else
        echo "⚠ LuLu: INSTALLED but NOT RUNNING"
    fi
fi

if [ -e "/Applications/BlockBlock.app" ]; then
    if pgrep -x "BlockBlock" > /dev/null 2>&1; then
        echo "✓ BlockBlock: RUNNING"
    else
        echo "⚠ BlockBlock: INSTALLED but NOT RUNNING"
    fi
fi

echo ""
echo "Done!"
