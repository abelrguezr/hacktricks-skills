#!/bin/bash
# ADWS ADCS Enumeration Script
# Collects Active Directory Certificate Services objects for ESC analysis

set -e

# Configuration
DOMAIN="${1:-}"
USER="${2:-}"
PASSWORD="${3:-}"
DC="${4:-}"
OUTPUT_DIR="${5:-./adcs-data}"

if [[ -z "$DOMAIN" || -z "$USER" || -z "$PASSWORD" || -z "$DC" ]]; then
    echo "Usage: $0 <domain> <user> <password> <dc> [output_dir]"
    echo "Example: $0 corp.local admin 'P@ssw0rd123' dc01.corp.local ./adcs"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# SoaPy connection string
SOAPY_CONN="${DOMAIN}/${USER}:${PASSWORD}@${DC}"

echo "[*] Starting ADCS enumeration against ${DC}"
echo "[*] Output directory: ${OUTPUT_DIR}"

# ADCS enumeration query
ADCS_FILTER='(|(objectClass=pkiCertificateTemplate)(objectClass=CertificationAuthority)(objectClass=pkiEnrollmentService)(objectClass=msPKI-Enterprise-Oid))'

echo "[*] Collecting ADCS objects from Configuration NC..."
soapy $SOAPY_CONN \
      -dn 'CN=Configuration,DC='${DOMAIN//./,DC=} \
      -q "$ADCS_FILTER" \
      -f cn,distinguishedName,objectClass,pKIDefaultIssuanceModes,pKIExtendedKeyUsage,msPKI-Template-Schema-Version,msPKI-RA-Signature,msPKI-Enrollment-Flag \
      --parse \
      | tee "$OUTPUT_DIR/adcs.log"

# Extract certificate templates
echo "[*] Extracting certificate templates..."
soapy $SOAPY_CONN \
      -dn 'CN=Configuration,DC='${DOMAIN//./,DC=} \
      -q '(objectClass=pkiCertificateTemplate)' \
      -f cn,pKIDefaultIssuanceModes,msPKI-Enrollment-Flag \
      --parse \
      | tee "$OUTPUT_DIR/templates.log"

# Extract certification authorities
echo "[*] Extracting certification authorities..."
soapy $SOAPY_CONN \
      -dn 'CN=Configuration,DC='${DOMAIN//./,DC=} \
      -q '(objectClass=CertificationAuthority)' \
      -f cn,dNSHostName,servicePrincipalName \
      --parse \
      | tee "$OUTPUT_DIR/cas.log"

# Convert to BloodHound format if bofhound is available
if command -v bofhound &> /dev/null; then
    echo "[*] Converting to BloodHound format..."
    bofhound -i "$OUTPUT_DIR" --zip -o "$OUTPUT_DIR/adcs-bloodhound.zip"
    echo "[+] ADCS BloodHound data saved to: $OUTPUT_DIR/adcs-bloodhound.zip"
else
    echo "[!] bofhound not found. Install with: pip install bofhound"
fi

echo ""
echo "[*] ADCS enumeration complete."
echo "[*] Next steps:"
echo "    1. Upload adcs-bloodhound.zip to BloodHound"
echo "    2. Run ESC queries: MATCH (u:User)-[:Can_Enroll*1..]->(c:CertTemplate) RETURN u,c"
echo "    3. Look for ESC1, ESC8, ESC10 paths"
