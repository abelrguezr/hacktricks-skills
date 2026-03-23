#!/bin/bash
#
# Validate email server configuration for phishing assessments
# Usage: ./validate_email_config.sh <domain>
#

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <domain>"
    echo "Example: $0 example.com"
    exit 1
fi

DOMAIN="$1"

echo "========================================"
echo "Email Configuration Validation"
echo "Domain: $DOMAIN"
echo "========================================"
echo ""

# Check SPF
echo "[1/5] Checking SPF Record..."
SPF=$(dig +short TXT $DOMAIN | grep -i "v=spf1" || echo "NOT FOUND")
if [ -n "$SPF" ]; then
    echo "✓ SPF Record Found:"
    echo "  $SPF"
else
    echo "✗ SPF Record NOT FOUND"
fi
echo ""

# Check DMARC
echo "[2/5] Checking DMARC Record..."
DMARC=$(dig +short TXT _dmarc.$DOMAIN || echo "NOT FOUND")
if [ -n "$DMARC" ]; then
    echo "✓ DMARC Record Found:"
    echo "  $DMARC"
else
    echo "✗ DMARC Record NOT FOUND"
fi
echo ""

# Check DKIM
echo "[3/5] Checking DKIM Record..."
DKIM=$(dig +short TXT default._domainkey.$DOMAIN || echo "NOT FOUND")
if [ -n "$DKIM" ]; then
    echo "✓ DKIM Record Found:"
    echo "  ${DKIM:0:80}..."
else
    echo "✗ DKIM Record NOT FOUND (or different selector)"
fi
echo ""

# Check MX
echo "[4/5] Checking MX Records..."
MX=$(dig +short MX $DOMAIN || echo "NOT FOUND")
if [ -n "$MX" ]; then
    echo "✓ MX Records Found:"
    echo "$MX" | while read line; do
        echo "  $line"
    done
else
    echo "✗ MX Records NOT FOUND"
fi
echo ""

# Check rDNS
echo "[5/5] Checking rDNS (PTR) Record..."
IP=$(dig +short $DOMAIN | head -1)
if [ -n "$IP" ]; then
    RDNS=$(dig +short -x $IP || echo "NOT FOUND")
    if [ -n "$RDNS" ]; then
        echo "✓ rDNS Record Found: $RDNS"
    else
        echo "✗ rDNS Record NOT FOUND"
    fi
else
    echo "✗ Could not resolve domain IP"
fi
echo ""

echo "========================================"
echo "Summary"
echo "========================================"
echo ""
echo "For optimal email deliverability:"
echo "  - SPF should be present and properly configured"
echo "  - DMARC should be set (start with p=none)"
echo "  - DKIM should be configured with Postfix"
echo "  - MX records should point to your mail server"
echo "  - rDNS should match your domain"
echo ""
echo "Test your configuration at:"
echo "  - https://www.mail-tester.com/"
echo "  - check-auth@verifier.port25.com"
echo ""
