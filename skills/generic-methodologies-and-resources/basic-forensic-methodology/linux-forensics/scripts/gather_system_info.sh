#!/bin/bash
# Linux Forensics - Initial System Information Gathering
# Usage: ./gather_system_info.sh [output_directory]

OUTPUT_DIR="${1:-./forensics_output}"
mkdir -p "$OUTPUT_DIR"

echo "=== Linux Forensics - System Information Gathering ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "Output directory: $OUTPUT_DIR"
echo ""

# System identification
echo "=== System Identification ==="
echo "Hostname: $(hostname)"
echo "Kernel: $(uname -a)"
echo "Date/Time: $(date)"
echo "Timezone: $(timedatectl 2>/dev/null || echo 'N/A')"
echo ""

# Network information
echo "=== Network Configuration ==="
if command -v ip &>/dev/null; then
    ip a > "$OUTPUT_DIR/network_interfaces.txt" 2>&1
    ip route > "$OUTPUT_DIR/routing_table.txt" 2>&1
else
    ifconfig -a > "$OUTPUT_DIR/network_interfaces.txt" 2>&1
    route -n > "$OUTPUT_DIR/routing_table.txt" 2>&1
fi
netstat -anp > "$OUTPUT_DIR/network_connections.txt" 2>&1 || ss -anp > "$OUTPUT_DIR/network_connections.txt" 2>&1
echo ""

# Running processes
echo "=== Running Processes ==="
ps -ef > "$OUTPUT_DIR/processes.txt" 2>&1
ps aux > "$OUTPUT_DIR/processes_detailed.txt" 2>&1
echo ""

# Open files and network
echo "=== Open Files ==="
lsof -V > "$OUTPUT_DIR/open_files.txt" 2>&1 || echo "lsof not available" > "$OUTPUT_DIR/open_files.txt"
echo ""

# System resources
echo "=== System Resources ==="
df -h > "$OUTPUT_DIR/disk_space.txt" 2>&1
mount > "$OUTPUT_DIR/mounted_devices.txt" 2>&1
free -h > "$OUTPUT_DIR/memory.txt" 2>&1
echo ""

# User activity
echo "=== User Activity ==="
w > "$OUTPUT_DIR/current_users.txt" 2>&1
last -Faiwx > "$OUTPUT_DIR/login_history.txt" 2>&1
echo ""

# Kernel modules
echo "=== Kernel Modules ==="
lsmod > "$OUTPUT_DIR/kernel_modules.txt" 2>&1
echo ""

# User accounts
echo "=== User Accounts ==="
cat /etc/passwd > "$OUTPUT_DIR/passwd.txt" 2>&1
cat /etc/shadow > "$OUTPUT_DIR/shadow.txt" 2>&1 || echo "Permission denied" > "$OUTPUT_DIR/shadow.txt"
cat /etc/groups > "$OUTPUT_DIR/groups.txt" 2>&1
echo ""

# Recently modified files
echo "=== Recently Modified Files (last 24 hours) ==="
find / -type f -mtime -1 -print 2>/dev/null > "$OUTPUT_DIR/recent_files.txt"
echo ""

# Suspicious indicators
echo "=== Suspicious Indicators ==="

# Root processes with high PIDs
echo "Root processes with PID > 1000:"
ps -ef | awk '$1=="root" && $2>1000 {print}' > "$OUTPUT_DIR/suspicious_root_processes.txt"

# Users without shells with password hashes
echo "Users without shells:"
awk -F: '$7 !~ /\/bin\/(sh|bash|zsh|csh|ksh|dash|nologin|false)/ && $7 != "" {print $1}' /etc/passwd > "$OUTPUT_DIR/users_without_shells.txt"

echo ""
echo "=== Collection Complete ==="
echo "All output saved to: $OUTPUT_DIR"
echo ""
echo "Next steps:"
echo "1. Review suspicious indicators in $OUTPUT_DIR/suspicious_*.txt"
echo "2. Run check_autostart.sh to scan persistence locations"
echo "3. Run analyze_logs.sh to extract key log entries"
