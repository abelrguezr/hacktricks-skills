#!/bin/bash
# macOS Sensitive Files Finder
# Usage: ./find-sensitive-files.sh [search_type]
# Search types: all, plist, logs, configs, keys, all

SEARCH_TYPE="${1:-all}"

echo "=== macOS Sensitive Files Search ==="
echo "Search type: $SEARCH_TYPE"
echo ""

# Define search patterns
declare -A SEARCH_PATTERNS
SEARCH_PATTERNS[plist]="*.plist"
SEARCH_PATTERNS[logs]="*.log *.asl"
SEARCH_PATTERNS[keys]="*.key *.pem *.p12 *.pfx"
SEARCH_PATTERNS[configs]="*.conf *.cfg *.ini"
SEARCH_PATTERNS[history]=".*history .bash_history .zsh_history"

# Sensitive directories to search
SENSITIVE_DIRS=(
    "/Library/Preferences"
    "/Library/LaunchDaemons"
    "/Library/LaunchAgents"
    "/etc"
    "/private/var/db"
    "/private/var/log"
    "$HOME/Library/Preferences"
    "$HOME/Library/Logs"
)

case $SEARCH_TYPE in
    plist)
        echo "=== Plist Files ==="
        for DIR in "${SENSITIVE_DIRS[@]}"; do
            if [ -d "$DIR" ]; then
                echo ""
                echo "Directory: $DIR"
                find "$DIR" -maxdepth 2 -name "*.plist" 2>/dev/null | head -20
            fi
        done
        ;;
    logs)
        echo "=== Log Files ==="
        for DIR in "${SENSITIVE_DIRS[@]}"; do
            if [ -d "$DIR" ]; then
                echo ""
                echo "Directory: $DIR"
                find "$DIR" -maxdepth 2 -name "*.log" -o -name "*.asl" 2>/dev/null | head -20
            fi
        done
        ;;
    keys)
        echo "=== Key/Certificate Files ==="
        echo "Searching common locations..."
        find /Library -name "*.key" -o -name "*.pem" -o -name "*.p12" 2>/dev/null | head -20
        find "$HOME" -name "*.key" -o -name "*.pem" -o -name "*.p12" 2>/dev/null | head -20
        ;;
    configs)
        echo "=== Configuration Files ==="
        for DIR in "/etc" "/Library/Preferences"; do
            if [ -d "$DIR" ]; then
                echo ""
                echo "Directory: $DIR"
                find "$DIR" -maxdepth 2 -name "*.conf" -o -name "*.cfg" 2>/dev/null | head -20
            fi
        done
        ;;
    all)
        echo "=== Comprehensive Search ==="
        echo ""
        echo "--- Plist Files ---"
        find /Library/Preferences -name "*.plist" 2>/dev/null | head -15
        find "$HOME/Library/Preferences" -name "*.plist" 2>/dev/null | head -15
        echo ""
        echo "--- Launch Daemons/Agents ---"
        ls -la /Library/LaunchDaemons/*.plist 2>/dev/null | head -10
        ls -la /Library/LaunchAgents/*.plist 2>/dev/null | head -10
        echo ""
        echo "--- Log Files ---"
        find /private/var/log -name "*.log" 2>/dev/null | head -15
        echo ""
        echo "--- Key Files ---"
        find /Library -name "*.key" 2>/dev/null | head -10
        echo ""
        echo "--- History Files ---"
        ls -la "$HOME/.bash_history" 2>/dev/null
        ls -la "$HOME/.zsh_history" 2>/dev/null
        ;;
    *)
        echo "Unknown search type: $SEARCH_TYPE"
        echo "Use: plist, logs, keys, configs, or all"
        exit 1
        ;;
esac

echo ""
echo "=== Note ==="
echo "Many files under /System are protected by SIP."
echo "Use 'sudo' for elevated access where needed."
