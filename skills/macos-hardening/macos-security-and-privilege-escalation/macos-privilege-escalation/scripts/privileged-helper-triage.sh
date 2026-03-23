#!/bin/bash
# macOS Privileged Helper Triage Script
# Identifies potential privilege escalation vectors in privileged helpers

set -e

echo "=== Privileged Helper Triage ==="
echo ""

# Check PrivilegedHelperTools directory
echo "[1] PrivilegedHelperTools contents:"
if [ -d "/Library/PrivilegedHelperTools" ]; then
    ls -la /Library/PrivilegedHelperTools/ 2>/dev/null || echo "  (directory not accessible)"
else
    echo "  /Library/PrivilegedHelperTools not found"
fi
echo ""

# Check LaunchDaemons
echo "[2] LaunchDaemons with MachServices or Program:"
if [ -d "/Library/LaunchDaemons" ]; then
    for plist in /Library/LaunchDaemons/*.plist; do
        if [ -f "$plist" ]; then
            name=$(basename "$plist")
            has_mach=$(plutil -p "$plist" 2>/dev/null | grep -E 'MachServices|Program|ProgramArguments' || true)
            if [ -n "$has_mach" ]; then
                echo "  $name:"
                plutil -p "$plist" 2>/dev/null | grep -E 'MachServices|Program|ProgramArguments|Label' | head -5
                echo ""
            fi
        fi
    done
else
    echo "  /Library/LaunchDaemons not found"
fi
echo ""

# Check codesign entitlements
echo "[3] Helper entitlements:"
if [ -d "/Library/PrivilegedHelperTools" ]; then
    for f in /Library/PrivilegedHelperTools/*; do
        if [ -f "$f" ]; then
            echo "  === $f ==="
            codesign -dvv --entitlements :- "$f" 2>&1 | grep -E 'identifier|TeamIdentifier|com.apple' || echo "    (no relevant entitlements)"
        fi
    done
fi
echo ""

# Search for XPC-related strings
echo "[4] XPC/Authorization patterns in helpers:"
if [ -d "/Library/PrivilegedHelperTools" ]; then
    for f in /Library/PrivilegedHelperTools/*; do
        if [ -f "$f" ]; then
            matches=$(strings "$f" 2>/dev/null | grep -E 'NSXPC|xpc_connection|AuthorizationCopyRights|authTrampoline|/Applications/.+\.sh' || true)
            if [ -n "$matches" ]; then
                echo "  $f:"
                echo "$matches" | head -3 | sed 's/^/    /'
            fi
        fi
    done
fi
echo ""

# Check for user-writable files
echo "[5] User-writable files in privileged locations:"
find /Library/PrivilegedHelperTools /Library/LaunchDaemons -writable 2>/dev/null | while read f; do
    echo "  $f"
done || echo "  (none found or no permission)"
echo ""

echo "=== Triage Complete ==="
echo ""
echo "Review findings for:"
echo "  - Helpers accepting requests after uninstall"
echo "  - Scripts from user-writable paths (/Applications/...)"
echo "  - PID-based or bundle-id-only peer validation"
echo "  - Root methods consuming user-controlled paths"
