#!/bin/bash
# Check cron jobs for common vulnerabilities
# - Writable scripts
# - Wildcard injection
# - PATH manipulation

echo "=== CRON VULNERABILITY CHECK ==="
echo ""

# Check user crontab
echo "[1] USER CRONTAB ANALYSIS"
USER_CRON=$(crontab -l 2>/dev/null)
if [ -n "$USER_CRON" ]; then
    echo "$USER_CRON" | while read line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^# ]] && continue
        [[ -z "$line" ]] && continue
        
        echo "Checking: $line"
        
        # Check for wildcards in script paths
        if [[ "$line" =~ \*\* ]] && [[ ! "$line" =~ ^[0-9*\,\-\/]+ ]]; then
            echo "  [!] WARNING: Wildcard found in cron entry"
        fi
        
        # Check for scripts in PATH
        if [[ "$line" =~ [a-zA-Z0-9_]+\.[sh|py|pl|rb] ]]; then
            script=$(echo "$line" | grep -oE '[a-zA-Z0-9_]+\.[sh|py|pl|rb]' | head -1)
            if [ -f "$script" ] && [ -w "$script" ]; then
                echo "  [!] WARNING: Writable script in cron: $script"
            fi
        fi
    done
else
    echo "No user crontab found"
fi
echo ""

# Check system crontabs
echo "[2] SYSTEM CRONTAB ANALYSIS"
for cronfile in /etc/crontab /etc/cron.d/* /etc/cron.daily/* /etc/cron.hourly/* /etc/cron.weekly/* /etc/cron.monthly/*; do
    if [ -f "$cronfile" ]; then
        echo "Checking: $cronfile"
        cat "$cronfile" | while read line; do
            [[ "$line" =~ ^# ]] && continue
            [[ -z "$line" ]] && continue
            
            # Check for wildcards
            if [[ "$line" =~ \*\* ]] && [[ ! "$line" =~ ^[0-9*\,\-\/]+ ]]; then
                echo "  [!] WARNING: Wildcard found"
            fi
            
            # Check for writable scripts
            if [[ "$line" =~ /[^ ]+\.[sh|py|pl|rb] ]]; then
                script=$(echo "$line" | grep -oE '/[^ ]+\.[sh|py|pl|rb]' | head -1)
                if [ -f "$script" ] && [ -w "$script" ]; then
                    echo "  [!] WARNING: Writable script: $script"
                fi
            fi
        done
    fi
done
echo ""

# Check PATH in cron
echo "[3] PATH IN CRON JOBS"
grep -r "PATH=" /etc/cron* 2>/dev/null | head -10
echo ""

echo "=== CRON CHECK COMPLETE ==="
