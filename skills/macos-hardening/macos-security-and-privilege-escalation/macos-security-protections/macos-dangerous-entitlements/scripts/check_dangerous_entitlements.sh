#!/bin/bash
# Quick check for dangerous entitlements in a binary
# Returns exit code 1 if dangerous entitlements found, 0 otherwise

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <path-to-binary>"
    exit 1
fi

BINARY_PATH="$1"

# Extract entitlements
ENTITLEMENTS=$(codesign -d --entitlements :- "$BINARY_PATH" 2>/dev/null || echo "")

if [ -z "$ENTITLEMENTS" ]; then
    echo "No entitlements found or binary not code-signed"
    exit 0
fi

# List of dangerous entitlements to check
DANGEROUS_ENTITLEMENTS=(
    "com.apple.rootless.install.heritable"
    "com.apple.rootless.install"
    "com.apple.system-task-ports"
    "com.apple.security.get-task-allow"
    "com.apple.security.cs.debugger"
    "com.apple.security.cs.disable-library-validation"
    "com.apple.private.security.clear-library-validation"
    "com.apple.security.cs.allow-dyld-environment-variables"
    "com.apple.private.tcc.manager"
    "com.apple.rootless.storage.TCC"
    "system.install.apple-software"
    "system.install.apple-software.standard-user"
    "com.apple.private.security.kext-management"
    "com.apple.private.icloud-account-access"
    "kTCCServiceSystemPolicyAllFiles"
    "kTCCServiceAppleEvents"
    "kTCCServiceEndpointSecurityClient"
    "kTCCServiceSystemPolicySysAdminFiles"
    "kTCCServiceSystemPolicyAppBundles"
    "kTCCServiceAccessibility"
)

FOUND=0
for entitlement in "${DANGEROUS_ENTITLEMENTS[@]}"; do
    if echo "$ENTITLEMENTS" | grep -qF "$entitlement"; then
        echo "DANGEROUS: $entitlement"
        FOUND=1
    fi
done

if [ $FOUND -eq 1 ]; then
    exit 1
else
    echo "No dangerous entitlements found"
    exit 0
fi
