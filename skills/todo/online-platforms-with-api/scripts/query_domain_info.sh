#!/bin/bash
# Query multiple domain intelligence services
# Usage: ./query_domain_info.sh <domain> [api_keys_file]

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <domain> [api_keys_file]"
    echo "Example: $0 example.com"
    exit 1
fi

DOMAIN="$1"
API_KEYS_FILE="${2:-}"

echo "=== Domain Intelligence Report for: $DOMAIN ==="
echo "Generated: $(date)"
echo ""

# mywot (no API key required for basic check)
echo "--- mywot ---"
MYWOT_RESULT=$(curl -s "https://www.mywot.com/annotation/$DOMAIN" 2>/dev/null || echo "Error - check manually at https://www.mywot.com/")
echo "Status: Check manually at https://www.mywot.com/annotation/$DOMAIN"
echo ""

# SecurityTrails (requires API key)
if [ -n "$API_KEYS_FILE" ] && [ -f "$API_KEYS_FILE" ]; then
    SECURITYTRAILS_KEY=$(grep -i "securitytrails" "$API_KEYS_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
    if [ -n "$SECURITYTRAILS_KEY" ]; then
        echo "--- SecurityTrails ---"
        ST_RESULT=$(curl -s -H "APIKEY: $SECURITYTRAILS_KEY" "https://api.securitytrails.com/v1/domain/$DOMAIN/dns" 2>/dev/null || echo "Error")
        echo "$ST_RESULT" | python3 -m json.tool 2>/dev/null || echo "$ST_RESULT"
        echo ""
    fi
fi

# BuiltWith (requires API key)
if [ -n "$API_KEYS_FILE" ] && [ -f "$API_KEYS_FILE" ]; then
    BUILTWITH_KEY=$(grep -i "builtwith" "$API_KEYS_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
    if [ -n "$BUILTWITH_KEY" ]; then
        echo "--- BuiltWith ---"
        BW_RESULT=$(curl -s "https://api.builtwith.com/v2/Parse/$BUILTWITH_KEY/$DOMAIN" 2>/dev/null || echo "Error")
        echo "$BW_RESULT" | python3 -m json.tool 2>/dev/null || echo "$BW_RESULT"
        echo ""
    fi
fi

echo "=== End of Report ==="
echo ""
echo "Note: For comprehensive results, also check:"
echo "- RiskIQ: https://www.spiderfoot.net/documentation/"
echo "- DNSDumpster: https://dnsdumpster.com/"
echo "- Netcraft: https://www.netcraft.com/"
echo "- NMMapper: https://www.nmmapper.com/sys/tools/subdomainfinder/"
echo "- AlienVault OTX: https://otx.alienvault.com/api"
