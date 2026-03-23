#!/bin/bash
# find-vulnerabilities.sh
# Find common Linux vulnerabilities
# Usage: sudo ./find-vulnerabilities.sh [output_dir]

set -e

OUTPUT_DIR="${1:-./vuln_scan_results}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="${OUTPUT_DIR}_${TIMESTAMP}"

mkdir -p "$OUTPUT_DIR"

echo "=== Linux Vulnerability Scanner ==="
echo "Started: $(date)"
echo "Output directory: $OUTPUT_DIR"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "WARNING: Not running as root. Some checks may be incomplete."
    echo "Run with sudo for full results."
    echo ""
fi

# Function to run find with common exclusions
find_with_exclusions() {
    local args="$@"
    find $args 2>/dev/null | grep -v "| /proc" | grep -v "| /dev" | grep -v "| /run" | grep -v "| /var/log" | grep -v "| /boot" | grep -v "| /sys/"
}

echo "1. Finding SUID files..."
find / -perm /u=s -ls 2>/dev/null > "$OUTPUT_DIR/suid_files.txt" || true
echo "   Found $(wc -l < "$OUTPUT_DIR/suid_files.txt") SUID files"

echo ""
echo "2. Finding SGID files..."
find / -perm /g=s -ls 2>/dev/null > "$OUTPUT_DIR/sgid_files.txt" || true
echo "   Found $(wc -l < "$OUTPUT_DIR/sgid_files.txt") SGID files"

echo ""
echo "3. Finding world-writable directories..."
find / -type d -perm -0002 -maxdepth 10 2>/dev/null > "$OUTPUT_DIR/writable_dirs.txt" || true
echo "   Found $(wc -l < "$OUTPUT_DIR/writable_dirs.txt") world-writable directories"

echo ""
echo "4. Finding world-writable files..."
find / -type f -perm -0002 -maxdepth 10 2>/dev/null > "$OUTPUT_DIR/writable_files.txt" || true
echo "   Found $(wc -l < "$OUTPUT_DIR/writable_files.txt") world-writable files"

echo ""
echo "5. Finding files owned by current user..."
find / -user $(id -u) -maxdepth 10 2>/dev/null > "$OUTPUT_DIR/user_owned.txt" || true
echo "   Found $(wc -l < "$OUTPUT_DIR/user_owned.txt") files owned by $(whoami)"

echo ""
echo "6. Finding recent files (last 7 days)..."
find / -type f -mtime -7 -maxdepth 10 2>/dev/null > "$OUTPUT_DIR/recent_files.txt" || true
echo "   Found $(wc -l < "$OUTPUT_DIR/recent_files.txt") files modified in last 7 days"

echo ""
echo "7. Finding readable config files..."
find /etc -type f -readable -maxdepth 3 2>/dev/null > "$OUTPUT_DIR/etc_readable.txt" || true
echo "   Found $(wc -l < "$OUTPUT_DIR/etc_readable.txt") readable files in /etc"

echo ""
echo "8. Finding hidden files..."
find /home -name ".*" -type f 2>/dev/null > "$OUTPUT_DIR/hidden_files.txt" || true
echo "   Found $(wc -l < "$OUTPUT_DIR/hidden_files.txt") hidden files in /home"

echo ""
echo "9. Finding SSH keys..."
find / -name "id_rsa*" -o -name "*.pem" 2>/dev/null > "$OUTPUT_DIR/ssh_keys.txt" || true
echo "   Found $(wc -l < "$OUTPUT_DIR/ssh_keys.txt") potential SSH key files"

echo ""
echo "10. Finding cron jobs..."
if [ -d /etc/cron.d ]; then
    ls -la /etc/cron.d/ > "$OUTPUT_DIR/cron_d.txt" 2>/dev/null || true
fi
if [ -f /etc/crontab ]; then
    cat /etc/crontab > "$OUTPUT_DIR/crontab.txt" 2>/dev/null || true
fi
if [ -d /var/spool/cron ]; then
    ls -la /var/spool/cron/ > "$OUTPUT_DIR/spool_cron.txt" 2>/dev/null || true
fi
echo "   Cron configuration saved"

echo ""
echo "11. Finding loaded kernel modules..."
lsmod > "$OUTPUT_DIR/kernel_modules.txt" 2>/dev/null || true
echo "   Found $(wc -l < "$OUTPUT_DIR/kernel_modules.txt") kernel modules"

echo ""
echo "12. Finding processes with open network connections..."
if command -v lsof &> /dev/null; then
    lsof -i 2>/dev/null > "$OUTPUT_DIR/network_connections.txt" || true
    echo "   Found $(wc -l < "$OUTPUT_DIR/network_connections.txt") network connections"
else
    echo "   lsof not available, skipping"
fi

echo ""
echo "13. Finding deleted but open files..."
if command -v lsof &> /dev/null; then
    lsof +L1 2>/dev/null > "$OUTPUT_DIR/deleted_open_files.txt" || true
    echo "   Found $(wc -l < "$OUTPUT_DIR/deleted_open_files.txt") deleted but open files"
else
    echo "   lsof not available, skipping"
fi

echo ""
echo "14. Checking eBPF programs (requires root)..."
if [ "$EUID" -eq 0 ] && command -v bpftool &> /dev/null; then
    bpftool prog 2>/dev/null > "$OUTPUT_DIR/ebpf_programs.txt" || true
    echo "   Found $(wc -l < "$OUTPUT_DIR/ebpf_programs.txt") eBPF programs"
else
    echo "   Skipping (not root or bpftool not available)"
fi

echo ""
echo "=== Scan Complete ==="
echo "Finished: $(date)"
echo ""
echo "Results saved to: $OUTPUT_DIR"
echo ""
echo "Key files to review:"
echo "  - suid_files.txt: Potential privilege escalation vectors"
echo "  - writable_dirs.txt: World-writable directories"
echo "  - ssh_keys.txt: SSH key files (check for weak keys)"
echo "  - kernel_modules.txt: Loaded modules (check for rootkits)"
echo "  - ebpf_programs.txt: eBPF programs (check for malicious code)"
