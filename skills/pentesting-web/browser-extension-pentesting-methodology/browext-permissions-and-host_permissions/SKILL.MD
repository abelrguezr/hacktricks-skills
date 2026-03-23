---
name: browser-extension-permission-audit
description: Audit browser extension permissions and host_permissions for security vulnerabilities. Use this skill whenever analyzing Chrome/Firefox extensions, reviewing manifest.json files, investigating extension security, or pentesting browser extensions. Trigger on mentions of extension permissions, host_permissions, manifest analysis, extension security testing, or when examining potentially malicious browser extensions.
---

# Browser Extension Permission Audit

A skill for analyzing browser extension permissions and identifying security vulnerabilities in Chrome/Firefox extensions.

## When to Use This Skill

Use this skill when:
- Analyzing a browser extension's `manifest.json` file
- Investigating potentially malicious extensions
- Pentesting browser extensions for security vulnerabilities
- Reviewing extension permissions for compliance
- Auditing extensions for excessive privilege requests
- Investigating extension-based attacks or data exfiltration

## Quick Start

```bash
# Analyze a manifest.json file
python scripts/analyze_manifest.py path/to/manifest.json

# Check for dangerous permission combinations
python scripts/check_risky_permissions.py path/to/manifest.json
```

## Understanding Extension Permissions

### `permissions` vs `host_permissions`

**`permissions`** - Controls access to privileged browser APIs:
- `storage` - Persistent key-value storage (can't be cleared without uninstalling)
- `cookies` - Access to all browser cookies (credential theft risk)
- `tabs` - Tab management and monitoring
- `history` - Full browsing history access
- `bookmarks` - Read all bookmarks
- `clipboard` - Monitor clipboard for passwords
- `geolocation` - Track user location
- `webRequest` - Intercept and modify network requests
- `scripting` - Execute arbitrary code in pages
- `declarativeNetRequest` - Block/redirect traffic

**`host_permissions`** - Controls which origins APIs can access:
- `"*://*/*"` or `"<all_urls>"` - Access to ALL websites (extremely dangerous)
- `"http://*/*", "https://*/*"` - Same as above
- Specific patterns like `"https://example.com/*"` - Limited scope

### Critical Permission Combinations

| Combination | Risk | Impact |
|-------------|------|--------|
| `cookies` + broad `host_permissions` | 🔴 Critical | Can steal auth cookies from any site |
| `scripting` + `<all_urls>` | 🔴 Critical | Can inject code into any page |
| `webRequest` + `<all_urls>` | 🔴 Critical | Can intercept/modify all traffic |
| `storage` + `tabs` + `host_permissions` | 🟠 High | Wallet drain pattern |
| `history` + `bookmarks` | 🟡 Medium | User profiling |
| `geolocation` + `clipboard` | 🟡 Medium | Privacy invasion |

## Audit Workflow

### Step 1: Extract and Parse Manifest

```bash
# If you have the extension package
unzip extension.crx -d extension/
cat extension/manifest.json | python scripts/analyze_manifest.py -
```

### Step 2: Identify Risky Permissions

Run the permission checker:

```bash
python scripts/check_risky_permissions.py manifest.json
```

This will flag:
- Overly broad `host_permissions`
- Dangerous API combinations
- MV3-specific risks (`declarativeNetRequestWithHostAccess`)
- Implicit privilege abuse patterns

### Step 3: Analyze Runtime Behavior

Check for these abuse patterns:

**Cookie Theft:**
```javascript
// Look for this pattern in background scripts
chrome.cookies.getAll({}, function(cookies) {
  // Exfiltration attempt
});
```

**Dynamic Script Injection:**
```javascript
// Dangerous: arbitrary code execution
chrome.tabs.executeScript(tabId, {code: maliciousCode});
chrome.scripting.executeScript({func: maliciousFunc});
```

**Traffic Hijacking:**
```javascript
// MV3 rule injection
chrome.declarativeNetRequest.updateDynamicRules({
  addRules: [{
    action: { type: "redirect", redirect: { url: "https://attacker.tld" } }
  }]
});
```

### Step 4: Check for Supply Chain Risks

- Verify extension signature and publisher
- Check update history for sudden permission changes
- Look for `declarativeNetRequestWithHostAccess` (weaker install prompt)
- Review Web Store API key usage patterns

## Common Abuse Patterns

### 1. Supply-Chain Trojanized Updates
- Stolen developer accounts push MV3 updates
- Add `<all_urls>` + `declarativeNetRequest`/`scripting`
- Inject remote JS to siphon headers/DOM content

### 2. Wallet Drains
- Host access + `storage` + `tabs`
- Backdoored wallet extensions exfiltrate seeds
- Stolen Web Store API keys ship malicious builds

### 3. Cookie Theft
- `cookies` + broad host access
- Reads auth cookies despite `HttpOnly`
- Treat as credential-stealing capable

### 4. Implicit Privilege Abuse
- `tabs.create()` - Bypass popup blockers, create unlimited tabs
- `tabs.update()` - Modify existing tabs, load ads
- `data:` URIs in Chrome - Phishing attacks
- Webcam/microphone - One-time prompt, then always-on access

## Prevention Recommendations

### For Users
1. Review permissions before installing extensions
2. Use `activeTab` permission when possible (user-initiated only)
3. Check extension permissions regularly in browser settings
4. Remove unused extensions immediately
5. Be wary of extensions requesting `<all_urls>`

### For Developers
1. Request minimum necessary permissions
2. Use `activeTab` for user-initiated actions
3. Avoid `host_permissions` when possible
4. Implement runtime permission requests for optional features
5. Follow Google's policy: no excessive privileges

### For Security Teams
1. Monitor extension update patterns
2. Check for sudden permission escalations
3. Audit `declarativeNetRequest` rules
4. Review `chrome://extensions/?errors` for hidden issues
5. Test with `chrome://extensions/?id=<id>` for developer mode

## Reference Commands

```bash
# Chrome extension inspection
chrome://extensions/?id=<extension-id>
chrome://extensions/?errors

# Firefox extension inspection
about:debugging#/runtime/this-firefox

# View extension permissions
chrome://extensions/ (click extension → Details)
```

## Scripts

### `analyze_manifest.py`
Analyzes manifest.json and reports permission risks.

### `check_risky_permissions.py`
Checks for dangerous permission combinations and abuse patterns.

## References

- [Impact of Extension Privileges](https://palant.info/2022/08/17/impact-of-extension-privileges/)
- [Chrome Extension Security Testing](https://www.cobalt.io/blog/introduction-to-chrome-browser-extension-security-testing)
- [Malicious Browser Extensions Feb 2025](https://gitlab-com.gitlab.io/gl-security/security-tech-notes/threat-intelligence-tech-notes/malicious-browser-extensions-feb-2025/)
- [Manifest V3 Transition](https://developer.chrome.com/blog/resuming-the-transition-to-mv3/)
- [Chrome Permissions Reference](https://developer.chrome.com/docs/extensions/develop/concepts/declare-permissions#permissions)
- [Firefox Permissions Reference](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/manifest.json/permissions#api_permissions)
