#!/bin/bash
# SCCM Management Point Endpoint Enumerator
# Usage: ./enumerate-mp-endpoints.sh <MP-FQDN>
# Queries unauthenticated MP endpoints to gather site information

if [ -z "$1" ]; then
    echo "Usage: $0 <MP-FQDN>"
    echo "Example: $0 MP01.contoso.local"
    exit 1
fi

MP_FQDN="$1"
MP_URL="http://${MP_FQDN}/SMS_MP/.sms_aut"

echo "[*] Enumerating SCCM Management Point: ${MP_FQDN}"
echo ""

# Query MPKEYINFORMATIONMEDIA
echo "[+] Fetching MPKEYINFORMATIONMEDIA..."
curl -s "${MP_URL}?MPKEYINFORMATIONMEDIA" | xmllint --format - 2>/dev/null || curl -s "${MP_URL}?MPKEYINFORMATIONMEDIA"
echo ""
echo ""

# Query MPLIST
echo "[+] Fetching MPLIST..."
curl -s "${MP_URL}?MPLIST" | xmllint --format - 2>/dev/null || curl -s "${MP_URL}?MPLIST"
echo ""
echo ""

# Query SITESIGNCERT
echo "[+] Fetching SITESIGNCERT..."
curl -s "${MP_URL}?SITESIGNCERT" | xmllint --format - 2>/dev/null || curl -s "${MP_URL}?SITESIGNCERT"
echo ""

echo ""
echo "[*] Enumeration complete."
