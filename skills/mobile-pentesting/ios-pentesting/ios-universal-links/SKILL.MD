---
name: ios-universal-links-pentest
description: Pentest iOS Universal Links by extracting entitlements, fetching apple-app-site-association (AASA) files, and identifying misconfigurations like over-broad paths, missing server validation, and wildcard subdomains. Use this skill whenever the user mentions iOS app security, universal links, deep links, AASA files, associated domains, or wants to test mobile app link handling vulnerabilities.
---

# iOS Universal Links Pentesting

A skill for security testing iOS Universal Links configurations to identify vulnerabilities that could lead to link hijacking, phishing, or unauthorized app behavior.

## What This Skill Does

This skill helps you:
1. Extract `applinks:` domains from iOS app entitlements
2. Fetch and analyze `apple-app-site-association` (AASA) files
3. Identify common vulnerabilities in Universal Links configuration
4. Validate server-side path handling
5. Generate a security assessment report

## When to Use This Skill

Use this skill when:
- Testing iOS app security and Universal Links implementation
- Analyzing `apple-app-site-association` files for misconfigurations
- Enumerating associated domains from iOS entitlements
- Investigating potential Universal Link hijacking vulnerabilities
- Auditing deep link security in mobile applications

## Workflow Overview

```
1. Extract entitlements → 2. Parse applinks domains → 3. Fetch AASA files → 4. Validate configuration → 5. Report findings
```

## Step 1: Extract Associated Domains from Entitlements

### From Xcode Project

If you have access to the Xcode project, check the Capabilities tab or the `.entitlements` file:

```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:example.com</string>
    <string>applinks:app.example.com</string>
</array>
```

### From Compiled Binary

Extract entitlements from a compiled `.app` or `.ipa` file:

```bash
# From .app bundle
plutil -p YourApp.app/Info.plist | grep -A 10 "com.apple.developer.associated-domains"

# Or extract the entitlements file directly
plutil -p YourApp.app/embedded.mobileprovision 2>/dev/null || \
    strings YourApp.app/YourApp | grep -A 5 "associated-domains"
```

### Using the Helper Script

If you have an entitlements XML file, use the extraction script:

```bash
./scripts/extract_applinks_domains.sh ent.xml
```

This outputs all `applinks:` domains, one per line.

## Step 2: Fetch AASA Files

The `apple-app-site-association` file should be at:
- `https://<domain>/apple-app-site-association`
- `https://<domain>/.well-known/apple-app-site-association`

### Using the Helper Script

```bash
./scripts/fetch_aasa_files.sh domain1.com domain2.com
```

Or pipe domains from the extraction script:

```bash
./scripts/extract_applinks_domains.sh ent.xml | xargs -I {} ./scripts/fetch_aasa_files.sh {}
```

### Manual Fetch

```bash
curl -sk "https://example.com/.well-known/apple-app-site-association" | jq '.'
curl -sk "https://example.com/apple-app-site-association" | jq '.'
```

## Step 3: Validate AASA Configuration

### Common Vulnerabilities to Check

| # | Weakness | How to Test | Impact |
|---|----------|-------------|--------|
| 1 | **Over-broad paths** (`"/": "*"` or wildcards like `"/a/*"`) | Inspect AASA for `*`, trailing slashes, or `{"?": ...}` rules | Universal link hijacking - malicious app can claim all matching links |
| 2 | **Missing server-side validation** | Request non-existing resources; anything other than 404 is suspicious | Attacker can host arbitrary content behind allowed paths |
| 3 | **App-side URL handling without whitelisting** | Look for direct `openURL:`/`open(_:options:)` calls | URL spoofing, bypassing browser safety checks |
| 4 | **Wildcard subdomains** (`*.example.com`) | `grep` for `*.` in entitlements | Subdomain takeover grants automatic Universal Link binding |

### Using the Validation Script

```bash
./scripts/validate_aasa.sh aasa_file.json
```

This checks for:
- Over-broad path patterns
- Wildcard usage
- Missing required fields
- Common misconfigurations

## Step 4: Server-Side Path Validation

Test that the server returns 404 for undefined paths:

```bash
# Test various paths that might match wildcard rules
for path in "/nonexistent" "/a/evil" "/a/evil?_p_dp=1" "/unknown/path"; do
  echo "Testing: $path"
  curl -sI "https://example.com$path" | head -1
done
```

**Expected**: `HTTP/1.1 404 Not Found`
**Suspicious**: `HTTP/1.1 200 OK` or `HTTP/1.1 302 Found`

## Step 5: Generate Assessment Report

Create a structured report of findings:

```markdown
# iOS Universal Links Security Assessment

## Target Application
- App Name: [Name]
- Bundle ID: [Bundle ID]
- Version: [Version]

## Associated Domains
| Domain | AASA Found | Status |
|--------|------------|--------|
| example.com | Yes | ⚠️ Over-broad paths |
| app.example.com | No | ❌ Missing AASA |

## Vulnerabilities Found

### 1. Over-broad Path Configuration
- **Domain**: example.com
- **Issue**: Path pattern `"/a/*"` matches all sub-paths
- **Risk**: High - Universal link hijacking possible
- **Reference**: CVE-2024-10474, Temu.com bug bounty (May 2025)

### 2. Missing Server-Side Validation
- **Domain**: example.com
- **Issue**: Non-existent paths return 200 instead of 404
- **Risk**: Medium - Phishing content can be served

## Recommendations
1. Restrict path patterns to specific, known routes
2. Ensure server returns 404 for undefined paths
3. Implement app-side URL scheme/host whitelisting
4. Remove wildcard subdomain entries if not needed

## Tools Used
- AASA Validator: https://branch.io/resources/aasa-validator/
- Knil: https://github.com/ethanhuang13/knil
- universal-link-validator: https://github.com/urbangems/universal-link-validator
```

## AASA File Structure Reference

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAMID.com.example.app",
        "paths": ["/specific/path", "/another/path"]
      }
    ]
  },
  "appclips": {
    "apps": [],
    "details": [
      {
        "appID": "TEAMID.com.example.app",
        "paths": ["/appclip/path"]
      }
    ]
  }
}
```

### iOS 11+ Components Syntax

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAMID.com.example.app",
        "components": [
          {
            "%path": "/users/:id",
            "?": {
              "action": ["view", "edit"]
            }
          }
        ]
      }
    ]
  }
}
```

## Quick Checklist

- [ ] Extract entitlements and enumerate every `applinks:` entry
- [ ] Download AASA for each entry and audit for wildcards
- [ ] Verify the web server returns **404** for undefined paths
- [ ] In the binary, confirm that **only** trusted hosts/schemes are handled
- [ ] If using `components` syntax (iOS 11+), fuzz query-parameter rules
- [ ] Check for wildcard subdomains (`*.example.com`) in entitlements
- [ ] Validate AASA file is served with correct MIME type (`application/json`)
- [ ] Ensure AASA is accessible via HTTPS only

## References

- [OWASP MASTG - iOS Universal Links Testing](https://mas.owasp.org/MASTG/tests/ios/MASVS-PLATFORM/MASTG-TEST-0070/)
- [Mobile Security Testing Guide - iOS Platform Interaction](https://mobile-security.gitbook.io/mobile-security-testing-guide/ios-testing-guide/0x06h-testing-platform-interaction)
- [Apple Developer Documentation - Universal Links](https://developer.apple.com/library/archive/documentation/General/Conceptual/AppSearch/UniversalLinks.html)
- [CVE-2024-10474 - Mozilla Focus Universal Link Bypass](https://nvd.nist.gov/vuln/detail/CVE-2024-10474)
- [Temu.com Universal Link Hijacking Case Study](https://medium.com/@m.habibgpi/universal-link-hijacking-via-misconfigured-aasa-file-on-temu-com)

## Tools

- [GetUniversal.link](https://getuniversal.link/) - AASA file verification and testing
- [Knil](https://github.com/ethanhuang13/knil) - iOS utility to tap-test Universal Links on device
- [universal-link-validator](https://github.com/urbangems/universal-link-validator) - CLI/web validator for AASA conformance
- [AASA Validator](https://branch.io/resources/aasa-validator/) - Online AASA file validator
