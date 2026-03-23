#!/bin/bash
# Email Discovery Script
# Usage: ./email-discovery.sh <target-domain>

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <target-domain>"
    echo "Example: $0 example.com"
    exit 1
fi

TARGET="$1"
OUTPUT_DIR="./recon-output/${TARGET}"
mkdir -p "$OUTPUT_DIR"

echo "[*] Email Discovery for: $TARGET"
echo "[*] Output directory: $OUTPUT_DIR"

EMAILS_FILE="$OUTPUT_DIR/emails.txt"

echo "[*] Running email discovery..."

# theHarvester (if available)
if command -v theHarvester &> /dev/null; then
    echo "[*] Running theHarvester..."
    theHarvester -d "$TARGET" -b "google, linkedin, twitter, github-code, virustotal" 2>/dev/null | \
        grep -E "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$" | \
        sort -u >> "$EMAILS_FILE" || true
fi

# Hunter.io API (requires API key)
echo ""
echo "[*] Hunter.io API:"
echo "  Visit: https://hunter.io/"
echo "  Or use API: curl -X GET https://api.hunter.io/v2/domain-search?domain=$TARGET&api_key=YOUR_KEY"

# Snov.io API (requires API key)
echo ""
echo "[*] Snov.io API:"
echo "  Visit: https://app.snov.io/"
echo "  Or use API with your key"

# Minelead.io API (requires API key)
echo ""
echo "[*] Minelead.io API:"
echo "  Visit: https://minelead.io/"
echo "  Or use API with your key"

# Check for emails in discovered files
echo ""
echo "[*] Searching for emails in discovered content..."
if [ -d "$OUTPUT_DIR" ]; then
    grep -r -E "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}" "$OUTPUT_DIR" 2>/dev/null | \
        grep -E "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}:" | \
        cut -d: -f2- | \
        sort -u >> "$EMAILS_FILE" || true
fi

# Deduplicate
if [ -f "$EMAILS_FILE" ]; then
    sort -u "$EMAILS_FILE" -o "$EMAILS_FILE"
    EMAIL_COUNT=$(wc -l < "$EMAILS_FILE")
    echo "[*] Found $EMAIL_COUNT unique emails"
    echo "[*] Results saved to: $EMAILS_FILE"
else
    echo "[!] No emails found"
fi

# Credential leak check
echo ""
echo "========================================"
echo "Credential Leak Check"
echo "========================================"
echo "[*] Check for leaked credentials:"
echo "  - https://leak-lookup.com/"
echo "  - https://www.dehashed.com/"
echo ""
echo "[*] For each email found, check if it appears in known breaches"

# Summary
echo ""
echo "========================================"
echo "Email Discovery Summary"
echo "========================================"
echo "Target: $TARGET"
echo "Emails found: $EMAIL_COUNT"
echo "Results: $EMAILS_FILE"
echo ""
echo "Next steps:"
echo "  1. Review emails: cat $EMAILS_FILE"
echo "  2. Check for credential leaks"
echo "  3. Use emails for authorized testing only"
echo "========================================"
