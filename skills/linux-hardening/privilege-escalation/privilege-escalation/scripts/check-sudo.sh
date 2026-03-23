#!/bin/bash
# Check for sudo misconfigurations

echo "=== Sudo Configuration Check ==="
echo ""

# Check if sudo is available
if ! command -v sudo &> /dev/null; then
  echo "Sudo not installed"
  exit 0
fi

echo "Sudo permissions:"
sudo -l 2>/dev/null || echo "No sudo access"
echo ""

# Check for NOPASSWD entries
echo "Checking for NOPASSWD entries:"
NOPASSWD=$(sudo -l 2>/dev/null | grep -i nopasswd)
if [ -n "$NOPASSWD" ]; then
  echo "  [!] NOPASSWD entries found:"
  echo "$NOPASSWD" | sed 's/^/    /'
else
  echo "  No NOPASSWD entries"
fi
echo ""

# Check for env_keep settings
echo "Checking for env_keep settings:"
ENV_KEEP=$(sudo -l 2>/dev/null | grep -i env_keep)
if [ -n "$ENV_KEEP" ]; then
  echo "  [!] env_keep settings found:"
  echo "$ENV_KEEP" | sed 's/^/    /'
  echo "  This could allow environment variable injection attacks"
else
  echo "  No env_keep settings"
fi
echo ""

# Check for SETENV
echo "Checking for SETENV:"
SETENV=$(sudo -l 2>/dev/null | grep -i setenv)
if [ -n "$SETENV" ]; then
  echo "  [!] SETENV found:"
  echo "$SETENV" | sed 's/^/    /'
else
  echo "  No SETENV"
fi
echo ""

# Check sudoers files
echo "Sudoers files:"
if [ -r /etc/sudoers ]; then
  echo "  /etc/sudoers - readable"
else
  echo "  /etc/sudoers - not readable"
fi

if [ -d /etc/sudoers.d ]; then
  echo "  /etc/sudoers.d/ contents:"
  ls -la /etc/sudoers.d/ 2>/dev/null | while read line; do
    echo "    $line"
  done
else
  echo "  /etc/sudoers.d/ - not found"
fi
echo ""

# Check for common dangerous sudo commands
echo "Checking for dangerous sudo commands:"
DANGEROUS_CMDS=$(sudo -l 2>/dev/null | grep -oE '/[a-zA-Z0-9/_-]+' | sort -u)
for cmd in $DANGEROUS_CMDS; do
  case "$cmd" in
    */vim|*/vi|*/nano|*/less|*/more|*/find|*/awk|*/python*|*/perl|*/ruby|*/bash|*/sh|*/cat|*/cp|*/mv|*/rm|*/chmod|*/chown)
      echo "  [!] $cmd - Potentially exploitable"
      ;;
  esac
done

echo ""
echo "Recommendations:"
echo "- Check GTFOBins for exploitation methods"
echo "- Test if commands can be used to spawn shells"
echo "- Check for writable scripts in sudo commands"
