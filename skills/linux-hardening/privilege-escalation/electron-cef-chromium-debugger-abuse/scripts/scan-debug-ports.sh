#!/bin/bash
# Scan for common debugging ports
# Usage: ./scan-debug-ports.sh

PORTS=(9229 9222 4444 9220 9221 9223 9224 9225)

echo "Scanning for debugging ports..."
echo ""

found_any=false

for port in "${PORTS[@]}"; do
    if command -v netstat &> /dev/null; then
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            echo "[!] Port $port is open"
            netstat -tlnp | grep ":$port "
            found_any=true
        fi
    elif command -v ss &> /dev/null; then
        if ss -tlnp 2>/dev/null | grep -q ":$port "; then
            echo "[!] Port $port is open"
            ss -tlnp | grep ":$port "
            found_any=true
        fi
    fi
done

if [ "$found_any" = false ]; then
    echo "No debugging ports found."
fi

echo ""
echo "Done."
