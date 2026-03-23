#!/bin/bash
# AD DNS Enumeration Helper Script
# Usage: ./dns-enumerate.sh -u user -d domain -t dc-ip [options]

set -e

# Default values
USERNAME=""
DOMAIN=""
TARGET_IP=""
OUTPUT_DIR="./dns-output"
VERBOSE=false
JSON_OUTPUT=false

# Parse arguments
while getopts "u:d:t:o:vj" opt; do
  case $opt in
    u) USERNAME="$OPTARG" ;;
    d) DOMAIN="$OPTARG" ;;
    t) TARGET_IP="$OPTARG" ;;
    o) OUTPUT_DIR="$OPTARG" ;;
    v) VERBOSE=true ;;
    j) JSON_OUTPUT=true ;;
    *) echo "Usage: $0 -u user -d domain -t dc-ip [-o output_dir] [-v] [-j]"; exit 1 ;;
  esac
done

# Validate required arguments
if [[ -z "$USERNAME" || -z "$DOMAIN" || -z "$TARGET_IP" ]]; then
  echo "Error: Missing required arguments"
  echo "Usage: $0 -u user -d domain -t dc-ip [-o output_dir] [-v] [-j]"
  echo "  -u: Username (e.g., admin)"
  echo "  -d: Domain (e.g., CORP)"
  echo "  -t: Target DC IP (e.g., 10.10.10.10)"
  echo "  -o: Output directory (default: ./dns-output)"
  echo "  -v: Verbose output"
  echo "  -j: JSON output format"
  exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Build adidnsdump command
ADIDNSDUMP_CMD="adidnsdump -u ${DOMAIN}\\${USERNAME} ldap://${TARGET_IP}"

if [[ "$JSON_OUTPUT" == true ]]; then
  ADIDNSDUMP_CMD="$ADIDNSDUMP_CMD --json"
fi

if [[ "$VERBOSE" == true ]]; then
  echo "[*] Starting AD DNS enumeration..."
  echo "[*] Target: ${TARGET_IP}"
  echo "[*] User: ${DOMAIN}\\${USERNAME}"
  echo "[*] Output: ${OUTPUT_DIR}"
fi

# Step 1: List all zones
echo "[*] Enumerating DNS zones..."
$ADIDNSDUMP_CMD --print-zones > "$OUTPUT_DIR/zones.txt" 2>&1
if [[ "$VERBOSE" == true ]]; then
  cat "$OUTPUT_DIR/zones.txt"
fi

# Step 2: Enumerate default zone with resolution
echo "[*] Enumerating default zone with DNS resolution..."
$ADIDNSDUMP_CMD -r > "$OUTPUT_DIR/records.csv" 2>&1
if [[ "$VERBOSE" == true ]]; then
  echo "[*] Records saved to $OUTPUT_DIR/records.csv"
  head -20 "$OUTPUT_DIR/records.csv"
fi

# Step 3: Count records by type
echo "[*] Analyzing record types..."
if [[ -f "$OUTPUT_DIR/records.csv" ]]; then
  echo "Record Type Distribution:"
  tail -n +2 "$OUTPUT_DIR/records.csv" | cut -d',' -f2 | sort | uniq -c | sort -rn > "$OUTPUT_DIR/record_types.txt"
  cat "$OUTPUT_DIR/record_types.txt"
fi

# Step 4: Extract SRV records (service locations)
echo "[*] Extracting SRV records..."
if [[ -f "$OUTPUT_DIR/records.csv" ]]; then
  grep -i ",SRV," "$OUTPUT_DIR/records.csv" > "$OUTPUT_DIR/srv_records.csv" 2>/dev/null || true
  if [[ -s "$OUTPUT_DIR/srv_records.csv" ]]; then
    echo "Found $(wc -l < "$OUTPUT_DIR/srv_records.csv") SRV records"
    head -10 "$OUTPUT_DIR/srv_records.csv"
  fi
fi

# Step 5: Extract CNAME records (aliases)
echo "[*] Extracting CNAME records..."
if [[ -f "$OUTPUT_DIR/records.csv" ]]; then
  grep -i ",CNAME," "$OUTPUT_DIR/records.csv" > "$OUTPUT_DIR/cname_records.csv" 2>/dev/null || true
  if [[ -s "$OUTPUT_DIR/cname_records.csv" ]]; then
    echo "Found $(wc -l < "$OUTPUT_DIR/cname_records.csv") CNAME records"
    head -10 "$OUTPUT_DIR/cname_records.csv"
  fi
fi

# Step 6: Check for suspicious records
echo "[*] Checking for suspicious records..."
SUSPICIOUS_PATTERNS=("wpad" "isatap" "*" "ms-wpad")
for pattern in "${SUSPICIOUS_PATTERNS[@]}"; do
  if grep -qi "$pattern" "$OUTPUT_DIR/records.csv" 2>/dev/null; then
    echo "[!] WARNING: Found suspicious pattern: $pattern"
    grep -i "$pattern" "$OUTPUT_DIR/records.csv" >> "$OUTPUT_DIR/suspicious_records.txt" 2>/dev/null || true
  fi
done

if [[ -f "$OUTPUT_DIR/suspicious_records.txt" ]]; then
  echo "[!] Suspicious records saved to $OUTPUT_DIR/suspicious_records.txt"
fi

# Summary
echo ""
echo "=== Enumeration Complete ==="
echo "Output directory: $OUTPUT_DIR"
echo "Files generated:"
ls -la "$OUTPUT_DIR/"
echo ""
echo "Next steps:"
echo "1. Review $OUTPUT_DIR/records.csv for all DNS records"
echo "2. Check $OUTPUT_DIR/srv_records.csv for service locations"
echo "3. Examine $OUTPUT_DIR/suspicious_records.txt for potential issues"
echo "4. Use $OUTPUT_DIR/zones.txt to enumerate additional zones if needed"
