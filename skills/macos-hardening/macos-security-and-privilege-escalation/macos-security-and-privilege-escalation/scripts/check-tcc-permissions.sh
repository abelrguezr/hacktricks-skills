#!/bin/bash
# TCC Permission Checker
# Lists all TCC database entries for privilege escalation assessment

set -e

echo "=== TCC Database Analysis ==="
echo ""

# Check if we can access the TCC database
TCC_DB="/Library/Application Support/com.apple.TCC/TCC.db"

if [ -f "$TCC_DB" ]; then
    echo "TCC Database found at: $TCC_DB"
    echo ""
    
    # List all access entries
    echo "=== All TCC Access Entries ==="
    sqlite3 "$TCC_DB" "SELECT service, client, auth_status, blocked_count FROM access ORDER BY service;" 2>/dev/null || echo "Cannot read TCC database (may require elevated privileges)"
    echo ""
    
    # Check for high-value permissions
    echo "=== High-Value Permissions ==="
    
    echo "Accessibility:"
    sqlite3 "$TCC_DB" "SELECT client, auth_status FROM access WHERE service='kTCCServiceAccessibility';" 2>/dev/null || echo "Cannot query"
    echo ""
    
    echo "Screen Recording:"
    sqlite3 "$TCC_DB" "SELECT client, auth_status FROM access WHERE service='kTCCServiceScreenCapture';" 2>/dev/null || echo "Cannot query"
    echo ""
    
    echo "Camera:"
    sqlite3 "$TCC_DB" "SELECT client, auth_status FROM access WHERE service='kTCCServiceCamera';" 2>/dev/null || echo "Cannot query"
    echo ""
    
    echo "Microphone:"
    sqlite3 "$TCC_DB" "SELECT client, auth_status FROM access WHERE service='kTCCServiceMicrophone';" 2>/dev/null || echo "Cannot query"
    echo ""
    
    echo "File System Access:"
    sqlite3 "$TCC_DB" "SELECT client, auth_status FROM access WHERE service LIKE '%File%';" 2>/dev/null || echo "Cannot query"
else
    echo "TCC Database not found at: $TCC_DB"
    echo "This is normal on some macOS versions. Try using tccutil instead:"
    echo "  tccutil list"
fi

echo ""
echo "=== tccutil Output ==="
tccutil list 2>/dev/null || echo "tccutil not available or requires elevated privileges"
