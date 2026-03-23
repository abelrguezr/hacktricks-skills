#!/bin/bash
# Generate and check domain variations for phishing detection
# Usage: ./generate_domain_variations.sh <brand-domain>

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <brand-domain>"
    echo "Example: $0 example.com"
    exit 1
fi

BRAND_DOMAIN="$1"
OUTPUT_DIR="./phishing-detection-output"
mkdir -p "$OUTPUT_DIR"

echo "=== Phishing Domain Variation Generator ==="
echo "Brand domain: $BRAND_DOMAIN"
echo "Output directory: $OUTPUT_DIR"
echo ""

# Check for required tools
if ! command -v dnstwist &> /dev/null; then
    echo "Warning: dnstwist not found. Install with: pip install dnstwist"
    echo "Falling back to basic permutation generation..."
    
    # Basic permutation generation without dnstwist
    echo "Generating basic domain variations..."
    
    # Extract domain parts
    DOMAIN_PART=$(echo "$BRAND_DOMAIN" | cut -d'.' -f1)
    TLD=$(echo "$BRAND_DOMAIN" | cut -d'.' -f2)
    
    # Common TLDs to check
    TLD_LIST="com net org io co uk ca au"
    
    # Generate variations
    > "$OUTPUT_DIR/variations.txt"
    
    # Add hyphenated versions
    for i in $(seq 1 ${#DOMAIN_PART}); do
        prefix="${DOMAIN_PART:0:$i}"
        suffix="${DOMAIN_PART:$i}"
        echo "${prefix}-${suffix}.${TLD}" >> "$OUTPUT_DIR/variations.txt"
    done
    
    # Add common phishing prefixes/suffixes
    PHISHING_WORDS="login secure account verify update payment support help portal my"
    for word in $PHISHING_WORDS; do
        echo "${word}${DOMAIN_PART}.${TLD}" >> "$OUTPUT_DIR/variations.txt"
        echo "${DOMAIN_PART}${word}.${TLD}" >> "$OUTPUT_DIR/variations.txt"
        echo "${word}-${DOMAIN_PART}.${TLD}" >> "$OUTPUT_DIR/variations.txt"
        echo "${DOMAIN_PART}-${word}.${TLD}" >> "$OUTPUT_DIR/variations.txt"
    done
    
    # Add TLD variations
    for tld in $TLD_LIST; do
        if [ "$tld" != "$TLD" ]; then
            echo "${DOMAIN_PART}.${tld}" >> "$OUTPUT_DIR/variations.txt"
        fi
    done
    
    # Remove duplicates and sort
    sort -u "$OUTPUT_DIR/variations.txt" -o "$OUTPUT_DIR/variations.txt"
    
else
    echo "Using dnstwist for comprehensive variation generation..."
    dnstwist -d "$BRAND_DOMAIN" -o "$OUTPUT_DIR/dnstwist_output.json" 2>/dev/null || true
    
    # Extract domain list from dnstwist output
    if [ -f "$OUTPUT_DIR/dnstwist_output.json" ]; then
        python3 -c "
import json
with open('$OUTPUT_DIR/dnstwist_output.json') as f:
    data = json.load(f)
    domains = [d['domain'] for d in data.get('permutations', [])]
    with open('$OUTPUT_DIR/variations.txt', 'w') as out:
        for d in domains:
            out.write(d + '\n')
" 2>/dev/null || true
    fi
fi

echo ""
echo "Generated variations saved to: $OUTPUT_DIR/variations.txt"
echo "Total variations: $(wc -l < "$OUTPUT_DIR/variations.txt")"
echo ""

# Check which domains are registered
echo "Checking DNS resolution for variations..."
echo "Domain,Status,IP" > "$OUTPUT_DIR/registered_domains.csv"

while IFS= read -r domain; do
    if [ -n "$domain" ]; then
        # Skip the original domain
        if [ "$domain" = "$BRAND_DOMAIN" ]; then
            continue
        fi
        
        # Check DNS resolution
        ip=$(dig +short "$domain" 2>/dev/null | head -1)
        if [ -n "$ip" ]; then
            echo "$domain,REGISTERED,$ip" >> "$OUTPUT_DIR/registered_domains.csv"
        else
            echo "$domain,NOT_REGISTERED," >> "$OUTPUT_DIR/registered_domains.csv"
        fi
    fi
done < "$OUTPUT_DIR/variations.txt"

echo ""
echo "=== Results ==="
echo "Registered domains: $(grep -c 'REGISTERED' "$OUTPUT_DIR/registered_domains.csv" || echo 0)"
echo "Not registered: $(grep -c 'NOT_REGISTERED' "$OUTPUT_DIR/registered_domains.csv" || echo 0)"
echo ""
echo "Registered domains (potential phishing):"
grep 'REGISTERED' "$OUTPUT_DIR/registered_domains.csv" | cut -d',' -f1,3 | head -20
echo ""
echo "Full results saved to: $OUTPUT_DIR/registered_domains.csv"
