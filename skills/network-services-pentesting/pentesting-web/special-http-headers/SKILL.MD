---
name: http-header-pentesting
description: How to test and exploit HTTP header vulnerabilities during web security assessments. Use this skill whenever you need to test HTTP headers for security issues, including header injection, cache poisoning, request smuggling, header bypass techniques, or analyzing security headers. Trigger this skill for any web pentesting task involving HTTP headers, proxy manipulation, or header-based attacks—even if the user doesn't explicitly mention "headers" but describes testing web applications, proxies, or security configurations.
---

# HTTP Header Pentesting

A comprehensive guide for testing HTTP header vulnerabilities during web security assessments.

## When to Use This Skill

Use this skill when:
- Testing web applications for header-based vulnerabilities
- Analyzing proxy configurations and header handling
- Investigating cache-related security issues
- Testing for HTTP request smuggling
- Bypassing security controls via header manipulation
- Auditing security headers on web applications
- Testing header name casing bypasses
- Any web pentesting task where HTTP headers are relevant

## Quick Reference: Common Attack Vectors

### IP Spoofing Headers

These headers can be used to spoof the client's IP address:

```
X-Originating-IP: 127.0.0.1
X-Forwarded-For: 127.0.0.1
X-Forwarded: 127.0.0.1
X-Remote-IP: 127.0.0.1
X-Remote-Addr: 127.0.0.1
Client-IP: 127.0.0.1
X-Client-IP: 127.0.0.1
True-Client-IP: 127.0.0.1
```

**Why this matters**: Applications that trust these headers for authentication, rate limiting, or access control can be bypassed by injecting spoofed values.

### URL Rewriting Headers

These headers can redirect or rewrite request paths:

```
X-Original-URL: /admin/console
X-Rewrite-URL: /admin/console
```

**Why this matters**: Some proxies and load balancers use these headers to determine the actual request path, potentially bypassing access controls.

### Hop-by-Hop Headers

Hop-by-hop headers are processed by the current proxy, not forwarded end-to-end:

```
Connection: close, X-Forwarded-For
```

**Why this matters**: Malicious headers can be injected into the Connection header to make them appear as hop-by-hop, potentially bypassing security filters.

## HTTP Request Smuggling

HTTP request smuggling occurs when there's a mismatch in how front-end and back-end servers interpret request boundaries.

### Content-Length vs Transfer-Encoding

The most common smuggling technique involves conflicting headers:

```
Content-Length: 30
Transfer-Encoding: chunked
```

**Why this matters**: Different servers prioritize these headers differently. When a proxy and backend disagree on which header to trust, requests can be desynchronized, allowing attackers to inject requests or steal responses.

### Expect Header Abuse

The `Expect: 100-continue` header can cause various issues:

```
Expect: 100-continue
Expect: y 100-continue
```

**Potential issues**:
- HEAD requests with bodies may keep connections open until timeout
- Servers may return random data or secret keys
- Can cause CL.0 or 0.CL desyncs if backend responds with 400/404 instead of 100

**Why this matters**: The Expect header is often poorly implemented, leading to request smuggling or information disclosure.

## Cache Manipulation

### Server Cache Headers

Monitor these response headers to understand caching behavior:

| Header | Purpose |
|--------|--------|
| `X-Cache` | Shows `hit` or `miss` status |
| `Cf-Cache-Status` | Cloudflare cache status |
| `Cache-Control` | Caching directives (e.g., `public, max-age=1800`) |
| `Vary` | Additional headers used as cache key |
| `Age` | Seconds since object was cached |
| `Server-Timing` | CDN cache status (e.g., `cdn-cache; desc=HIT`) |

### Local Cache Headers

```
Clear-Site-Data: "cache", "cookies"
Expires: Wed, 21 Oct 2015 07:28:00 GMT
Pragma: no-cache
Warning: 110 anderson/1.3.37 "Response is stale"
```

**Why this matters**: Cache headers can be manipulated to poison caches, steal sensitive data, or bypass authentication.

### Conditional Requests

```
If-Modified-Since: <date>
If-Unmodified-Since: <date>
If-Match: <etag>
If-None-Match: <etag>
```

**Why this matters**: These headers interact with `Last-Modified` and `ETag` to control caching. Misconfigurations can lead to cache poisoning or information disclosure.

## Range Request Attacks

Range requests can be used for various attacks:

```
Range: bytes=80-100
Accept-Ranges: bytes
If-Range: <etag-or-date>
```

**Attack vectors**:
- **Information disclosure**: Combine `Range` with `ETag` in HEAD requests to leak content hashes
- **XSS injection**: Reflect arbitrary JavaScript through range responses
- **Content manipulation**: Request specific byte ranges to bypass filters

**Example**: A request with `Range: bytes=20-20` and response `ETag: W/"1-eoGvPlkaxxP4HqHv6T3PNhV9g3Y"` leaks the SHA1 of byte 20.

**Why this matters**: Range requests are often overlooked in security testing but can leak sensitive information or enable XSS.

## Security Headers Audit

### Content Security Policy (CSP)

CSP restricts resource loading and script execution:

```
Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline'
```

**Why this matters**: Missing or weak CSP allows XSS attacks. Test for bypasses in CSP configurations.

### X-Content-Type-Options

Prevents MIME type sniffing:

```
X-Content-Type-Options: nosniff
```

**Why this matters**: Without this header, browsers may interpret files as different types, enabling XSS.

### X-Frame-Options

Prevents clickjacking:

```
X-Frame-Options: DENY
X-Frame-Options: SAMEORIGIN
```

**Why this matters**: Missing or misconfigured X-Frame-Options allows pages to be embedded in iframes.

### Cross-Origin Headers

```
Cross-Origin-Resource-Policy: same-origin
Access-Control-Allow-Origin: https://example.com
Access-Control-Allow-Credentials: true
Cross-Origin-Embedder-Policy: require-corp
Cross-Origin-Opener-Policy: same-origin-allow-popups
```

**Why this matters**: These headers control cross-origin resource access. Misconfigurations can lead to data leaks or Spectre-like attacks.

### HTTP Strict Transport Security (HSTS)

Forces HTTPS connections:

```
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
```

**Why this matters**: Without HSTS, users can be downgraded to HTTP, enabling MITM attacks.

### Permissions-Policy

Controls browser feature access:

```
Permissions-Policy: geolocation=(), camera=(), microphone=()
```

**Common directives**:
- `accelerometer`, `camera`, `geolocation`, `gyroscope`, `magnetometer`
- `microphone`, `payment`, `usb`, `fullscreen`
- `autoplay`, `clipboard-read`, `clipboard-write`

**Syntax values**:
- `()` - Disable entirely
- `(self)` - Same origin only
- `*` - All origins
- `(self "https://example.com")` - Same origin plus specified domain

**Why this matters**: Overly permissive policies allow attackers to abuse browser features through XSS or embedded iframes.

## Header Name Casing Bypass

HTTP/1.1 defines header names as case-insensitive, but many applications perform case-sensitive comparisons.

### How It Works

1. Identify a header that is filtered or validated server-side
2. Send the same header with different casing (e.g., `CAmelExecCommandExecutable` instead of `CamelExecCommandExecutable`)
3. The vulnerable check is skipped, but the downstream component accepts it

### Example: Apache Camel RCE (CVE-2025-27636)

```bash
curl "http://<IP>/command-center" \
  -H "CAmelExecCommandExecutable: ls" \
  -H "CAmelExecCommandArgs: /"
```

**Why this matters**: Custom middleware, security filters, and business logic often compare header names case-sensitively, allowing bypasses.

### Detection & Mitigation

- Normalize all header names to lowercase before comparisons
- Reject suspicious duplicates (e.g., both `Header:` and `HeAdEr:`)
- Use positive allow-lists enforced after canonicalization
- Protect management endpoints with authentication

## Testing Methodology

### Step 1: Reconnaissance

1. Send requests with various header combinations
2. Observe response headers for caching behavior
3. Identify security headers present or missing
4. Test for header reflection in responses

### Step 2: Header Injection

1. Try IP spoofing headers to bypass access controls
2. Test URL rewriting headers for path traversal
3. Inject hop-by-hop headers to bypass filters
4. Test header name casing variations

### Step 3: Cache Testing

1. Send requests with different `Vary` header values
2. Test conditional request headers
3. Attempt cache poisoning with manipulated headers
4. Check for sensitive data in cached responses

### Step 4: Request Smuggling

1. Send conflicting `Content-Length` and `Transfer-Encoding`
2. Test `Expect: 100-continue` variations
3. Monitor for desync indicators (unexpected responses, timing anomalies)
4. Attempt to inject requests or steal responses

### Step 5: Security Header Audit

1. Check for missing security headers
2. Test CSP bypasses
3. Verify X-Frame-Options effectiveness
4. Audit Permissions-Policy configurations
5. Test HSTS implementation

## Tools and Resources

### Wordlists

- [SecLists HTTP Headers](https://github.com/danielmiessler/SecLists/tree/master/Miscellaneous/Web/http-request-headers)
- [humble](https://github.com/rfc-st/humble)

### Testing Commands

Use the `test-http-headers.sh` script (see scripts/) to:
- Generate test requests with various header combinations
- Test for header-based vulnerabilities
- Audit security headers on target applications

## Best Practices

1. **Always test in authorized environments only** - Header manipulation can disrupt services
2. **Document findings clearly** - Include request/response pairs for reproducibility
3. **Consider business logic** - Header vulnerabilities often depend on application-specific behavior
4. **Test edge cases** - Different casing, encoding, and header combinations
5. **Verify mitigations** - Ensure fixes don't break legitimate functionality

## References

- [MDN HTTP Headers](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers)
- [web.dev Security Headers](https://web.dev/security-headers/)
- [CVE-2025-27636 - Apache Camel RCE](https://www.offsec.com/blog/cve-2025-27636/)
- [HTTP Request Smuggling](https://portswigger.net/web-security/request-smuggling)
