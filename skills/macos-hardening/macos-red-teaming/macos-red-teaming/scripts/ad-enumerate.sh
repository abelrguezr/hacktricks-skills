#!/bin/bash
# Active Directory Enumeration Script for macOS
# Usage: ./ad-enumerate.sh [domain]

set -e

DOMAIN=${1:-""}

echo "=== Active Directory Enumeration ==="
echo ""

# Get domain information
echo "[+] Domain Information:"
echo show com.apple.opendirectoryd.ActiveDirectory | scutil 2>/dev/null || echo "[!] Could not retrieve domain info"
echo ""

dsconfigad -show 2>/dev/null || echo "[!] dsconfigad not available or no AD configured"
echo ""

# If domain provided, enumerate that domain
if [ -n "$DOMAIN" ]; then
    echo "[+] Enumerating domain: $DOMAIN"
    echo ""
    
    echo "[+] Users:"
    dscl "/Active Directory/$DOMAIN/All Domains" ls /Users 2>/dev/null || echo "[!] Could not list users"
    echo ""
    
    echo "[+] Computers:"
    dscl "/Active Directory/$DOMAIN/All Domains" ls /Computers 2>/dev/null || echo "[!] Could not list computers"
    echo ""
    
    echo "[+] Groups:"
    dscl "/Active Directory/$DOMAIN/All Domains" ls /Groups 2>/dev/null || echo "[!] Could not list groups"
    echo ""
else
    echo "[+] Local Users:"
    dscl . ls /Users 2>/dev/null || echo "[!] Could not list local users"
    echo ""
    
    echo "[+] Local Groups:"
    dscl . ls /Groups 2>/dev/null || echo "[!] Could not list local groups"
    echo ""
    
    echo "[+] Cached Users:"
    dscacheutil -q user 2>/dev/null | head -20 || echo "[!] Could not query cached users"
    echo ""
fi

echo "=== Enumeration Complete ==="
