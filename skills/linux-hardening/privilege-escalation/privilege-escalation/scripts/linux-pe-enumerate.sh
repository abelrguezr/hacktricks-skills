#!/bin/bash
# Linux Privilege Escalation Enumeration Script
# Comprehensive enumeration of potential privilege escalation vectors

set -e

OUTPUT_DIR="./pe-enumeration-results"
mkdir -p "$OUTPUT_DIR"

echo "=== Linux Privilege Escalation Enumeration ==="
echo "Output directory: $OUTPUT_DIR"
echo ""

# System Information
echo "[1/15] System Information..."
echo "=== System Information ===" > "$OUTPUT_DIR/system-info.txt"
uname -a >> "$OUTPUT_DIR/system-info.txt"
cat /etc/os-release 2>/dev/null >> "$OUTPUT_DIR/system-info.txt" || true
echo "" >> "$OUTPUT_DIR/system-info.txt"
echo "Kernel: $(uname -r)" >> "$OUTPUT_DIR/system-info.txt"
echo ""

# User Information
echo "[2/15] User Information..."
echo "=== User Information ===" > "$OUTPUT_DIR/user-info.txt"
id >> "$OUTPUT_DIR/user-info.txt"
echo "" >> "$OUTPUT_DIR/user-info.txt"
echo "Groups:" >> "$OUTPUT_DIR/user-info.txt"
groups >> "$OUTPUT_DIR/user-info.txt"
echo "" >> "$OUTPUT_DIR/user-info.txt"
echo "All users:" >> "$OUTPUT_DIR/user-info.txt"
cat /etc/passwd | cut -d: -f1 >> "$OUTPUT_DIR/user-info.txt"
echo "" >> "$OUTPUT_DIR/user-info.txt"
echo "Users with shell access:" >> "$OUTPUT_DIR/user-info.txt"
cat /etc/passwd | grep "sh$" >> "$OUTPUT_DIR/user-info.txt" || true
echo "" >> "$OUTPUT_DIR/user-info.txt"
echo "Superusers (UID 0):" >> "$OUTPUT_DIR/user-info.txt"
awk -F: '($3 == "0") {print}' /etc/passwd >> "$OUTPUT_DIR/user-info.txt" || true
echo ""

# Environment Variables
echo "[3/15] Environment Variables..."
echo "=== Environment Variables ===" > "$OUTPUT_DIR/env-info.txt"
echo "PATH: $PATH" >> "$OUTPUT_DIR/env-info.txt"
echo "" >> "$OUTPUT_DIR/env-info.txt"
echo "Checking for credentials in environment..." >> "$OUTPUT_DIR/env-info.txt"
(env || set) 2>/dev/null | grep -iE 'password|api|key|token|secret|credential' >> "$OUTPUT_DIR/env-info.txt" || true
echo ""

# SUID/SGID Binaries
echo "[4/15] SUID/SGID Binaries..."
echo "=== SUID/SGID Binaries ===" > "$OUTPUT_DIR/suid-binaries.txt"
echo "SUID binaries:" >> "$OUTPUT_DIR/suid-binaries.txt"
find / -perm -4000 -type f 2>/dev/null >> "$OUTPUT_DIR/suid-binaries.txt" || true
echo "" >> "$OUTPUT_DIR/suid-binaries.txt"
echo "SGID binaries:" >> "$OUTPUT_DIR/suid-binaries.txt"
find / -perm -2000 -type f 2>/dev/null >> "$OUTPUT_DIR/suid-binaries.txt" || true
echo ""

# Sudo Configuration
echo "[5/15] Sudo Configuration..."
echo "=== Sudo Configuration ===" > "$OUTPUT_DIR/sudo-config.txt"
sudo -l 2>/dev/null >> "$OUTPUT_DIR/sudo-config.txt" || echo "No sudo access or sudo not installed" >> "$OUTPUT_DIR/sudo-config.txt"
echo "" >> "$OUTPUT_DIR/sudo-config.txt"
echo "Sudoers files:" >> "$OUTPUT_DIR/sudo-config.txt"
ls -l /etc/sudoers /etc/sudoers.d/ 2>/dev/null >> "$OUTPUT_DIR/sudo-config.txt" || true
echo ""

# Cron Jobs
echo "[6/15] Cron Jobs..."
echo "=== Cron Jobs ===" > "$OUTPUT_DIR/cron-jobs.txt"
echo "User crontab:" >> "$OUTPUT_DIR/cron-jobs.txt"
crontab -l 2>/dev/null >> "$OUTPUT_DIR/cron-jobs.txt" || echo "No user crontab" >> "$OUTPUT_DIR/cron-jobs.txt"
echo "" >> "$OUTPUT_DIR/cron-jobs.txt"
echo "System cron directories:" >> "$OUTPUT_DIR/cron-jobs.txt"
ls -al /etc/cron* /etc/at* 2>/dev/null >> "$OUTPUT_DIR/cron-jobs.txt" || true
echo "" >> "$OUTPUT_DIR/cron-jobs.txt"
echo "Crontab contents:" >> "$OUTPUT_DIR/cron-jobs.txt"
cat /etc/crontab /etc/cron.d/* /var/spool/cron/crontabs/* 2>/dev/null | grep -v "^#" >> "$OUTPUT_DIR/cron-jobs.txt" || true
echo ""

# Writable Files
echo "[7/15] Writable Files..."
echo "=== Writable Files ===" > "$OUTPUT_DIR/writable-files.txt"
echo "Files owned by current user or world-writable:" >> "$OUTPUT_DIR/writable-files.txt"
find / \( -type f -o -type d \) \( -user $USER -o -perm -o=w \) ! -path "/proc/*" ! -path "/sys/*" ! -path "$HOME/*" 2>/dev/null | head -100 >> "$OUTPUT_DIR/writable-files.txt" || true
echo "" >> "$OUTPUT_DIR/writable-files.txt"
echo "Writable PATH directories:" >> "$OUTPUT_DIR/writable-files.txt"
for dir in $(echo $PATH | tr ':' '\n'); do
  if [ -d "$dir" ] && [ -w "$dir" ]; then
    echo "  $dir" >> "$OUTPUT_DIR/writable-files.txt"
  fi
done
echo ""

# Interesting Files
echo "[8/15] Interesting Files..."
echo "=== Interesting Files ===" > "$OUTPUT_DIR/interesting-files.txt"
echo "Password-related files:" >> "$OUTPUT_DIR/interesting-files.txt"
find / -type f \( -name "*password*" -o -name "*passwd*" -o -name "*shadow*" \) 2>/dev/null | head -50 >> "$OUTPUT_DIR/interesting-files.txt" || true
echo "" >> "$OUTPUT_DIR/interesting-files.txt"
echo "History files:" >> "$OUTPUT_DIR/interesting-files.txt"
find / -type f -name "*_history" 2>/dev/null | head -50 >> "$OUTPUT_DIR/interesting-files.txt" || true
echo "" >> "$OUTPUT_DIR/interesting-files.txt"
echo "SSH keys:" >> "$OUTPUT_DIR/interesting-files.txt"
find / -type f \( -name "id_rsa*" -o -name "id_dsa*" -o -name "id_ecdsa*" \) 2>/dev/null | head -50 >> "$OUTPUT_DIR/interesting-files.txt" || true
echo "" >> "$OUTPUT_DIR/interesting-files.txt"
echo "Backup files:" >> "$OUTPUT_DIR/interesting-files.txt"
find / -type f \( -name "*backup*" -o -name "*.bak" -o -name "*.bck" \) 2>/dev/null | head -50 >> "$OUTPUT_DIR/interesting-files.txt" || true
echo ""

# Network Services
echo "[9/15] Network Services..."
echo "=== Network Services ===" > "$OUTPUT_DIR/network-services.txt"
echo "Listening services:" >> "$OUTPUT_DIR/network-services.txt"
ss -tulpn 2>/dev/null >> "$OUTPUT_DIR/network-services.txt" || netstat -punta 2>/dev/null >> "$OUTPUT_DIR/network-services.txt" || true
echo "" >> "$OUTPUT_DIR/network-services.txt"
echo "Localhost-only services:" >> "$OUTPUT_DIR/network-services.txt"
ss -tulpn 2>/dev/null | grep "127.0" >> "$OUTPUT_DIR/network-services.txt" || true
echo ""

# Docker
echo "[10/15] Docker..."
echo "=== Docker ===" > "$OUTPUT_DIR/docker-info.txt"
echo "Docker socket:" >> "$OUTPUT_DIR/docker-info.txt"
ls -la /var/run/docker.sock 2>/dev/null >> "$OUTPUT_DIR/docker-info.txt" || echo "Docker socket not found" >> "$OUTPUT_DIR/docker-info.txt"
echo "" >> "$OUTPUT_DIR/docker-info.txt"
echo "Docker group membership:" >> "$OUTPUT_DIR/docker-info.txt"
groups | grep docker >> "$OUTPUT_DIR/docker-info.txt" || echo "Not in docker group" >> "$OUTPUT_DIR/docker-info.txt"
echo ""

# Security Protections
echo "[11/15] Security Protections..."
echo "=== Security Protections ===" > "$OUTPUT_DIR/security-protections.txt"
echo "AppArmor:" >> "$OUTPUT_DIR/security-protections.txt"
aa-status 2>/dev/null >> "$OUTPUT_DIR/security-protections.txt" || apparmor_status 2>/dev/null >> "$OUTPUT_DIR/security-protections.txt" || echo "Not found" >> "$OUTPUT_DIR/security-protections.txt"
echo "" >> "$OUTPUT_DIR/security-protections.txt"
echo "SELinux:" >> "$OUTPUT_DIR/security-protections.txt"
sestatus 2>/dev/null >> "$OUTPUT_DIR/security-protections.txt" || echo "Not found" >> "$OUTPUT_DIR/security-protections.txt"
echo "" >> "$OUTPUT_DIR/security-protections.txt"
echo "ASLR:" >> "$OUTPUT_DIR/security-protections.txt"
cat /proc/sys/kernel/randomize_va_space 2>/dev/null >> "$OUTPUT_DIR/security-protections.txt" || echo "Not found" >> "$OUTPUT_DIR/security-protections.txt"
echo "" >> "$OUTPUT_DIR/security-protections.txt"
echo "ptrace_scope:" >> "$OUTPUT_DIR/security-protections.txt"
cat /proc/sys/kernel/yama/ptrace_scope 2>/dev/null >> "$OUTPUT_DIR/security-protections.txt" || echo "Not found" >> "$OUTPUT_DIR/security-protections.txt"
echo ""

# Processes
echo "[12/15] Processes..."
echo "=== Processes ===" > "$OUTPUT_DIR/processes.txt"
echo "Running processes:" >> "$OUTPUT_DIR/processes.txt"
ps aux 2>/dev/null | head -50 >> "$OUTPUT_DIR/processes.txt" || true
echo "" >> "$OUTPUT_DIR/processes.txt"
echo "Processes with elevated privileges:" >> "$OUTPUT_DIR/processes.txt"
ps aux 2>/dev/null | grep -E "root|UID" | head -20 >> "$OUTPUT_DIR/processes.txt" || true
echo ""

# Installed Software
echo "[13/15] Installed Software..."
echo "=== Installed Software ===" > "$OUTPUT_DIR/installed-software.txt"
echo "Debian packages:" >> "$OUTPUT_DIR/installed-software.txt"
dpkg -l 2>/dev/null | head -50 >> "$OUTPUT_DIR/installed-software.txt" || true
echo "" >> "$OUTPUT_DIR/installed-software.txt"
echo "RPM packages:" >> "$OUTPUT_DIR/installed-software.txt"
rpm -qa 2>/dev/null | head -50 >> "$OUTPUT_DIR/installed-software.txt" || true
echo ""

# Useful Binaries
echo "[14/15] Useful Binaries..."
echo "=== Useful Binaries ===" > "$OUTPUT_DIR/useful-binaries.txt"
which nmap aws nc ncat netcat wget curl ping gcc g++ make gdb base64 socat python python2 python3 perl php ruby xterm sudo docker 2>/dev/null >> "$OUTPUT_DIR/useful-binaries.txt" || true
echo "" >> "$OUTPUT_DIR/useful-binaries.txt"
echo "Compilers:" >> "$OUTPUT_DIR/useful-binaries.txt"
which gcc g++ 2>/dev/null >> "$OUTPUT_DIR/useful-binaries.txt" || echo "No compilers found" >> "$OUTPUT_DIR/useful-binaries.txt"
echo ""

# Summary
echo "[15/15] Summary..."
echo "=== Enumeration Complete ==="
echo "Results saved to: $OUTPUT_DIR"
echo ""
echo "Key findings:"
echo "- SUID binaries: $(grep -c '' "$OUTPUT_DIR/suid-binaries.txt" 2>/dev/null || echo 0)"
echo "- Writable files: $(grep -c '' "$OUTPUT_DIR/writable-files.txt" 2>/dev/null || echo 0)"
echo "- Interesting files: $(grep -c '' "$OUTPUT_DIR/interesting-files.txt" 2>/dev/null || echo 0)"
echo ""
echo "Review the output files for detailed findings."
echo "Use check-suid.sh, check-sudo.sh, and check-cron.sh for specific vulnerability checks."
