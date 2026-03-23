---
name: mobile-phishing-analysis
description: Analyze mobile phishing campaigns, malicious Android APKs, and iOS mobile configuration profiles. Use this skill whenever investigating suspicious mobile apps, phishing infrastructure, or mobile malware. Trigger when users mention APK analysis, mobileconfig inspection, phishing campaign investigation, Android/iOS malware triage, or mobile threat intelligence. This skill helps security researchers and analysts understand attack patterns, extract indicators, and document findings from mobile threats.
---

# Mobile Phishing & Malicious App Analysis

A skill for analyzing mobile phishing campaigns, malicious Android APKs, and iOS mobile configuration profiles. This skill helps security professionals investigate threats, extract indicators, and understand attack patterns.

## When to Use This Skill

Use this skill when:
- Investigating suspicious Android APKs or iOS mobile configuration profiles
- Analyzing mobile phishing campaigns (dating apps, fake stores, government benefit scams)
- Extracting indicators of compromise (IOCs) from mobile malware
- Understanding attack patterns like WebView droppers, accessibility abuse, or FCM-based C2
- Documenting mobile threat intelligence findings
- Performing triage on potentially malicious mobile apps

## Core Analysis Workflow

### 1. Initial Triage

Start by understanding what you're analyzing:

**For Android APKs:**
- Check if it's a dropper (contains embedded payloads in `assets/`)
- Review permissions in `AndroidManifest.xml`
- Look for suspicious patterns (WebView with JavaScript interfaces, PackageInstaller usage)

**For iOS mobileconfig:**
- Inspect `PayloadType` and `PayloadContent`
- Check for excessive entitlements (Contacts, Photos, MDM enrollment)
- Look for Web Clip payloads that pin phishing URLs

### 2. Static Analysis

Use the bundled scripts to extract key information:

```bash
# Extract permissions from APK
python scripts/extract_apk_permissions.py <apk-file>

# Check for embedded payloads
python scripts/check_embedded_payloads.py <apk-file>

# Inspect mobileconfig profiles
python scripts/inspect_mobileconfig.py <profile.mobileconfig>
```

### 3. Dynamic Analysis Preparation

If you need to test behavior:
- Set up a sandbox environment (Android emulator or iOS simulator)
- Configure network monitoring (tcpdump, Wireshark)
- Prepare Frida scripts for hooking (see `scripts/frida_hooks/`)
- Set up HTTP canaries to detect C2 communication

### 4. IOC Extraction

Document all indicators:
- Domain names and URLs
- File hashes (MD5, SHA256)
- C2 endpoints and paths
- Package names and bundle IDs
- Certificate fingerprints
- Behavioral patterns

## Common Attack Patterns

### Pattern 1: Invitation Code Evasion

Malware waits for a valid "invitation code" before activating malicious behavior:

**Detection:**
- Look for HTTP POST to endpoints like `/checkCode.php` or `/req/checkCode.php`
- Check for conditional permission requests after C2 response
- Use Frida to auto-bypass (see `scripts/frida_hooks/bypass_invitation.js`)

**Analysis tip:** Static analysis may show no malicious behavior. You need to simulate the code submission to trigger the payload.

### Pattern 2: WebView Dropper with Native Bridge

A WebView loads attacker HTML that calls into native code via JavaScript interface:

**Detection:**
- Search for `addJavascriptInterface` in decompiled code
- Look for exported methods like `installApk()`, `download()`, `execute()`
- Check for embedded APKs in `assets/` directory

**Static triage:**
```bash
unzip -l sample.apk | grep -i "assets/.*\.apk"
strings sample.apk | grep -i "javascriptinterface"
```

### Pattern 3: Accessibility Service Abuse

Malware requests Accessibility permissions to automate UI interactions:

**Detection:**
- Check for `AccessibilityService` in manifest
- Look for `ACTION_ACCESSIBILITY_SETTINGS` navigation
- Search for node tree traversal and click automation

**Red flags:**
- Apps requesting Accessibility for non-assistive purposes
- Combined with overlay permissions
- Used for ATS (Automated Transfer System) in banking apps

### Pattern 4: FCM-Based C2

Firebase Cloud Messaging used as resilient command channel:

**Detection:**
- Look for Firebase SDK integration
- Check for custom `_type` field in message handling
- Search for switch/case on message data

**Analysis:**
```bash
strings sample.apk | grep -i "fcm\|firebase\|cloudmessaging"
```

### Pattern 5: iOS Mobileconfig Abuse

Malicious configuration profiles for device enrollment:

**Detection:**
- `PayloadType=com.apple.sharedlicenses` or `com.apple.managedConfiguration`
- `com.apple.webClip.managed` for phishing URL pinning
- Excessive entitlements without App Store review

**Inspection:**
```bash
security cms -D -i profile.mobileconfig
```

## IOC Categories

### Network Indicators
- C2 domains and paths (`/upload.php`, `/checkCode.php`, `/addsm.php`)
- Shortlink services used for config delivery
- WebSocket/Socket.IO endpoints for payload smuggling
- Plain HTTP on port 80 (no TLS)

### File Indicators
- APK hashes and embedded payload hashes
- `LubanCompress` string in `classes.dex`
- Secondary payloads in `assets/app.apk`

### Behavioral Indicators
- Permission requests after C2 validation
- SMS interception and exfiltration
- Contact list harvesting
- Screen capture and remote control
- NFC relay orchestration

## Documentation Template

When documenting findings, use this structure:

```markdown
# Analysis Report: [App Name/Hash]

## Summary
[Brief description of the threat]

## Indicators
- **Package/Bundle ID:** [ID]
- **File Hash:** [SHA256]
- **C2 Domains:** [List]
- **Malicious Endpoints:** [List]

## Attack Pattern
[Which pattern(s) observed]

## Permissions Requested
[List dangerous permissions]

## Exfiltrated Data
[What data is stolen]

## Mitigation
[Recommended defenses]
```

## Scripts Reference

### `scripts/extract_apk_permissions.py`
Extracts all permissions from an APK's manifest.

### `scripts/check_embedded_payloads.py`
Scans for embedded APKs in assets directory.

### `scripts/inspect_mobileconfig.py`
Parses and displays iOS mobile configuration profile contents.

### `scripts/frida_hooks/bypass_invitation.js`
Frida script to auto-bypass invitation code checks.

### `scripts/frida_hooks/network_monitor.js`
Frida script to monitor HTTP/HTTPS calls.

## Safety Notes

- Always analyze in isolated environments (VMs, sandboxes)
- Never run suspicious apps on production devices
- Use network isolation to prevent C2 communication
- Document all findings for threat intelligence sharing
- Follow responsible disclosure practices

## References

- [Android Malware Analysis Guide](https://github.com/nowsecure/mobile-security-testing-guide)
- [iOS Security Guide](https://www.apple.com/business/docs/iOS_Security_Guide.pdf)
- [OWASP Mobile Security Testing Guide](https://owasp.org/www-project-mobile-security-testing-guide/)

---

## Quick Start

1. **For APK analysis:**
   ```bash
   python scripts/extract_apk_permissions.py suspicious.apk
   python scripts/check_embedded_payloads.py suspicious.apk
   ```

2. **For mobileconfig analysis:**
   ```bash
   python scripts/inspect_mobileconfig.py profile.mobileconfig
   ```

3. **For dynamic analysis:**
   - Set up Android emulator with the APK installed
   - Run Frida hooks: `frida -U -f <package> -l scripts/frida_hooks/bypass_invitation.js`
   - Monitor network traffic with tcpdump or Wireshark

4. **Document findings** using the template above and share IOCs with your team.
