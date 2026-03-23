#!/bin/bash
# macOS Chromium Injection - Create Test Extension
# Usage: ./create-test-extension.sh [output-dir]
#
# Creates a minimal extension for testing debugger API capabilities.
# Only use on systems you own or have explicit authorization to test.

set -e

OUTPUT_DIR="${1:-./test-extension}"

echo -e "[+] Creating test extension in: $OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Create manifest.json
cat > "$OUTPUT_DIR/manifest.json" << 'EOF'
{
  "manifest_version": 3,
  "name": "Test Debugger Extension",
  "version": "1.0.0",
  "description": "Test extension for CDP debugging capabilities",
  "permissions": [
    "debugger",
    "tabs",
    "cookies",
    "scripting"
  ],
  "background": {
    "service_worker": "background.js"
  },
  "icons": {
    "48": "icon.png"
  }
}
EOF

# Create background.js
cat > "$OUTPUT_DIR/background.js" << 'EOF'
// Test extension background script
console.log('[Extension] Background script loaded');

// Track when tabs are updated
chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
  if (changeInfo.status === 'complete' && tab.url && tab.url.startsWith('http')) {
    console.log(`[Extension] Tab updated: ${tab.url}`);
    
    // Attach debugger to the tab
    chrome.debugger.attach({ tabId }, '1.3', () => {
      if (chrome.runtime.lastError) {
        console.error(`[Extension] Failed to attach: ${chrome.runtime.lastError.message}`);
        return;
      }
      
      console.log(`[Extension] Debugger attached to tab ${tabId}`);
      
      // Enable network monitoring
      chrome.debugger.sendCommand({ tabId }, 'Network.enable', () => {
        if (chrome.runtime.lastError) {
          console.error(`[Extension] Failed to enable Network: ${chrome.runtime.lastError.message}`);
          return;
        }
        console.log(`[Extension] Network monitoring enabled`);
      });
      
      // Get cookies
      chrome.debugger.sendCommand({ tabId }, 'Network.getAllCookies', {}, (response) => {
        if (chrome.runtime.lastError) {
          console.error(`[Extension] Failed to get cookies: ${chrome.runtime.lastError.message}`);
          return;
        }
        console.log(`[Extension] Found ${response.cookies.length} cookies for ${tab.url}`);
        response.cookies.forEach(cookie => {
          console.log(`  - ${cookie.name} (${cookie.domain})`);
        });
      });
      
      // Listen for debugger events
      chrome.debugger.onEvent.addListener((source, method, params) => {
        if (source.tabId === tabId) {
          console.log(`[Extension] Debugger event: ${method}`);
        }
      });
    });
  }
});

// Handle extension installation
chrome.runtime.onInstalled.addListener((details) => {
  console.log(`[Extension] Installed: ${details.reason}`);
});
EOF

# Create a simple icon (1x1 transparent PNG)
printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82' > "$OUTPUT_DIR/icon.png"

echo ""
echo "[+] Extension created successfully!"
echo ""
echo "To use this extension:"
echo "  1. Launch Chrome with:"
echo "     open -na 'Google Chrome' --args \\\"
echo "       --user-data-dir=\$TMPDIR/chrome-test \\\"
echo "       --load-extension=$OUTPUT_DIR \\\"
echo "       --disable-extensions-except=$OUTPUT_DIR \\\"
echo "       --remote-debugging-port=9222"
echo ""
echo "  2. Visit any website to trigger the extension"
echo "  3. Check Chrome DevTools (F12) -> Extensions for logs"
