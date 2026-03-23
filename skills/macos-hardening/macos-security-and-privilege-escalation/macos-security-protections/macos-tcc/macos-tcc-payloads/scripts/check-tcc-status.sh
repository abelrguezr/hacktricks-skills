#!/bin/bash
# Check TCC (Transparency, Consent, and Control) status for various services
# macOS security testing utility

TCC_DB="/Library/Application Support/com.apple.TCC/TCC.db"

if [ ! -f "$TCC_DB" ]; then
    echo "TCC database not found at $TCC_DB"
    echo "Note: This file may require elevated privileges to read"
    exit 1
fi

echo "=== TCC Permission Status ==="
echo ""

# Query TCC database for various services
SERVICES=(
    "kTCCServiceCamera"
    "kTCCServiceMicrophone"
    "kTCCServiceScreenCapture"
    "kTCCServiceAccessibility"
    "kTCCServiceAddressBook"
    "kTCCServiceCalendar"
    "kTCCServicePhotos"
    "kTCCServiceSystemPolicyDesktopFolder"
    "kTCCServiceSystemPolicyDocumentsFolder"
    "kTCCServiceSystemPolicyDownloadsFolder"
)

for service in "${SERVICES[@]}"; do
    echo "Service: $service"
    sqlite3 "$TCC_DB" "SELECT client, allowed, promptCount FROM access WHERE service='$service';" 2>/dev/null || echo "  (query failed)"
    echo ""
done

echo "=== Location Services ==="
if [ -f "/var/db/locationd/clients.plist" ]; then
    plutil -p "/var/db/locationd/clients.plist" 2>/dev/null | head -50 || echo "(requires elevated privileges)"
else
    echo "Location database not accessible"
fi
