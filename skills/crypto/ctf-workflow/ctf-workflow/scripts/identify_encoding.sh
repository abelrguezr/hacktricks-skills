#!/bin/bash
# Identify potential encodings in input
# Usage: ./identify_encoding.sh <string> or echo "string" | ./identify_encoding.sh

if [ $# -eq 0 ]; then
    # Read from stdin
    INPUT=$(cat)
else
    INPUT="$1"
fi

echo "=== Encoding Analysis ==="
echo "Input: $INPUT"
echo "Length: ${#INPUT}"
echo ""

# Check for Base64
if echo "$INPUT" | grep -qE '^[A-Za-z0-9+/=]+$'; then
    echo "✓ Matches Base64 pattern"
    echo "  Decoded: $(echo "$INPUT" | base64 -d 2>/dev/null || echo "[invalid base64]")"
else
    echo "✗ Does not match Base64 pattern"
fi
echo ""

# Check for Base32
if echo "$INPUT" | grep -qE '^[A-Z2-7=]+$'; then
    echo "✓ Matches Base32 pattern"
    echo "  Decoded: $(echo "$INPUT" | base32 -d 2>/dev/null || echo "[invalid base32]")"
else
    echo "✗ Does not match Base32 pattern"
fi
echo ""

# Check for hex
if echo "$INPUT" | grep -qE '^[0-9a-fA-F]+$'; then
    echo "✓ Matches hex pattern"
    echo "  Decoded: $(echo "$INPUT" | xxd -r -p 2>/dev/null || echo "[invalid hex]")"
else
    echo "✗ Does not match hex pattern"
fi
echo ""

# Check for URL encoding
if echo "$INPUT" | grep -qE '%[0-9a-fA-F]{2}'; then
    echo "✓ Contains URL encoding"
    echo "  Decoded: $(python3 -c "import urllib.parse; print(urllib.parse.unquote('$INPUT'))" 2>/dev/null || echo "[error]")"
else
    echo "✗ No URL encoding detected"
fi
echo ""

# Check for common hash lengths
LEN=${#INPUT}
if [ $LEN -eq 32 ]; then
    echo "⚠ Length 32: Could be MD5 (hex)"
elif [ $LEN -eq 40 ]; then
    echo "⚠ Length 40: Could be SHA1 (hex)"
elif [ $LEN -eq 64 ]; then
    echo "⚠ Length 64: Could be SHA256 (hex)"
elif [ $LEN -eq 128 ]; then
    echo "⚠ Length 128: Could be SHA512 (hex)"
fi
