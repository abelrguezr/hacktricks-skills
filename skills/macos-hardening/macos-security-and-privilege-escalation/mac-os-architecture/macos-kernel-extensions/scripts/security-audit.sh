#!/bin/bash
# Security audit for kernel extensions and SIP configuration
# Usage: ./security-audit.sh

set -e

echo "=== macOS Kernel Security Audit ==="
echo "Date: $(date)"
echo ""

# Check SIP status
echo "=== System Integrity Protection (SIP) ==="
if csrutil status 2>/dev/null | grep -q "enabled"; then
    echo "✓ SIP is enabled"
else
    echo "✗ WARNING: SIP may be disabled"
    csrutil status 2>/dev/null || echo "Could not determine SIP status"
fi
echo ""

# Check for third-party kexts
echo "=== Third-Party Kernel Extensions ==="
THIRD_PARTY=$(sudo kmutil showloaded --collection aux 2>/dev/null | wc -l)
echo "Third-party kexts loaded: $THIRD_PARTY"

if [ "$THIRD_PARTY" -gt 0 ]; then
    echo ""
    echo "Loaded third-party kexts:"
    sudo kmutil showloaded --collection aux
fi
echo ""

# Check /Library/Extensions
echo "=== /Library/Extensions Directory ==="
if [ -d "/Library/Extensions" ]; then
    EXT_COUNT=$(ls -1 /Library/Extensions/*.kext 2>/dev/null | wc -l)
    echo "Kexts in /Library/Extensions: $EXT_COUNT"
    
    if [ "$EXT_COUNT" -gt 0 ]; then
        echo ""
        echo "Kext files:"
        ls -la /Library/Extensions/*.kext 2>/dev/null | head -10
    fi
else
    echo "Directory does not exist"
fi
echo ""

# Check entitled daemons
echo "=== Entitled Daemons (Kext Management) ==="
for daemon in /usr/sbin/kextd /usr/sbin/syspolicyd /usr/bin/kextutil; do
    if [ -f "$daemon" ]; then
        echo "Checking: $daemon"
        codesign -dvv "$daemon" 2>/dev/null | grep -i entitlements || echo "  No custom entitlements"
    fi
done
echo ""

# Check for known vulnerable patterns
echo "=== Vulnerability Checks ==="

# Check for storagekitd (CVE-2024-44243)
if [ -f "/usr/libexec/storagekitd" ]; then
    VERSION=$(sw_vers -productVersion)
    echo "storagekitd found - ensure macOS is patched (14.2+ / 15.2+)"
    echo "Current macOS version: $VERSION"
fi

# Check for rootless install entitlements
echo ""
echo "Checking for com.apple.rootless.install entitlements..."
find /System/Library/LaunchDaemons -name "*.plist" 2>/dev/null | while read plist; do
    if grep -q "com.apple.rootless.install" "$plist" 2>/dev/null; then
        echo "Found: $plist"
    fi
done
echo ""

# Recommendations
echo "=== Recommendations ==="
echo "1. Keep SIP enabled unless absolutely necessary"
echo "2. Monitor /Library/Extensions for unauthorized writes"
echo "3. Alert on kmutil load/create from non-Apple binaries"
echo "4. Use Endpoint Security: ES_EVENT_TYPE_NOTIFY_KEXTLOAD"
echo "5. Keep macOS updated to patch kernel vulnerabilities"
echo ""
echo "Audit complete."
