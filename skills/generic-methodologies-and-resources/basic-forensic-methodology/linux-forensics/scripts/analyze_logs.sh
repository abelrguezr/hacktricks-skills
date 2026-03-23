#!/bin/bash
# Linux Forensics - Log Analysis Script
# Usage: ./analyze_logs.sh [output_directory]

OUTPUT_DIR="${1:-./forensics_output}"
mkdir -p "$OUTPUT_DIR/logs"

echo "=== Linux Forensics - Log Analysis ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "Output directory: $OUTPUT_DIR/logs"
echo ""

# Authentication logs
echo "=== Authentication Logs ==="

# Debian/Ubuntu
if [ -f "/var/log/auth.log" ]; then
    echo "--- Auth.log Analysis ---"
    grep -iE "session opened for|accepted password|new session|failed password|invalid user|authentication failure" /var/log/auth.log > "$OUTPUT_DIR/logs/auth_events.txt" 2>&1
    grep -iE "sudo|su:" /var/log/auth.log > "$OUTPUT_DIR/logs/sudo_events.txt" 2>&1
    grep -iE "not in sudoers|authentication failure" /var/log/auth.log > "$OUTPUT_DIR/logs/auth_failures.txt" 2>&1
fi

# RedHat/CentOS
if [ -f "/var/log/secure" ]; then
    echo "--- Secure Log Analysis ---"
    grep -iE "session opened for|accepted password|new session|failed password|invalid user" /var/log/secure > "$OUTPUT_DIR/logs/secure_events.txt" 2>&1
    grep -iE "sudo|su:" /var/log/secure > "$OUTPUT_DIR/logs/secure_sudo.txt" 2>&1
fi

# Failed login attempts
echo "--- Failed Login Attempts ---"
if [ -f "/var/log/faillog" ]; then
    faillog -a > "$OUTPUT_DIR/logs/faillog.txt" 2>&1
fi
if [ -f "/var/log/btmp" ]; then
    lastb > "$OUTPUT_DIR/logs/lastb.txt" 2>&1
fi

echo ""

# System logs
echo "=== System Logs ==="

# Main system log
if [ -f "/var/log/syslog" ]; then
    echo "--- Syslog (last 1000 lines) ---"
    tail -1000 /var/log/syslog > "$OUTPUT_DIR/logs/syslog_recent.txt" 2>&1
fi

if [ -f "/var/log/messages" ]; then
    echo "--- Messages (last 1000 lines) ---"
    tail -1000 /var/log/messages > "$OUTPUT_DIR/logs/messages_recent.txt" 2>&1
fi

# Boot log
if [ -f "/var/log/boot.log" ]; then
    cat /var/log/boot.log > "$OUTPUT_DIR/logs/boot.log" 2>&1
fi

# Kernel log
if [ -f "/var/log/kern.log" ]; then
    tail -500 /var/log/kern.log > "$OUTPUT_DIR/logs/kern.log" 2>&1
fi

# Dmesg
if command -v dmesg &>/dev/null; then
    dmesg > "$OUTPUT_DIR/logs/dmesg.txt" 2>&1
fi

echo ""

# Service logs
echo "=== Service Logs ==="

# Cron
if [ -f "/var/log/cron" ]; then
    cat /var/log/cron > "$OUTPUT_DIR/logs/cron.log" 2>&1
fi

# Daemon
if [ -f "/var/log/daemon.log" ]; then
    tail -500 /var/log/daemon.log > "$OUTPUT_DIR/logs/daemon.log" 2>&1
fi

# Mail
if [ -f "/var/log/mail.log" ] || [ -f "/var/log/maillog" ]; then
    if [ -f "/var/log/mail.log" ]; then
        tail -500 /var/log/mail.log > "$OUTPUT_DIR/logs/mail.log" 2>&1
    else
        tail -500 /var/log/maillog > "$OUTPUT_DIR/logs/maillog.txt" 2>&1
    fi
fi

# Web server logs
if [ -d "/var/log/httpd" ]; then
    ls -la /var/log/httpd/ > "$OUTPUT_DIR/logs/httpd_list.txt" 2>&1
    tail -500 /var/log/httpd/access_log > "$OUTPUT_DIR/logs/httpd_access.txt" 2>&1
    tail -500 /var/log/httpd/error_log > "$OUTPUT_DIR/logs/httpd_error.txt" 2>&1
fi

if [ -d "/var/log/apache2" ]; then
    ls -la /var/log/apache2/ > "$OUTPUT_DIR/logs/apache2_list.txt" 2>&1
    tail -500 /var/log/apache2/access.log > "$OUTPUT_DIR/logs/apache2_access.txt" 2>&1
    tail -500 /var/log/apache2/error.log > "$OUTPUT_DIR/logs/apache2_error.txt" 2>&1
fi

# MySQL
if [ -f "/var/log/mysqld.log" ] || [ -f "/var/log/mysql.log" ]; then
    if [ -f "/var/log/mysqld.log" ]; then
        tail -500 /var/log/mysqld.log > "$OUTPUT_DIR/logs/mysql.log" 2>&1
    else
        tail -500 /var/log/mysql.log > "$OUTPUT_DIR/logs/mysql.log" 2>&1
    fi
fi

# FTP
if [ -f "/var/log/xferlog" ]; then
    cat /var/log/xferlog > "$OUTPUT_DIR/logs/xferlog.txt" 2>&1
fi

echo ""

# User history files
echo "=== User History Files ==="

for user_home in /home/* /root; do
    username=$(basename "$user_home")
    mkdir -p "$OUTPUT_DIR/logs/history/$username"
    
    # Shell history
    if [ -f "$user_home/.bash_history" ]; then
        cat "$user_home/.bash_history" > "$OUTPUT_DIR/logs/history/$username/bash_history.txt" 2>&1
    fi
    if [ -f "$user_home/.zsh_history" ]; then
        cat "$user_home/.zsh_history" > "$OUTPUT_DIR/logs/history/$username/zsh_history.txt" 2>&1
    fi
    
    # Application history
    if [ -f "$user_home/.mysql_history" ]; then
        cat "$user_home/.mysql_history" > "$OUTPUT_DIR/logs/history/$username/mysql_history.txt" 2>&1
    fi
    if [ -f "$user_home/.python_history" ]; then
        cat "$user_home/.python_history" > "$OUTPUT_DIR/logs/history/$username/python_history.txt" 2>&1
    fi
    if [ -f "$user_home/.viminfo" ]; then
        cat "$user_home/.viminfo" > "$OUTPUT_DIR/logs/history/$username/viminfo.txt" 2>&1
    fi
    if [ -f "$user_home/.lesshst" ]; then
        cat "$user_home/.lesshst" > "$OUTPUT_DIR/logs/history/$username/lesshst.txt" 2>&1
    fi
    if [ -f "$user_home/.ftp_history" ]; then
        cat "$user_home/.ftp_history" > "$OUTPUT_DIR/logs/history/$username/ftp_history.txt" 2>&1
    fi
    if [ -f "$user_home/.sftp_history" ]; then
        cat "$user_home/.sftp_history" > "$OUTPUT_DIR/logs/history/$username/sftp_history.txt" 2>&1
    fi
    
    # SSH keys
    if [ -d "$user_home/.ssh" ]; then
        ls -la "$user_home/.ssh/" > "$OUTPUT_DIR/logs/history/$username/ssh_list.txt" 2>&1
        if [ -f "$user_home/.ssh/known_hosts" ]; then
            cat "$user_home/.ssh/known_hosts" > "$OUTPUT_DIR/logs/history/$username/known_hosts.txt" 2>&1
        fi
    fi
done

echo ""

# Look for log gaps or tampering
echo "=== Log Integrity Check ==="

# Check for gaps in syslog
if [ -f "/var/log/syslog" ]; then
    echo "--- Syslog Timeline Analysis ---"
    awk '{print $1, $2, $3}' /var/log/syslog | sort | uniq -c | sort -n | tail -20 > "$OUTPUT_DIR/logs/syslog_timeline.txt" 2>&1
fi

# Check for deleted log entries (look for rotation patterns)
echo "--- Log Rotation Check ---"
ls -la /var/log/*.gz /var/log/*.[0-9]* 2>/dev/null > "$OUTPUT_DIR/logs/log_rotation.txt"

echo ""
echo "=== Log Analysis Complete ==="
echo "All output saved to: $OUTPUT_DIR/logs"
echo ""
echo "Key files to review:"
echo "- $OUTPUT_DIR/logs/auth_events.txt (authentication events)"
echo "- $OUTPUT_DIR/logs/auth_failures.txt (failed authentications)"
echo "- $OUTPUT_DIR/logs/sudo_events.txt (sudo usage)"
echo "- $OUTPUT_DIR/logs/history/ (user command history)"
