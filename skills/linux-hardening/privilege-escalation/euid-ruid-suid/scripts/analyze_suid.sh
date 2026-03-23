#!/bin/bash
# Find and analyze SUID binaries
# Usage: ./analyze_suid.sh [path]

SEARCH_PATH="${1:-/}"

echo "=== SUID Binary Analysis ==="
echo "Searching: $SEARCH_PATH"
echo ""

echo "SUID binaries found:"
find "$SEARCH_PATH" -perm -4000 -type f 2>/dev/null | while read -r binary; do
    if [ -f "$binary" ]; then
        owner=$(stat -c '%U' "$binary" 2>/dev/null || stat -f '%Su' "$binary" 2>/dev/null)
        perms=$(stat -c '%A' "$binary" 2>/dev/null || stat -f '%OLp' "$binary" 2>/dev/null)
        echo "  $binary (owner: $owner, perms: $perms)"
    fi
done | head -50

echo ""
echo "=== Common SUID Locations ==="
for path in /usr/bin/sudo /usr/bin/passwd /usr/bin/su /usr/bin/newgrp /usr/bin/chsh; do
    if [ -f "$path" ]; then
        perms=$(stat -c '%A' "$path" 2>/dev/null || stat -f '%OLp' "$path" 2>/dev/null)
        owner=$(stat -c '%U' "$path" 2>/dev/null || stat -f '%Su' "$path" 2>/dev/null)
        echo "  $path: $perms (owner: $owner)"
    fi
done

echo ""
echo "=== Analysis Tips ==="
echo "1. Check if binary is a shell wrapper: file <binary>"
echo "2. Look for setuid/setreuid calls: strings <binary> | grep -i setuid"
echo "3. Check for environment variable usage: strings <binary> | grep -i env"
echo "4. Test with strace: strace -e trace=setuid,setreuid,setresuid <binary>"
