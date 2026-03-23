#!/bin/bash
# JAMF Configuration Enumeration Script
# Usage: ./jamf-enumerate.sh

set -e

echo "=== JAMF Configuration Enumeration ==="
echo ""

# Check if JAMF is installed
if [ -f /Library/Preferences/com.jamfsoftware.jamf.plist ]; then
    echo "[+] JAMF configuration found"
    echo ""
    
    # Extract JSS URL
    echo "[+] JSS URL:"
    plutil -convert xml1 -o - /Library/Preferences/com.jamfsoftware.jamf.plist 2>/dev/null | grep -A1 "jss_url" || echo "[!] Could not extract JSS URL"
    echo ""
    
    # Check for keychain
    if [ -f "/Library/Application Support/Jamf/JAMF.keychain" ]; then
        echo "[+] JAMF keychain found at /Library/Application Support/Jamf/JAMF.keychain"
    else
        echo "[-] JAMF keychain not found"
    fi
    echo ""
    
    # Check for LaunchDaemon
    if [ -f "/Library/LaunchAgents/com.jamf.management.agent.plist" ]; then
        echo "[+] JAMF LaunchDaemon found"
    else
        echo "[-] JAMF LaunchDaemon not found"
    fi
    echo ""
    
    # Check for tmp scripts
    if [ -d "/Library/Application Support/Jamf/tmp/" ]; then
        echo "[+] JAMF tmp directory found"
        ls -la "/Library/Application Support/Jamf/tmp/" 2>/dev/null || echo "[!] Could not list tmp directory"
    else
        echo "[-] JAMF tmp directory not found"
    fi
else
    echo "[-] JAMF not installed on this system"
fi

echo ""
echo "[+] Device UUID:"
ioreg -d2 -c IOPlatformExpertDevice 2>/dev/null | awk -F" " '/IOPlatformUUID/{print $(NF-1)}' || echo "[!] Could not extract UUID"

echo ""
echo "[+] Running JAMF processes:"
ps aux | grep -i jamf | grep -v grep || echo "[!] No JAMF processes found"

echo ""
echo "=== Enumeration Complete ==="
