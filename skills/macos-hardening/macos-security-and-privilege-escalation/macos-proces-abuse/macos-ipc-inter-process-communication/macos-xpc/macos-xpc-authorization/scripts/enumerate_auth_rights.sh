#!/bin/bash
# macOS XPC Authorization Rights Enumerator
# Finds permissive authorization rules that may allow privilege escalation

set -e

AUTH_DB="/var/db/auth.db"

echo "========================================"
echo "macOS XPC Authorization Rights Scanner"
echo "========================================"
echo ""

# Check if we have permissions
if [ ! -r "$AUTH_DB" ]; then
    echo "[!] Need sudo access to read $AUTH_DB"
    echo "[!] Run with: sudo $0"
    exit 1
fi

echo "[*] Scanning $AUTH_DB..."
echo ""

# Function to read and parse authorization right
read_auth_right() {
    local right_name="$1"
    local output
    
    output=$(security authorizationdb read "$right_name" 2>/dev/null || echo "")
    
    if [ -n "$output" ]; then
        echo "  Right: $right_name"
        echo "  $output" | sed 's/^/    /'
        echo ""
        
        # Check for permissive patterns
        if echo "$output" | grep -q '"authenticate-user": *false'; then
            echo "  [!] PERMISSIVE: authenticate-user is false"
        fi
        if echo "$output" | grep -q '"allow-root": *true'; then
            echo "  [!] PERMISSIVE: allow-root is true"
        fi
        if echo "$output" | grep -q '"session-owner": *true'; then
            echo "  [!] PERMISSIVE: session-owner is true"
        fi
        echo ""
    fi
}

# Get all rule names
echo "[*] Listing all authorization rules..."
ALL_RULES=$(sqlite3 "$AUTH_DB" "SELECT name FROM rules;" 2>/dev/null || echo "")

if [ -z "$ALL_RULES" ]; then
    echo "[!] No rules found or unable to query database"
    exit 1
fi

RULE_COUNT=$(echo "$ALL_RULES" | wc -l | tr -d ' ')
echo "[*] Found $RULE_COUNT rules"
echo ""

# Section 1: Rules with authenticate-user: false
echo "========================================"
echo "1. Rules with 'authenticate-user': false"
echo "========================================"
echo ""

for rule in $ALL_RULES; do
    output=$(security authorizationdb read "$rule" 2>/dev/null || echo "")
    if echo "$output" | grep -q '"authenticate-user": *false'; then
        echo "  - $rule"
    fi
done
echo ""

# Section 2: Rules with allow-root: true
echo "========================================"
echo "2. Rules with 'allow-root': true"
echo "========================================"
echo ""

for rule in $ALL_RULES; do
    output=$(security authorizationdb read "$rule" 2>/dev/null || echo "")
    if echo "$output" | grep -q '"allow-root": *true'; then
        echo "  - $rule"
    fi
done
echo ""

# Section 3: Rules with session-owner: true
echo "========================================"
echo "3. Rules with 'session-owner': true"
echo "========================================"
echo ""

for rule in $ALL_RULES; do
    output=$(security authorizationdb read "$rule" 2>/dev/null || echo "")
    if echo "$output" | grep -q '"session-owner": *true'; then
        echo "  - $rule"
    fi
done
echo ""

# Section 4: HelperTool-related rules
echo "========================================"
echo "4. HelperTool-related rules"
echo "========================================"
echo ""

HELPER_RULES=$(sqlite3 "$AUTH_DB" "SELECT name FROM rules WHERE name LIKE '%helper%' OR name LIKE '%Helper%';" 2>/dev/null || echo "")

if [ -n "$HELPER_RULES" ]; then
    for rule in $HELPER_RULES; do
        echo "  - $rule"
    done
else
    echo "  (none found)"
fi
echo ""

# Section 5: XPC-related rules
echo "========================================"
echo "5. XPC-related rules"
echo "========================================"
echo ""

XPC_RULES=$(sqlite3 "$AUTH_DB" "SELECT name FROM rules WHERE name LIKE '%xpc%' OR name LIKE '%XPC%';" 2>/dev/null || echo "")

if [ -n "$XPC_RULES" ]; then
    for rule in $XPC_RULES; do
        echo "  - $rule"
    done
else
    echo "  (none found)"
fi
echo ""

# Section 6: Privileged helper tools
echo "========================================"
echo "6. Installed Privileged HelperTools"
echo "========================================"
echo ""

if [ -d "/Library/PrivilegedHelperTools" ]; then
    ls -la /Library/PrivilegedHelperTools/ 2>/dev/null || echo "  (directory not accessible)"
else
    echo "  /Library/PrivilegedHelperTools not found"
fi
echo ""

# Section 7: Mach services in LaunchDaemons
echo "========================================"
echo "7. MachServices in LaunchDaemons"
echo "========================================"
echo ""

if [ -d "/Library/LaunchDaemons" ]; then
    for plist in /Library/LaunchDaemons/*.plist; do
        if [ -f "$plist" ]; then
            MACH_SERVICES=$(grep -A10 "MachServices" "$plist" 2>/dev/null | grep -v "MachServices" | grep -v "^--" | head -5 || echo "")
            if [ -n "$MACH_SERVICES" ]; then
                echo "  $(basename $plist):"
                echo "$MACH_SERVICES" | sed 's/^/    /'
            fi
        fi
    done
else
    echo "  /Library/LaunchDaemons not found"
fi
echo ""

echo "========================================"
echo "Scan complete"
echo "========================================"
echo ""
echo "[+] Review the permissive rules above for potential privilege escalation"
echo "[+] Use 'security authorizationdb read <rule>' to see full details"
echo "[+] Check HelperTools with class-dump to find exposed methods"
