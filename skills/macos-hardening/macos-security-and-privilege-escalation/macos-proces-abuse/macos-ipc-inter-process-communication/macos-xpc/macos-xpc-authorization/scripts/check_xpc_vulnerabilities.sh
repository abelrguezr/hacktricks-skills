#!/bin/bash
# macOS XPC HelperTool Vulnerability Checker
# Scans for common XPC authorization vulnerabilities

set -e

HELPER_DIR="/Library/PrivilegedHelperTools"

echo "========================================"
echo "macOS XPC HelperTool Vulnerability Scanner"
echo "========================================"
echo ""

# Check if directory exists
if [ ! -d "$HELPER_DIR" ]; then
    echo "[!] $HELPER_DIR not found"
    exit 1
fi

# Get list of helper tools
HELPER_TOOLS=$(ls -1 "$HELPER_DIR" 2>/dev/null || echo "")

if [ -z "$HELPER_TOOLS" ]; then
    echo "[!] No HelperTools found in $HELPER_DIR"
    exit 1
fi

echo "[*] Found $(echo "$HELPER_TOOLS" | wc -l | tr -d ' ') HelperTools"
echo ""

for helper in $HELPER_TOOLS; do
    HELPER_PATH="$HELPER_DIR/$helper"
    
    if [ ! -f "$HELPER_PATH" ]; then
        continue
    fi
    
    echo "========================================"
    echo "Analyzing: $helper"
    echo "========================================"
    echo ""
    
    # Check 1: shouldAcceptNewConnection pattern
echo "[*] Checking for 'shouldAcceptNewConnection'..."
    if strings "$HELPER_PATH" 2>/dev/null | grep -q "shouldAcceptNewConnection"; then
        echo "  [!] Found: shouldAcceptNewConnection"
        
        # Check if it has code signing requirement
        if strings "$HELPER_PATH" 2>/dev/null | grep -q "setCodeSigningRequirement"; then
            echo "  [i] Has: setCodeSigningRequirement (good)"
        else
            echo "  [!] WARNING: No setCodeSigningRequirement found (potential vulnerability)"
        fi
    else
        echo "  [i] Not found: shouldAcceptNewConnection"
    fi
    echo ""
    
    # Check 2: AuthorizationCopyRights with NULL
echo "[*] Checking for AuthorizationCopyRights..."
    if strings "$HELPER_PATH" 2>/dev/null | grep -q "AuthorizationCopyRights"; then
        echo "  [!] Found: AuthorizationCopyRights"
        
        # Check for checkAuthorization function
        if strings "$HELPER_PATH" 2>/dev/null | grep -q "checkAuthorization"; then
            echo "  [i] Has: checkAuthorization function"
        fi
        
        # Check for AuthorizationCreateFromExternalForm
        if strings "$HELPER_PATH" 2>/dev/null | grep -q "AuthorizationCreateFromExternalForm"; then
            echo "  [i] Has: AuthorizationCreateFromExternalForm (uses client auth)"
        else
            echo "  [!] WARNING: No AuthorizationCreateFromExternalForm (may use NULL)"
        fi
    else
        echo "  [i] Not found: AuthorizationCopyRights"
    fi
    echo ""
    
    # Check 3: Command injection patterns
echo "[*] Checking for command execution..."
    if strings "$HELPER_PATH" 2>/dev/null | grep -q "NSTask\|system(\|popen\|exec"; then
        echo "  [!] Found command execution functions"
        strings "$HELPER_PATH" 2>/dev/null | grep -E "NSTask|system\(|popen|exec" | head -5 | sed 's/^/    /'
    else
        echo "  [i] No obvious command execution found"
    fi
    echo ""
    
    # Check 4: Protocol methods
echo "[*] Checking for exposed protocol methods..."
    if strings "$HELPER_PATH" 2>/dev/null | grep -q "Protocol"; then
        echo "  [i] Protocol methods found:"
        strings "$HELPER_PATH" 2>/dev/null | grep -E "Protocol|WithAuthorization|WithReply" | head -10 | sed 's/^/    /'
    fi
    echo ""
    
    # Check 5: Code signature requirements
echo "[*] Checking code signature..."
    if command -v codesign &> /dev/null; then
        codesign --display --requirements "$HELPER_PATH" 2>/dev/null | head -10 | sed 's/^/    /' || echo "    [!] Unable to read code signature"
    else
        echo "  [i] codesign not available"
    fi
    echo ""
    
    # Check 6: Find associated LaunchDaemon
echo "[*] Finding associated LaunchDaemon..."
    HELPER_NAME=$(basename "$helper")
    LAUNCHDAEMONS=$(find /Library/LaunchDaemons -name "*.plist" -exec grep -l "$HELPER_NAME" {} \; 2>/dev/null || echo "")
    
    if [ -n "$LAUNCHDAEMONS" ]; then
        echo "  Associated LaunchDaemons:"
        echo "$LAUNCHDAEMONS" | sed 's/^/    /'
        
        # Extract Mach service name
        for ld in $LAUNCHDAEMONS; do
            MACH_NAME=$(grep -A5 "MachServices" "$ld" 2>/dev/null | grep -v "MachServices" | grep -v "^--" | head -1 | tr -d '"' | tr -d '<>' | tr -d ' ' || echo "")
            if [ -n "$MACH_NAME" ]; then
                echo "  Mach Service: $MACH_NAME"
            fi
        done
    else
        echo "  [i] No associated LaunchDaemon found"
    fi
    echo ""
    
    echo "----------------------------------------"
done

echo "========================================"
echo "Scan complete"
echo "========================================"
echo ""
echo "[+] Review findings for potential vulnerabilities"
echo "[+] Use class-dump to extract full protocol definitions"
echo "[+] Test with empty authorization reference if vulnerable patterns found"
