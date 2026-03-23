#!/bin/bash
# Enumerate constrained delegation targets in Active Directory
# Usage: ./enumerate-constrained-delegation.sh [domain] [dc_ip]

set -e

DOMAIN=${1:-"domain.local"}
DC_IP=${2:-""}

echo "=== Constrained Delegation Enumeration ==="
echo "Domain: $DOMAIN"
echo ""

# Check if running on Windows with PowerView available
if command -v powershell &> /dev/null; then
    echo "[+] Using PowerView (Windows)"
    
    echo ""
    echo "=== Users with TrustedToAuthForDelegation ==="
    powershell -Command "Get-DomainUser -TrustedToAuth | select userprincipalname, name, msds-allowedtodelegateto"
    
    echo ""
    echo "=== Computers with TrustedToAuthForDelegation ==="
    powershell -Command "Get-DomainComputer -TrustedToAuth | select userprincipalname, name, msds-allowedtodelegateto"
else
    echo "[!] PowerView not available, using Impacket"
    
    # Using Impacket's ldapdump or similar
    if command -v ldapsearch &> /dev/null; then
        echo ""
        echo "=== Searching for constrained delegation objects ==="
        ldapsearch -x -H "ldap://${DC_IP:-localhost}" \
            -b "DC=${DOMAIN//./,DC=}" \
            "(&(objectClass=*)(msDS-AllowedToDelegateTo=*))" \
            sAMAccountName msDS-AllowedToDelegateTo 2>/dev/null || \
        echo "[!] LDAP search failed or no results"
    else
        echo "[!] No enumeration tools available"
        echo "Install PowerView (Windows) or ldapsearch (Linux)"
    fi
fi

echo ""
echo "=== Next Steps ==="
echo "1. Identify service accounts with delegation enabled"
echo "2. Obtain TGT/hash for those accounts"
echo "3. Use Rubeus s4u or Impacket getST.py for exploitation"
