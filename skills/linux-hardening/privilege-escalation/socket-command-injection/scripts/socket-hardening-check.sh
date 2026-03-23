#!/bin/bash
# Socket Hardening Checklist
# Audits a Unix socket for security best practices

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <socket_path>"
    echo "Example: $0 /tmp/socket_test.s"
    exit 1
fi

SOCKET_PATH="$1"
ISSUES=0
WARNINGS=0

echo "[*] Socket Hardening Audit"
echo "[*] Target: $SOCKET_PATH"
echo ""

# Check 1: Socket exists
if [ ! -S "$SOCKET_PATH" ]; then
    echo "[!] Socket does not exist or is not a socket file"
    exit 1
fi
echo "[+] Socket exists"

# Check 2: Socket permissions
echo ""
echo "[*] Checking socket permissions..."
PERMS=$(stat -c '%a' "$SOCKET_PATH" 2>/dev/null || stat -f '%OLp' "$SOCKET_PATH" 2>/dev/null)
OWNER=$(stat -c '%U:%G' "$SOCKET_PATH" 2>/dev/null || stat -f '%Su:%Sg' "$SOCKET_PATH" 2>/dev/null)

echo "    Permissions: $PERMS"
echo "    Owner: $OWNER"

if [ "$PERMS" = "666" ] || [ "$PERMS" = "777" ]; then
    echo "    [!] CRITICAL: Socket is world-writable!"
    echo "        Fix: chmod 600 $SOCKET_PATH"
    ((ISSUES++))
elif [ "$PERMS" = "660" ] || [ "$PERMS" = "664" ]; then
    echo "    [!] WARNING: Socket is group/world readable"
    echo "        Consider: chmod 600 $SOCKET_PATH"
    ((WARNINGS++))
else
    echo "    [✓] Permissions are restrictive"
fi

# Check 3: Socket directory
echo ""
echo "[*] Checking socket directory..."
DIR_PATH=$(dirname "$SOCKET_PATH")
DIR_PERMS=$(stat -c '%a' "$DIR_PATH" 2>/dev/null || stat -f '%OLp' "$DIR_PATH" 2>/dev/null)

echo "    Directory: $DIR_PATH"
echo "    Directory permissions: $DIR_PERMS"

if [ "$DIR_PATH" = "/tmp" ] || [ "$DIR_PATH" = "/var/tmp" ]; then
    echo "    [!] WARNING: Socket in world-writable directory"
    echo "        Consider moving to /var/run or private directory"
    ((WARNINGS++))
fi

if [ "$DIR_PERMS" = "777" ]; then
    echo "    [!] CRITICAL: Socket directory is world-writable!"
    echo "        Fix: chmod 755 $DIR_PATH"
    ((ISSUES++))
fi

# Check 4: Socket ownership
echo ""
echo "[*] Checking socket ownership..."
if [ "$OWNER" = "root:root" ]; then
    echo "    [✓] Socket owned by root"
else
    echo "    [!] Socket owned by: $OWNER"
    echo "        If this should be privileged, ensure it's root:root"
    ((WARNINGS++))
fi

# Check 5: Process listening
echo ""
echo "[*] Checking listening process..."
if command -v netstat &> /dev/null; then
    PROCESS=$(netstat -a -p --unix 2>/dev/null | grep "$SOCKET_PATH" | awk '{print $6}' | head -1)
elif command -v ss &> /dev/null; then
    PROCESS=$(ss -x -l -p 2>/dev/null | grep "$SOCKET_PATH" | grep -oP 'users:\(\"\K[^"]+' | head -1)
else
    PROCESS="unknown (install netstat or ss)"
fi

echo "    Process: $PROCESS"

# Check 6: Recommendations
echo ""
echo "[*] Hardening Recommendations"
echo ""

echo "1. Socket Permissions:"
echo "   chmod 600 $SOCKET_PATH"
echo "   chown root:root $SOCKET_PATH"
echo ""

echo "2. If in /tmp, move to secure location:"
echo "   mkdir -p /var/run/secure-sockets"
echo "   chmod 750 /var/run/secure-sockets"
echo "   chown root:root /var/run/secure-sockets"
echo ""

echo "3. Code-level hardening:"
echo "   - Never use os.system() with socket input"
echo "   - Never use subprocess with shell=True"
echo "   - Validate and whitelist all commands"
echo "   - Implement authentication (SO_PEERCRED)"
echo "   - Don't use client-controlled TIDs for privileged operations"
echo ""

echo "[*] Summary"
echo "    Issues: $ISSUES"
echo "    Warnings: $WARNINGS"

if [ $ISSUES -gt 0 ]; then
    echo ""
    echo "[!] CRITICAL: Found $ISSUES security issues that need immediate attention"
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo ""
    echo "[!] WARNING: Found $WARNINGS potential issues to review"
    exit 0
else
    echo ""
    echo "[✓] Socket appears to follow security best practices"
    exit 0
fi
