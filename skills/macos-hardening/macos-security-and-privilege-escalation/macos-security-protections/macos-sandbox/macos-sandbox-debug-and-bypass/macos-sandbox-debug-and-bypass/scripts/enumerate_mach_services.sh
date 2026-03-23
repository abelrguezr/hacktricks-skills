#!/bin/bash
# Enumerate available Mach services on macOS
# These can potentially be abused for sandbox escape

echo "=== Enumerating Mach Services ==="
echo ""

LAUNCHD_PLIST="/System/Library/xpc/launchd.plist"

if [ ! -f "$LAUNCHD_PLIST" ]; then
    echo "Error: $LAUNCHD_PLIST not found"
    exit 1
fi

echo "1. System Mach Services:"
echo "   (Services available to all processes)"
echo "   ----------------------------------------"
grep -B 2 -A 10 "<string>System</string>" "$LAUNCHD_PLIST" | grep "<key>" | head -20
echo ""

echo "2. User Mach Services:"
echo "   (Services available to user processes)"
echo "   ----------------------------------------"
grep -B 2 -A 10 "<string>User</string>" "$LAUNCHD_PLIST" | grep "<key>" | head -20
echo ""

echo "3. Application Mach Services:"
echo "   (Services visible in app's PID domain)"
echo "   ----------------------------------------"
grep -B 2 -A 10 "<string>Application</string>" "$LAUNCHD_PLIST" | grep "<key>" | head -20
echo ""

echo "4. XPC Service Files:"
echo "   ----------------------------------------"
echo "   Frameworks:"
find /System/Library/Frameworks -name "*.xpc" 2>/dev/null | head -10
echo ""
echo "   Private Frameworks:"
find /System/Library/PrivateFrameworks -name "*.xpc" 2>/dev/null | head -10
echo ""

echo "5. Known Abusable Services:"
echo "   ----------------------------------------"
echo "   - com.apple.storagekitfsrunner (StorageKit)"
echo "   - com.apple.internal.audioanalytics.helper (AudioAnalytics)"
echo "   - com.apple.WorkflowKit.ShortcutsFileAccessHelper (WorkflowKit)"
echo ""

echo "To check if a service is available to your sandboxed app:"
echo "  Use bootstrap_look_up() in Objective-C code"
echo "  See scripts/check_service.m for example"
