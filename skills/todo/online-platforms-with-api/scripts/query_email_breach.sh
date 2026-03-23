#!/bin/bash
# Query email breach databases
# Usage: ./query_email_breach.sh <email> [api_keys_file]

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <email> [api_keys_file]"
    echo "Example: $0 user@example.com"
    exit 1
fi

EMAIL="$1"
API_KEYS_FILE="${2:-}"

echo "=== Email Breach Report for: $EMAIL ==="
echo "Generated: $(date)"
echo ""

# HaveIBeenPwned (requires API key for API access)
if [ -n "$API_KEYS_FILE" ] && [ -f "$API_KEYS_FILE" ]; then
    HIBP_KEY=$(grep -i "haveibeenpwned" "$API_KEYS_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
    if [ -n "$HIBP_KEY" ]; then
        echo "--- HaveIBeenPwned ---"
        HIBP_RESULT=$(curl -s -H "Authorization: Bearer $HIBP_KEY" "https://haveibeenpwned.com/api/v3/breachedaccount/$EMAIL" 2>/dev/null || echo "Error")
        echo "$HIBP_RESULT" | python3 -m json.tool 2>/dev/null || echo "$HIBP_RESULT"
        echo ""
    else
        echo "--- HaveIBeenPwned ---"
        echo "No API key provided. Check manually at: https://haveibeenpwned.com/"
        echo ""
    fi
fi

# EmailRep.io (requires API key)
if [ -n "$API_KEYS_FILE" ] && [ -f "$API_KEYS_FILE" ]; then
    EMAILREP_KEY=$(grep -i "emailrep" "$API_KEYS_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
    if [ -n "$EMAILREP_KEY" ]; then
        echo "--- EmailRep.io ---"
        ER_RESULT=$(curl -s -H "Authorization: $EMAILREP_KEY" "https://api.emailrep.io/v4/?email=$EMAIL" 2>/dev/null || echo "Error")
        echo "$ER_RESULT" | python3 -m json.tool 2>/dev/null || echo "$ER_RESULT"
        echo ""
    fi
fi

# Hunter (requires API key)
if [ -n "$API_KEYS_FILE" ] && [ -f "$API_KEYS_FILE" ]; then
    HUNTER_KEY=$(grep -i "hunter" "$API_KEYS_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
    if [ -n "$HUNTER_KEY" ]; then
        echo "--- Hunter ---"
        HUNTER_RESULT=$(curl -s -H "X-Api-Key: $HUNTER_KEY" "https://api.hunter.io/v2/email-verifier?email=$EMAIL" 2>/dev/null || echo "Error")
        echo "$HUNTER_RESULT" | python3 -m json.tool 2>/dev/null || echo "$HUNTER_RESULT"
        echo ""
    fi
fi

echo "=== End of Report ==="
echo ""
echo "Note: For comprehensive results, also check:"
echo "- Dehashed: https://www.dehashed.com/data"
echo "- PSBDMP: https://psbdmp.ws/"
echo "- IntelligenceX: https://intelx.io/"
echo "- GhostProject: https://ghostproject.fr/"
echo "- FullContact: https://www.fullcontact.com/"
echo "- Clearbit: https://dashboard.clearbit.com/"
