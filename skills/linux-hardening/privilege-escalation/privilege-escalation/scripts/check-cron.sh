#!/bin/bash
# Check for cron job vulnerabilities

echo "=== Cron Job Check ==="
echo ""

# Check user crontab
echo "User crontab:"
crontab -l 2>/dev/null || echo "No user crontab"
echo ""

# Check system cron directories
echo "System cron directories:"
for dir in /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly; do
  if [ -d "$dir" ]; then
    echo "  $dir:"
    ls -la "$dir" 2>/dev/null | while read line; do
      echo "    $line"
    done
  fi
done
echo ""

# Check crontab contents
echo "Crontab contents (non-comment lines):"
for file in /etc/crontab /etc/cron.d/* /var/spool/cron/crontabs/*; do
  if [ -f "$file" ] && [ -r "$file" ]; then
    echo "  $file:"
    grep -v "^#" "$file" 2>/dev/null | grep -v "^$" | while read line; do
      echo "    $line"
      
      # Check for wildcards
      if echo "$line" | grep -q '\*'; then
        echo "      [!] Contains wildcard - potential injection risk"
      fi
      
      # Check for relative paths
      if echo "$line" | grep -qE '[a-zA-Z0-9_-]+\s'; then
        echo "      [!] May use relative path - PATH hijacking risk"
      fi
    done
  fi
done
echo ""

# Check for writable cron scripts
echo "Checking for writable cron scripts:"
for file in /etc/crontab /etc/cron.d/* /var/spool/cron/crontabs/*; do
  if [ -f "$file" ]; then
    if [ -w "$file" ]; then
      echo "  [!] $file - Writable"
    fi
  fi
done
echo ""

# Check cron PATH
echo "Cron PATH configuration:"
CRON_PATH=$(grep -i "^PATH=" /etc/crontab 2>/dev/null)
if [ -n "$CRON_PATH" ]; then
  echo "  $CRON_PATH"
  echo "  Checking for writable directories in cron PATH..."
  for dir in $(echo "$CRON_PATH" | cut -d= -f2 | tr ':' '\n'); do
    if [ -d "$dir" ] && [ -w "$dir" ]; then
      echo "    [!] $dir - Writable"
    fi
  done
else
  echo "  No custom PATH in crontab"
fi
echo ""

# Check for frequent cron jobs
echo "Checking for frequently running cron jobs:"
echo "  Monitor with: pspy -a or watch -n 1 'ps aux | grep cron'"
echo ""

echo "Recommendations:"
echo "- Check for writable scripts executed by cron"
echo "- Look for wildcard injection vulnerabilities"
echo "- Check for PATH hijacking opportunities"
echo "- Monitor cron execution with pspy"
