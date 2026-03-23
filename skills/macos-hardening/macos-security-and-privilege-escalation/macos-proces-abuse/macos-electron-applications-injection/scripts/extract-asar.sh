#!/bin/bash
# Extract and repack Electron ASAR files
# Usage: ./extract-asar.sh /Applications/Slack.app [output_dir]

if [ -z "$1" ]; then
    echo "Usage: $0 /path/to/app.app [output_dir]"
    echo "Example: $0 /Applications/Slack.app /tmp/slack-decomp"
    exit 1
fi

APP_PATH="$1"
OUTPUT_DIR="${2:-/tmp/asar-extract-$(date +%s)}"
ASAR_PATH="$APP_PATH/Contents/Resources/app.asar"

if [ ! -f "$ASAR_PATH" ]; then
    echo "Error: ASAR file not found at $ASAR_PATH"
    echo "Looking for ASAR files in $APP_PATH..."
    find "$APP_PATH" -name "*.asar" 2>/dev/null
    exit 1
fi

echo "=== Extracting ASAR from $ASAR_PATH ==="
echo "Output directory: $OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

if command -v npx &> /dev/null; then
    echo "Extracting with npx asar..."
    npx asar extract "$ASAR_PATH" "$OUTPUT_DIR"
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "Extraction complete!"
        echo "Files extracted to: $OUTPUT_DIR"
        echo ""
        echo "To repack after modifications:"
        echo "  npx asar pack $OUTPUT_DIR new-app.asar"
        echo ""
        echo "Common files to modify:"
        echo "  - main.js (main process)"
        echo "  - preload.js (preload script)"
        echo "  - index.html (renderer entry)"
    else
        echo "Extraction failed"
        exit 1
    fi
else
    echo "Error: npx not found. Install Node.js to use asar tool."
    echo "  npm install -g @electron/asar"
    exit 1
fi
