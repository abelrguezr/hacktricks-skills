---
name: vuejs-security-audit
description: Security audit and vulnerability assessment for Vue.js applications. Use this skill whenever the user mentions Vue.js security, XSS vulnerabilities, Vue application hardening, frontend security review, or needs to identify security issues in Vue code. Trigger for any Vue.js code review, security assessment, or when users ask about protecting Vue applications from attacks.
---

# Vue.js Security Audit Skill

A comprehensive guide for identifying and remediating security vulnerabilities in Vue.js applications.

## When to Use This Skill

Use this skill when:
- Reviewing Vue.js code for security vulnerabilities
- Auditing frontend applications for XSS risks
- Hardening Vue.js applications against common attacks
- Investigating security issues in Vue projects
- Creating security checklists for Vue development teams

## Core Vulnerability Categories

### 1. XSS Sinks in Vue.js

#### v-html Directive (CRITICAL)

The `v-html` directive renders **raw** HTML without sanitization. Any `<script>` tags or event handlers in user input execute immediately.

**Vulnerable:**
```html
<div v-html="htmlContent"></div>
```

**Secure:**
```html
<div v-html="sanitizedContent"></div>
<script>
import DOMPurify from 'dompurify';

export default {
  computed: {
    sanitizedContent() {
      return DOMPurify.sanitize(this.htmlContent);
    }
  }
}
</script>
```

#### v-bind with URL Attributes (HIGH)

Binding user strings to URL-bearing attributes (`href`, `src`, `xlink:href`, `formaction`) allows `javascript:` URI attacks.

**Vulnerable:**
```html
<a v-bind:href="userInput">Click me</a>
```

**Secure:**
```html
<a :href="safeUrl" target="_blank" rel="noopener noreferrer">Click me</a>
<script>
export default {
  computed: {
    safeUrl() {
      if (!this.userInput) return '#';
      const url = new URL(this.userInput, 'https://example.com');
      if (!['http:', 'https:'].includes(url.protocol)) return '#';
      return url.toString();
    }
  }
}
</script>
```

#### v-on with User-Controlled Handlers (CRITICAL)

`v-on` compiles its value with `new Function`. User-controlled handler values enable code execution.

**Vulnerable:**
```html
<button v-on:click="malicious">Click me</button>
<script>
export default {
  data() {
    return { malicious: 'alert(1)' }
  }
}
</script>
```

**Secure:**
```html
<button @click="handleClick">Click me</button>
<script>
export default {
  methods: {
    handleClick() {
      // Safe method reference
    }
  }
}
</script>
```

#### Dynamic Attribute/Event Names (HIGH)

User-supplied names in `v-bind:[attr]` or `v-on:[event]` let attackers create arbitrary handlers.

**Vulnerable:**
```html
<img v-bind:[userAttr]="payload">
<!-- userAttr = 'onerror', payload = 'alert(1)' -->
```

**Secure:**
```html
<img :src="safeSrc" :alt="safeAlt">
<script>
export default {
  computed: {
    safeAttr() {
      const allowed = ['src', 'alt', 'title'];
      return allowed.includes(this.userAttr) ? this.userAttr : null;
    }
  }
}
</script>
```

#### Dynamic Component (`<component :is>`) (CRITICAL)

User strings in `:is` can mount arbitrary components or inline templates.

**Vulnerable:**
```html
<component :is="userChoice"></component>
```

**Secure:**
```html
<component :is="safeComponent"></component>
<script>
export default {
  computed: {
    safeComponent() {
      const allowed = ['button', 'input', 'div', 'MyComponent'];
      return allowed.includes(this.userChoice) ? this.userChoice : 'div';
    }
  }
}
</script>
```

#### Untrusted Templates in SSR (CRITICAL - RCE Risk)

During server-side rendering, templates run **on your server**. Injecting user HTML can escalate XSS to Remote Code Execution.

**Vulnerable:**
```js
const app = createSSRApp({ template: userProvidedHtml })
```

**Secure:**
```js
// Never use user input as templates
const app = createSSRApp({
  template: require('./App.vue').template
})
```

#### Filters/Render Functions with eval (HIGH)

Legacy filters that call `eval` or `new Function` on user data are XSS vectors.

**Vulnerable:**
```js
Vue.filter('run', code => eval(code))
```

**Secure:**
```js
// Replace with computed properties
export default {
  computed: {
    processedValue() {
      // Safe transformation without eval
    }
  }
}
```

### 2. Other Common Vulnerabilities

#### Prototype Pollution in Plugins (HIGH)

Deep-merge helpers in plugins (e.g., vue-i18n) can allow `Object.prototype` modification.

**Vulnerable:**
```js
import merge from 'deepmerge'
merge({}, JSON.parse('{ "__proto__": { "polluted": true } }'))
```

**Secure:**
```js
import merge from 'deepmerge'
const safeMerge = (target, source) => {
  const cleanSource = JSON.parse(JSON.stringify(source));
  delete cleanSource.__proto__;
  delete cleanSource.constructor;
  delete cleanSource.prototype;
  return merge(target, cleanSource);
};
```

#### Open Redirects with vue-router (MEDIUM)

Unchecked user URLs in `router.push` or `<router-link>` enable phishing.

**Vulnerable:**
```js
this.$router.push(this.$route.query.next)
```

**Secure:**
```js
const safePath = this.$route.query.next;
if (safePath && safePath.startsWith('/') && !safePath.includes('..')) {
  this.$router.push(safePath);
} else {
  this.$router.push('/');
}
```

#### CSRF in Axios/fetch (MEDIUM)

SPAs need server-side CSRF tokens; SameSite cookies alone can't block auto-submitted cross-origin POSTs.

**Vulnerable:**
```js
axios.post('/api/transfer', data)
```

**Secure:**
```js
axios.post('/api/transfer', data, {
  headers: { 'X-CSRF-TOKEN': this.csrfToken }
})
```

#### Click-jacking (MEDIUM)

Vue apps are frameable without proper headers.

**Required Headers:**
```http
X-Frame-Options: DENY
Content-Security-Policy: frame-ancestors 'none';
```

#### Content-Security-Policy Pitfalls (HIGH)

The full Vue build needs `unsafe-eval`. Use runtime build or pre-compiled templates.

**Vulnerable CSP:**
```http
Content-Security-Policy: script-src 'unsafe-eval';
```

**Secure CSP:**
```http
Content-Security-Policy: default-src 'self'; script-src 'self';
```

#### Supply-Chain Attacks (HIGH)

Transitive dependencies can run arbitrary code on dev machines (e.g., node-ipc March 2022).

**Secure Practices:**
```shell
npm ci --ignore-scripts  # Safer install
npm audit                # Regular audits
npm audit fix            # Auto-fix where possible
```

## Hardening Checklist

Use this checklist when auditing Vue.js applications:

| # | Check | Severity | Action |
|---|-------|----------|--------|
| 1 | Sanitize all `v-html` content with DOMPurify | CRITICAL | Implement sanitization |
| 2 | Whitelist URL schemes in `v-bind:href/src` | HIGH | Add URL validation |
| 3 | Never use user input in `v-on` handlers | CRITICAL | Use method references |
| 4 | Whitelist dynamic attribute/event names | HIGH | Add allowlist validation |
| 5 | Whitelist components in `<component :is>` | CRITICAL | Add component allowlist |
| 6 | Never use user input as SSR templates | CRITICAL | Use pre-compiled templates |
| 7 | Remove `eval`/`new Function` from filters | HIGH | Replace with computed properties |
| 8 | Sanitize deep-merge inputs | HIGH | Clean __proto__/constructor |
| 9 | Validate router.push URLs | MEDIUM | Check for safe paths |
| 10 | Implement CSRF tokens | MEDIUM | Add X-CSRF-TOKEN header |
| 11 | Set X-Frame-Options: DENY | MEDIUM | Configure server headers |
| 12 | Set CSP frame-ancestors 'none' | MEDIUM | Configure server headers |
| 13 | Use Vue runtime build | HIGH | Switch from full build |
| 14 | Run `npm audit` weekly | HIGH | Schedule automated audits |
| 15 | Pin dependency versions | HIGH | Use lockfiles |

## Audit Workflow

### Step 1: Static Analysis

1. Search for `v-html` usages
2. Search for `v-bind:href`, `v-bind:src` with user data
3. Search for `v-on:` with dynamic values
4. Search for `<component :is>` with user input
5. Search for `eval(`, `new Function(` in codebase
6. Check `package.json` for known vulnerable packages

### Step 2: Runtime Testing

1. Test XSS payloads in all user input fields
2. Test `javascript:` URIs in URL parameters
3. Test prototype pollution payloads
4. Test CSRF with missing tokens
5. Test click-jacking by embedding in iframe

### Step 3: Configuration Review

1. Check CSP headers
2. Check X-Frame-Options headers
3. Review vue-router configuration
4. Audit npm dependencies
5. Verify SSR template sources

## Quick Reference: Payload Testing

```javascript
// XSS payloads to test
const xssPayloads = [
  '<script>alert(1)</script>',
  '<img src=x onerror=alert(1)>',
  '<svg onload=alert(1)>',
  'javascript:alert(1)',
  'data:text/html,<script>alert(1)</script>',
  '<iframe src="javascript:alert(1)">',
];

// Prototype pollution payloads
const protoPayloads = [
  JSON.stringify({ '__proto__': { 'polluted': true } }),
  JSON.stringify({ 'constructor': { 'prototype': { 'polluted': true } } }),
];
```

## References

- [Vue.js Security Best Practices](https://vuejs.org/guide/best-practices/security)
- [Vue XSS Guide - StackHawk](https://www.stackhawk.com/blog/vue-xss-guide-examples-and-prevention/)
- [Vue.js Security - Medium](https://medium.com/@isaacwangethi30/vue-js-security-6e246a7613da)
- [DOMPurify Documentation](https://github.com/cure53/DOMPurify)
- [OWASP Vue.js Security](https://owasp.org/www-project-web-security-testing-guide/)

## Tools to Use

- **DOMPurify**: HTML sanitization library
- **npm audit**: Dependency vulnerability scanning
- **ESLint with security plugins**: Static analysis
- **Burp Suite**: Runtime testing
- **Snyk**: Supply chain security

## Common Mistakes to Avoid

1. ❌ Using `v-html` without sanitization
2. ❌ Binding user input directly to `href`/`src`
3. ❌ Using `eval` in filters or computed properties
4. ❌ Trusting `router.query` parameters
5. ❌ Missing CSRF protection on state-changing endpoints
6. ❌ Using `unsafe-eval` in CSP
7. ❌ Not pinning dependency versions
8. ❌ Skipping `npm audit` in CI/CD
