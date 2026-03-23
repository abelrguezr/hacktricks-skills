#!/bin/bash
# Enumerate nib-driven applications on macOS
# Finds apps with NSMainNibFile in their Info.plist

set -e

APP_DIR="${1:-/Applications}"

echo "Scanning for nib-driven applications in $APP_DIR..."
echo ""

find "$APP_DIR" -maxdepth 2 -name "Info.plist" -type f 2>/dev/null | while read -r plist; do
    app_path=$(dirname "$plist")
    
    # Check if NSMainNibFile exists
    if /usr/libexec/PlistBuddy -c "Print :NSMainNibFile" "$plist" >/dev/null 2>&1; then
        nib_file=$(/usr/libexec/PlistBuddy -c "Print :NSMainNibFile" "$plist" 2>/dev/null)
        app_name=$(basename "$app_path" .app)
        echo "[+] $app_name"
        echo "    Path: $app_path"
        echo "    NSMainNibFile: $nib_file"
        echo ""
    fi
done

echo "Scan complete."
