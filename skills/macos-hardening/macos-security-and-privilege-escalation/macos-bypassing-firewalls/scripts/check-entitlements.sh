#!/bin/bash
# macOS Firewall Audit: Check Network Entitlements
# Finds binaries with outgoing network entitlements that could be abused

set -e

echo "=== macOS Network Entitlements Audit ==="
echo "Timestamp: $(date)"
echo ""

# Function to check entitlements for a binary
check_binary() {
    local binary="$1"
    if [ -f "$binary" ]; then
        echo "=== $binary ==="
        codesign -d --entitlements :- "$binary" 2>/dev/null | \
            plutil -extract com.apple.security.network.client xml1 -o - - 2>/dev/null || \
            echo "No network.client entitlement found"
        echo ""
    fi
}

# Check common system binaries
echo "Checking common system binaries:"
check_binary "/System/Applications/App Store.app/Contents/MacOS/App Store"
check_binary "/System/Library/CoreServices/Menu Extras/User.menu/Contents/MacOS/User"
check_binary "/System/Library/CoreServices/Menu Extras/TimeMachine.menu/Contents/MacOS/TimeMachine"
check_binary "/System/Library/CoreServices/Menu Extras/Battery.menu/Contents/MacOS/Battery"

# Check browsers
echo "Checking browsers:"
check_binary "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
check_binary "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"
check_binary "/Applications/Firefox.app/Contents/MacOS/firefox"
check_binary "/Applications/Safari.app/Contents/MacOS/Safari"

# Check mdnsreponder (DNS)
echo "Checking mdnsreponder:"
check_binary "/usr/sbin/mDNSResponder"

# Check nsurlsessiond
echo "Checking nsurlsessiond:"
check_binary "/System/Library/PrivateFrameworks/NSUrlSession.framework/Versions/A/Support/nsurlsessiond"

echo ""
echo "Tip: Use this script on any binary to check its network entitlements:"
echo "  codesign -d --entitlements :- /path/to/binary 2>/dev/null | plutil -extract com.apple.security.network.client xml1 -o - -"
