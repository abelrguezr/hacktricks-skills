#!/bin/bash
# Network Extensions Enumeration Script
# Lists and analyzes Network Extensions on macOS

set -e

echo "=== macOS Network Extensions Analysis ==="
echo ""

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "Warning: This script is designed for macOS. Current OS: $OSTYPE"
    echo ""
fi

echo "1. Network Extension Types Reference"
echo "------------------------------------"
echo "| Type           | Purpose                              | Traffic Level      |"
echo "|----------------|--------------------------------------|--------------------|"
echo "| App Proxy      | VPN client (flow-oriented)           | Connection/flow    |"
echo "| Packet Tunnel  | VPN client (packet-oriented)         | Individual packets |"
echo "| Filter Data    | Monitor/modify network flows         | Flow level         |"
echo "| Filter Packet  | Monitor/modify individual packets    | Packet level       |"
echo "| DNS Proxy      | Custom DNS provider                  | DNS requests       |"
echo ""

echo "2. Active Network Extensions"
echo "----------------------------"
if command -v networkextension &> /dev/null; then
    networkextension list 2>/dev/null || echo "Unable to list network extensions"
else
    echo "networkextension command not found"
fi
echo ""

echo "3. VPN Configurations"
echo "---------------------"
if command -v scutil &> /dev/null; then
    echo "Network Configuration:"
    scutil --nc list 2>/dev/null | head -30 || echo "Unable to retrieve"
else
    echo "scutil command not found"
fi
echo ""

echo "4. Network Extension Daemons"
echo "----------------------------"
ps aux 2>/dev/null | grep -E "(networkextension|com.apple.networkextension)" | grep -v grep || echo "No network extension daemons found"
echo ""

echo "5. Network Extension Files"
echo "--------------------------"
find /System/Library -name "*NetworkExtension*" 2>/dev/null | head -10 || echo "No matches found"
find /Library -name "*NetworkExtension*" 2>/dev/null | head -10 || echo "No matches found in /Library"
echo ""

echo "6. Network Extension Preferences"
echo "--------------------------------"
if [ -d "/Library/Preferences/com.apple.networkextension" ]; then
    ls -la "/Library/Preferences/com.apple.networkextension/" 2>/dev/null || echo "Not accessible"
else
    echo "Network extension preferences directory not found"
fi
echo ""

echo "=== Analysis Complete ==="
echo ""
echo "Note: Some commands require elevated privileges (sudo)"
