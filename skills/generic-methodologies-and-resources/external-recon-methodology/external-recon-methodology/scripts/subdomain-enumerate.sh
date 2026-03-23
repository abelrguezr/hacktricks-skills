#!/bin/bash
# Subdomain Enumeration Script
# Usage: ./subdomain-enumerate.sh <target-domain>

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <target-domain>"
    echo "Example: $0 example.com"
    exit 1
fi

TARGET="$1"
OUTPUT_DIR="./recon-output/${TARGET}"
mkdir -p "$OUTPUT_DIR"

echo "[*] Starting subdomain enumeration for: $TARGET"
echo "[*] Output directory: $OUTPUT_DIR"

# Create output files
SUBDOMAINS_FILE="$OUTPUT_DIR/subdomains.txt"
WEB_SERVERS_FILE="$OUTPUT_DIR/web_servers.txt"

echo "[*] Running passive subdomain enumeration..."

# BBOT (if available)
if command -v bbot &> /dev/null; then
    echo "[*] Running BBOT..."
    bbot -t "$TARGET" -f subdomain-enum -rf passive 2>/dev/null | grep -E "^[a-zA-Z0-9]" | sort -u >> "$SUBDOMAINS_FILE" || true
fi

# Subfinder (if available)
if command -v subfinder &> /dev/null; then
    echo "[*] Running Subfinder..."
    subfinder -d "$TARGET" -silent 2>/dev/null >> "$SUBDOMAINS_FILE" || true
fi

# Amass (if available)
if command -v amass &> /dev/null; then
    echo "[*] Running Amass..."
    amass enum -passive -d "$TARGET" 2>/dev/null | grep "$TARGET" | sort -u >> "$SUBDOMAINS_FILE" || true
fi

# Assetfinder (if available)
if command -v assetfinder &> /dev/null; then
    echo "[*] Running Assetfinder..."
    assetfinder --subs-only "$TARGET" 2>/dev/null >> "$SUBDOMAINS_FILE" || true
fi

# crt.sh API
echo "[*] Querying crt.sh..."
curl -s "https://crt.sh/?q=%25.$TARGET&output=json" 2>/dev/null | \
    jq -r '.[].name_value' 2>/dev/null | \
    grep -E "^[a-zA-Z0-9]" | \
    grep "$TARGET" | \
    sort -u >> "$SUBDOMAINS_FILE" || true

# Sonar API
echo "[*] Querying Sonar API..."
curl -s "https://sonar.omnisint.io/subdomains/$TARGET" 2>/dev/null | \
    jq -r '.[]' 2>/dev/null | \
    sort -u >> "$SUBDOMAINS_FILE" || true

# Deduplicate and clean
echo "[*] Deduplicating results..."
sort -u "$SUBDOMAINS_FILE" -o "$SUBDOMAINS_FILE"

# Count results
TOTAL=$(wc -l < "$SUBDOMAINS_FILE")
echo "[*] Found $TOTAL unique subdomains"

# Find web servers
echo "[*] Discovering web servers..."
if command -v httprobe &> /dev/null; then
    cat "$SUBDOMAINS_FILE" | httprobe 2>/dev/null > "$WEB_SERVERS_FILE" || true
    WEB_COUNT=$(wc -l < "$WEB_SERVERS_FILE")
    echo "[*] Found $WEB_COUNT web servers"
else
    echo "[!] httprobe not found - skipping web server discovery"
fi

# Summary
echo ""
echo "========================================"
echo "Reconnaissance Summary for $TARGET"
echo "========================================"
echo "Subdomains: $SUBDOMAINS_FILE ($TOTAL found)"
echo "Web Servers: $WEB_SERVERS_FILE"
echo ""
echo "Next steps:"
echo "  1. Review subdomains: cat $SUBDOMAINS_FILE"
echo "  2. Check web servers: cat $WEB_SERVERS_FILE"
echo "  3. Take screenshots: gowitness file $WEB_SERVERS_FILE"
echo "  4. DNS brute force: massdns with wordlists"
echo "========================================"
