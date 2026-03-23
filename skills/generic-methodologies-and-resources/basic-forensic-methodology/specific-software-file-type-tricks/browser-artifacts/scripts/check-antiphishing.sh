#!/bin/bash
# Check anti-phishing settings across all browsers
# Usage: ./check-antiphishing.sh [os]
# OS: linux, macos, windows (default: auto-detect)

set -e

OS="${1:-$(uname -s | tr '[:upper:]' '[:lower:]')}"

echo "=== Browser Anti-Phishing Status ==="
echo "OS: $OS"
echo ""

# Firefox
check_firefox() {
    echo "--- Firefox ---"
    case "$OS" in
        linux)
            PREFS="~/.mozilla/firefox/*/prefs.js"
            ;;
        macos|darwin)
            PREFS="/Users/*/Library/Application Support/Firefox/Profiles/*/prefs.js"
            ;;
        *)
            echo "Windows: Check %userprofile%\AppData\Roaming\Mozilla\Firefox\Profiles\*\prefs.js"
            echo "Search for: browser.safebrowsing"
            return
            ;;
    esac
    
    for file in $PREFS; do
        if [ -f "$file" ]; then
            echo "Profile: $file"
            grep -i 'browser.safebrowsing' "$file" 2>/dev/null || echo "  No safebrowsing settings found"
        fi
    done
    echo ""
}

# Chrome
check_chrome() {
    echo "--- Chrome ---"
    case "$OS" in
        linux)
            PREFS="~/.config/google-chrome/*/Preferences"
            ;;
        macos|darwin)
            PREFS="/Users/*/Library/Application Support/Google/Chrome/*/Preferences"
            ;;
        *)
            echo "Windows: Check C:\\Users\\*\\AppData\\Local\\Google\\Chrome\\User Data\\*\\Preferences"
            echo "Search for: safebrowsing"
            return
            ;;
    esac
    
    for file in $PREFS; do
        if [ -f "$file" ]; then
            echo "Profile: $file"
            grep -i 'safebrowsing' "$file" 2>/dev/null | head -5 || echo "  No safebrowsing settings found"
        fi
    done
    echo ""
}

# Safari (macOS only)
check_safari() {
    if [ "$OS" != "macos" ] && [ "$OS" != "darwin" ]; then
        echo "--- Safari ---"
        echo "Safari is macOS only"
        echo ""
        return
    fi
    
    echo "--- Safari ---"
    for user in /Users/*; do
        if [ -d "$user/Library/Safari" ]; then
            echo "User: $user"
            defaults read com.apple.Safari WarnAboutFraudulentWebsites 2>/dev/null || echo "  Setting not found"
        fi
    done
    echo ""
}

# Opera
check_opera() {
    echo "--- Opera ---"
    case "$OS" in
        linux)
            PREFS="~/.config/opera/*/Preferences"
            ;;
        macos|darwin)
            PREFS="/Users/*/Library/Application Support/com.operasoftware.Opera/*/Preferences"
            ;;
        *)
            echo "Windows: Check C:\\Users\\*\\AppData\\Roaming\\Opera Software\\Opera Stable\\Preferences"
            echo "Search for: fraud_protection_enabled"
            return
            ;;
    esac
    
    for file in $PREFS; do
        if [ -f "$file" ]; then
            echo "Profile: $file"
            grep -i 'fraud_protection_enabled' "$file" 2>/dev/null || echo "  No fraud protection settings found"
        fi
    done
    echo ""
}

# Run checks
case "$OS" in
    linux)
        check_firefox
        check_chrome
        check_opera
        ;;
    macos|darwin)
        check_firefox
        check_chrome
        check_safari
        check_opera
        ;;
    *)
        echo "Windows detected. Manual checks required:"
        echo "Firefox: %userprofile%\AppData\Roaming\Mozilla\Firefox\Profiles\*\prefs.js"
        echo "Chrome: C:\\Users\\*\\AppData\\Local\\Google\\Chrome\\User Data\\*\\Preferences"
        echo "Edge: C:\\Users\\*\\AppData\\Local\\Microsoft\\Edge\\User Data\\Default\\Preferences"
        echo "Opera: C:\\Users\\*\\AppData\\Roaming\\Opera Software\\Opera Stable\\Preferences"
        ;;
esac

echo "=== Summary ==="
echo "true/enabled = Anti-phishing is ON"
echo "false/disabled = Anti-phishing is OFF (security risk)"
