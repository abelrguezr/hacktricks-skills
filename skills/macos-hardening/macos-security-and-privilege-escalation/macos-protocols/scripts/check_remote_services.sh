#!/bin/bash
# macOS Remote Services Status Checker
# Checks which remote access services are enabled on the system

echo "========================================"
echo "macOS Remote Services Status Check"
echo "========================================"
echo ""

# Check each service
rmMgmt=$(netstat -na 2>/dev/null | grep LISTEN | grep tcp46 | grep "*.3283" | wc -l)
scrShrng=$(netstat -na 2>/dev/null | grep LISTEN | egrep 'tcp4|tcp6' | grep "*.5900" | wc -l)
flShrng=$(netstat -na 2>/dev/null | grep LISTEN | egrep 'tcp4|tcp6' | egrep "\\*.88|\\*.445|\\*.548" | wc -l)
rLgn=$(netstat -na 2>/dev/null | grep LISTEN | egrep 'tcp4|tcp6' | grep "*.22" | wc -l)
rAE=$(netstat -na 2>/dev/null | grep LISTEN | egrep 'tcp4|tcp6' | grep "*.3031" | wc -l)
bmM=$(netstat -na 2>/dev/null | grep LISTEN | egrep 'tcp4|tcp6' | grep "*.4488" | wc -l)

echo "Service Status (0=OFF, >0=ON):"
echo "----------------------------------------"
printf "%-25s %s\n" "Screen Sharing (VNC):" "$scrShrng"
printf "%-25s %s\n" "File Sharing:" "$flShrng"
printf "%-25s %s\n" "Remote Login (SSH):" "$rLgn"
printf "%-25s %s\n" "Remote Management (ARD):" "$rmMgmt"
printf "%-25s %s\n" "Remote Apple Events:" "$rAE"
printf "%-25s %s\n" "Back to My Mac:" "$bmM"
echo ""

# Check Bonjour
mdns_status=$(pgrep -x mDNSResponder > /dev/null && echo "ON" || echo "OFF")
echo "Service Discovery:"
echo "----------------------------------------"
printf "%-25s %s\n" "Bonjour/mDNS:" "$mdns_status"
echo ""

# Check macOS version
os_version=$(sw_vers -productVersion 2>/dev/null)
echo "System Information:"
echo "----------------------------------------"
printf "%-25s %s\n" "macOS Version:" "$os_version"
echo ""

echo "========================================"
echo "Security Notes:"
echo "========================================"
echo "- ARD uses only first 8 chars of VNC password"
echo "- Keep macOS patched for CVE-2023-42940, CVE-2024-23296"
echo "- CVE-2024-44183 and CVE-2025-31222 affect mDNSResponder"
echo "- Enable SIP for full vulnerability protection"
echo "========================================"
