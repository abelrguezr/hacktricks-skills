#!/bin/bash
# AD CS Enumeration Helper Script
# Usage: ./enumerate-adcs.sh <domain> <username> <password> <dc-ip>

set -e

if [ $# -lt 4 ]; then
    echo "Usage: $0 <domain> <username> <password> <dc-ip>"
    echo "Example: $0 corp.local john@corp.local Passw0rd 172.16.126.128"
    exit 1
fi

DOMAIN=$1
USERNAME=$2
PASSWORD=$3
DC_IP=$4
OUTPUT_DIR="./adcs-enumeration-$(date +%Y%m%d-%H%M%S)"

mkdir -p "$OUTPUT_DIR"

echo "[*] Starting AD CS Enumeration"
echo "[*] Domain: $DOMAIN"
echo "[*] Output: $OUTPUT_DIR"
echo ""

# Check if certipy is available
if command -v certipy &> /dev/null; then
    echo "[*] Using Certipy for enumeration"
    
    # Enumerate CAs
    echo "[*] Enumerating Certificate Authorities..."
    certipy casenum -u "$USERNAME" -p "$PASSWORD" -dc-ip "$DC_IP" > "$OUTPUT_DIR/casenum.txt" 2>&1
    
    # Find vulnerable templates
    echo "[*] Finding vulnerable templates..."
    certipy find -vulnerable -u "$USERNAME" -p "$PASSWORD" -dc-ip "$DC_IP" > "$OUTPUT_DIR/vulnerable-templates.txt" 2>&1
    
    # Find all templates
    echo "[*] Enumerating all templates..."
    certipy find -u "$USERNAME" -p "$PASSWORD" -dc-ip "$DC_IP" > "$OUTPUT_DIR/all-templates.txt" 2>&1
    
else
    echo "[!] Certipy not found. Please install: pip install certipy"
    echo "[!] Or use Certify.exe on Windows:"
    echo "    Certify.exe cas /domain:$DOMAIN /showAllPermissions"
    echo "    Certify.exe find /vulnerable /showAllPermissions"
fi

echo ""
echo "[*] Enumeration complete. Results saved to: $OUTPUT_DIR"
echo "[*] Review the following files:"
echo "    - casenum.txt: Certificate Authority information"
echo "    - vulnerable-templates.txt: Potentially exploitable templates"
echo "    - all-templates.txt: Complete template enumeration"
