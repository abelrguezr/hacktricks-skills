#!/bin/bash
# List all Electron applications on the system
# Usage: ./list-electron-apps.sh

echo "=== Scanning for Electron Applications ==="
echo ""

# Common Electron app paths
COMMON_PATHS=(
    "/Applications"
    "/Applications/Utilities"
    "$HOME/Applications"
)

echo "Checking common application directories..."
echo ""

for dir in "${COMMON_PATHS[@]}"; do
    if [ -d "$dir" ]; then
        echo "Scanning: $dir"
        find "$dir" -maxdepth 2 -name "*.app" -type d 2>/dev/null | while read app; do
            # Check if it's an Electron app by looking for Electron in the bundle
            if grep -r "Electron" "$app/Contents" 2>/dev/null | grep -q .; then
                BUNDLE_ID=$(defaults read "$app/Contents/Info" CFBundleIdentifier 2>/dev/null || echo "unknown")
                printf "  ✓ %-40s | %s\n" "$BUNDLE_ID" "$app"
            fi
        done
        echo ""
    fi
done

echo "=== Known Electron Apps ==="
echo "Checking for common Electron applications..."
echo ""

declare -A KNOWN_APPS=(
    ["Slack.app"]="com.tinyspeck.slackmacgap"
    ["Discord.app"]="com.hnc.Discord"
    ["Visual Studio Code.app"]="com.microsoft.VSCode"
    ["Signal.app"]="org.whispersystems.signal-desktop"
    ["Docker.app"]="com.electron.dockerdesktop"
    ["GitHub Desktop.app"]="com.github.GitHubClient"
    ["Postman.app"]="com.postmanlabs.mac"
    ["Neo4j Desktop.app"]="com.neo4j.neo4j-desktop"
    ["OpenVPN Connect.app"]="org.openvpn.client.app"
    ["Ledger Live.app"]="com.ledger.live"
)

for app in "${!KNOWN_APPS[@]}"; do
    for base_dir in "/Applications" "$HOME/Applications"; do
        if [ -d "$base_dir/$app" ]; then
            echo "  ✓ ${KNOWN_APPS[$app]} | $base_dir/$app"
        fi
    done
done

echo ""
echo "=== Quick Check Commands ==="
echo "To check fuses for an app:"
echo "  npx @electron/fuses read --app /Applications/Slack.app"
echo ""
echo "To verify vulnerability with electroniz3r:"
echo "  ./electroniz3r verify /Applications/Slack.app"
