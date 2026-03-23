#!/bin/bash
# macOS Security Audit Script
# Run this script to perform a comprehensive security assessment

set -e

echo "=== macOS Security Audit ==="
echo "Started at: $(date)"
echo ""

# Create output directory
OUTPUT_DIR="./macos-security-audit-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUTPUT_DIR"

# Function to run command and save output
run_command() {
    local title="$1"
    local cmd="$2"
    local output_file="$OUTPUT_DIR/$(echo $title | tr ' ' '_' | tr '[:upper:]' '[:lower:]').txt"
    
    echo "Running: $title"
    echo "=== $title ===" | tee -a "$output_file"
    eval "$cmd" 2>&1 | tee -a "$output_file"
    echo "" >> "$output_file"
}

# System Information
run_command "System Information" "sw_vers"
run_command "Kernel Info" "uname -a"
run_command "Current User" "whoami && id && groups"

# Security Protections
echo "=== Security Protections ===" > "$OUTPUT_DIR/security_protections.txt"
echo "SIP Status:" >> "$OUTPUT_DIR/security_protections.txt"
csrutil status 2>&1 >> "$OUTPUT_DIR/security_protections.txt" || echo "Cannot check SIP (requires recovery mode)" >> "$OUTPUT_DIR/security_protections.txt"
echo "" >> "$OUTPUT_DIR/security_protections.txt"
echo "TCC Permissions:" >> "$OUTPUT_DIR/security_protections.txt"
tccutil list 2>&1 >> "$OUTPUT_DIR/security_protections.txt" || echo "Cannot access TCC" >> "$OUTPUT_DIR/security_protections.txt"
echo "" >> "$OUTPUT_DIR/security_protections.txt"
echo "FileVault Status:" >> "$OUTPUT_DIR/security_protections.txt"
fdesetup status 2>&1 >> "$OUTPUT_DIR/security_protections.txt" || echo "Cannot check FileVault" >> "$OUTPUT_DIR/security_protections.txt"
echo "" >> "$OUTPUT_DIR/security_protections.txt"
echo "Firewall Status:" >> "$OUTPUT_DIR/security_protections.txt"
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>&1 >> "$OUTPUT_DIR/security_protections.txt" || echo "Cannot check firewall" >> "$OUTPUT_DIR/security_protections.txt"

# SUID/SGID Binaries
echo "=== SUID/SGID Binaries ===" > "$OUTPUT_DIR/suid_binaries.txt"
find / -perm -4000 -type f 2>/dev/null >> "$OUTPUT_DIR/suid_binaries.txt"
echo "" >> "$OUTPUT_DIR/suid_binaries.txt"
echo "SGID Binaries:" >> "$OUTPUT_DIR/suid_binaries.txt"
find / -perm -2000 -type f 2>/dev/null >> "$OUTPUT_DIR/suid_binaries.txt"

# World-Writable Files
echo "=== World-Writable Files ===" > "$OUTPUT_DIR/world_writable.txt"
find /usr /System /Library -perm -0002 -type f 2>/dev/null >> "$OUTPUT_DIR/world_writable.txt"

# Writable Directories
echo "=== Writable Directories ===" > "$OUTPUT_DIR/writable_dirs.txt"
find /usr /System /Library -perm -0002 -type d 2>/dev/null >> "$OUTPUT_DIR/writable_dirs.txt"

# Cron Jobs
echo "=== Cron Jobs ===" > "$OUTPUT_DIR/cron_jobs.txt"
cat /etc/crontab 2>/dev/null >> "$OUTPUT_DIR/cron_jobs.txt"
ls -la /etc/cron.* 2>/dev/null >> "$OUTPUT_DIR/cron_jobs.txt"

# LaunchDaemons
echo "=== LaunchDaemons ===" > "$OUTPUT_DIR/launch_daemons.txt"
ls -la /Library/LaunchDaemons/ 2>/dev/null >> "$OUTPUT_DIR/launch_daemons.txt"
ls -la /System/Library/LaunchDaemons/ 2>/dev/null >> "$OUTPUT_DIR/launch_daemons.txt"

# User Accounts
echo "=== User Accounts ===" > "$OUTPUT_DIR/user_accounts.txt"
df -H 2>/dev/null >> "$OUTPUT_DIR/user_accounts.txt"
grep -i sudo /etc/sudoers 2>/dev/null >> "$OUTPUT_DIR/user_accounts.txt"
grep -i sudo /etc/sudoers.d/* 2>/dev/null >> "$OUTPUT_DIR/user_accounts.txt" || true

# Installed Packages
echo "=== Installed Packages ===" > "$OUTPUT_DIR/installed_packages.txt"
pkgutil --pkgs 2>/dev/null >> "$OUTPUT_DIR/installed_packages.txt"

echo ""
echo "=== Audit Complete ==="
echo "Results saved to: $OUTPUT_DIR"
echo "Finished at: $(date)"
