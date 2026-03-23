#!/bin/bash
# macOS Firewall Audit: Check Allowed Traffic
# Lists all established TCP connections to identify allowed applications

set -e

echo "=== macOS Allowed Traffic Audit ==="
echo "Timestamp: $(date)"
echo ""

echo "Established TCP connections:"
lsof -i TCP -sTCP:ESTABLISHED -n -P 2>/dev/null | head -50

echo ""
echo "All network connections (first 50):"
lsof -i -n -P 2>/dev/null | head -50

echo ""
echo "DNS queries in progress:"
lsof -i -n -P 2>/dev/null | grep -i "53/udp" | head -20

echo ""
echo "Tip: Use 'sudo lsof -i' for complete visibility including privileged processes"
