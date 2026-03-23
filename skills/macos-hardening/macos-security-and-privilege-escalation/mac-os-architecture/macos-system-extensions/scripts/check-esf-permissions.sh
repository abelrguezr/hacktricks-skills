#!/bin/bash
# Endpoint Security Framework Permission Checker
# Analyzes TCC permissions related to Endpoint Security

set -e

echo "=== Endpoint Security Framework Permission Analysis ==="
echo ""

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "Warning: This script is designed for macOS. Current OS: $OSTYPE"
    echo ""
fi

echo "1. Full Disk Access Permissions"
echo "--------------------------------"
if command -v tccutil &> /dev/null; then
    echo "Full Disk Access (All):"
    tccutil list 2>/dev/null | grep -A 100 "Full Disk" | head -20 || echo "Unable to retrieve"
else
    echo "tccutil not available"
fi
echo ""

echo "2. Endpoint Security Client Permission"
echo "--------------------------------------"
echo "Checking for kTCCServiceEndpointSecurityClient..."
# This permission is managed by tccd and may not show in tccutil list
echo "Note: kTCCServiceEndpointSecurityClient is managed internally by tccd"
echo "Security apps with this permission won't be cleared by 'tccutil reset All'"
echo ""

echo "3. Security Software with Full Disk Access"
echo "------------------------------------------"
if command -v tccutil &> /dev/null; then
    tccutil list 2>/dev/null | grep -B 1 "Full Disk" | grep -v "Full Disk" | grep -v "^--$" || echo "None found or unable to retrieve"
else
    echo "tccutil not available"
fi
echo ""

echo "4. Endpoint Security Framework Status"
echo "-------------------------------------"
echo "ESF KEXT:"
kextstat 2>/dev/null | grep -i "EndpointSecurity" || echo "Not loaded or not found"
echo ""

echo "ESF Daemon:"
ps aux 2>/dev/null | grep endpointsecurityd | grep -v grep || echo "Not running"
echo ""

echo "5. CVE-2021-30965 Bypass Check"
echo "------------------------------"
echo "The CVE-2021-30965 bypass involved: tccutil reset All"
echo "This was fixed by introducing kTCCServiceEndpointSecurityClient"
echo ""
echo "To check if security apps are protected:"
echo "  - Apps with kTCCServiceEndpointSecurityClient won't be affected by tccutil reset"
echo "  - This permission is managed by tccd, not visible in tccutil list"
echo ""

echo "=== Analysis Complete ==="
echo ""
echo "Important Notes:"
echo "- Modern macOS versions protect security apps from TCC resets"
echo "- Full Disk Access is required for ESF functionality"
echo "- kTCCServiceEndpointSecurityClient prevents permission clearing"
