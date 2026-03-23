---
name: web-security-tricks
description: Security testing techniques for web applications including Host header injection, session manipulation, email takeover detection, and HTTP method exploitation. Use this skill when testing web application security, performing penetration testing, or investigating potential vulnerabilities in web services. Make sure to use this skill whenever the user mentions web security testing, penetration testing, vulnerability assessment, Host header attacks, session manipulation, email takeover, or HTTP method exploitation.
---

# Web Security Testing Tricks

A collection of web security testing techniques for identifying common vulnerabilities in web applications.

## Host Header Injection

Back-end systems often trust the **Host header** to perform actions like sending password reset emails. The domain used in reset links may come from the Host header value you provide.

### How to test

1. Intercept a password reset request
2. Modify the Host header to a domain you control
3. Check if the reset link uses your controlled domain

### Example

```bash
# Test with curl
curl -H "Host: attacker-controlled-domain.com" \
     -X POST https://target-site.com/reset-password \
     -d "email=victim@example.com"
```

### What to look for

- Password reset emails sent to your controlled domain
- Token leakage through spam filters or intermediary bots that auto-click links
- Account takeover possibilities

> **Note:** You may not need to wait for a user to click the link. Spam filters and security bots often auto-click links to analyze them, potentially exposing tokens.

## Session Boolean Manipulation

Some back-ends add boolean flags (e.g., `verified=True`) to session attributes after successful verification. Other endpoints may check the same attribute for access control.

### How to test

1. Complete a verification step that sets a session flag
2. Attempt to access other resources that depend on the same flag
3. Check if you gain unauthorized access

### Example

```bash
# After email verification, try accessing admin resources
curl -c cookies.txt -b cookies.txt \
     https://target-site.com/admin-panel
```

### What to look for

- Access to resources you shouldn't have permissions for
- Second-order IDOR vulnerabilities
- Inconsistent access control checks across endpoints

## Registration Functionality Testing

Test the registration endpoint for various edge cases and potential bypasses.

### Test cases

1. **Duplicate registration**: Try registering with an existing username/email
2. **Character normalization**: Use equivalent characters:
   - Dots: `user.name` vs `username`
   - Spaces: `user name` vs `username`
   - Unicode: `user` vs `user` (different Unicode representations)
3. **Case sensitivity**: `User` vs `user` vs `USER`

### Example

```bash
# Test with various character combinations
curl -X POST https://target-site.com/register \
     -d "username=user.name&email=test@example.com"

curl -X POST https://target-site.com/register \
     -d "username=user%20name&email=test@example.com"
```

## Email Takeover Detection

Test for email takeover vulnerabilities in account recovery and verification flows.

### Technique 1: Email change before confirmation

1. Register with email A
2. Before confirming email A, change email to B
3. Check if confirmation for A is sent to B

### Technique 2: Secondary email confirmation

1. Register with email A
2. Add email B as secondary
3. Confirm email B
4. Check if this confirms email A

### What to look for

- Confirmation emails sent to wrong addresses
- Account takeover through email verification bypass
- Inconsistent email validation logic

## Atlassian Service Desk Access

Companies using Atlassian may expose internal service desks through predictable URLs.

### Test URL pattern

```
https://yourcompanyname.atlassian.net/servicedesk/customer/user/login
```

### How to test

1. Identify company's Atlassian subdomain
2. Try accessing the service desk login URL
3. Check for exposed internal resources

### Example

```bash
# Check if service desk is accessible
curl -I https://companyname.atlassian.net/servicedesk/customer/user/login
```

## HTTP TRACE Method Exploitation

The HTTP TRACE method echoes back the exact request received. If enabled in production, it can reveal internal authentication headers added by reverse proxies.

### How to test

```bash
# Send TRACE request
curl -X TRACE https://target-site.com/

# Or with verbose output
curl -v -X TRACE https://target-site.com/
```

### What to look for

- Echoed request headers in response
- Internal authentication headers (e.g., `X-Internal-Auth`, `X-Forwarded-User`)
- Debug information that shouldn't be exposed

### Example response

```
HTTP/1.1 200 OK
Content-Type: message/http

HTTP/1.1 TRACE / HTTP/1.1
Host: target-site.com
X-Internal-Auth: internal-token-12345
X-Forwarded-User: admin
```

## Testing Workflow

When testing a web application:

1. **Start with reconnaissance**: Identify the technology stack and endpoints
2. **Test Host header injection**: Especially on password reset and email functionality
3. **Check session handling**: Look for boolean flags and access control issues
4. **Test registration flows**: Try edge cases and character normalization
5. **Verify email flows**: Check for takeover possibilities
6. **Test HTTP methods**: Try TRACE and other less common methods
7. **Document findings**: Record all vulnerabilities with reproduction steps

## Safety and Ethics

- Only test systems you have explicit authorization to test
- Document all findings for responsible disclosure
- Avoid causing service disruption during testing
- Follow responsible disclosure practices when reporting vulnerabilities
