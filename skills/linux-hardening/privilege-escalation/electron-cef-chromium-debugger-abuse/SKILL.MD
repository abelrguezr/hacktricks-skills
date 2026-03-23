---
name: node-inspector-security-audit
description: Security audit skill for identifying Node.js inspector and CEF/Chromium debugger vulnerabilities in applications. Use this skill when assessing Electron apps, Node.js services, or CEF-based applications for exposed debugging ports, remote code execution risks, or Chrome DevTools Protocol abuse. Trigger when users mention security audits, penetration testing, Electron security, Node.js debugging vulnerabilities, CEF security, or Chrome DevTools Protocol exploitation.
---

# Node Inspector & CEF Debugger Security Audit

A comprehensive skill for auditing Node.js inspector and Chromium Embedded Framework (CEF) debugging vulnerabilities in applications.

## When to Use This Skill

Use this skill when:
- Conducting security assessments of Electron applications
- Auditing Node.js services for exposed debugging endpoints
- Testing CEF-based applications for debugger vulnerabilities
- Investigating potential privilege escalation via debugging ports
- Reviewing Chrome DevTools Protocol security configurations
- Performing penetration testing on desktop/web applications with debugging capabilities

## Understanding the Vulnerability

### Node.js Inspector

When a Node.js process starts with the `--inspect` flag, it opens a debugging port (default: `127.0.0.1:9229`) that provides full access to the execution environment. A malicious actor who can connect to this port may execute arbitrary code.

**Common startup patterns:**
```bash
node --inspect app.js                    # Port 9229, localhost only
node --inspect=4444 app.js               # Custom port, localhost only
node --inspect=0.0.0.0:4444 app.js       # All interfaces - DANGEROUS
node --inspect-brk=0.0.0.0:4444 app.js   # All interfaces with breakpoint
```

### CEF/Chromium Debugging

CEF applications use `--remote-debugging-port` (default: 9222) and communicate via Chrome DevTools Protocol. While this doesn't provide direct Node.js RCE, it allows browser control and potential information exfiltration.

## Audit Checklist

### 1. Identify Exposed Debugging Ports

**Scan for common debugging ports:**
```bash
# Check for Node.js inspector ports
netstat -tlnp | grep -E '9229|9222|4444'
ss -tlnp | grep -E '9229|9222|4444'

# Check all listening ports for debugging patterns
lsof -i -P -n | grep LISTEN | grep -E '922[0-9]|4444'
```

**Look for processes with debugging flags:**
```bash
ps aux | grep -E 'inspect|debugging-port'
pgrep -a node | grep -E 'inspect|debug'
```

### 2. Check Binding Configuration

**Critical security finding:** If a debugging port binds to `0.0.0.0` or any non-localhost interface, it's potentially accessible from the network.

**Safe configuration:**
- `127.0.0.1:9229` - Localhost only (acceptable for development)
- `::1:9229` - IPv6 localhost only (acceptable for development)

**Unsafe configuration:**
- `0.0.0.0:9229` - All interfaces (CRITICAL)
- Any external IP address (CRITICAL)

### 3. Test Inspector Accessibility

**From localhost (authorized testing only):**
```bash
# Check if inspector is responding
curl -s http://127.0.0.1:9229/json/version

# List available debug sessions
curl -s http://127.0.0.1:9229/json/list
```

**Check for CEF/Chrome DevTools:**
```bash
curl -s http://127.0.0.1:9222/json/version
curl -s http://127.0.0.1:9222/json/list
```

### 4. Identify Electron-Specific Risks

Electron applications may expose additional attack vectors:

**Check for exposed IPC channels:**
```javascript
// In renderer process (if you have access)
console.log(window.require ? 'Node integration enabled' : 'Node integration disabled')
```

**Look for dangerous patterns in source:**
- `nodeIntegration: true` in webPreferences
- `contextIsolation: false`
- Exposed `remote` module
- Unsanitized `shell.openExternal()` calls

### 5. Chrome DevTools Protocol Risks

The Chrome DevTools Protocol allows browser control. Key risks include:

**File download manipulation:**
```javascript
// Can redirect downloads to overwrite application files
Browser.setDownloadBehavior({
  behavior: "allow",
  downloadPath: "/sensitive/path/"
})
```

**Page inspection and data exfiltration:**
- Read all open tabs
- Extract cookies, local storage
- Capture network traffic
- Take screenshots

**Parameter injection via custom URIs:**
Some CEF applications register custom URI schemes that may be vulnerable to parameter injection (CVE-2021-38112 pattern).

## Remediation Guidance

### Immediate Actions

1. **Disable debugging in production:**
   ```bash
   # Remove --inspect and --remote-debugging-port flags
   # Use environment variables to control debugging
   ```

2. **Bind to localhost only:**
   ```bash
   # Always use 127.0.0.1 or ::1
   node --inspect=127.0.0.1:9229 app.js
   ```

3. **Use firewall rules:**
   ```bash
   # Block external access to debugging ports
   iptables -A INPUT -p tcp --dport 9229 -s ! 127.0.0.1 -j DROP
   ```

### Long-term Security

1. **Environment-based configuration:**
   ```javascript
   // Only enable debugging in development
   if (process.env.NODE_ENV === 'development') {
     require('node-inspect').start()
   }
   ```

2. **Electron security best practices:**
   ```javascript
   const BrowserWindow = require('electron').BrowserWindow
   
   const win = new BrowserWindow({
     webPreferences: {
       nodeIntegration: false,
       contextIsolation: true,
       preload: path.join(__dirname, 'preload.js')
     }
   })
   ```

3. **CEF security hardening:**
   - Disable remote debugging in production builds
   - Use CEF's security features (site isolation, sandbox)
   - Validate all URI scheme parameters

4. **Container security:**
   - Don't expose debugging ports in container networks
   - Use `--inspect=127.0.0.1:9229` even in containers
   - Consider using `kill -s SIGUSR1` for on-demand debugging instead of always-on

## Detection Scripts

### Quick Port Scanner

Save as `scripts/scan-debug-ports.sh`:
```bash
#!/bin/bash
# Scan for common debugging ports

PORTS=(9229 9222 4444 9220 9221 9223 9224 9225)

echo "Scanning for debugging ports..."
for port in "${PORTS[@]}"; do
    if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
        echo "[!] Port $port is open"
        netstat -tlnp | grep ":$port "
    fi
done

echo "Done."
```

### Process Inspector Detector

Save as `scripts/find-inspect-processes.sh`:
```bash
#!/bin/bash
# Find Node.js processes with inspector enabled

echo "Checking for Node.js processes with debugging enabled..."
ps aux | grep -E 'node.*inspect|node.*debugging' | grep -v grep

echo ""
echo "Checking for CEF/Chromium processes with debugging..."
ps aux | grep -E 'cef|chromium|electron' | grep -E 'remote-debugging|inspect' | grep -v grep
```

## Severity Classification

| Finding | Severity | Description |
|---------|----------|-------------|
| Debugging port on 0.0.0.0 | CRITICAL | Network-accessible RCE |
| Debugging port on localhost | MEDIUM | Local privilege escalation |
| Node integration enabled in Electron | HIGH | Renderer process RCE |
| CEF debugging enabled in production | MEDIUM | Information disclosure |
| Custom URI scheme without validation | HIGH | Parameter injection RCE |

## References

- [Node.js Debugging Guide](https://nodejs.org/en/docs/guides/debugging-getting-started/)
- [Chrome DevTools Protocol](https://chromedevtools.github.io/devtools-protocol/)
- [CVE-2021-38112 - AWS Workspaces RCE](https://rhinosecuritylabs.com/aws/cve-2021-38112-aws-workspaces-rce/)
- [CEF Debug Tool](https://github.com/taviso/cefdebug)
- [Electron Security Best Practices](https://www.electronjs.org/docs/latest/tutorial/security)

## Usage Notes

**Authorization Required:** Only perform these tests on systems you own or have explicit authorization to audit.

**Development vs Production:** Debugging ports are acceptable in development environments but must be disabled in production.

**Container Considerations:** In containerized environments, shutting down and restarting processes may not be feasible. Use `kill -s SIGUSR1` for on-demand inspector activation instead of always-on debugging.

**Browser vs Node.js:** Remember that Chrome DevTools Protocol connections to browsers don't provide the same RCE capabilities as Node.js inspector connections. The attack surface differs significantly.
