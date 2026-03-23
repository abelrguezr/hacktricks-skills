#!/bin/bash
# Hash length extension attack helper
# Usage: length-extension.sh <hash> <original_message> <appended_data> [secret_length]

if [ $# -lt 3 ]; then
    echo "Usage: length-extension.sh <hash> <original_message> <appended_data> [secret_length]"
    echo ""
    echo "Example:"
    echo "  length-extension.sh 5d41402abc4b2a76b9719d911017c592 'admin=true' '&delete=all' 16"
    echo ""
    echo "Parameters:"
    echo "  hash           - Original signature (hex)"
    echo "  original_msg   - Original message that was signed"
    echo "  appended_data  - Data to append to the message"
    echo "  secret_length  - Length of secret key (optional, try 1-64 if unknown)"
    exit 1
fi

HASH="$1"
ORIGINAL_MSG="$2"
APPENDED_DATA="$3"
SECRET_LEN="${4:-16}"

echo "=== Hash Length Extension Attack ==="
echo ""
echo "Original signature: $HASH"
echo "Original message: $ORIGINAL_MSG"
echo "Appended data: $APPENDED_DATA"
echo "Secret length: $SECRET_LEN bytes"
echo ""

# Detect hash type from length
HASH_LEN=${#HASH}

case $HASH_LEN in
    32)
        HASH_TYPE="md5"
        echo "✓ Detected: MD5 (32 hex chars)"
        ;;
    40)
        HASH_TYPE="sha1"
        echo "✓ Detected: SHA-1 (40 hex chars)"
        ;;
    64)
        HASH_TYPE="sha256"
        echo "✓ Detected: SHA-256 (64 hex chars)"
        ;;
    128)
        HASH_TYPE="sha512"
        echo "✓ Detected: SHA-512 (128 hex chars)"
        ;;
    *)
        echo "✗ Unknown hash type (length: $HASH_LEN)"
        echo "  Supported: MD5 (32), SHA-1 (40), SHA-256 (64), SHA-512 (128)"
        exit 1
        ;;
esac

echo ""
echo "=== Using hash_extender ==="
echo ""

# Check if hash_extender is installed
if ! command -v hash_extender &> /dev/null; then
    echo "Installing hash_extender..."
    pip install hash_extender 2>/dev/null || pip3 install hash_extender 2>/dev/null
fi

echo "Command to run:"
echo "hash_extender -h $HASH_TYPE -s $HASH -m \"$ORIGINAL_MSG\" -p \"$APPENDED_DATA\" -l $SECRET_LEN"
echo ""

# Run the attack
if command -v hash_extender &> /dev/null; then
    echo "=== Running attack ==="
    hash_extender -h "$HASH_TYPE" -s "$HASH" -m "$ORIGINAL_MSG" -p "$APPENDED_DATA" -l "$SECRET_LEN"
else
    echo "✗ hash_extender not found"
    echo "Install with: pip install hash_extender"
    echo ""
    echo "Manual command (run after installing):"
    echo "hash_extender -h $HASH_TYPE -s $HASH -m \"$ORIGINAL_MSG\" -p \"$APPENDED_DATA\" -l $SECRET_LEN"
fi

echo ""
echo "=== Alternative: hashpump ==="
echo ""

if command -v hashpump &> /dev/null; then
    echo "Command:"
    echo "hashpump -h $HASH_TYPE -s $HASH -m \"$ORIGINAL_MSG\" -a \"$APPENDED_DATA\" -l $SECRET_LEN"
else
    echo "Install with: npm install -g hashpump"
    echo ""
    echo "Command (after installing):"
    echo "hashpump -h $HASH_TYPE -s $HASH -m \"$ORIGINAL_MSG\" -a \"$APPENDED_DATA\" -l $SECRET_LEN"
fi

echo ""
echo "=== Important Notes ==="
echo "1. This only works on HASH(secret || message), NOT HMAC"
echo "2. If the attack fails, try different secret lengths (1-64)"
echo "3. The output includes the new message AND new signature"
echo "4. Test the forged signature against the target"
