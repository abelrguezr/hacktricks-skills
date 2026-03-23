#!/bin/bash
# SCCM Policy Blob Decoder
# Usage: ./decode-policy-blob.sh <hex-blob>
# Removes UTF-16 LE BOM and converts hex to XML

if [ -z "$1" ]; then
    echo "Usage: $0 <hex-blob>"
    echo "Example: $0 fffe3c003f0078..."
    exit 1
fi

HEX_BLOB="$1"

# Remove the first 4 characters (FF FE = UTF-16 LE BOM)
CLEAN_HEX="${HEX_BLOB:4}"

# Convert hex to binary and save to policy.xml
echo "$CLEAN_HEX" | xxd -r -p > policy.xml

echo "Decoded policy saved to policy.xml"
echo ""
echo "To decrypt with PXEthief:"
echo "  python3 pxethief.py 7 \$(xmlstarlet sel -t -v '//value/text()' policy.xml)"
