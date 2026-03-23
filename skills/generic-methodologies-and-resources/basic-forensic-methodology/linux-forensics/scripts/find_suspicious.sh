#!/bin/bash
# Linux Forensics - Suspicious File and Indicator Scanner
# Usage: ./find_suspicious.sh [output_directory]

OUTPUT_DIR="${1:-./forensics_output}"
mkdir -p "$OUTPUT_DIR/suspicious"

echo "=== Linux Forensics - Suspicious Indicator Scanner ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "Output directory: $OUTPUT_DIR/suspicious"
echo ""

# Setuid/setgid files
echo "=== Setuid/Setgid Files ==="
echo "--- Setuid Root Files ---"
find / -user root -perm -04000 -type f 2>/dev/null > "$OUTPUT_DIR/suspicious/setuid_root.txt"
echo "--- Setgid Files ---"
find / -perm -02000 -type f 2>/dev/null > "$OUTPUT_DIR/suspicious/setgid_files.txt"
echo "--- All Setuid/Setgid ---"
find / -perm -4000 -o -perm -2000 2>/dev/null > "$OUTPUT_DIR/suspicious/all_setuid_setgid.txt"

echo ""

# Recently modified system files
echo "=== Recently Modified System Files ==="
echo "--- /bin and /sbin (last 7 days) ---"
find /bin /sbin -type f -mtime -7 2>/dev/null > "$OUTPUT_DIR/suspicious/recent_bin_sbin.txt"
echo "--- /usr/bin and /usr/sbin (last 7 days) ---"
find /usr/bin /usr/sbin -type f -mtime -7 2>/dev/null > "$OUTPUT_DIR/suspicious/recent_usr_bin.txt"
echo "--- /etc (last 7 days) ---"
find /etc -type f -mtime -7 2>/dev/null > "$OUTPUT_DIR/suspicious/recent_etc.txt"

echo ""

# Hidden files and directories
echo "=== Hidden Files and Directories ==="
echo "--- Files starting with dot in system directories ---"
find /bin /sbin /usr/bin /usr/sbin /etc -name ".*" -type f 2>/dev/null > "$OUTPUT_DIR/suspicious/hidden_system_files.txt"
echo "--- Files with unusual hidden names ---"
find / -name ".. *" -o -name "..^G" 2>/dev/null > "$OUTPUT_DIR/suspicious/unusual_hidden.txt"

echo ""

# Files in /tmp and /var/tmp
echo "=== Temporary Directory Analysis ==="
echo "--- /tmp contents ---"
ls -laR /tmp/ > "$OUTPUT_DIR/suspicious/tmp_contents.txt" 2>&1
echo "--- /var/tmp contents ---"
ls -laR /var/tmp/ > "$OUTPUT_DIR/suspicious/var_tmp_contents.txt" 2>&1
echo "--- Executables in /tmp ---"
find /tmp /var/tmp -type f -executable 2>/dev/null > "$OUTPUT_DIR/suspicious/tmp_executables.txt"

echo ""

# Unusual files in /dev
echo "=== /dev Directory Analysis ==="
ls -la /dev/ > "$OUTPUT_DIR/suspicious/dev_contents.txt" 2>&1
find /dev -type f 2>/dev/null > "$OUTPUT_DIR/suspicious/dev_regular_files.txt"

echo ""

# Deleted files still open
echo "=== Deleted Files Still Open ==="
if command -v lsof &>/dev/null; then
    lsof +L1 > "$OUTPUT_DIR/suspicious/deleted_open_files.txt" 2>&1
    lsof | grep '(deleted)' > "$OUTPUT_DIR/suspicious/deleted_files.txt" 2>&1
else
    echo "lsof not available" > "$OUTPUT_DIR/suspicious/deleted_files.txt"
fi

echo ""

# Scripts in PATH
echo "=== Scripts in PATH ==="
echo "--- Shell scripts in PATH ---"
for dir in $(echo $PATH | tr ':' ' '); do
    if [ -d "$dir" ]; then
        find "$dir" -type f \( -name "*.sh" -o -name "*.bash" \) 2>/dev/null >> "$OUTPUT_DIR/suspicious/scripts_in_path.txt"
    fi
done
echo "--- PHP scripts in PATH ---"
for dir in $(echo $PATH | tr ':' ' '); do
    if [ -d "$dir" ]; then
        find "$dir" -type f -name "*.php" 2>/dev/null >> "$OUTPUT_DIR/suspicious/php_in_path.txt"
    fi
done

echo ""

# Inode analysis
echo "=== Inode Analysis ==="
echo "--- Inode pressure ---"
df -i > "$OUTPUT_DIR/suspicious/inode_pressure.txt" 2>&1
echo "--- Files sorted by inode in /bin ---"
ls -lai /bin 2>/dev/null | sort -n > "$OUTPUT_DIR/suspicious/bin_inodes.txt"

echo ""

# Check for rootkit indicators
echo "=== Rootkit Indicators ==="
echo "--- Modified ls/ps/netstat ---"
for cmd in ls ps netstat ifconfig; do
    if command -v $cmd &>/dev/null; then
        which $cmd >> "$OUTPUT_DIR/suspicious/command_paths.txt"
        ldd $(which $cmd) 2>/dev/null >> "$OUTPUT_DIR/suspicious/command_libraries.txt"
    fi
done

echo ""

# Network connections to suspicious ports
echo "=== Network Analysis ==="
if command -v netstat &>/dev/null; then
    netstat -anp 2>/dev/null > "$OUTPUT_DIR/suspicious/network_connections.txt"
    netstat -anp 2>/dev/null | grep -E ':4444|:5555|:6666|:31337|:12345' > "$OUTPUT_DIR/suspicious/suspicious_ports.txt"
elif command -v ss &>/dev/null; then
    ss -anp 2>/dev/null > "$OUTPUT_DIR/suspicious/network_connections.txt"
    ss -anp 2>/dev/null | grep -E ':4444|:5555|:6666|:31337|:12345' > "$OUTPUT_DIR/suspicious/suspicious_ports.txt"
fi

echo ""

# Check for reverse shells indicators
echo "=== Reverse Shell Indicators ==="
ps aux 2>/dev/null | grep -E 'nc -e|/dev/tcp|bash -i|python.*socket|perl.*socket|ruby.*socket' > "$OUTPUT_DIR/suspicious/reverse_shell_processes.txt"

echo ""

# Check for crypto mining
echo "=== Cryptocurrency Mining Indicators ==="
ps aux 2>/dev/null | grep -E 'xmrig|minerd|cgminer|bfgminer|stratum|pool\.mining' > "$OUTPUT_DIR/suspicious/crypto_miners.txt"

echo ""

# Check for web shells
echo "=== Web Shell Indicators ==="
find /var/www -type f -name "*.php" -exec grep -l -E 'eval\(|base64_decode|system\(|exec\(|passthru\(' {} \; 2>/dev/null > "$OUTPUT_DIR/suspicious/web_shells.txt"

echo ""

echo "=== Suspicious Indicator Scan Complete ==="
echo "All output saved to: $OUTPUT_DIR/suspicious"
echo ""
echo "Priority files to review:"
echo "- $OUTPUT_DIR/suspicious/setuid_root.txt (elevated permission files)"
echo "- $OUTPUT_DIR/suspicious/recent_bin_sbin.txt (modified system binaries)"
echo "- $OUTPUT_DIR/suspicious/tmp_executables.txt (executables in temp)"
echo "- $OUTPUT_DIR/suspicious/deleted_files.txt (deleted but open files)"
echo "- $OUTPUT_DIR/suspicious/reverse_shell_processes.txt (potential reverse shells)"
