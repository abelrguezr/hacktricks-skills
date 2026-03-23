#!/bin/bash
# macOS Firewall Audit: Test QUIC/ECH Capability
# Checks if QUIC and Encrypted Client Hello are available for bypass testing

set -e

echo "=== macOS QUIC/ECH Capability Test ==="
echo "Timestamp: $(date)"
echo ""

# Check curl version and QUIC support
echo "Checking curl QUIC support:"
if command -v curl &> /dev/null; then
    curl_version=$(curl --version | head -1)
    echo "Curl version: $curl_version"
    
    if curl --version | grep -q "HTTP3"; then
        echo "✓ Curl has HTTP3/QUIC support"
    else
        echo "✗ Curl does not have HTTP3/QUIC support (need curl 8.10+ with quiche)"
    fi
else
    echo "✗ Curl not installed"
fi

echo ""

# Check Chrome QUIC support
echo "Checking Chrome QUIC support:"
if [ -f "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]; then
    echo "✓ Chrome is installed"
    echo "  Chrome supports --enable-quic and --enable-features=EncryptedClientHello"
else
    echo "✗ Chrome not found"
fi

echo ""

# Check Edge QUIC support
echo "Checking Edge QUIC support:"
if [ -f "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" ]; then
    echo "✓ Edge is installed"
    echo "  Edge supports --enable-quic and --enable-features=EncryptedClientHello"
else
    echo "✗ Edge not found"
fi

echo ""

# Test QUIC connectivity (if curl supports it)
echo "Testing QUIC connectivity to cloudflare.com:"
if curl --version | grep -q "HTTP3"; then
    echo "Attempting HTTP3 connection..."
    if curl --http3-only -s -o /dev/null -w "%{http_code}" https://cloudflare.com 2>/dev/null; then
        echo "✓ HTTP3 connection successful"
    else
        echo "✗ HTTP3 connection failed (may be blocked or not supported by server)"
    fi
else
    echo "Skipping HTTP3 test (curl doesn't support it)"
fi

echo ""
echo "=== Test Commands ==="
echo "To test QUIC bypass with Chrome:"
echo '  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \\'
echo '    --enable-quic \\'
echo '    --origin-to-force-quic-on=test-domain.com:443 \\'
echo '    --enable-features=EncryptedClientHello \\'
echo '    --user-data-dir=/tmp/h3test \\'
echo '    https://test-domain.com'
echo ""
echo "To test with curl:"
echo "  curl --http3-only https://test-domain.com"
