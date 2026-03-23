#!/bin/bash
# Check all TCC permissions for a specific app
# Usage: ./check-app-permissions.sh <bundle_id_or_name>

set -e

APP_NAME="${1:-}"

if [[ -z "$APP_NAME" ]]; then
  echo "Usage: $0 <bundle_id_or_name>"
  echo "Example: $0 telegram"
  echo "Example: $0 com.apple.Finder"
  exit 1
fi

echo "========================================"
echo "TCC Permissions for: $APP_NAME"
echo "========================================"
echo ""

# Check user database
echo "[USER DATABASE]"
echo "Path: ~/Library/Application Support/com.apple.TCC/TCC.db"
echo "----------------------------------------"

USER_DB="$HOME/Library/Application Support/com.apple.TCC/TCC.db"
if [[ -f "$USER_DB" ]]; then
  echo "All permissions:"
  sqlite3 -header -column "$USER_DB" \
    "SELECT service, client, auth_value as status FROM access WHERE client LIKE '%$APP_NAME%' ORDER BY service;"
  
  echo ""
  echo "Approved (auth_value=2):"
  sqlite3 -header -column "$USER_DB" \
    "SELECT service, client FROM access WHERE client LIKE '%$APP_NAME%' AND auth_value=2;"
  
  echo ""
  echo "Denied (auth_value=0):"
  sqlite3 -header -column "$USER_DB" \
    "SELECT service, client FROM access WHERE client LIKE '%$APP_NAME%' AND auth_value=0;"
else
  echo "User TCC database not found"
fi

echo ""
echo "[SYSTEM DATABASE]"
echo "Path: /Library/Application Support/com.apple.TCC/TCC.db"
echo "----------------------------------------"

SYSTEM_DB="/Library/Application Support/com.apple.TCC/TCC.db"
if [[ -f "$SYSTEM_DB" ]]; then
  echo "All permissions:"
  sudo sqlite3 -header -column "$SYSTEM_DB" \
    "SELECT service, client, auth_value as status FROM access WHERE client LIKE '%$APP_NAME%' ORDER BY service;" 2>/dev/null || echo "(requires sudo)"
else
  echo "System TCC database not found"
fi

echo ""
echo "========================================"
echo "Privilege Escalation Analysis"
echo "========================================"

# Check for high-value permissions
HIGH_VALUE_SERVICES=(
  "kTCCServiceSystemPolicyAllFiles"
  "kTCCServiceEndpointSecurityClient"
  "kTCCServiceAppleEvents"
  "kTCCServiceAccessibility"
  "kTCCServicePostEvent"
  "kTCCServiceSystemPolicySysAdminFiles"
)

echo ""
echo "Checking for high-value permissions..."

for service in "${HIGH_VALUE_SERVICES[@]}"; do
  if sqlite3 "$USER_DB" "SELECT 1 FROM access WHERE client LIKE '%$APP_NAME%' AND service='$service' AND auth_value=2;" 2>/dev/null | grep -q 1; then
    echo "⚠️  FOUND: $service (HIGH VALUE)"
  fi
done

echo ""
echo "Done."
