#!/bin/bash
# macOS TCC Service Enumerator
# Lists all known TCC service identifiers and their purposes

echo "=== macOS TCC Service Identifiers ==="
echo ""

cat << 'EOF'
Service Identifier                                    | Purpose
-----------------------------------------------------|--------------------------------------------------
kTCCServiceAddressBook                                | Contacts/Address Book access
kTCCServiceCalendar                                   | Calendar access
kTCCServicePhotos                                     | Photos library access
kTCCServiceReminders                                  | Reminders access
kTCCServiceScreenCapture                              | Screen recording/capture
kTCCServiceAccessibility                              | Accessibility features
kTCCServiceCamera                                     | Camera access
kTCCServiceMicrophone                                 | Microphone access
kTCCServiceSystemPolicyAllFiles                       | Full Disk Access
kTCCServiceSystemPolicyNetworkVolumes                 | Network volumes access
kTCCServiceSystemPolicyFullDiskAccess                 | Full Disk Access (alternate)
kTCCServiceSystemPolicyDesktopFolder                  | Desktop folder access
kTCCServiceSystemPolicyDocumentsFolder                | Documents folder access
kTCCServiceSystemPolicyDownloadsFolder                | Downloads folder access
kTCCServiceSystemPolicyReminders                      | Reminders (system policy)
kTCCServiceSystemPolicySiri                           | Siri access
kTCCServiceSystemPolicyHomeKit                        | HomeKit access
kTCCServiceSystemPolicyVoiceControl                   | Voice Control access
kTCCServiceSystemPolicyAppleEvents                    | Apple Events/Automation
kTCCServiceSystemPolicySysAdminFiles                  | System Admin Files
kTCCServiceAppleEvents                                | Apple Events (automation)
kTCCServiceLocation                                   | Location services
kTCCServiceBluetoothAlways                            | Bluetooth access
kTCCServiceMediaLibrary                               | Media library access
kTCCServiceSiri                                       | Siri (alternate)
kTCCServiceHomeKit                                    | HomeKit (alternate)
kTCCServiceVoiceControl                               | Voice Control (alternate)

Common TCC Database Paths:
--------------------------
$HOME/Library/Application Support/com.apple.TCC/TCC.db          | User TCC database
/var/db/locationd/clients.plist                                 | Location services database
/Library/Application Support/com.apple.TCC/TCC.db               | System TCC database (root)

TCC Management Commands:
------------------------
tccutil reset All                                              | Reset all TCC permissions
tccutil reset <Service> <BundleID>                             | Reset specific service for app
tccutil list                                                   | List all TCC permissions (macOS 10.14+)

Notes:
------
- Service names may vary by macOS version
- Some services are deprecated or renamed in newer versions
- TCC database schema may change between macOS versions
- Always test in authorized environments only
EOF

echo ""
echo "=== Current TCC Database Schema ==="
TCC_DB="$HOME/Library/Application Support/com.apple.TCC/TCC.db"
if [ -f "$TCC_DB" ]; then
    sqlite3 "$TCC_DB" ".schema" 2>/dev/null || echo "  Unable to read schema (permission denied)"
else
    echo "  TCC database not found at: $TCC_DB"
fi

echo ""
echo "=== Usage ==="
echo "  Use this information for authorized security research only"
echo "  Reference: https://developer.apple.com/documentation/security/transparency_and_consent"
