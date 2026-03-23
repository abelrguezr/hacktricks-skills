#!/bin/bash
# Test HTTP TRACE Method
# Usage: ./test-trace-method.sh <target-url>

if [ $# -lt 1 ]; then
    echo "Usage: $0 <target-url>"
    echo "Example: $0 https://example.com/"
    exit 1
fi

TARGET_URL="$1"

echo "Testing HTTP TRACE Method..."
echo "Target: $TARGET_URL"
echo ""

# Send TRACE request
echo "Sending TRACE request..."
curl -v -X TRACE "$TARGET_URL" 2>&1 | tee trace-test.log

echo ""
echo "Analyzing response for sensitive headers..."

# Check if TRACE is enabled
if grep -q "200 OK" trace-test.log; then
    echo "[!] TRACE method appears to be ENABLED"
    echo "[!] Check response for internal headers like:"
    echo "    - X-Internal-Auth"
    echo "    - X-Forwarded-User"
    echo "    - X-Auth-Token"
    grep -i "x-" trace-test.log | grep -v "x-requested-with" | grep -v "x-powered-by" || echo "No suspicious X- headers found"
else
    echo "[+] TRACE method appears to be DISABLED or blocked"
fi

echo ""
echo "Results saved to: trace-test.log"
