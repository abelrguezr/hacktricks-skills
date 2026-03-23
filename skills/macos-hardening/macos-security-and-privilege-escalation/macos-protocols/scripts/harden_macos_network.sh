#!/bin/bash
# macOS Network Security Hardening Script
# WARNING: Review each step before running. Some commands require sudo.

echo "========================================"
echo "macOS Network Security Hardening"
echo "========================================"
echo ""
echo "This script provides hardening recommendations."
echo "Commands are shown but NOT executed automatically."
echo "Review and run manually as needed."
echo ""

# Function to show command without executing
show_command() {
    echo "[COMMAND] $1"
    echo "[RUN]     $2"
    echo ""
}

echo "========================================"
echo "1. DISABLE UNNECESSARY SERVICES"
echo "========================================"
echo ""

show_command \
    "Disable Screen Sharing / ARD" \
    "sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -deactivate"

show_command \
    "Disable Remote Login (SSH)" \
    "sudo launchctl unload -w /System/Library/LaunchDaemons/ssh.plist"

show_command \
    "Disable Bonjour (if not needed)" \
    "sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.mDNSResponder.plist"

echo "========================================"
echo "2. FIREWALL CONFIGURATION"
echo "========================================"
echo ""

show_command \
    "Add ARDAgent to Application Firewall" \
    "sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/MacOS/ARDAgent"

show_command \
    "Block ARDAgent by default" \
    "sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setblockapp /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/MacOS/ARDAgent on"

show_command \
    "Enable Application Firewall" \
    "sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on"

echo "========================================"
echo "3. VERIFY HARDENING"
echo "========================================"
echo ""

show_command \
    "Check firewall status" \
    "/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate"

show_command \
    "Check listening ports" \
    "sudo netstat -na | grep LISTEN"

show_command \
    "Check SIP status" \
    "csrutil status"

echo "========================================"
echo "4. PATCH VERIFICATION"
echo "========================================"
echo ""

show_command \
    "Check macOS version" \
    "sw_vers"

show_command \
    "Check for updates" \
    "softwareupdate -l"

echo "========================================"
echo "SECURITY NOTES"
echo "========================================"
echo ""
echo "Critical CVEs to patch:"
echo "  - CVE-2023-42940 (Screen Sharing leak) - Fixed in Sonoma 14.2.1"
echo "  - CVE-2024-23296 (Kernel bypass) - Fixed in Ventura 13.6.4 / Sonoma 14.4"
echo "  - CVE-2024-44183 (mDNS DoS) - Fixed in Ventura 13.7 / Sonoma 14.7 / Sequoia 15.0"
echo "  - CVE-2025-31222 (mDNS privilege escalation) - Fixed in Ventura 13.7.6 / Sonoma 14.7.6 / Sequoia 15.5"
echo ""
echo "Additional recommendations:"
echo "  - Enable System Integrity Protection (SIP)"
echo "  - Use strong passwords (8+ chars for VNC/ARD)"
echo "  - Put remote services behind VPN"
echo "  - Restrict UDP 5353 to link-local scope"
echo "  - Use MDM for enterprise deployments"
echo "========================================"
