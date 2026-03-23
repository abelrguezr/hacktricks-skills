#!/bin/bash
# Linux Forensics - Autostart and Persistence Location Scanner
# Usage: ./check_autostart.sh [output_directory]

OUTPUT_DIR="${1:-./forensics_output}"
mkdir -p "$OUTPUT_DIR/autostart"

echo "=== Linux Forensics - Autostart/Persistence Scanner ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "Output directory: $OUTPUT_DIR/autostart"
echo ""

# Cron and scheduled tasks
echo "=== Cron and Scheduled Tasks ==="

# System crontabs
echo "--- System Crontabs ---"
for crontab_dir in /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly; do
    if [ -d "$crontab_dir" ]; then
        echo "Contents of $crontab_dir:"
        ls -la "$crontab_dir" >> "$OUTPUT_DIR/autostart/cron_directories.txt" 2>&1
        find "$crontab_dir" -type f -exec echo "=== {} ===" \; -exec cat {} \; >> "$OUTPUT_DIR/autostart/cron_contents.txt" 2>&1
    fi
done

# User crontabs
echo "--- User Crontabs ---"
if [ -d "/var/spool/cron/crontabs" ]; then
    ls -la /var/spool/cron/crontabs/ > "$OUTPUT_DIR/autostart/user_crontabs.txt" 2>&1
    cat /var/spool/cron/crontabs/* >> "$OUTPUT_DIR/autostart/user_crontab_contents.txt" 2>&1
fi

# Anacron
echo "--- Anacron ---"
if [ -f "/etc/anacrontab" ]; then
    cat /etc/anacrontab > "$OUTPUT_DIR/autostart/anacrontab.txt" 2>&1
fi
if [ -d "/var/spool/anacron" ]; then
    ls -la /var/spool/anacron/ > "$OUTPUT_DIR/autostart/anacron_spool.txt" 2>&1
fi

# 0anacron stubs (common persistence location)
echo "--- 0anacron Stubs ---"
for d in /etc/cron.*; do
    if [ -f "$d/0anacron" ]; then
        stat -c '%n %y %s' "$d/0anacron" >> "$OUTPUT_DIR/autostart/0anacron_info.txt" 2>&1
        echo "=== $d/0anacron ===" >> "$OUTPUT_DIR/autostart/0anacron_contents.txt"
        cat "$d/0anacron" >> "$OUTPUT_DIR/autostart/0anacron_contents.txt" 2>&1
    fi
done

# Search for suspicious commands in cron
echo "--- Suspicious Commands in Cron ---"
find /etc/cron.* -type f 2>/dev/null | xargs grep -l -E 'curl|wget|/bin/sh|python|bash -c|nc |netcat|/dev/tcp' 2>/dev/null > "$OUTPUT_DIR/autostart/suspicious_cron.txt"
find /etc/cron.* -type f 2>/dev/null | xargs grep -n -E 'curl|wget|/bin/sh|python|bash -c|nc |netcat|/dev/tcp' 2>/dev/null > "$OUTPUT_DIR/autostart/suspicious_cron_details.txt"

echo ""

# SSH configuration
echo "=== SSH Configuration ==="
if [ -f "/etc/ssh/sshd_config" ]; then
    grep -E '^\s*PermitRootLogin|^\s*PasswordAuthentication|^\s*PubkeyAuthentication' /etc/ssh/sshd_config > "$OUTPUT_DIR/autostart/sshd_config.txt" 2>&1
fi

# System accounts with interactive shells
echo "--- System Accounts with Shells ---"
awk -F: '($7 ~ /bin\/(sh|bash|zsh)/ && $1 ~ /^(games|lp|sync|shutdown|halt|mail|operator|daemon|bin|sys|uucp|man)$/) {print}' /etc/passwd > "$OUTPUT_DIR/autostart/suspicious_system_accounts.txt" 2>&1

# Authorized keys
echo "--- SSH Authorized Keys ---"
for user_home in /home/* /root; do
    if [ -f "$user_home/.ssh/authorized_keys" ]; then
        echo "=== $user_home/.ssh/authorized_keys ===" >> "$OUTPUT_DIR/autostart/authorized_keys.txt"
        cat "$user_home/.ssh/authorized_keys" >> "$OUTPUT_DIR/autostart/authorized_keys.txt" 2>&1
    fi
done

echo ""

# Service autostart locations
echo "=== Service Autostart Locations ==="

# Systemd services
echo "--- Systemd Services ---"
if [ -d "/etc/systemd/system" ]; then
    ls -la /etc/systemd/system/ > "$OUTPUT_DIR/autostart/systemd_services.txt" 2>&1
fi
if [ -d "/etc/systemd/system/multi-user.target.wants" ]; then
    ls -la /etc/systemd/system/multi-user.target.wants/ > "$OUTPUT_DIR/autostart/systemd_enabled.txt" 2>&1
fi
if [ -d "/lib/systemd/system" ]; then
    ls -la /lib/systemd/system/ > "$OUTPUT_DIR/autostart/systemd_default.txt" 2>&1
fi

# Init.d scripts
echo "--- Init.d Scripts ---"
if [ -d "/etc/init.d" ]; then
    ls -la /etc/init.d/ > "$OUTPUT_DIR/autostart/initd_scripts.txt" 2>&1
fi

# RC scripts
echo "--- RC Scripts ---"
for rc_dir in /etc/rc.d /etc/rc.boot /etc/rc.local; do
    if [ -e "$rc_dir" ]; then
        ls -la "$rc_dir" >> "$OUTPUT_DIR/autostart/rc_scripts.txt" 2>&1
    fi
done

# User autostart
echo "--- User Autostart ---"
for user_home in /home/* /root; do
    if [ -d "$user_home/.config/autostart" ]; then
        ls -la "$user_home/.config/autostart/" >> "$OUTPUT_DIR/autostart/user_autostart.txt" 2>&1
    fi
done

echo ""

# Kernel modules
echo "=== Kernel Modules ==="
lsmod > "$OUTPUT_DIR/autostart/loaded_modules.txt" 2>&1
if [ -d "/etc/modprobe.d" ]; then
    cat /etc/modprobe.d/* > "$OUTPUT_DIR/autostart/modprobe_config.txt" 2>&1
fi
if [ -f "/etc/modprobe.conf" ]; then
    cat /etc/modprobe.conf >> "$OUTPUT_DIR/autostart/modprobe_config.txt" 2>&1
fi

echo ""

# Login scripts
echo "=== Login Scripts ==="
for script in /etc/profile /etc/bash.bashrc /etc/rc.local ~/.bashrc ~/.bash_profile ~/.profile; do
    if [ -f "$script" ]; then
        echo "=== $script ===" >> "$OUTPUT_DIR/autostart/login_scripts.txt"
        cat "$script" >> "$OUTPUT_DIR/autostart/login_scripts.txt" 2>&1
    fi
done

# Profile.d scripts
if [ -d "/etc/profile.d" ]; then
    ls -la /etc/profile.d/ > "$OUTPUT_DIR/autostart/profile_d.txt" 2>&1
    cat /etc/profile.d/* >> "$OUTPUT_DIR/autostart/profile_d_contents.txt" 2>&1
fi

echo ""

# Cloud C2 indicators
echo "=== Cloud C2 Indicators ==="
ps aux | grep -E '[c]loudflared|trycloudflare' > "$OUTPUT_DIR/autostart/cloudflare_processes.txt" 2>&1
systemctl list-units 2>/dev/null | grep -i cloudflared > "$OUTPUT_DIR/autostart/cloudflare_services.txt" 2>&1

echo ""
echo "=== Autostart Scan Complete ==="
echo "All output saved to: $OUTPUT_DIR/autostart"
echo ""
echo "Review these files for suspicious entries:"
echo "- $OUTPUT_DIR/autostart/suspicious_cron*.txt"
echo "- $OUTPUT_DIR/autostart/suspicious_system_accounts.txt"
echo "- $OUTPUT_DIR/autostart/0anacron*.txt"
