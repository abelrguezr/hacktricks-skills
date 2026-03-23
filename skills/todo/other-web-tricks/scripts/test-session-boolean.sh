#!/bin/bash
# Test Session Boolean Manipulation
# Usage: ./test-session-boolean.sh <target-url> <verification-endpoint> <protected-endpoint>

if [ $# -lt 3 ]; then
    echo "Usage: $0 <target-url> <verification-endpoint> <protected-endpoint>"
    echo "Example: $0 https://example.com /verify-email /admin-panel"
    exit 1
fi

BASE_URL="$1"
VERIFY_ENDPOINT="$2"
PROTECTED_ENDPOINT="$3"

echo "Testing Session Boolean Manipulation..."
echo "Base URL: $BASE_URL"
echo "Verification Endpoint: $VERIFY_ENDPOINT"
echo "Protected Endpoint: $PROTECTED_ENDPOINT"
echo ""

# Step 1: Complete verification
echo "Step 1: Completing verification..."
curl -c cookies.txt -b cookies.txt "$BASE_URL$VERIFY_ENDPOINT" -o /dev/null -s
if [ $? -eq 0 ]; then
    echo "[+] Verification completed"
else
    echo "[-] Verification failed or endpoint not accessible"
fi

# Step 2: Try accessing protected resource
echo ""
echo "Step 2: Attempting to access protected resource..."
curl -c cookies.txt -b cookies.txt -s "$BASE_URL$PROTECTED_ENDPOINT" -o protected-response.html

# Check response
echo "Response status:"
curl -c cookies.txt -b cookies.txt -s -o /dev/null -w "%{http_code}" "$BASE_URL$PROTECTED_ENDPOINT"
echo ""

# Check for success indicators
echo ""
echo "Checking response for access indicators..."
if grep -qi "admin\|dashboard\|welcome" protected-response.html; then
    echo "[!] Possible unauthorized access detected"
    echo "[!] Review protected-response.html for sensitive content"
else
    echo "[+] No obvious unauthorized access detected"
fi

echo ""
echo "Response saved to: protected-response.html"
echo "Cookies saved to: cookies.txt"
