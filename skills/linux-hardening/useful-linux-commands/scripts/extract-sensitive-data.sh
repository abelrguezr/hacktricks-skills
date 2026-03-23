#!/bin/bash
# extract-sensitive-data.sh
# Extract sensitive data patterns from files
# Usage: ./extract-sensitive-data.sh <directory_or_file> [output_dir]

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <directory_or_file> [output_dir]"
    echo "Extracts emails, IPs, passwords, hashes, credit cards, SSNs from files"
    exit 1
fi

INPUT="$1"
OUTPUT_DIR="${2:-./extraction_results}"

mkdir -p "$OUTPUT_DIR"

echo "Starting extraction from: $INPUT"
echo "Results will be saved to: $OUTPUT_DIR"
echo ""

# Function to run grep on input
run_grep() {
    local pattern="$1"
    local output_file="$2"
    local description="$3"
    
    echo "Extracting: $description"
    if [ -d "$INPUT" ]; then
        grep -rE -o "$pattern" "$INPUT" 2>/dev/null | cut -d: -f2- | sort -u > "$OUTPUT_DIR/$output_file" || true
    else
        grep -E -o "$pattern" "$INPUT" 2>/dev/null > "$OUTPUT_DIR/$output_file" || true
    fi
    
    local count=$(wc -l < "$OUTPUT_DIR/$output_file" 2>/dev/null || echo "0")
    echo "  -> Found $count matches in $output_file"
}

# Extract emails
echo "=== Email Addresses ==="
run_grep "\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}\b" "emails.txt" "Email addresses"

# Extract IP addresses
echo ""
echo "=== IP Addresses ==="
run_grep "(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)" "ip_addresses.txt" "IP addresses"

# Extract password-related strings
echo ""
echo "=== Password Indicators ==="
run_grep "pwd|passw|password|passwd" "password_indicators.txt" "Password-related strings"

# Extract MD5 hashes (32 hex chars)
echo ""
echo "=== Hashes ==="
run_grep "(^|[^a-fA-F0-9])[a-fA-F0-9]{32}([^a-fA-F0-9]|$)" "md5_hashes.txt" "MD5 hashes (32 chars)"

# Extract SHA256 hashes (64 hex chars)
run_grep "(^|[^a-fA-F0-9])[a-fA-F0-9]{64}([^a-fA-F0-9]|$)" "sha256_hashes.txt" "SHA256 hashes (64 chars)"

# Extract credit cards
echo ""
echo "=== Credit Cards ==="
run_grep "4[0-9]{3}[ -]?[0-9]{4}[ -]?[0-9]{4}[ -]?[0-9]{4}" "visa_cards.txt" "Visa cards"
run_grep "5[0-9]{3}[ -]?[0-9]{4}[ -]?[0-9]{4}[ -]?[0-9]{4}" "mastercard_cards.txt" "MasterCard cards"
run_grep "\b3[47][0-9]{13}\b" "amex_cards.txt" "American Express cards"

# Extract SSNs
echo ""
echo "=== Personal Identifiers ==="
run_grep "[0-9]{3}[ -]?[0-9]{2}[ -]?[0-9]{4}" "ssn_candidates.txt" "SSN patterns"

# Extract URLs
echo ""
echo "=== URLs ==="
run_grep "https?://[^\s\"<>]+" "urls.txt" "HTTP/HTTPS URLs"

# Extract user/authentication mentions
echo ""
echo "=== Authentication ==="
run_grep "user|invalid|authentication|login" "auth_indicators.txt" "Authentication-related strings"

echo ""
echo "=== Extraction Complete ==="
echo "Results saved to: $OUTPUT_DIR"
echo ""
echo "Summary:"
for f in "$OUTPUT_DIR"/*.txt; do
    if [ -f "$f" ]; then
        count=$(wc -l < "$f")
        echo "  $(basename "$f"): $count matches"
    fi
done
