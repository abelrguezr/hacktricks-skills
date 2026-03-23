#!/bin/bash
# Linux Group-Based Privilege Escalation Checker
# This script identifies exploitable group memberships

set -e

echo "========================================"
echo "Linux Group Privilege Escalation Checker"
echo "========================================"
echo ""

# Get current user info
echo "[INFO] Current user: $(whoami)"
echo "[INFO] User ID: $(id -u)"
echo "[INFO] Groups: $(id -Gn)"
echo ""

# Define exploitable groups and their risk levels
declare -A GROUP_RISK
declare -A GROUP_DESC

GROUP_RISK["sudo"]="CRITICAL"
GROUP_DESC["sudo"]="Direct sudo access to any command"

GROUP_RISK["admin"]="CRITICAL"
GROUP_DESC["admin"]="Direct sudo access to any command"

GROUP_RISK["wheel"]="CRITICAL"
GROUP_DESC["wheel"]="Direct sudo access (RHEL/CentOS/Fedora)"

GROUP_RISK["docker"]="CRITICAL"
GROUP_DESC["docker"]="Container escape to root"

GROUP_RISK["lxc"]="CRITICAL"
GROUP_DESC["lxc"]="LXC container escape"

GROUP_RISK["lxd"]="CRITICAL"
GROUP_DESC["lxd"]="LXD container escape"

GROUP_RISK["disk"]="HIGH"
GROUP_DESC["disk"]="Direct filesystem access via debugfs"

GROUP_RISK["shadow"]="HIGH"
GROUP_DESC["shadow"]="Can read /etc/shadow for password cracking"

GROUP_RISK["staff"]="HIGH"
GROUP_DESC["staff"]="PATH hijacking via /usr/local/"

GROUP_RISK["video"]="MEDIUM"
GROUP_DESC["video"]="Screen capture via framebuffer"

GROUP_RISK["root"]="MEDIUM"
GROUP_DESC["root"]="Can modify some root-owned files"

GROUP_RISK["adm"]="LOW"
GROUP_DESC["adm"]="Can read system logs for credentials"

GROUP_RISK["backup"]="LOW"
GROUP_DESC["backup"]="May access backup archives with credentials"

GROUP_RISK["mail"]="LOW"
GROUP_DESC["mail"]="May access mail spools with credentials"

GROUP_RISK["lp"]="LOW"
GROUP_DESC["lp"]="May access print spools with documents"

GROUP_RISK["operator"]="LOW"
GROUP_DESC["operator"]="May access operational data"

GROUP_RISK["auth"]="MEDIUM"
GROUP_DESC["auth"]="OpenBSD: Can write auth files (CVE-2019-19520)"

# Check each group
echo "[CHECKING] Group memberships..."
echo ""

FOUND_CRITICAL=0
FOUND_HIGH=0
FOUND_MEDIUM=0
FOUND_LOW=0

for group in "${!GROUP_RISK[@]}"; do
    if id -nG | grep -qw "$group"; then
        risk="${GROUP_RISK[$group]}"
        desc="${GROUP_DESC[$group]}"
        
        case $risk in
            "CRITICAL")
                echo "[CRITICAL] Group: $group"
                echo "         Description: $desc"
                FOUND_CRITICAL=$((FOUND_CRITICAL + 1))
                ;;
            "HIGH")
                echo "[HIGH]     Group: $group"
                echo "         Description: $desc"
                FOUND_HIGH=$((FOUND_HIGH + 1))
                ;;
            "MEDIUM")
                echo "[MEDIUM]   Group: $group"
                echo "         Description: $desc"
                FOUND_MEDIUM=$((FOUND_MEDIUM + 1))
                ;;
            "LOW")
                echo "[LOW]      Group: $group"
                echo "         Description: $desc"
                FOUND_LOW=$((FOUND_LOW + 1))
                ;;
        esac
        echo ""
    fi
done

# Summary
echo "========================================"
echo "SUMMARY"
echo "========================================"
echo "Critical: $FOUND_CRITICAL"
echo "High:     $FOUND_HIGH"
echo "Medium:   $FOUND_MEDIUM"
echo "Low:      $FOUND_LOW"
echo ""

# Additional checks
echo "[CHECKING] Additional privilege indicators..."
echo ""

# Check sudoers
echo "[SUDOERS] Checking /etc/sudoers..."
if [ -r /etc/sudoers ]; then
    grep -v '^#' /etc/sudoers | grep -v '^$' | head -20
else
    echo "[SUDOERS] Cannot read /etc/sudoers (expected)"
fi
echo ""

# Check for SUID binaries
echo "[SUID] Checking for interesting SUID binaries..."
find / -perm -4000 -type f 2>/dev/null | grep -E '(pkexec|sudo|docker|lxc)' | head -10
echo ""

# Check docker socket
echo "[DOCKER] Checking Docker socket..."
if [ -S /var/run/docker.sock ]; then
    ls -la /var/run/docker.sock
else
    echo "[DOCKER] Docker socket not found"
fi
echo ""

# Check for writable /usr/local
echo "[STAFF] Checking /usr/local/ write access..."
if [ -w /usr/local/bin ]; then
    echo "[STAFF] WARNING: /usr/local/bin is writable!"
else
    echo "[STAFF] /usr/local/bin is not writable"
fi
echo ""

# Check shadow file access
echo "[SHADOW] Checking /etc/shadow access..."
if [ -r /etc/shadow ]; then
    echo "[SHADOW] WARNING: /etc/shadow is readable!"
    head -5 /etc/shadow
else
    echo "[SHADOW] /etc/shadow is not readable (expected)"
fi
echo ""

# Check disk group access
echo "[DISK] Checking block device access..."
if [ -r /dev/sda ]; then
    echo "[DISK] Block devices are accessible"
else
    echo "[DISK] Block devices not accessible"
fi
echo ""

echo "========================================"
echo "Check complete. Review findings above."
echo "========================================"
