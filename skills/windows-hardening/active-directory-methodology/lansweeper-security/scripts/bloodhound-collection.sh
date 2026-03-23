#!/bin/bash
# Lansweeper AD Assessment - BloodHound Collection
# Usage: ./bloodhound-collection.sh <dc_host> <domain> <username> <password>

set -e

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
    echo "Usage: $0 <dc_host> <domain> <username> <password>"
    echo "Example: $0 inventory.sweep.vl sweep.vl svc_inventory_lnx 'password123'"
    exit 1
fi

DC_HOST="$1"
DOMAIN="$2"
USERNAME="$3"
PASSWORD="$4"

echo "[*] BloodHound Collection for Lansweeper Assessment"
echo "[*] Target: ${DC_HOST}"
echo "[*] Domain: ${DOMAIN}"
echo ""

# Check available tools
if command -v netexec &> /dev/null; then
    echo "[*] Running NetExec BloodHound collection..."
    netexec ldap "${DC_HOST}" -u "${USERNAME}" -p "${PASSWORD}" --bloodhound -c All --dns-server "${DC_HOST}"
    echo "[+] NetExec collection complete. Data in /var/lib/netexec/bloodhound/"
elif command -v rusthound-ce &> /dev/null; then
    echo "[*] Running RustHound-CE collection..."
    rusthound-ce --domain "${DOMAIN}" -u "${USERNAME}" -p "${PASSWORD}" -c All --zip
    echo "[+] RustHound-CE collection complete. Check for .zip file."
else
    echo "[!] Neither netexec nor rusthound-ce found."
    echo "    Install netexec: pipx install netexec"
    echo "    Install rusthound-ce: See https://github.com/SpecterOps/BloodHound"
    exit 1
fi

echo ""
echo "[+] Next steps:"
echo "    1. Import data into BloodHound CE"
echo "    2. Run queries to find paths from ${USERNAME} to privileged groups"
echo "    3. Look for: 'Lansweeper Admins', 'Lansweeper Discovery', 'Remote Management Users'"
echo "    4. Identify GenericAll/WriteDACL/WriteProperty on privileged groups"
