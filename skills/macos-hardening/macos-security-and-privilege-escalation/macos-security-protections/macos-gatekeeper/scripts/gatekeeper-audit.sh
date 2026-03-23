#!/bin/bash
# macOS Gatekeeper Security Audit
# Usage: ./gatekeeper-audit.sh [path-to-audit]
# If no path provided, audits /Applications

AUDIT_PATH="${1:-/Applications}"

echo "========================================"
echo "macOS Gatekeeper Security Audit"
echo "Audit Path: $AUDIT_PATH"
echo "Date: $(date)"
echo "========================================"
echo ""

echo "=== 1. Gatekeeper Status ==="
spctl --status 2>&1
echo ""

echo "=== 2. macOS Version ==="
sw_vers
echo ""

echo "=== 3. XProtect Version ==="
system_profiler SPInstallHistoryDataType 2>/dev/null | grep -A 4 "XProtectPlistConfigData" | tail -n 5
echo ""

echo "=== 4. Application Audit ==="
echo "Scanning applications..."
echo ""

TOTAL_APPS=0
SIGNED_APPS=0
UNSIGNED_APPS=0
NOTARIZED_APPS=0
BLOCKED_APPS=0

if [ -d "$AUDIT_PATH" ]; then
    for app in "$AUDIT_PATH"/*.app; do
        [ -e "$app" ] || continue
        TOTAL_APPS=$((TOTAL_APPS + 1))
        
        APP_NAME=$(basename "$app")
        
        # Check signature
        if codesign --verify --verbose "$app" 2>/dev/null; then
            SIGNED_APPS=$((SIGNED_APPS + 1))
            SIGN_STATUS="✓ Signed"
        else
            UNSIGNED_APPS=$((UNSIGNED_APPS + 1))
            SIGN_STATUS="✗ Unsigned"
        fi
        
        # Check notarization
        if codesign -dv --verbose "$app" 2>&1 | grep -qi "notarized"; then
            NOTARIZED_APPS=$((NOTARIZED_APPS + 1))
            NOTAR_STATUS="✓ Notarized"
        else
            NOTAR_STATUS="✗ Not notarized"
        fi
        
        # Check Gatekeeper assessment
        GK_RESULT=$(spctl --assess -v "$app" 2>&1)
        if echo "$GK_RESULT" | grep -q "accepted"; then
            GK_STATUS="✓ Allowed"
        else
            BLOCKED_APPS=$((BLOCKED_APPS + 1))
            GK_STATUS="✗ Blocked"
        fi
        
        echo "$APP_NAME: $SIGN_STATUS | $NOTAR_STATUS | $GK_STATUS"
    done
else
    echo "Path does not exist or is not a directory: $AUDIT_PATH"
    exit 1
fi

echo ""
echo "=== 5. Audit Summary ==="
echo "Total applications: $TOTAL_APPS"
echo "Signed: $SIGNED_APPS ($(( TOTAL_APPS > 0 ? SIGNED_APPS * 100 / TOTAL_APPS : 0 ))%)"
echo "Unsigned: $UNSIGNED_APPS"
echo "Notarized: $NOTARIZED_APPS"
echo "Blocked by Gatekeeper: $BLOCKED_APPS"
echo ""

if [ $BLOCKED_APPS -gt 0 ]; then
    echo "⚠ Warning: $BLOCKED_APPS application(s) are blocked by Gatekeeper"
    echo "Review these applications for security concerns"
fi

if [ $UNSIGNED_APPS -gt 0 ]; then
    echo "⚠ Warning: $UNSIGNED_APPS application(s) are not code-signed"
    echo "Unsigned applications may be blocked or pose security risks"
fi

echo ""
echo "=== 6. Recent Gatekeeper Events ==="
log show --last 24h --predicate 'process == "syspolicyd" && eventMessage CONTAINS[cd] "GK scan"' --style syslog 2>/dev/null | head -20
echo ""

echo "=== 7. System Policy Database (if accessible) ==="
if [ -r /var/db/SystemPolicy ]; then
    echo "Authority rules count:"
    sqlite3 /var/db/SystemPolicy "SELECT COUNT(*) FROM authority;" 2>/dev/null
    echo ""
    echo "Sample allowed rules:"
    sqlite3 /var/db/SystemPolicy "SELECT label, COUNT(*) FROM authority WHERE allow=1 AND disabled=0 GROUP BY label;" 2>/dev/null
else
    echo "SystemPolicy database not accessible (requires root)"
fi
echo ""

echo "========================================"
echo "Audit Complete"
echo "========================================"
