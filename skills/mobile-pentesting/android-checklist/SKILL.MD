---
name: android-apk-pentest
description: Android APK penetration testing methodology and checklist. Use this skill whenever analyzing Android applications for security vulnerabilities, performing mobile app security assessments, reverse engineering APKs, or conducting static/dynamic analysis of Android apps. Trigger for any Android security testing, APK analysis, mobile pentesting, or when investigating Android app vulnerabilities including exported components, insecure data storage, crypto issues, intent-based attacks, WebView exploits, or Play Integrity bypasses.
---

# Android APK Penetration Testing

A comprehensive methodology for security testing Android applications.

## Quick Start

1. **Static Analysis** - Examine the APK without running it
2. **Dynamic Analysis** - Test the running application
3. **Exploitation** - Attempt to leverage findings
4. **Reporting** - Document vulnerabilities

## Static Analysis

### Environment Setup

```bash
# Install essential tools
apktool
jadx
mobf
semgrep
# Optional: MobSF, Pithus, flutter-packer, rn-differ
```

### Manifest Review

Check for:
- Debug mode enabled (`android:debuggable="true"`)
- Backup permissions (`android:allowBackup="true"`)
- Exported components (Activities, Services, Providers, Receivers)
- Network security config (`networkSecurityConfig` XML)
- Intent filters and URL schemes
- `android:exported` flag (mandatory on Android 12+)
- App Links / Deep Links (`android:autoVerify`)

**Critical checks:**
- Unity Runtime: exported `UnityPlayerActivity`/`UnityPlayerGameActivity` with `unity` CLI extras bridge
- Test `-xrsdk-pre-init-library <abs-path>` for pre-init `dlopen()` RCE
- OEM ROM add-ons (OxygenOS/ColorOS/MIUI/OneUI) for extra exported ContentProviders

### Code Analysis

Search for:
- Hardcoded credentials and API keys
- Insecure crypto algorithms (deprecated/weak)
- Sensitive data storage (internal/external)
- Firebase configuration and APIs
- Passwords, tokens, Bluetooth UUIDs
- Obfuscation presence (ProGuard, R8, etc.)
- Root detection, emulator detection, anti-tampering checks
- `WebView.addJavascriptInterface` or `loadData*()` calls
- Play Integrity / SafetyNet / DeviceCheck implementations

### Component Analysis

Test each component:
- **Activities** - especially exported ones
- **Services** - check for exposed services
- **Content Providers** - test for SQL injection, path traversal
- **Broadcast Receivers** - check for intent injection
- **URL Schemes** - verify intent handling

### Library Analysis

- Check if all libraries compiled with PIE flag
- Scan third-party native libraries for known CVEs (libwebp CVE-2023-4863, libpng, etc.)
- Analyze cross-platform bundles (Flutter `libapp.so`, React-Native JS bundles, Capacitor/Ionic assets)
- Use SEMgrep Mobile rules, Pithus, MobSF ≥ 3.9 AI-assisted scans

## Dynamic Analysis

### Environment Setup

- Online dynamic analysis environment
- Local VM or physical device
- ADB configured and working
- Proxy tool ready (Burp, mitmproxy, etc.)

### Runtime Testing

Check for:
- Unintended data leakage (logging, copy/paste, crash logs)
- Confidential information in SQLite databases
- Exploitable exposed Activities (authorization bypass)
- Exploitable Content Providers (accessing/manipulating sensitive data)
- Exploitable exposed Services
- Exploitable Broadcast Receivers
- Clear text transmission / weak algorithms
- MitM possibilities

### Traffic Inspection

- Intercept HTTP/HTTPS traffic
- Search for common Web vulnerabilities
- Check for Android Client Side Injections
- Verify certificate pinning

### Runtime Hooking

Use **Frida** to:
- Obtain dynamic data from the application
- Bypass security checks
- Extract passwords and tokens
- Hook Play Integrity / SafetyNet
- Test runtime modifications

**Modern tooling:**
- Objection > 2.0
- Frida 17+ (Android 16 support, ART offset fixes)
- NowSecure-Tracer (2024)
- Dynamic system-wide tracing with `perfetto` / `simpleperf`

### Advanced Exploitation

- **Tapjacking / Animation-driven attacks** (TapTrap 2025) - even on Android 15+
- **Overlay / SYSTEM_ALERT_WINDOW clickjacking**
- **Accessibility Service abuse** for privilege escalation
- `adb backup` / `bmgr backupnow` for app data dumping
- **Binder-level LPEs** (CVE-2023-20963, CVE-2023-20928)
- Play Integrity bypass: `Frida Gadget`, `MagiskIntegrityFix`, `Integrity-faker`
- Recent Play Integrity Fix forks (≥17.x) with `playcurl`
- ZygiskNext + PIF + ZygiskAssistant/TrickyStore combinations

### OEM-Specific Testing

For OEM telephony/provider bugs (e.g., OxygenOS CVE-2025-10184):
- Attempt permission-less SMS read/send via `content` CLI
- Test blind SQLi in `update()` to exfiltrate rows
- Query: `content query --uri content://com.android.providers.telephony/ServiceNumberProvider` without `READ_SMS`

## Common Vulnerabilities Checklist

### Authentication & Authorization
- [ ] Weak authentication mechanisms
- [ ] Session management issues
- [ ] Authorization bypass in exported components
- [ ] Intent-based authorization bypass

### Data Protection
- [ ] Insecure data storage (internal/external)
- [ ] Hardcoded credentials
- [ ] Weak or deprecated crypto
- [ ] Sensitive data in logs
- [ ] SQLite database exposure

### Network Security
- [ ] Cleartext traffic permitted
- [ ] Certificate pinning bypass
- [ ] Weak TLS configuration
- [ ] API key exposure

### Component Security
- [ ] Exported Activities without proper validation
- [ ] Exported Services without authentication
- [ ] Content Provider SQL injection
- [ ] Broadcast Receiver intent injection
- [ ] URL Scheme vulnerabilities

### Runtime Security
- [ ] Root detection bypass
- [ ] Emulator detection bypass
- [ ] Anti-tampering bypass
- [ ] WebView JavaScript interface exposure
- [ ] Play Integrity / SafetyNet bypass

## Reporting

Document:
- Vulnerability description
- CVSS score
- Proof of concept
- Impact assessment
- Remediation recommendations
- References to CVEs where applicable

## References

- [CVE-2025-59489 – Arbitrary Code Execution in Unity Runtime](https://flatt.tech/research/posts/arbitrary-code-execution-in-unity-runtime/)
- [CVE-2025-10184 – OnePlus OxygenOS Telephony Provider Bypass](https://www.rapid7.com/blog/post/cve-2025-10184-oneplus-oxygenos-telephony-provider-permission-bypass-not-fixed/)
- [TapTrap Animation-Based Tapjacking Research](https://www.tomsguide.com/computing/online-security/this-new-android-attack-could-trick-you-into-compromising-your-own-phone-everything-you-need-to-know)
- [Hacktricks Android Pentesting](https://book.hacktricks.xyz/pentesting-mobile/android-app-pentesting)
