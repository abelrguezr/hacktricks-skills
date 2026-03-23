#!/bin/bash
# ADWS Enumeration Helper Script
# Automates common ADWS enumeration tasks with SoaPy

set -e

# Configuration
DOMAIN="${1:-}"
USER="${2:-}"
PASSWORD="${3:-}"
DC="${4:-}"
OUTPUT_DIR="${5:-./adws-data}"

if [[ -z "$DOMAIN" || -z "$USER" || -z "$PASSWORD" || -z "$DC" ]]; then
    echo "Usage: $0 <domain> <user> <password> <dc> [output_dir]"
    echo "Example: $0 corp.local admin 'P@ssw0rd123' dc01.corp.local ./data"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# SoaPy connection string
SOAPY_CONN="${DOMAIN}/${USER}:${PASSWORD}@${DC}"

echo "[*] Starting ADWS enumeration against ${DC}"
echo "[*] Output directory: ${OUTPUT_DIR}"

# 1. Domain object
echo "[*] Collecting domain object..."
soapy $SOAPY_CONN -q '(objectClass=domain)' | tee "$OUTPUT_DIR/domain.log"

# 2. Users
echo "[*] Collecting users..."
soapy $SOAPY_CONN --users --parse | tee "$OUTPUT_DIR/users.log"

# 3. Computers
echo "[*] Collecting computers..."
soapy $SOAPY_CONN --computers --parse | tee "$OUTPUT_DIR/computers.log"

# 4. Groups
echo "[*] Collecting groups..."
soapy $SOAPY_CONN --groups --parse | tee "$OUTPUT_DIR/groups.log"

# 5. SPNs (Kerberoasting targets)
echo "[*] Collecting SPNs..."
soapy $SOAPY_CONN --spns -f samAccountName,servicePrincipalName --parse | tee "$OUTPUT_DIR/spns.log"

# 6. AS-REP roastable
echo "[*] Collecting AS-REP roastable accounts..."
soapy $SOAPY_CONN --asreproastable --parse | tee "$OUTPUT_DIR/asreproastable.log"

# 7. Admins
echo "[*] Collecting admin accounts..."
soapy $SOAPY_CONN --admins --parse | tee "$OUTPUT_DIR/admins.log"

# 8. RBCD-capable objects
echo "[*] Collecting RBCD-capable objects..."
soapy $SOAPY_CONN --rbcds --parse | tee "$OUTPUT_DIR/rbcds.log"

# 9. Constrained delegation
echo "[*] Collecting constrained delegation objects..."
soapy $SOAPY_CONN --constrained --parse | tee "$OUTPUT_DIR/constrained.log"

# 10. Unconstrained delegation
echo "[*] Collecting unconstrained delegation objects..."
soapy $SOAPY_CONN --unconstrained --parse | tee "$OUTPUT_DIR/unconstrained.log"

# Convert to BloodHound format if bofhound is available
if command -v bofhound &> /dev/null; then
    echo "[*] Converting to BloodHound format..."
    bofhound -i "$OUTPUT_DIR" --zip -o "$OUTPUT_DIR/bloodhound.zip"
    echo "[+] BloodHound data saved to: $OUTPUT_DIR/bloodhound.zip"
else
    echo "[!] bofhound not found. Install with: pip install bofhound"
fi

echo "[*] Enumeration complete. Results in: $OUTPUT_DIR"
