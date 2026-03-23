#!/bin/bash
# RDP Check - Verify RDP Connectivity
# Usage: ./rdp-check.sh <target-ip> [port]

TARGET=${1:-"localhost"}
PORT=${2:-3389}

echo "Checking RDP connectivity to $TARGET:$PORT..."
echo ""

# Check if nmap is available
if command -v nmap &> /dev/null; then
    echo "[+] Port scan (nmap):"
    nmap -p $PORT -sT $TARGET 2>/dev/null | grep -E "($PORT|open|closed)"
else
    echo "[-] nmap not available, using netcat..."
fi

# Check with netcat
if command -v nc &> /dev/null; then
    echo ""
    echo "[+] Connection test (netcat):"
    if nc -zv $TARGET $PORT 2>&1; then
        echo "[✓] Port $PORT is open on $TARGET"
    else
        echo "[✗] Port $PORT is closed or filtered on $TARGET"
    fi
fi

# Check with telnet (fallback)
if command -v telnet &> /dev/null; then
    echo ""
    echo "[+] Telnet test:"
    echo "quit" | telnet $TARGET $PORT 2>&1 | head -5
fi

echo ""
echo "Security Note: Only test systems you own or have authorization to scan."
