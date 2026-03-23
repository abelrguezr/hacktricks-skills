---
name: http-referrer-security
description: Analyze HTTP Referrer header security issues, test for sensitive data leakage via referrer headers, and implement proper Referrer-Policy mitigations. Use this skill whenever the user mentions referrer headers, HTTP header security, information disclosure via URLs, GET parameter security, or needs to audit web applications for referrer-based vulnerabilities.
---

# HTTP Referrer Security Analysis

This skill helps you identify, test, and mitigate security vulnerabilities related to HTTP Referrer headers that can leak sensitive information.

## What is the Referrer Header?

The `Referrer` (note the British spelling) header is automatically sent by browsers to indicate which page the user came from. This can inadvertently expose sensitive information if:

- Sensitive data appears in GET request parameters
- Sensitive data appears in URL paths
- The page links to external resources
- An attacker can trick users into visiting attacker-controlled URLs

## Common Vulnerability Patterns

### 1. Sensitive Data in GET Parameters

```http
GET /dashboard?token=abc123&user=admin HTTP/1.1
Host: vulnerable-site.com
```

If this page links to external resources or the user is redirected to an attacker's site, the full URL (including `token=abc123&user=admin`) gets sent in the Referrer header.

### 2. Sensitive Data in URL Paths

```http
GET /api/users/12345/secrets HTTP/1.1
Host: vulnerable-site.com
```

The path itself can leak information about user IDs, internal structure, or sensitive operations.

## Testing for Referrer Vulnerabilities

### Manual Testing Steps

1. **Identify sensitive GET parameters**
   - Look for tokens, session IDs, passwords, API keys in URLs
   - Check for user IDs, internal identifiers in paths
   - Review any authentication or authorization parameters

2. **Test referrer leakage**
   - Visit a page with sensitive URL parameters
   - Click on external links (or use browser dev tools to see outgoing requests)
   - Check if the full URL is sent in the Referrer header

3. **Check Referrer-Policy header**
   ```bash
   curl -I https://example.com/sensitive-page
   ```
   Look for `Referrer-Policy` in the response headers.

4. **Test with the included script**
   ```bash
   ./scripts/test-referrer-policy.sh https://example.com
   ```

### Automated Testing

Use the `test-referrer-policy.sh` script to check a site's referrer policy:

```bash
./scripts/test-referrer-policy.sh https://target-site.com
```

This will:
- Fetch the Referrer-Policy header
- Evaluate the security level
- Suggest improvements if needed

## Referrer-Policy Values

| Policy | Behavior | Security Level |
|--------|----------|----------------|
| `no-referrer` | Never send referrer | Highest |
| `no-referrer-when-downgrade` | Don't send to HTTPS→HTTP | High |
| `same-origin` | Only send to same origin | High |
| `strict-origin` | Send origin only, not to HTTPS→HTTP | Medium-High |
| `strict-origin-when-cross-origin` | Full URL same-origin, origin only cross-origin | Medium |
| `origin` | Send only origin (no path/query) | Medium |
| `origin-when-cross-origin` | Full URL same-origin, origin cross-origin | Low-Medium |
| `unsafe-url` | Send full URL always | Lowest (default) |

## Mitigation Strategies

### 1. Server-Side: Set Referrer-Policy Header

Add this header to your web server configuration:

**Nginx:**
```nginx
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
```

**Apache:**
```apache
Header always set Referrer-Policy "strict-origin-when-cross-origin"
```

**Express.js:**
```javascript
app.use((req, res, next) => {
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
  next();
});
```

**Django:**
```python
# settings.py
SECURE_REFERRER_POLICY = "strict-origin-when-cross-origin"
```

### 2. HTML Meta Tag (Fallback)

If you can't control server headers, add to your HTML `<head>`:

```html
<meta name="referrer" content="strict-origin-when-cross-origin">
```

⚠️ **Warning:** This can be exploited if the site has HTML injection vulnerabilities. An attacker could override it with:
```html
<meta name="referrer" content="unsafe-url">
```

### 3. Best Practice: Never Put Sensitive Data in URLs

This is the most important defense:

- **Use POST requests** for sensitive data
- **Use cookies or headers** for authentication tokens
- **Use POST** for any data that shouldn't be logged or cached
- **Avoid** putting session IDs, tokens, passwords, or PII in URLs

## Security Recommendations

### For Security Auditors

1. Check all pages for sensitive GET parameters
2. Verify Referrer-Policy headers are set appropriately
3. Test if external links leak referrer information
4. Look for HTML injection that could override referrer policy
5. Review server logs for referrer-based information disclosure

### For Developers

1. Default to `strict-origin-when-cross-origin` or `no-referrer`
2. Never put sensitive data in URLs
3. Use POST for forms with sensitive data
4. Consider using CSRF tokens instead of URL-based tokens
5. Audit third-party scripts that might leak referrer info

### For Bug Bounty Hunters

Look for:
- Authentication tokens in URLs
- API keys in GET parameters
- Internal user IDs in paths
- Missing or weak Referrer-Policy headers
- HTML injection that could override referrer policy
- External resource loading from sensitive pages

## Quick Reference

**Most Secure:** `no-referrer`
**Recommended Default:** `strict-origin-when-cross-origin`
**Avoid:** `unsafe-url` (this is often the default)

**Critical Rule:** Never put sensitive data in GET parameters or URL paths, regardless of referrer policy.
