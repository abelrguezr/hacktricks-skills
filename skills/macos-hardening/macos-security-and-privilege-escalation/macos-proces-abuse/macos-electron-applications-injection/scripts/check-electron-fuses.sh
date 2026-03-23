#!/bin/bash
# Check Electron fuses for a given application
# Usage: ./check-electron-fuses.sh /Applications/Slack.app

if [ -z "$1" ]; then
    echo "Usage: $0 /path/to/app.app"
    echo "Example: $0 /Applications/Slack.app"
    exit 1
fi

APP_PATH="$1"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: Application not found at $APP_PATH"
    exit 1
fi

echo "=== Checking Electron Fuses for $APP_PATH ==="
echo ""

# Try using npx @electron/fuses
if command -v npx &> /dev/null; then
    echo "Using @electron/fuses tool:"
    npx @electron/fuses read --app "$APP_PATH" 2>/dev/null || echo "Failed to read fuses with npx"
else
    echo "npx not found. Attempting manual check..."
    
    # Find the Electron Framework binary
    FUSE_STRING="dL7pKGdnNz796PbbjQWNKmHXBZaB9tsX"
    BINARY_PATH=$(grep -r "$FUSE_STRING" "$APP_PATH" 2>/dev/null | head -1 | cut -d: -f1)
    
    if [ -n "$BINARY_PATH" ]; then
        echo "Found fuse configuration in: $BINARY_PATH"
        echo "Note: Manual hex analysis required to determine fuse states"
    else
        echo "Could not locate fuse configuration string"
    fi
fi

echo ""
echo "=== Fuse Interpretation Guide ==="
echo "RunAsNode: If Disabled, ELECTRON_RUN_AS_NODE injection works"
echo "EnableNodeCliInspectArguments: If Disabled, --inspect works"
echo "EnableEmbeddedAsarIntegrityValidation: If Disabled, ASAR modification works"
echo "OnlyLoadAppFromAsar: If Disabled, can load from app/ folder"
echo "EnableNodeOptionsEnvironmentVariable: If Disabled, NODE_OPTIONS works"
