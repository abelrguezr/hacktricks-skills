#!/bin/bash
# Credential Harvester Script
# Searches for credentials and secrets in extracted firmware

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <extracted_filesystem_dir> [output_file]"
    echo "Searches for credentials, API keys, and secrets in firmware"
    exit 1
fi

FS_DIR="$1"
OUTPUT_FILE="${2:-credentials_findings.txt}"

if [ ! -d "$FS_DIR" ]; then
    echo "Error: Directory not found: $FS_DIR"
    exit 1
fi

echo "=== Credential Harvester ==="
echo "Scanning: $FS_DIR"
echo "Output: $OUTPUT_FILE"
echo ""

# Initialize output file
echo "Credential Harvester Report" > "$OUTPUT_FILE"
echo "Generated: $(date)" >> "$OUTPUT_FILE"
echo "Target: $FS_DIR" >> "$OUTPUT_FILE"
echo "========================================" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Function to search and report
search_pattern() {
    local pattern="$1"
    local description="$2"
    local results
    
    results=$(grep -rn --include="*" "$pattern" "$FS_DIR" 2>/dev/null | head -50 || true)
    
    if [ -n "$results" ]; then
        echo "[$description]" >> "$OUTPUT_FILE"
        echo "Pattern: $pattern" >> "$OUTPUT_FILE"
        echo "Found $(echo "$results" | wc -l) matches:" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        echo "$results" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        echo "Found: $description"
    fi
}

echo "[1/10] Checking /etc/shadow..."
if [ -f "$FS_DIR/etc/shadow" ]; then
    echo "[Shadow File]" >> "$OUTPUT_FILE"
    cat "$FS_DIR/etc/shadow" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    echo "Found: /etc/shadow"
else
    echo "Not found: /etc/shadow"
fi
echo ""

echo "[2/10] Checking /etc/passwd..."
if [ -f "$FS_DIR/etc/passwd" ]; then
    echo "[Passwd File]" >> "$OUTPUT_FILE"
    cat "$FS_DIR/etc/passwd" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    echo "Found: /etc/passwd"
else
    echo "Not found: /etc/passwd"
fi
echo ""

echo "[3/10] Searching for password patterns..."
search_pattern "password" "Password references"
search_pattern "passwd" "Passwd references"
search_pattern "pwd" "PWD references"
echo ""

echo "[4/10] Searching for API keys..."
search_pattern "api_key" "API Key references"
search_pattern "apikey" "APIKey references"
search_pattern "api-key" "API-KEY references"
search_pattern "API_KEY" "API_KEY references"
echo ""

echo "[5/10] Searching for secrets..."
search_pattern "secret" "Secret references"
search_pattern "SECRET" "SECRET references"
search_pattern "private_key" "Private key references"
search_pattern "PRIVATE_KEY" "PRIVATE_KEY references"
echo ""

echo "[6/10] Searching for tokens..."
search_pattern "token" "Token references"
search_pattern "TOKEN" "TOKEN references"
search_pattern "auth_token" "Auth token references"
search_pattern "access_token" "Access token references"
echo ""

echo "[7/10] Searching for credentials in config files..."
search_pattern "username" "Username references"
search_pattern "user" "User references"
search_pattern "credential" "Credential references"
echo ""

echo "[8/10] Searching for URLs and endpoints..."
search_pattern "http://" "HTTP URLs"
search_pattern "https://" "HTTPS URLs"
search_pattern "mqtt://" "MQTT endpoints"
search_pattern "ftp://" "FTP endpoints"
echo ""

echo "[9/10] Searching for hardcoded IPs..."
search_pattern "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" "IP addresses"
echo ""

echo "[10/10] Checking SSL certificates and keys..."
SSL_FILES=$(find "$FS_DIR" -type f \( -name "*.key" -o -name "*.pem" -o -name "*.crt" -o -name "*.cer" \) 2>/dev/null || true)
if [ -n "$SSL_FILES" ]; then
    echo "[SSL Files]" >> "$OUTPUT_FILE"
    echo "$SSL_FILES" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    echo "Found SSL files:"
    echo "$SSL_FILES"
else
    echo "No SSL files found"
fi
echo ""

echo "=== Search Complete ==="
echo "Results saved to: $OUTPUT_FILE"
echo ""
echo "Review the output file for potential credentials and secrets."
