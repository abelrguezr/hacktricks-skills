#!/bin/bash
# macOS Entitlements Extractor and Analyzer
# Extracts entitlements from a code-signed binary and checks for dangerous ones

set -e

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <path-to-binary>"
    echo "Example: $0 /Applications/MyApp.app/Contents/MacOS/MyApp"
    exit 1
fi

BINARY_PATH="$1"
ENTITLEMENTS_FILE="/tmp/entitlements_$$_.xml"

# Check if file exists
if [ ! -f "$BINARY_PATH" ]; then
    echo -e "${RED}Error: File not found: $BINARY_PATH${NC}"
    exit 1
fi

# Check if codesign is available
if ! command -v codesign &> /dev/null; then
    echo -e "${RED}Error: codesign not found. This script requires macOS.${NC}"
    exit 1
fi

echo "=== macOS Entitlements Analyzer ==="
echo "Binary: $BINARY_PATH"
echo ""

# Extract entitlements
echo "Extracting entitlements..."
if ! codesign -d --entitlements :- "$BINARY_PATH" > "$ENTITLEMENTS_FILE" 2>/dev/null; then
    echo -e "${YELLOW}Warning: Could not extract entitlements. Binary may not be code-signed.${NC}"
    rm -f "$ENTITLEMENTS_FILE"
    exit 0
fi

# Check if entitlements file is empty or has no content
if [ ! -s "$ENTITLEMENTS_FILE" ]; then
    echo -e "${YELLOW}No entitlements found in binary.${NC}"
    rm -f "$ENTITLEMENTS_FILE"
    exit 0
fi

# Define dangerous entitlements with their severity and descriptions
declare -A HIGH_RISK_ENTITLEMENTS
HIGH_RISK_ENTITLEMENTS["com.apple.rootless.install.heritable"]="Bypass SIP (System Integrity Protection)"
HIGH_RISK_ENTITLEMENTS["com.apple.rootless.install"]="Bypass SIP (System Integrity Protection)"
HIGH_RISK_ENTITLEMENTS["com.apple.system-task-ports"]="Get task port for any process (except kernel)"
HIGH_RISK_ENTITLEMENTS["com.apple.security.get-task-allow"]="Allow code injection via debugger"
HIGH_RISK_ENTITLEMENTS["com.apple.security.cs.debugger"]="Call task_for_pid() on apps with get-task-allow"
HIGH_RISK_ENTITLEMENTS["com.apple.security.cs.disable-library-validation"]="Load unsigned frameworks/libraries"
HIGH_RISK_ENTITLEMENTS["com.apple.private.security.clear-library-validation"]="Disable library validation via csops"
HIGH_RISK_ENTITLEMENTS["com.apple.security.cs.allow-dyld-environment-variables"]="Use DYLD injection variables"
HIGH_RISK_ENTITLEMENTS["com.apple.private.tcc.manager"]="Modify TCC database"
HIGH_RISK_ENTITLEMENTS["com.apple.rootless.storage.TCC"]="Modify TCC database"
HIGH_RISK_ENTITLEMENTS["system.install.apple-software"]="Install software without user permission"
HIGH_RISK_ENTITLEMENTS["system.install.apple-software.standard-user"]="Install software without user permission"
HIGH_RISK_ENTITLEMENTS["com.apple.private.security.kext-management"]="Load kernel extensions"
HIGH_RISK_ENTITLEMENTS["com.apple.private.icloud-account-access"]="Access iCloud tokens"
HIGH_RISK_ENTITLEMENTS["kTCCServiceSystemPolicyAllFiles"]="Full Disk Access"
HIGH_RISK_ENTITLEMENTS["kTCCServiceAppleEvents"]="Automate/abuse other applications"
HIGH_RISK_ENTITLEMENTS["kTCCServiceEndpointSecurityClient"]="Write TCC database"
HIGH_RISK_ENTITLEMENTS["kTCCServiceSystemPolicySysAdminFiles"]="Bypass TCC by changing home directory"
HIGH_RISK_ENTITLEMENTS["kTCCServiceSystemPolicyAppBundles"]="Modify app bundle contents"
HIGH_RISK_ENTITLEMENTS["kTCCServiceAccessibility"]="Control UI, approve dialogs programmatically"

declare -A MEDIUM_RISK_ENTITLEMENTS
MEDIUM_RISK_ENTITLEMENTS["com.apple.security.cs.allow-jit"]="Create writable+executable memory"
MEDIUM_RISK_ENTITLEMENTS["com.apple.security.cs.allow-unsigned-executable-memory"]="Patch C code, use deprecated APIs"
MEDIUM_RISK_ENTITLEMENTS["com.apple.security.cs.disable-executable-page-protection"]="Modify own executable on disk"
MEDIUM_RISK_ENTITLEMENTS["com.apple.private.nullfs_allow"]="Mount nullfs filesystem"
MEDIUM_RISK_ENTITLEMENTS["kTCCServiceAll"]="Request all TCC permissions"

# Extract all entitlements from the XML
ALL_ENTITLEMENTS=$(grep -oP '(?<=<key>)[^<]+(?=</key>)' "$ENTITLEMENTS_FILE" 2>/dev/null || echo "")

echo ""
echo "=== Analysis Results ==="
echo ""

# Track findings
HIGH_COUNT=0
MEDIUM_COUNT=0
FOUND_HIGH=()
FOUND_MEDIUM=()

# Check for high-risk entitlements
echo -e "${RED}🔴 HIGH RISK ENTITLEMENTS:${NC}"
for entitlement in "${!HIGH_RISK_ENTITLEMENTS[@]}"; do
    if echo "$ALL_ENTITLEMENTS" | grep -qF "$entitlement"; then
        echo -e "  ${RED}• $entitlement${NC}"
        echo "    → ${HIGH_RISK_ENTITLEMENTS[$entitlement]}"
        FOUND_HIGH+=("$entitlement")
        ((HIGH_COUNT++))
    fi
done

if [ $HIGH_COUNT -eq 0 ]; then
    echo -e "  ${GREEN}None found${NC}"
fi

echo ""

# Check for medium-risk entitlements
echo -e "${YELLOW}🟡 MEDIUM RISK ENTITLEMENTS:${NC}"
for entitlement in "${!MEDIUM_RISK_ENTITLEMENTS[@]}"; do
    if echo "$ALL_ENTITLEMENTS" | grep -qF "$entitlement"; then
        echo -e "  ${YELLOW}• $entitlement${NC}"
        echo "    → ${MEDIUM_RISK_ENTITLEMENTS[$entitlement]}"
        FOUND_MEDIUM+=("$entitlement")
        ((MEDIUM_COUNT++))
    fi
done

if [ $MEDIUM_COUNT -eq 0 ]; then
    echo -e "  ${GREEN}None found${NC}"
fi

echo ""
echo "=== Summary ==="
echo "High Risk: $HIGH_COUNT"
echo "Medium Risk: $MEDIUM_COUNT"
echo ""

# Generate recommendations
if [ $HIGH_COUNT -gt 0 ]; then
    echo -e "${RED}⚠️  WARNING: High-risk entitlements detected!${NC}"
    echo ""
    echo "Recommendations:"
    
    if [[ " ${FOUND_HIGH[*]} " =~ " com.apple.rootless.install" ]]; then
        echo "  • SIP bypass capability detected - investigate thoroughly"
    fi
    
    if [[ " ${FOUND_HIGH[*]} " =~ " com.apple.system-task-ports" ]] || [[ " ${FOUND_HIGH[*]} " =~ " com.apple.security.get-task-allow" ]]; then
        echo "  • Code injection capabilities detected - review for privilege escalation"
    fi
    
    if [[ " ${FOUND_HIGH[*]} " =~ " com.apple.private.tcc.manager" ]] || [[ " ${FOUND_HIGH[*]} " =~ " kTCCService" ]]; then
        echo "  • TCC manipulation capabilities detected - check for permission abuse"
    fi
    
    if [[ " ${FOUND_HIGH[*]} " =~ " com.apple.private.icloud-account-access" ]]; then
        echo "  • iCloud token access detected - potential credential theft vector"
    fi
    
    if [[ " ${FOUND_HIGH[*]} " =~ " com.apple.security.cs.disable-library-validation" ]]; then
        echo "  • Library validation disabled - check for code injection via frameworks"
    fi
else
    echo -e "${GREEN}✓ No high-risk entitlements detected${NC}"
fi

if [ $MEDIUM_COUNT -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Medium-risk entitlements present - review for context${NC}"
fi

# Cleanup
rm -f "$ENTITLEMENTS_FILE"

echo ""
echo "=== Raw Entitlements ==="
grep -oP '(?<=<key>)[^<]+(?=</key>)' "$ENTITLEMENTS_FILE" 2>/dev/null | sort -u || echo "(already cleaned up)"

exit 0
