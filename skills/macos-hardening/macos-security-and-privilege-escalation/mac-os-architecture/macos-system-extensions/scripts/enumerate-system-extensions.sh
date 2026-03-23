#!/bin/bash
# macOS System Extensions Enumeration Script
# Use this to enumerate and analyze system extensions on macOS

set -e

echo "=== macOS System Extensions Enumeration ==="
echo ""

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "Warning: This script is designed for macOS. Current OS: $OSTYPE"
    echo "Some commands may not work as expected."
    echo ""
fi

echo "1. Loaded Kernel Extensions (including System Extensions)"
echo "----------------------------------------------------------"
kextstat 2>/dev/null | grep -iE "(SystemExtension|DriverKit|NetworkExtension|EndpointSecurity)" || echo "No system extensions found or kextstat not available"
echo ""

echo "2. System Extensions Status"
echo "---------------------------"
if command -v systemextensionsctl &> /dev/null; then
    systemextensionsctl list 2>/dev/null || echo "systemextensionsctl not available or requires elevated privileges"
else
    echo "systemextensionsctl command not found"
fi
echo ""

echo "3. Endpoint Security Framework"
echo "------------------------------"
echo "ESF KEXT Status:"
kextstat 2>/dev/null | grep -i "EndpointSecurity" || echo "EndpointSecurity.kext not loaded or not found"
echo ""

echo "ESF Library:"
if [ -f "/System/Library/PrivateFrameworks/EndpointSecurity.framework/" ]; then
    ls -la "/System/Library/PrivateFrameworks/EndpointSecurity.framework/" 2>/dev/null || echo "Not accessible"
else
    echo "EndpointSecurity.framework not found at expected location"
fi
echo ""

echo "4. System Extension Daemons"
echo "---------------------------"
ps aux 2>/dev/null | grep -E "(endpointsecurityd|sysextd)" | grep -v grep || echo "No system extension daemons found"
echo ""

echo "5. TCC Permissions Summary"
echo "--------------------------"
if command -v tccutil &> /dev/null; then
    tccutil list 2>/dev/null | head -50 || echo "tccutil list failed"
else
    echo "tccutil command not found"
fi
echo ""

echo "6. Network Extensions"
echo "---------------------"
if command -v networkextension &> /dev/null; then
    networkextension list 2>/dev/null || echo "networkextension list failed"
else
    echo "networkextension command not found"
fi
echo ""

echo "7. System Extension Files"
echo "-------------------------"
find /System/Library/Extensions -name "*Endpoint*" -o -name "*SystemExtension*" 2>/dev/null | head -20 || echo "No matches found or permission denied"
echo ""

echo "=== Enumeration Complete ==="
echo ""
echo "Note: Some commands require elevated privileges (sudo)"
echo "For full enumeration, run: sudo $0
