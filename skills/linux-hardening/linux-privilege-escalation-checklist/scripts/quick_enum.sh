#!/bin/bash
# Quick Linux Privilege Escalation Enumeration
# Run this to get a fast overview of potential privesc vectors

echo "=== QUICK LINUX PRIVILEGE ESCALATION ENUMERATION ==="
echo ""

# Basic info
echo "[1] SYSTEM INFO"
whoami
echo "Current user: $(whoami)"
echo "User ID: $(id)"
echo "Kernel: $(uname -a)"
echo "OS: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2)"
echo ""

# Sudo permissions
echo "[2] SUDO PERMISSIONS"
sudo -l 2>/dev/null || echo "No sudo access or sudo not installed"
echo ""

# SUID binaries
echo "[3] SUID BINARIES (first 20)"
find / -perm -4000 -type f 2>/dev/null | head -20
echo ""

# Capabilities
echo "[4] CAPABILITIES"
getcap -r / 2>/dev/null | head -20 || echo "getcap not available"
echo ""

# Cron jobs
echo "[5] CRON JOBS"
echo "User crontab:"
crontab -l 2>/dev/null || echo "No user crontab"
echo "System crontab:"
cat /etc/crontab 2>/dev/null | head -10 || echo "No system crontab"
echo ""

# Writable PATH directories
echo "[6] WRITABLE PATH DIRECTORIES"
echo $PATH | tr ':' '\n' | while read dir; do
    if [ -d "$dir" ] && [ -w "$dir" ]; then
        echo "WRITABLE: $dir"
    fi
done
echo ""

# Interesting groups
echo "[7] GROUP MEMBERSHIPS"
groups
echo ""

# Open shell sessions
echo "[8] OPEN SHELL SESSIONS"
echo "Screen sessions:"
screen -ls 2>/dev/null || echo "No screen sessions"
echo "Tmux sessions:"
tmux list-sessions 2>/dev/null || echo "No tmux sessions"
echo ""

# SSH keys
echo "[9] SSH KEYS"
find /home -name 'id_rsa*' -o -name 'id_dsa*' 2>/dev/null | head -10
echo ""

# Recently modified files
echo "[10] RECENTLY MODIFIED FILES (last 24h, first 20)"
find / -mtime -1 -type f 2>/dev/null | head -20
echo ""

echo "=== ENUMERATION COMPLETE ==="
echo "For detailed analysis, run LinPEAS: curl -L https://github.com/carlospolop/privilege-escalation-awesome-scripts-suite/raw/master/linPEAS/linPEAS.sh | sh"
