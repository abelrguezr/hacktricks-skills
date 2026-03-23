---
name: http-bypass-auditor
description: How to audit and test for HTTP 403/401 bypass vulnerabilities. Use this skill whenever the user mentions access control testing, forbidden page bypasses, authentication bypass, 403 errors, 401 errors, HTTP method fuzzing, header manipulation, path traversal testing, or any web security testing involving restricted resources. Make sure to use this skill when users want to test if they can access protected endpoints through various bypass techniques, even if they don't explicitly mention 'bypass' or '403'.
---

# HTTP 403/401 Bypass Auditor

A skill for systematically testing HTTP access control bypasses on web applications.

## When to Use This Skill

Use this skill when:
- You encounter 403 Forbidden or 401 Unauthorized responses
- You need to test if access controls can be bypassed
- You're performing web application security assessments
- You want to enumerate protected resources
- You're testing authentication/authorization mechanisms

## Testing Methodology

Follow this systematic approach to test for bypass vulnerabilities:

### 1. HTTP Method Fuzzing

Try different HTTP verbs to access the protected resource:

**Methods to test:**
- `GET`, `HEAD`, `POST`, `PUT`, `DELETE`, `CONNECT`, `OPTIONS`, `TRACE`, `PATCH`
- Custom/invented methods: `INVENTED`, `HACK`

**What to check:**
- Response codes (200, 403, 401, 404, 500)
- Response headers (Content-Length, Server, X-Powered-By)
- Response body differences
- HEAD requests returning 200 with Content-Length may indicate accessible content

**Method override headers:**
- `X-HTTP-Method-Override: PUT`
- `X-HTTP-Method-Override: DELETE`

**TRACE method:**
- Can reveal headers added by intermediate proxies
- May expose internal infrastructure details

### 2. HTTP Header Fuzzing

**Host header manipulation:**
- Change Host to arbitrary values
- Try `Host: localhost`
- Remove Host header entirely

**User-Agent variations:**
- Test different User-Agent strings
- Use common bypass User-Agents
- Try empty User-Agent

**Proxy/Forwarding headers (try with 127.0.0.1):**
- `X-Originating-IP: 127.0.0.1`
- `X-Forwarded-For: 127.0.0.1`
- `X-Forwarded: 127.0.0.1`
- `Forwarded-For: 127.0.0.1`
- `X-Remote-IP: 127.0.0.1`
- `X-Remote-Addr: 127.0.0.1`
- `X-ProxyUser-Ip: 127.0.0.1`
- `X-Original-URL: 127.0.0.1`
- `Client-IP: 127.0.0.1`
- `True-Client-IP: 127.0.0.1`
- `Cluster-Client-IP: 127.0.0.1`

**Path bypass headers:**
- `X-Original-URL: /admin/console`
- `X-Rewrite-URL: /admin/console`

**Special headers to fuzz:**
- Content-Type variations
- Accept headers
- Authorization headers
- Custom application headers

### 3. Path Fuzzing

**URL encoding bypasses:**
- `/%2e/path` (dot encoding)
- `/%252e/path` (double URL encoding)
- `/%ef%bc%8fpath` (Unicode full-width slash)

**Path manipulation techniques:**
- Case variations: `/SECRET` vs `/secret`
- Trailing slashes: `/secret/`
- Dot sequences: `/secret/.`, `/./secret/..`
- Double slashes: `//secret//`
- Semicolon injection: `/;/secret`, `/.;/secret`, `//;//secret`
- File extensions: `/secret.json` (Ruby apps)

**API version bypasses:**
- `/v3/users_data/1234` → `/v1/users_data/1234`
- Try different API version numbers

**Parameter pollution:**
- JSON: `{"user_id":"<legit_id>","user_id":"<victims_id>"}`
- Query: `user_id=ATTACKER_ID&user_id=VICTIM_ID`
- Array injection: `{"id":[111]}` instead of `{"id":111}`
- Nested objects: `{"id":{"id":111}}`

### 4. Parameter Manipulation

**Value changes:**
- Increment/decrement IDs: `id=123` → `id=124`
- Boundary testing: `-234`, `0`, `99999999`
- Special characters in values

**Parameter additions:**
- Add admin flags: `?id=124&isAdmin=true`
- Add authentication parameters
- Add debug parameters

**Parameter removal:**
- Remove required parameters
- Remove authentication tokens

**Parameter reordering:**
- Change parameter order in query string
- May bypass validation logic

### 5. Protocol Testing

**HTTP version changes:**
- HTTP/1.1 → HTTP/1.0
- HTTP/1.1 → HTTP/2.0
- Different protocol versions may have different handling

**Protocol switching:**
- HTTP → HTTPS
- HTTPS → HTTP
- May bypass SSL/TLS checks

### 6. Infrastructure Bypasses

**Direct IP access:**
- Get IP or CNAME of domain
- Contact directly without DNS
- May bypass domain-based restrictions

**Archive testing:**
- Check https://archive.org/web/
- See if resources were previously accessible
- May reveal historical access patterns

**Server stress:**
- Send rapid common GET requests
- May cause race conditions or timeout bypasses

### 7. Authentication Bypass

**Common credentials to test:**
```
admin    admin
admin    password
admin    1234
admin    admin1234
admin    123456
root     toor
test     test
guest    guest
```

**Authentication methods:**
- Basic authentication
- Digest authentication
- NTLM authentication
- Session token manipulation

## Automated Testing

Use these tools for systematic testing:

| Tool | Purpose |
|------|---------|
| [byp4xx](https://github.com/lobuhi/byp4xx) | 4xx error bypass automation |
| [bypass-403](https://github.com/iamj0ker/bypass-403) | 403 bypass testing |
| [forbiddenpass](https://github.com/gotr00t0day/forbiddenpass) | Forbidden page bypass |
| [403 Bypasser](https://portswigger.net/bappstore/444407b96d9c4de0adb7aed89e826122) | Burp extension |
| [Forbidden Buster](https://github.com/Sn1r/Forbidden-Buster) | Automated bypass testing |
| [NoMoreForbidden](https://github.com/akinerk/NoMoreForbidden) | 403 bypass tool |

## Advanced Techniques

**HTTP Request Smuggling:**
- If behind a proxy, test for request smuggling vulnerabilities
- Can bypass proxy-based access controls

**Hop-by-Hop Headers:**
- Abuse hop-by-hop headers to bypass proxy restrictions
- Headers like `Connection`, `Keep-Alive`, `Proxy-Authenticate`

**Unicode Fuzzing:**
- Use Unicode character lists for path fuzzing
- Test at different positions: `/FUZZsecret`, `/FUZZ/secret`, `/secretFUZZ`

## Reporting Findings

When documenting bypass vulnerabilities:

1. **Endpoint**: The protected URL
2. **Original Response**: 403/401 status and body
3. **Bypass Method**: Which technique worked
4. **Modified Request**: The successful request details
5. **Impact**: What was accessed or what could be accessed
6. **Remediation**: How to fix the vulnerability

## Safety and Ethics

- Only test systems you have authorization to test
- Document all findings for remediation
- Avoid destructive operations (DELETE, PUT with data modification)
- Respect rate limits to avoid DoS
- Follow responsible disclosure practices

## Quick Reference

**Most effective bypasses to try first:**
1. HTTP method changes (HEAD, OPTIONS, TRACE)
2. Path case variations and trailing slashes
3. X-Forwarded-For header with 127.0.0.1
4. URL encoding variations
5. Parameter pollution
6. API version changes
7. Direct IP access

**Response indicators of success:**
- Status code changes from 403/401 to 200
- Content-Length changes
- Different response body
- New headers appear
- Server error (500) may indicate partial bypass
