#!/bin/bash
# Parse and analyze an X.509 certificate
# Usage: ./parse_certificate.sh <certificate_file>

if [ -z "$1" ]; then
    echo "Usage: $0 <certificate_file>"
    echo "Example: $0 cert.pem"
    exit 1
fi

CERT_FILE="$1"

if [ ! -f "$CERT_FILE" ]; then
    echo "Error: File not found: $CERT_FILE"
    exit 1
fi

echo "=== Certificate Analysis ==="
echo "File: $CERT_FILE"
echo ""

# Detect format and parse
if head -1 "$CERT_FILE" | grep -q "BEGIN CERTIFICATE"; then
    echo "Format: PEM"
    openssl x509 -in "$CERT_FILE" -noout -text 2>/dev/null
elif file "$CERT_FILE" | grep -q "ASN.1"; then
    echo "Format: DER (binary)"
    openssl x509 -in "$CERT_FILE" -inform DER -noout -text 2>/dev/null
else
    echo "Attempting to parse as PEM..."
    openssl x509 -in "$CERT_FILE" -noout -text 2>/dev/null || \
    openssl x509 -in "$CERT_FILE" -inform DER -noout -text 2>/dev/null || \
    echo "Could not parse certificate. Try specifying format explicitly."
fi

echo ""
echo "=== Quick Summary ==="

# Extract key fields
SUBJECT=$(openssl x509 -in "$CERT_FILE" -noout -subject 2>/dev/null | sed 's/subject=//')
ISSUER=$(openssl x509 -in "$CERT_FILE" -noout -issuer 2>/dev/null | sed 's/issuer=//')
VALID_FROM=$(openssl x509 -in "$CERT_FILE" -noout -startdate 2>/dev/null | sed 's/notBefore=//')
VALID_TO=$(openssl x509 -in "$CERT_FILE" -noout -enddate 2>/dev/null | sed 's/notAfter=//')
SIG_ALG=$(openssl x509 -in "$CERT_FILE" -noout -text 2>/dev/null | grep "Signature Algorithm" | head -1 | awk '{print $3}')

echo "Subject: $SUBJECT"
echo "Issuer: $ISSUER"
echo "Valid From: $VALID_FROM"
echo "Valid To: $VALID_TO"
echo "Signature Algorithm: $SIG_ALG"

# Check for weak algorithms
if echo "$SIG_ALG" | grep -qi "md5\|sha1"; then
    echo ""
    echo "⚠️  WARNING: Weak signature algorithm detected!"
    echo "   MD5 and SHA1 are deprecated and should not be used."
fi

# Check if expired
if openssl x509 -in "$CERT_FILE" -noout -checkend 0 2>/dev/null; then
    echo ""
    echo "✓ Certificate is currently valid"
else
    echo ""
    echo "⚠️  WARNING: Certificate has expired or is not yet valid!"
fi
