#!/bin/bash
# macOS Authorization Database Query Script
# Usage: ./query-auth-db.sh [OPTIONS]
#
# Options:
#   --rule <name>     Query specific authorization rule
#   --export <file>   Export all rules to CSV file
#   --list            List all rules with names and comments
#   --high-risk       Show potentially risky rules
#   --help            Show this help message

set -e

AUTH_DB="/var/db/auth.db"

show_help() {
    cat << EOF
macOS Authorization Database Query Script

Usage: $0 [OPTIONS]

Options:
  --rule <name>     Query specific authorization rule using security command
  --export <file>   Export all rules to CSV file
  --list            List all rules with names and comments
  --high-risk       Show potentially risky rules (allow class, high timeout, etc.)
  --help            Show this help message

Examples:
  $0 --list
  $0 --rule "authenticate-admin-nonshared"
  $0 --export auth_rules.csv
  $0 --high-risk

Note: Requires sudo/root access to read /var/db/auth.db
EOF
}

check_sudo() {
    if [[ $EUID -ne 0 ]]; then
        echo "Error: This script requires root/sudo access"
        echo "Please run: sudo $0 $*"
        exit 1
    fi
}

check_auth_db() {
    if [[ ! -f "$AUTH_DB" ]]; then
        echo "Error: Authorization database not found at $AUTH_DB"
        echo "This script must be run on macOS"
        exit 1
    fi
}

list_rules() {
    echo "=== Authorization Rules ==="
    echo ""
    echo "Name | Comment"
    echo "-----|--------"
    sqlite3 "$AUTH_DB" "SELECT name || ' | ' || COALESCE(comment, '(no comment)') FROM rules ORDER BY name;"
    echo ""
    echo "Total rules: $(sqlite3 "$AUTH_DB" "SELECT COUNT(*) FROM rules;")"
}

query_rule() {
    local rule_name="$1"
    echo "=== Rule: $rule_name ==="
    echo ""
    
    # Try security command first (gives formatted output)
    if command -v security &> /dev/null; then
        echo "Security command output:"
        security authorizationdb read "$rule_name" 2>/dev/null || echo "Rule not found or access denied"
        echo ""
    fi
    
    # Also show raw database entry
    echo "Database entry:"
    sqlite3 -header -column "$AUTH_DB" "SELECT * FROM rules WHERE name='$rule_name';"
}

export_rules() {
    local output_file="$1"
    echo "Exporting rules to $output_file..."
    sqlite3 -header -csv "$AUTH_DB" "SELECT * FROM rules;" > "$output_file"
    echo "Export complete. Total rules: $(sqlite3 "$AUTH_DB" "SELECT COUNT(*) FROM rules;")"
}

show_high_risk() {
    echo "=== Potentially High-Risk Authorization Rules ==="
    echo ""
    
    echo "--- Rules with 'allow' class (unconditional access) ---"
    sqlite3 "$AUTH_DB" "SELECT name, comment FROM rules WHERE class='allow' ORDER BY name;"
    echo ""
    
    echo "--- Rules with timeout > 300 seconds (5 minutes) ---"
    sqlite3 "$AUTH_DB" "SELECT name, timeout, comment FROM rules WHERE timeout > 300 ORDER BY timeout DESC;"
    echo ""
    
    echo "--- Rules with tries > 100 ---"
    sqlite3 "$AUTH_DB" "SELECT name, tries, comment FROM rules WHERE tries > 100 ORDER BY tries DESC;"
    echo ""
    
    echo "--- Admin-related rules ---"
    sqlite3 "$AUTH_DB" "SELECT name, comment FROM rules WHERE name LIKE '%admin%' OR name LIKE '%privilege%' ORDER BY name;"
}

# Main script logic
if [[ $# -eq 0 ]]; then
    show_help
    exit 0
fi

check_sudo
check_auth_db

case "$1" in
    --help|-h)
        show_help
        ;;
    --list)
        list_rules
        ;;
    --rule)
        if [[ -z "$2" ]]; then
            echo "Error: --rule requires a rule name"
            exit 1
        fi
        query_rule "$2"
        ;;
    --export)
        if [[ -z "$2" ]]; then
            echo "Error: --export requires an output filename"
            exit 1
        fi
        export_rules "$2"
        ;;
    --high-risk)
        show_high_risk
        ;;
    *)
        echo "Unknown option: $1"
        show_help
        exit 1
        ;;
esac
