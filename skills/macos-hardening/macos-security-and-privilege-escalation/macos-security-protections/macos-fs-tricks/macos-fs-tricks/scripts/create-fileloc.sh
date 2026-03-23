#!/bin/bash
# Create a .fileloc file that points to a target application
# Usage: ./create-fileloc.sh <target-app-path> <output-fileloc>

if [ $# -lt 2 ]; then
    echo "Usage: $0 <target-app-path> <output-fileloc>"
    echo "Example: $0 /System/Applications/Calculator.app /tmp/calc.fileloc"
    exit 1
fi

TARGET_APP="$1"
OUTPUT_FILE="$2"

# Validate target exists
if [ ! -e "$TARGET_APP" ]; then
    echo "Error: Target application does not exist: $TARGET_APP"
    exit 1
fi

# Create .fileloc plist
cat > "$OUTPUT_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>URL</key>
    <string>file://$TARGET_APP</string>
    <key>URLPrefix</key>
    <integer>0</integer>
</dict>
</plist>
EOF

echo "Created .fileloc file: $OUTPUT_FILE"
echo "Target: $TARGET_APP"
echo ""
echo "To test: open $OUTPUT_FILE"
