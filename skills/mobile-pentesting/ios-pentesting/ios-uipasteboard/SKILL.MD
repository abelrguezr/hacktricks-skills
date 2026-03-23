---
name: ios-pasteboard-pentest
description: How to test iOS applications for pasteboard security vulnerabilities. Use this skill whenever you need to analyze iOS app clipboard usage, check for sensitive data exposure via UIPasteboard, or perform static/dynamic analysis of iOS pasteboard implementations. Make sure to use this skill when pentesting iOS apps and you need to check clipboard/pasteboard security, analyze data sharing mechanisms, or look for sensitive information leakage through UIPasteboard.
---

# iOS Pasteboard Pentesting

This skill guides you through testing iOS applications for pasteboard security vulnerabilities. The `UIPasteboard` mechanism is a common attack vector for data exfiltration and information leakage.

## Understanding iOS Pasteboard Types

iOS has two primary pasteboard categories:

### Systemwide General Pasteboard
- Used for sharing data with **any application**
- Persists across device restarts and app uninstallations (iOS 10+)
- Most common attack surface for data leakage
- Accessible by all apps when in foreground

### Custom/Named Pasteboards
- For data sharing **within an app or with apps sharing the same team ID**
- Not designed to persist beyond the creating process (iOS 10+)
- Less commonly exploited but still worth checking

## Security Considerations

Key security facts to keep in mind:

- **No user permission controls** exist for pasteboard access
- Access is restricted to **foreground applications only** (iOS 9+)
- **Universal Clipboard** (iOS 10+) can sync content across devices
- **Persistent named pasteboards are deprecated** due to privacy concerns
- Sensitive data should **never** be stored on the global pasteboard

## Static Analysis

Search the source code or binary for these indicators:

### General Pasteboard Usage
```objc
[UIPasteboard generalPasteboard]
UIPasteboard.generalPasteboard()
```

### Custom Pasteboard Creation
```objc
[UIPasteboard pasteboardWithName:create:]
[UIPasteboard pasteboardWithUniqueName]
```

### Deprecated Persistence
```objc
[UIPasteboard setPersistent:]
```

**What to look for:**
- Sensitive data (tokens, passwords, PII) being written to pasteboard
- Lack of data expiration settings
- Use of deprecated persistent named pasteboards
- No validation of pasteboard content before reading

## Dynamic Analysis

### Hooking Key Methods

Monitor these methods during runtime:

1. **`generalPasteboard`** - System-wide usage
2. **`pasteboardWithName:create:`** - Custom implementations
3. **`pasteboardWithUniqueName`** - Unique custom pasteboards
4. **`setItems:options:`** - Check expiry and local-only options

### What to Monitor

- **Pasteboard names** - Identify custom pasteboards
- **Contents** - Check for strings, URLs, images, sensitive data
- **Number of items** - Track data volume
- **Data types** - Standard and custom type checks
- **Expiry settings** - Verify data expiration is configured
- **Local-only flags** - Check Universal Clipboard behavior

### Using the Pasteboard Monitor Script

The bundled `monitor-pasteboard.js` script polls the general pasteboard every 5 seconds and logs changes. Use it with Frida:

```bash
frida -U -f com.example.app --no-pause -l monitor-pasteboard.js --no-pause
```

Or attach to a running process:

```bash
frida -U -l monitor-pasteboard.js -f <process_name>
```

The script will output:
- Change count
- Data type indicators (strings, URLs, images)
- Full pasteboard contents

### Manual Testing Steps

1. **Identify pasteboard usage** - Use static analysis to find pasteboard calls
2. **Hook the methods** - Use Frida or objection to monitor runtime behavior
3. **Trigger pasteboard operations** - Copy/paste within the app, share data
4. **Capture sensitive data** - Look for tokens, credentials, PII in pasteboard
5. **Test cross-app access** - Launch another app and check if it can read the data
6. **Verify expiration** - Check if sensitive data persists longer than necessary
7. **Test Universal Clipboard** - If applicable, verify cross-device sync behavior

## Common Vulnerabilities

### 1. Sensitive Data Exposure
- Tokens, passwords, or PII written to general pasteboard
- No expiration set on sensitive data
- Data persists after app termination

### 2. Unrestricted Read Access
- App reads from general pasteboard without validation
- No sanitization of pasteboard content before use
- Potential for malicious pasteboard injection attacks

### 3. Improper Custom Pasteboard Usage
- Using deprecated persistent named pasteboards
- Custom pasteboards with overly broad team ID sharing
- No access controls on custom pasteboard data

## Remediation Recommendations

- **Avoid storing sensitive data** on any pasteboard
- **Use app-specific pasteboards** with unique names when sharing is necessary
- **Set expiration** on pasteboard items using `setItems:options:`
- **Disable Universal Clipboard** for sensitive content
- **Clear pasteboard** after use when possible
- **Validate and sanitize** all pasteboard content before processing

## References

- [OWASP MSTG - Testing Object Persistence](https://mobile-security.gitbook.io/mobile-security-testing-guide/ios-testing-guide/0x06h-testing-platform-interaction#testing-object-persistence-mstg-platform-8)
- [OWASP MASTG - MASVS-PLATFORM/MASTG-TEST-0073](https://mas.owasp.org/MASTG/tests/ios/MASVS-PLATFORM/MASTG-TEST-0073/)
- [iOS Pasteboard Documentation](https://developer.apple.com/documentation/uikit/uipasteboard)
