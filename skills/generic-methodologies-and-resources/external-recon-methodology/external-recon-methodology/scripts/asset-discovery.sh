#!/bin/bash
# Asset Discovery Script
# Usage: ./asset-discovery.sh <target-company-or-domain>

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <target-company-or-domain>"
    echo "Example: $0 tesla.com or $0 Tesla"
    exit 1
fi

TARGET="$1"
OUTPUT_DIR="./recon-output/${TARGET}"
mkdir -p "$OUTPUT_DIR"

echo "[*] Starting asset discovery for: $TARGET"
echo "[*] Output directory: $OUTPUT_DIR"

# ASN Discovery
echo ""
echo "========================================"
echo "Phase 1: ASN and IP Range Discovery"
echo "========================================"

# Check bgp.he.net
echo "[*] Checking BGP.he.net for ASN information..."
echo "Visit: https://bgp.he.net/search?search=$TARGET"
echo "Or use: https://bgpview.io/ip/$TARGET"

# Amass intel (if available)
if command -v amass &> /dev/null; then
    echo "[*] Running Amass intel..."
    amass intel -d "$TARGET" 2>/dev/null | tee "$OUTPUT_DIR/amass-intel.txt" || true
fi

# BBOT ASN discovery (if available)
if command -v bbot &> /dev/null; then
    echo "[*] Running BBOT for ASN aggregation..."
    bbot -t "$TARGET" -f subdomain-enum 2>&1 | grep -A 20 "bbot.modules.asn" | tee "$OUTPUT_DIR/bbot-asn.txt" || true
fi

# Reverse Whois
echo ""
echo "========================================"
echo "Phase 2: Reverse Whois Discovery"
echo "========================================"
echo "[*] Manual reverse whois tools:"
echo "  - https://viewdns.info/reversewhois/"
echo "  - https://domaineye.com/reverse-whois"
echo "  - https://www.reversewhois.io/"
echo "  - https://www.whoxy.com/"

# Certificate Transparency
echo ""
echo "========================================"
echo "Phase 3: Certificate Transparency Logs"
echo "========================================"
echo "[*] Querying crt.sh..."
crt_domains="$OUTPUT_DIR/crt-domains.txt"
curl -s "https://crt.sh/?q=%25.$TARGET&output=json" 2>/dev/null | \
    jq -r '.[].name_value' 2>/dev/null | \
    sort -u > "$crt_domains" || true
CRT_COUNT=$(wc -l < "$crt_domains")
echo "[*] Found $CRT_COUNT domains in certificate logs"
echo "[*] Results saved to: $crt_domains"

# Shodan organization search
echo ""
echo "========================================"
echo "Phase 4: Shodan Organization Search"
echo "========================================"
echo "[*] Shodan search queries to try:"
echo "  shodan search org:\"$TARGET\""
echo "  shodan search ssl:\"$TARGET\""
echo "[*] Visit: https://www.shodan.io/"

# DMARC discovery
echo ""
echo "========================================"
echo "Phase 5: DMARC Information"
echo "========================================"
echo "[*] Check DMARC records at:"
echo "  https://dmarc.live/info/$TARGET"
echo "  https://dmarcian.com/"

# Summary
echo ""
echo "========================================"
echo "Asset Discovery Summary"
echo "========================================"
echo "Target: $TARGET"
echo "Output directory: $OUTPUT_DIR"
echo ""
echo "Files created:"
ls -la "$OUTPUT_DIR" 2>/dev/null || echo "  (none yet)"
echo ""
echo "Next steps:"
echo "  1. Review ASN information from BGP.he.net"
echo "  2. Check certificate transparency logs: cat $crt_domains"
echo "  3. Run subdomain enumeration on discovered domains"
echo "  4. Search Shodan for organization assets"
echo "========================================"
