#!/bin/bash
# macOS Chromium Injection - Launch Instrumented Browser
# Usage: ./launch-instrumented-chrome.sh [browser-name] [extension-path] [port]
#
# Only use on systems you own or have explicit authorization to test.

set -e

# Defaults
BROWSER="${1:-Google Chrome}"
EXTENSION_PATH="${2:-}"
PORT="${3:-9222}"
USER_DATA_DIR="${TMPDIR:-/tmp}/chrome-test-$$"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}[!] macOS Chromium Injection Tool${NC}"
echo -e "${RED}[!] Only use on authorized systems${NC}"
echo ""

# Validate browser
if ! /usr/bin/pgrep -x "$BROWSER" > /dev/null 2>&1 && ! /Applications/"$BROWSER".app > /dev/null 2>&1; then
    echo -e "${RED}[!] Browser '$BROWSER' not found${NC}"
    echo "Available browsers:"
    /usr/bin/find /Applications -name "*.app" -maxdepth 1 | grep -iE "(chrome|edge|brave|arc|opera|vivaldi)" | sed 's|.*/||'
    exit 1
fi

# Create user data directory
echo -e "${GREEN}[+] Creating user data directory: $USER_DATA_DIR${NC}"
mkdir -p "$USER_DATA_DIR"

# Build arguments
ARGS=(
    "--user-data-dir=$USER_DATA_DIR"
    "--remote-debugging-port=$PORT"
)

# Add extension if provided
if [ -n "$EXTENSION_PATH" ]; then
    if [ ! -d "$EXTENSION_PATH" ]; then
        echo -e "${RED}[!] Extension path not found: $EXTENSION_PATH${NC}"
        exit 1
    fi
    echo -e "${GREEN}[+] Loading extension: $EXTENSION_PATH${NC}"
    ARGS+=(
        "--load-extension=$EXTENSION_PATH"
        "--disable-extensions-except=$EXTENSION_PATH"
    )
fi

# Add media stream bypass (optional, comment out if not needed)
# ARGS+=("--use-fake-ui-for-media-stream")
# ARGS+=("--auto-select-desktop-capture-source=Entire Screen")

# Force quit existing browser
echo -e "${YELLOW}[*] Force quitting existing $BROWSER instance...${NC}"
osascript -e "tell application \"$BROWSER\" to quit" 2>/dev/null || true
sleep 1

# Launch instrumented browser
echo -e "${GREEN}[+] Launching $BROWSER with CDP on port $PORT${NC}"
echo -e "${YELLOW}[*] CDP endpoint: http://127.0.0.1:$PORT${NC}"
echo -e "${YELLOW}[*] User data dir: $USER_DATA_DIR${NC}"
echo ""

open -na "$BROWSER" --args "${ARGS[@]}"

# Wait for CDP to be ready
echo -e "${YELLOW}[*] Waiting for CDP to be ready...${NC}"
for i in {1..30}; do
    if curl -s "http://127.0.0.1:$PORT/json" > /dev/null 2>&1; then
        echo -e "${GREEN}[+] CDP is ready!${NC}"
        echo ""
        echo "Next steps:"
        echo "  1. Open http://127.0.0.1:$PORT/json in a browser to see available targets"
        echo "  2. Use scripts/extract-cookies.js to extract cookies"
        echo "  3. Use scripts/grant-permissions.js to grant permissions"
        echo "  4. Use scripts/inject-script.js to inject JavaScript"
        echo ""
        echo "To stop: osascript -e 'tell application \"$BROWSER\" to quit'"
        exit 0
    fi
    sleep 1
done

echo -e "${RED}[!] CDP did not become ready in time${NC}"
exit 1
