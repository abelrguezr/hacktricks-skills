#!/bin/bash
# Quick security checklist for XPC implementations
# Scans Objective-C/Swift files for common XPC security issues

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <directory-to-scan>"
    echo "Example: $0 ./src"
    exit 1
fi

SCAN_DIR="$1"
ISSUES_FOUND=0

echo "Scanning for XPC security issues in: $SCAN_DIR"
echo "=========================================="

# Check 1: Missing shouldAcceptNewConnection implementation
echo -e "\n[1] Checking for XPC listeners without verification..."
if grep -r "NSXPCListener" "$SCAN_DIR" --include="*.m" --include="*.mm" --include="*.swift" 2>/dev/null | grep -v "shouldAcceptNewConnection" > /dev/null; then
    echo "⚠️  WARNING: Found NSXPCListener usage. Verify shouldAcceptNewConnection is implemented."
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# Check 2: Using processIdentifier instead of audit token
echo -e "\n[2] Checking for PID-based verification (vulnerable)..."
if grep -r "processIdentifier" "$SCAN_DIR" --include="*.m" --include="*.mm" --include="*.swift" 2>/dev/null | grep -i "xpc\|connection" > /dev/null; then
    echo "⚠️  CRITICAL: Found processIdentifier usage with XPC. This is vulnerable to PID reuse attacks!"
    echo "           Use audit tokens instead."
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# Check 3: Using xpc_connection_get_audit_token (potentially vulnerable)
echo -e "\n[3] Checking for vulnerable audit token API..."
if grep -r "xpc_connection_get_audit_token" "$SCAN_DIR" --include="*.m" --include="*.mm" 2>/dev/null > /dev/null; then
    echo "⚠️  WARNING: Found xpc_connection_get_audit_token. Consider using xpc_dictionary_get_audit_token."
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# Check 4: Always returning YES in shouldAcceptNewConnection
echo -e "\n[4] Checking for always-accept implementations..."
if grep -A5 "shouldAcceptNewConnection" "$SCAN_DIR" --include="*.m" --include="*.mm" --include="*.swift" 2>/dev/null | grep -E "return\s+YES|return\s+true" > /dev/null; then
    echo "⚠️  CRITICAL: Found shouldAcceptNewConnection returning YES without verification!"
    echo "           This accepts ALL connections without security checks."
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# Check 5: Missing SecRequirement usage
echo -e "\n[5] Checking for certificate verification..."
if grep -r "shouldAcceptNewConnection" "$SCAN_DIR" --include="*.m" --include="*.mm" --include="*.swift" 2>/dev/null > /dev/null; then
    if ! grep -r "SecRequirement\|SecTaskValidate" "$SCAN_DIR" --include="*.m" --include="*.mm" 2>/dev/null > /dev/null; then
        echo "⚠️  WARNING: XPC listener found but no SecRequirement/SecTaskValidate usage detected."
        echo "           Consider implementing certificate verification."
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
fi

# Check 6: Missing hardened runtime checks
echo -e "\n[6] Checking for hardened runtime verification..."
if grep -r "shouldAcceptNewConnection" "$SCAN_DIR" --include="*.m" --include="*.mm" --include="*.swift" 2>/dev/null > /dev/null; then
    if ! grep -r "csFlags\|kSecCodeInfoStatus\|SecCodeCopySigningInformation" "$SCAN_DIR" --include="*.m" --include="*.mm" 2>/dev/null > /dev/null; then
        echo "⚠️  INFO: No hardened runtime checks detected. Consider adding them."
    fi
fi

echo -e "\n=========================================="
if [ $ISSUES_FOUND -eq 0 ]; then
    echo "✓ No obvious security issues found."
    echo "  Note: This is a basic scan. Manual review is still recommended."
else
    echo "⚠️  Found $ISSUES_FOUND potential security issue(s)."
    echo "  Review the warnings above and implement fixes."
fi

echo -e "\nSecurity Checklist:"
echo "  [ ] Audit tokens used instead of PIDs"
echo "  [ ] Certificate verification implemented"
echo "  [ ] Team ID verification implemented"
echo "  [ ] Bundle ID verification implemented"
echo "  [ ] Version or hardened runtime check implemented"
echo "  [ ] Deny-by-default (return NO on failure)"
