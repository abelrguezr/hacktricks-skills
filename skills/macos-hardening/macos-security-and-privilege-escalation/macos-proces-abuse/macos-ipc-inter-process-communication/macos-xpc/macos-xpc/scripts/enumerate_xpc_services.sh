#!/bin/bash
# macOS XPC Service Enumeration Script
# Searches for XPC services across the system

set -e

echo "=== macOS XPC Service Enumeration ==="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if running on macOS
check_macos() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo -e "${RED}Error: This script requires macOS${NC}"
        exit 1
    fi
}

# Function to enumerate application XPC services
enumerate_app_xpc() {
    echo -e "${GREEN}[+] Application-Specific XPC Services${NC}"
    echo "----------------------------------------"
    
    # Search common application locations
    for app_dir in /Applications /Applications/Utilities ~/Applications; do
        if [[ -d "$app_dir" ]]; then
            find "$app_dir" -type d -name "XPCServices" 2>/dev/null | while read xpc_dir; do
                echo ""
                echo "Location: $xpc_dir"
                find "$xpc_dir" -name "*.xpc" -type d 2>/dev/null | while read xpc_bundle; do
                    bundle_name=$(basename "$xpc_bundle")
                    echo "  - $bundle_name"
                    
                    # Check Info.plist
                    info_plist="$xpc_bundle/Contents/Info.plist"
                    if [[ -f "$info_plist" ]]; then
                        service_type=$(plutil -extract "ServiceType" raw "$info_plist" 2>/dev/null || echo "N/A")
                        echo "    ServiceType: $service_type"
                        
                        # Check for JoinExistingSession
                        join_session=$(plutil -extract "JoinExistingSession" raw "$info_plist" 2>/dev/null || echo "false")
                        if [[ "$join_session" == "true" ]]; then
                            echo -e "    ${YELLOW}⚠️  JoinExistingSession: true (potential privilege issue)${NC}"
                        fi
                        
                        # Check for _AllowedClients
                        allowed_clients=$(plutil -extract "_AllowedClients" raw "$info_plist" 2>/dev/null || echo "N/A")
                        if [[ "$allowed_clients" != "N/A" && -n "$allowed_clients" ]]; then
                            echo "    _AllowedClients: Configured"
                        else
                            echo -e "    ${YELLOW}⚠️  _AllowedClients: Not configured${NC}"
                        fi
                    fi
                done
            done
        fi
    done
    echo ""
}

# Function to enumerate system-wide XPC services
enumerate_system_xpc() {
    echo -e "${GREEN}[+] System-Wide XPC Services${NC}"
    echo "----------------------------------------"
    
    local locations=(
        "/System/Library/LaunchDaemons"
        "/Library/LaunchDaemons"
        "/System/Library/LaunchAgents"
        "/Library/LaunchAgents"
        "~/Library/LaunchAgents"
    )
    
    for location in "${locations[@]}"; do
        if [[ -d "$location" ]]; then
            echo ""
            echo "Location: $location"
            
            find "$location" -name "*.plist" -type f 2>/dev/null | while read plist; do
                # Check if plist contains MachServices
                if plutil -extract "MachServices" raw "$plist" 2>/dev/null; then
                    label=$(plutil -extract "Label" raw "$plist" 2>/dev/null || echo "unknown")
                    echo "  - $label"
                    
                    # Get program path
                    program=$(plutil -extract "Program" raw "$plist" 2>/dev/null || echo "N/A")
                    if [[ "$program" != "N/A" && -n "$program" ]]; then
                        echo "    Program: $program"
                        
                        # Check if program exists and its permissions
                        if [[ -f "$program" ]]; then
                            perms=$(stat -f "%OLp" "$program" 2>/dev/null || echo "unknown")
                            owner=$(stat -f "%Su" "$program" 2>/dev/null || echo "unknown")
                            echo "    Permissions: $perms, Owner: $owner"
                            
                            # Check for world-writable
                            if [[ "$perms" == *"w"* ]] && [[ "$perms" == *"w"* ]]; then
                                echo -e "    ${RED}⚠️  WARNING: World-writable binary!${NC}"
                            fi
                        else
                            echo -e "    ${YELLOW}⚠️  Program not found${NC}"
                        fi
                    fi
                    
                    # Check for _AllowedClients
                    if plutil -extract "_AllowedClients" raw "$plist" 2>/dev/null; then
                        echo "    _AllowedClients: Configured"
                    else
                        if [[ "$location" == *"LaunchDaemons"* ]]; then
                            echo -e "    ${YELLOW}⚠️  _AllowedClients: Not configured (LaunchDaemon)${NC}"
                        fi
                    fi
                    
                    # Check for UsesRemoteXPC
                    if plutil -extract "UsesRemoteXPC" raw "$plist" 2>/dev/null; then
                        echo -e "    ${GREEN}ℹ️  UsesRemoteXPC: true${NC}"
                    fi
                    
                    echo ""
                fi
            done
        fi
    done
}

# Function to list XPC-related processes
list_xpc_processes() {
    echo -e "${GREEN}[+] XPC-Related Processes${NC}"
    echo "----------------------------------------"
    
    echo ""
    echo "xpcproxy processes:"
    ps aux | grep -E "xpcproxy|xpc" | grep -v grep || echo "  None found"
    
    echo ""
    echo "launchd children:"
    ps -o pid,ppid,comm -g $(pgrep -n launchd | head -1) 2>/dev/null | head -20 || echo "  Unable to retrieve"
}

# Function to check for XPC debugging tools
check_tools() {
    echo -e "${GREEN}[+] XPC Analysis Tools${NC}"
    echo "----------------------------------------"
    
    echo ""
    echo "Available tools:"
    
    if command -v xpcspy &> /dev/null; then
        echo "  ✓ xpcspy installed"
    else
        echo "  ✗ xpcspy not installed (pip3 install xpcspy)"
    fi
    
    if [[ -f "/usr/libexec/remotectl" ]]; then
        echo "  ✓ remotectl available"
    else
        echo "  ✗ remotectl not found"
    fi
    
    if command -v supraudit &> /dev/null; then
        echo "  ✓ supraudit available"
    else
        echo "  ✗ supraudit not found"
    fi
}

# Main execution
main() {
    check_macos
    
    echo -e "${GREEN}Starting XPC service enumeration...${NC}"
    echo ""
    
    enumerate_app_xpc
    enumerate_system_xpc
    list_xpc_processes
    check_tools
    
    echo ""
    echo -e "${GREEN}Enumeration complete.${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Review flagged services for potential issues"
    echo "  2. Use analyze_xpc_plist.sh for detailed analysis"
    echo "  3. Create test clients with create_xpc_client.sh"
    echo "  4. Monitor traffic with xpcspy"
}

main "$@"
