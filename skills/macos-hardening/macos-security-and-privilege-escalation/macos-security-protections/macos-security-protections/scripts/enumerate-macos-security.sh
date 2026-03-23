#!/bin/bash
# macOS Security Enumeration Script
# Use for authorized security assessments only

set -e

echo "=== macOS Security Enumeration ==="
echo ""

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "Error: This script requires macOS"
    exit 1
fi

echo "1. Gatekeeper Status"
echo "-------------------"
spctl --status 2>/dev/null || echo "spctl not available or requires privileges"
echo ""

echo "2. SIP Status"
echo "-------------"
if csrutil status 2>/dev/null; then
    echo "SIP status retrieved"
else
    echo "SIP status check requires Recovery Mode or privileges"
fi
echo ""

echo "3. TCC Database Location"
echo "------------------------"
echo "Database: /Library/Application Support/com.apple.TCC/TCC.db"
if [ -f "/Library/Application Support/com.apple.TCC/TCC.db" ]; then
    echo "TCC database exists"
else
    echo "TCC database not found (may require elevated access)"
fi
echo ""

echo "4. Background Task Management"
echo "-----------------------------"
if command -v sfltool &> /dev/null; then
    echo "sfltool available"
    echo "To enumerate BTM items, run: sfltool dumpbtm"
else
    echo "sfltool not found"
fi

if [ -f "/private/var/db/com.apple.backgroundtaskmanagement/BackgroundItems-v4.btm" ]; then
    echo "BTM database exists at: /private/var/db/com.apple.backgroundtaskmanagement/BackgroundItems-v4.btm"
else
    echo "BTM database not accessible (may require Full Disk Access)"
fi
echo ""

echo "5. MRT Location"
echo "---------------"
if [ -d "/Library/Apple/System/Library/CoreServices/MRT.app" ]; then
    echo "MRT found at: /Library/Apple/System/Library/CoreServices/MRT.app"
else
    echo "MRT not found at expected location"
fi
echo ""

echo "6. BackgroundTaskManagementAgent Status"
echo "---------------------------------------"
if pgrep -x "BackgroundTaskManagementAgent" > /dev/null 2>&1; then
    PID=$(pgrep -x "BackgroundTaskManagementAgent")
    echo "Agent is running (PID: $PID)"
    ps -o pid,state,command -p $PID 2>/dev/null || true
else
    echo "Agent is not running"
fi
echo ""

echo "7. Quarantine Attributes Sample"
echo "-------------------------------"
echo "Checking for quarantined files in Downloads..."
if [ -d "~/Downloads" ]; then
    count=$(find ~/Downloads -maxdepth 1 -type f -xattr com.apple.quarantine 2>/dev/null | wc -l)
    echo "Files with quarantine attribute in Downloads: $count"
else
    echo "Downloads folder not found"
fi
echo ""

echo "=== Enumeration Complete ==="
echo ""
echo "Note: For full enumeration, some commands require elevated privileges."
echo "Run with sudo where appropriate for authorized security testing."
