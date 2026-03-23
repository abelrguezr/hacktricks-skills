#!/bin/bash
# macOS TCC Status Checker
# Usage: ./check-tcc-status.sh [service]
# Services: All, AddressBook, Calendar, Photos, Reminders, Contacts, Photos, ScreenCapture, Accessibility, Automation, Camera, Microphone, FullDisk, Documents, Downloads, Reminders, Siri, HomeKit, VoiceControl, AppleEvents, SystemPolicyAllFiles, SystemPolicyNetworkVolumes, SystemPolicyFullDiskAccess, SystemPolicyDesktopFolder, SystemPolicyDocumentsFolder, SystemPolicyDownloadsFolder, SystemPolicyReminders, SystemPolicySiri, SystemPolicyHomeKit, SystemPolicyVoiceControl, SystemPolicyAppleEvents, SystemPolicyNetworkVolumes, SystemPolicySystemPolicySysAdminFiles

SERVICE="${1:-All}"

echo "=== TCC Database Status ==="
echo ""

# Check if TCC database exists
TCC_DB="$HOME/Library/Application Support/com.apple.TCC/TCC.db"
if [ -f "$TCC_DB" ]; then
    echo "✓ TCC database found: $TCC_DB"
    echo "  Size: $(du -h "$TCC_DB" | cut -f1)"
    echo "  Modified: $(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$TCC_DB")"
else
    echo "✗ TCC database not found"
    echo "  Path: $TCC_DB"
fi

echo ""
echo "=== TCC Access Records ==="
if [ -f "$TCC_DB" ]; then
    # Query TCC database
    sqlite3 "$TCC_DB" "SELECT service, client, allowed, prompted, last_used FROM access WHERE service LIKE '%${SERVICE}%' OR '${SERVICE}' = 'All';" 2>/dev/null || echo "  Unable to query database (may require elevated permissions)"
else
    echo "  Database not available"
fi

echo ""
echo "=== TCC Daemon Status ==="
launchctl list | grep -E "tccd|com.apple.tccd" || echo "  tccd not found in launchctl list"

echo ""
echo "=== Environment Variables ==="
echo "  HOME: $HOME"
launchctl printenv | grep -E "^HOME|^SQLITE|^MTL_" || echo "  No relevant TCC-related env vars found"

echo ""
echo "=== Full Disk Access Apps ==="
if [ -f "$TCC_DB" ]; then
    sqlite3 "$TCC_DB" "SELECT DISTINCT client FROM access WHERE service = 'kTCCServiceSystemPolicyAllFiles' AND allowed = 1;" 2>/dev/null || echo "  Unable to query"
fi

echo ""
echo "=== Notes ==="
echo "  - Some queries may require elevated permissions"
echo "  - TCC database is protected and may not be directly readable"
echo "  - Use tccutil for official TCC management"
