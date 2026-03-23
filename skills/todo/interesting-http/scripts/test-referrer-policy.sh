#!/bin/bash
# Test Referrer-Policy header for a given URL
# Usage: ./test-referrer-policy.sh https://example.com

if [ -z "$1" ]; then
    echo "Usage: $0 <url>"
    echo "Example: $0 https://example.com"
    exit 1
fi

URL="$1"

echo "Testing Referrer-Policy for: $URL"
echo "=========================================="

# Fetch headers
HEADERS=$(curl -s -I "$URL" 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "Error: Could not fetch headers from $URL"
    exit 1
fi

# Extract Referrer-Policy header
REFERRER_POLICY=$(echo "$HEADERS" | grep -i "Referrer-Policy" | head -1 | awk -F: '{print $2}' | xargs)

if [ -z "$REFERRER_POLICY" ]; then
    echo "⚠️  WARNING: No Referrer-Policy header found!"
    echo ""
    echo "The site is using the browser default (usually 'unsafe-url')."
    echo "This means full URLs including query parameters will be sent to external sites."
    echo ""
    echo "Recommendation: Add Referrer-Policy header with value:"
    echo "  - 'strict-origin-when-cross-origin' (recommended default)"
    echo "  - 'no-referrer' (most secure)"
    echo "  - 'same-origin' (only send to same domain)"
    exit 0
fi

echo "✓ Referrer-Policy found: $REFERRER_POLICY"
echo ""

# Evaluate the policy
case "$REFERRER_POLICY" in
    "no-referrer")
        echo "✅ HIGH SECURITY: No referrer information is sent."
        echo "   This is the most secure option."
        ;;
    "no-referrer-when-downgrade")
        echo "✅ HIGH SECURITY: Referrer not sent when downgrading from HTTPS to HTTP."
        echo "   Good protection against downgrade attacks."
        ;;
    "same-origin")
        echo "✅ HIGH SECURITY: Referrer only sent to same origin."
        echo "   External sites receive no referrer information."
        ;;
    "strict-origin")
        echo "✅ MEDIUM-HIGH SECURITY: Only origin sent, not to HTTPS→HTTP."
        echo "   Good balance of functionality and security."
        ;;
    "strict-origin-when-cross-origin")
        echo "✅ MEDIUM SECURITY: Full URL same-origin, origin only cross-origin."
        echo "   Recommended default for most sites."
        ;;
    "origin")
        echo "⚠️  MEDIUM SECURITY: Only origin sent (no path/query)."
        echo "   Better than default, but consider stricter options."
        ;;
    "origin-when-cross-origin")
        echo "⚠️  LOW-MEDIUM SECURITY: Full URL same-origin, origin cross-origin."
        echo "   Consider using 'strict-origin-when-cross-origin' instead."
        ;;
    "unsafe-url")
        echo "❌ LOW SECURITY: Full URL always sent."
        echo "   This can leak sensitive information in query parameters!"
        echo "   Strongly recommend changing to 'strict-origin-when-cross-origin' or 'no-referrer'."
        ;;
    *)
        echo "⚠️  Unknown or custom policy: $REFERRER_POLICY"
        echo "   Please verify this is intentional."
        ;;
esac

echo ""
echo "=========================================="
echo "Additional checks:"
echo ""

# Check for HTML meta tag
HTML=$(curl -s "$URL" 2>/dev/null)
META_REFERRER=$(echo "$HTML" | grep -i '<meta.*name="referrer"' | head -1)

if [ -n "$META_REFERRER" ]; then
    echo "⚠️  HTML meta referrer tag found:"
    echo "$META_REFERRER"
    echo ""
    echo "Note: HTML meta tags can be overridden by HTML injection attacks."
    echo "Server-side headers are more secure."
else
    echo "✓ No HTML meta referrer tag found (good - server header takes precedence)"
fi

echo ""
echo "Tip: Always avoid putting sensitive data in URL parameters,"
echo "regardless of Referrer-Policy settings."
