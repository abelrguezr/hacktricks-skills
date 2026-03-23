#!/bin/bash
# XPC Plist Analysis Script
# Analyzes a specific XPC service plist for security issues

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check arguments
if [[ $# -lt 1 ]]; then
    echo -e "${RED}Usage: $0 <path-to-plist>${NC}"
    echo ""
    echo "Example: $0 /Library/LaunchDaemons/com.example.service.plist"
    exit 1
fi

PLIST_PATH="$1"

# Check if file exists
if [[ ! -f "$PLIST_PATH" ]]; then
    echo -e "${RED}Error: File not found: $PLIST_PATH${NC}"
    exit 1
fi

echo -e "${GREEN}=== XPC Plist Security Analysis ===${NC}"
echo "File: $PLIST_PATH"
echo ""

# Function to extract plist value
get_plist_value() {
    local key="$1"
    plutil -extract "$key" raw "$PLIST_PATH" 2>/dev/null || echo "NOT_SET"
}

# Function to check if key exists
has_key() {
    local key="$1"
    plutil -extract "$key" raw "$PLIST_PATH" &>/dev/null
}

# Basic information
echo -e "${BLUE}[1] Basic Information${NC}"
echo "----------------------------------------"

label=$(get_plist_value "Label")
echo "Label: $label"

program=$(get_plist_value "Program")
echo "Program: $program"

program_args=$(get_plist_value "ProgramArguments")
if [[ "$program_args" != "NOT_SET" ]]; then
    echo "ProgramArguments: Configured"
fi

service_type=$(get_plist_value "ServiceType")
echo "ServiceType: ${service_type:-NOT_SET}"

# Check if this is a LaunchDaemon (runs as root)
if [[ "$PLIST_PATH" == *"LaunchDaemons"* ]]; then
    echo -e "${YELLOW}⚠️  This is a LaunchDaemon (runs as root)${NC}"
fi

echo ""

# MachServices configuration
echo -e "${BLUE}[2] MachServices Configuration${NC}"
echo "----------------------------------------"

if has_key "MachServices"; then
    echo "MachServices: Configured"
    
    # Extract service names
    echo "Service names:"
    plutil -p "$PLIST_PATH" 2>/dev/null | grep -A 100 "<key>MachServices</key>" | grep "<key>" | grep -v "MachServices" | sed 's/.*<key>\(.*\)<\/key>.*/  - \1/' | head -20
else
    echo -e "${RED}✗ MachServices: NOT CONFIGURED${NC}"
    echo "  This plist may not define an XPC service"
fi

echo ""

# Security checks
echo -e "${BLUE}[3] Security Analysis${NC}"
echo "----------------------------------------"

# Check 1: _AllowedClients
if has_key "_AllowedClients"; then
    echo -e "${GREEN}✓ _AllowedClients: Configured${NC}"
    echo "  Client restrictions are in place"
else
    echo -e "${RED}✗ _AllowedClients: NOT CONFIGURED${NC}"
    echo "  ⚠️  Any process may be able to connect to this service"
    if [[ "$PLIST_PATH" == *"LaunchDaemons"* ]]; then
        echo -e "  ${RED}⚠️  CRITICAL: This is a root-owned service with no client restrictions${NC}"
    fi
fi

echo ""

# Check 2: JoinExistingSession
if has_key "JoinExistingSession"; then
    join_session=$(get_plist_value "JoinExistingSession")
    if [[ "$join_session" == "true" ]]; then
        echo -e "${YELLOW}⚠️  JoinExistingSession: true${NC}"
        echo "  ⚠️  Service runs in caller's security context"
        echo "  ⚠️  Privilege separation may be bypassed"
    else
        echo -e "${GREEN}✓ JoinExistingSession: false${NC}"
        echo "  Service maintains separate security context"
    fi
else
    echo -e "${GREEN}✓ JoinExistingSession: Not set (defaults to false)${NC}"
fi

echo ""

# Check 3: Program path security
if [[ "$program" != "NOT_SET" && -n "$program" ]]; then
    echo "Program path analysis:"
    
    if [[ -f "$program" ]]; then
        echo "  ✓ Binary exists"
        
        # Check permissions
        perms=$(stat -f "%OLp" "$program" 2>/dev/null || echo "unknown")
        echo "  Permissions: $perms"
        
        # Check owner
        owner=$(stat -f "%Su" "$program" 2>/dev/null || echo "unknown")
        echo "  Owner: $owner"
        
        # Check for world-writable
        if [[ "$perms" =~ w.*w ]]; then
            echo -e "  ${RED}⚠️  CRITICAL: Binary is world-writable!${NC}"
            echo "  ⚠️  Attacker can replace binary and execute as service user"
        fi
        
        # Check for symlink
        if [[ -L "$program" ]]; then
            echo -e "  ${YELLOW}⚠️  WARNING: Binary is a symlink${NC}"
            echo "  Target: $(readlink "$program")"
        fi
        
        # Check if in writable directory
        dir=$(dirname "$program")
        dir_perms=$(stat -f "%OLp" "$dir" 2>/dev/null || echo "unknown")
        if [[ "$dir_perms" =~ w.*w ]]; then
            echo -e "  ${YELLOW}⚠️  WARNING: Binary directory is world-writable${NC}"
        fi
    else
        echo -e "  ${RED}✗ Binary not found at: $program${NC}"
    fi
fi

echo ""

# Check 4: Sandbox profile
if has_key "_SandboxProfile"; then
    echo -e "${GREEN}✓ _SandboxProfile: Configured${NC}"
    echo "  Service runs with sandbox restrictions"
else
    echo -e "${YELLOW}⚠️  _SandboxProfile: Not configured${NC}"
    echo "  Service may have broad system access"
fi

echo ""

# Check 5: Remote XPC
if has_key "UsesRemoteXPC"; then
    echo -e "${BLUE}ℹ️  UsesRemoteXPC: true${NC}"
    echo "  Service supports cross-host communication"
    echo "  ⚠️  May be accessible over network"
fi

echo ""

# Check 6: RunAtLoad and KeepAlive
run_at_load=$(get_plist_value "RunAtLoad")
keep_alive=$(get_plist_value "KeepAlive")

echo -e "${BLUE}[4] Service Lifecycle${NC}"
echo "----------------------------------------"
echo "RunAtLoad: ${run_at_load:-false}"
echo "KeepAlive: ${keep_alive:-false}"

if [[ "$keep_alive" == "true" ]]; then
    echo -e "${YELLOW}⚠️  Service is kept alive continuously${NC}"
    echo "  Always available for exploitation if vulnerable"
fi

echo ""

# Check 7: Environment variables
if has_key "EnvironmentVariables"; then
    echo -e "${BLUE}[5] Environment Variables${NC}"
    echo "----------------------------------------"
    echo "EnvironmentVariables: Configured"
    echo "  ⚠️  Review for sensitive data or path manipulation"
    plutil -p "$PLIST_PATH" 2>/dev/null | grep -A 50 "<key>EnvironmentVariables</key>" | grep "<string>" | head -20
fi

echo ""

# Summary
echo -e "${GREEN}=== Analysis Summary ===${NC}"
echo ""

# Count issues
critical=0
warnings=0

if ! has_key "_AllowedClients" && [[ "$PLIST_PATH" == *"LaunchDaemons"* ]]; then
    ((critical++))
fi

if [[ "$program" != "NOT_SET" && -f "$program" ]]; then
    perms=$(stat -f "%OLp" "$program" 2>/dev/null || echo "")
    if [[ "$perms" =~ w.*w ]]; then
        ((critical++))
    fi
fi

if has_key "JoinExistingSession"; then
    join_session=$(get_plist_value "JoinExistingSession")
    if [[ "$join_session" == "true" ]]; then
        ((warnings++))
    fi
fi

if ! has_key "_AllowedClients" && [[ "$PLIST_PATH" != *"LaunchDaemons"* ]]; then
    ((warnings++))
fi

if ! has_key "_SandboxProfile"; then
    ((warnings++))
fi

echo "Critical Issues: $critical"
echo "Warnings: $warnings"
echo ""

if [[ $critical -gt 0 ]]; then
    echo -e "${RED}⚠️  CRITICAL ISSUES FOUND - Immediate review recommended${NC}"
elif [[ $warnings -gt 0 ]]; then
    echo -e "${YELLOW}⚠️  Security concerns identified - Review recommended${NC}"
else
    echo -e "${GREEN}✓ No obvious security issues detected${NC}"
fi

echo ""
echo "Next steps:"
echo "  1. Review flagged issues in detail"
echo "  2. Test service connectivity with create_xpc_client.sh"
echo "  3. Monitor service with xpcspy"
echo "  4. Check for input validation vulnerabilities"
