#!/bin/bash
# PXEthief Decryptor Wrapper
# Usage: ./pxethief-decrypt.sh <encrypted-hex-value>
# Decrypts SCCM policy attribute values

if [ -z "$1" ]; then
    echo "Usage: $0 <encrypted-hex-value>"
    echo "Example: $0 1a2b3c4d5e6f..."
    exit 1
fi

ENCRYPTED_VALUE="$1"

echo "Decrypting SCCM policy value..."
echo ""

# Run PXEthief with mode 7 (decrypt attribute value)
python3 pxethief.py 7 "$ENCRYPTED_VALUE"
