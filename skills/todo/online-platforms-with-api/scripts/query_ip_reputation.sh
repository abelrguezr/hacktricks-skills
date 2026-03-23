#!/bin/bash
# Query multiple IP reputation services
# Usage: ./query_ip_reputation.sh <ip_address> [api_keys_file]

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <ip_address> [api_keys_file]"
    echo "Example: $0 192.168.1.1"
    exit 1
fi

IP="$1"
API_KEYS_FILE="${2:-}"

echo "=== IP Reputation Report for: $IP ==="
echo "Generated: $(date)"
echo ""

# ProjectHoneypot (no API key required)
echo "--- ProjectHoneypot ---"
PH_RESULT=$(curl -s "https://api.projecthoneypot.net/dnsbl/$IP" 2>/dev/null || echo "Error")
echo "Status: $PH_RESULT"
echo "URL: https://www.projecthoneypot.org/"
echo ""

# ipinfo (requires API key for programmatic access)
if [ -n "$API_KEYS_FILE" ] && [ -f "$API_KEYS_FILE" ]; then
    IPINFO_KEY=$(grep -i "ipinfo" "$API_KEYS_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
    if [ -n "$IPINFO_KEY" ]; then
        echo "--- ipinfo ---"
        IPINFO_RESULT=$(curl -s "https://ipinfo.io/$IP/json?token=$IPINFO_KEY" 2>/dev/null || echo "Error")
        echo "$IPINFO_RESULT" | python3 -m json.tool 2>/dev/null || echo "$IPINFO_RESULT"
        echo ""
    fi
fi

# Greynoise (requires API key)
if [ -n "$API_KEYS_FILE" ] && [ -f "$API_KEYS_FILE" ]; then
    GREYNOISE_KEY=$(grep -i "greynoise" "$API_KEYS_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
    if [ -n "$GREYNOISE_KEY" ]; then
        echo "--- Greynoise ---"
        GREYNOISE_RESULT=$(curl -s -H "Authorization: Bearer $GREYNOISE_KEY" "https://api.greynoise.io/v3/noise/ip/$IP" 2>/dev/null || echo "Error")
        echo "$GREYNOISE_RESULT" | python3 -m json.tool 2>/dev/null || echo "$GREYNOISE_RESULT"
        echo ""
    fi
fi

# Shodan (requires API key)
if [ -n "$API_KEYS_FILE" ] && [ -f "$API_KEYS_FILE" ]; then
    SHODAN_KEY=$(grep -i "shodan" "$API_KEYS_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
    if [ -n "$SHODAN_KEY" ]; then
        echo "--- Shodan ---"
        SHODAN_RESULT=$(curl -s "https://api.shodan.io/shodan/host/$IP?key=$SHODAN_KEY" 2>/dev/null || echo "Error")
        echo "$SHODAN_RESULT" | python3 -m json.tool 2>/dev/null || echo "$SHODAN_RESULT"
        echo ""
    fi
fi

echo "=== End of Report ==="
echo ""
echo "Note: For comprehensive results, also check:"
echo "- FortiGuard: https://fortiguard.com/"
echo "- Fraudguard: https://fraudguard.io/"
echo "- SpamCop: https://www.spamcop.net/"
echo "- IBM X-Force: https://exchange.xforce.ibmcloud.com/"
echo "- Censys: https://censys.io/"
echo "- Binaryedge: https://www.binaryedge.io/"
