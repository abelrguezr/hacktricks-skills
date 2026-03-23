---
name: android-biometric-bypass
description: Android biometric authentication pentesting and bypass techniques. Use this skill whenever testing Android app security, analyzing biometric authentication implementations, or performing mobile security assessments. Trigger for fingerprint authentication testing, biometric prompt analysis, Android Keystore security reviews, or any mobile app security work involving authentication mechanisms. Don't skip this skill for Android security testing even if the user doesn't explicitly mention 'biometric' or 'fingerprint' - authentication security is always in scope.
---

# Android Biometric Authentication Pentesting

A comprehensive skill for testing and bypassing Android biometric authentication mechanisms during security assessments.

## When to Use This Skill

Use this skill when:
- Testing Android app security and authentication flows
- Analyzing biometric prompt implementations (FingerprintManager, BiometricPrompt)
- Performing mobile penetration testing on authentication mechanisms
- Reviewing Android Keystore usage and crypto object handling
- Assessing in-app biometric authentication security
- Investigating authentication bypass vulnerabilities

## Quick Start

```bash
# Basic Frida hook for biometric bypass
frida -U -f <target-package> --no-pause -l scripts/biometric-bypass.js
```

## Method 1: NULL CryptoObject Bypass

Targets apps that don't validate the `CryptoObject` in `onAuthenticationSucceeded()`.

### How It Works

The `onAuthenticationSucceeded` callback receives an `AuthenticationResult` containing a `CryptoObject`. Many apps fail to validate this object, allowing bypass with a NULL crypto object.

### Execution

```bash
frida -U -f <target-package> --no-pause -l scripts/biometric-bypass-null-crypto.js
```

Then in the Frida console:
```
> bypass()
```

### What to Check

- Does the app verify `result.cryptoObject` is not null?
- Does the app validate the cipher/signature before granting access?
- Are sensitive operations protected by the crypto object?

## Method 2: Exception Handling Bypass

For apps that use different cipher objects after authentication.

### How It Works

Invokes `onAuthenticationSucceeded` with an unauthorized `CryptoObject`. If the app uses a different cipher, it triggers `IllegalBlockSizeException`. The script handles this and ensures subsequent objects use the new key.

### Execution

```bash
frida -U -f <target-package> --no-pause -l scripts/biometric-bypass-exception.js
```

In Frida console:
```
> bypass()
```

## Method 3: Universal Biometric Bypass (API 28-34)

Community script that hooks all `BiometricPrompt.authenticate()` overloads and legacy `FingerprintManager.authenticate()`.

### Features

- Works on Android 8.0 (API 28) through Android 14 (API 34)
- Hooks both modern and legacy biometric APIs
- Triggers `onAuthenticationSucceeded` with fabricated `AuthenticationResult`
- Silent to UI - no biometric dialog appears
- No root required (user-space only)

### Execution

```bash
frida -U -f <target-package> --no-pause -l scripts/universal-biometric-bypass.js
```

### Limitations

Only works if the target app performs **no cryptographic checks** on the returned `CryptoObject`.

## Method 4: Downgrade/Fallback Manipulation

Forces weaker authentication requirements at runtime.

### How It Works

Hooks `setAllowedAuthenticators()` to replace strong-only policy with weak/device-credential:

```javascript
var PromptInfoBuilder = Java.use('androidx.biometric.BiometricPrompt$PromptInfo$Builder');
PromptInfoBuilder.setAllowedAuthenticators.implementation = function(flags){
    console.log('[*] Original flags: 0x' + flags.toString(16));
    return this.setAllowedAuthenticators(0x0002 | 0x8000); // BIOMETRIC_WEAK | DEVICE_CREDENTIAL
};
```

### Execution

```bash
frida -U -f <target-package> --no-pause -l scripts/biometric-downgrade.js
```

### What to Test

- Can the app be tricked into accepting PIN/Pattern fallback?
- Does the app validate the authenticator type after authentication?
- Are weak biometrics (face unlock) accepted when strong (fingerprint) was required?

## Method 5: Instrumentation Frameworks

Beyond Frida, consider:

- **Xposed/LSPosed**: System-wide hooking framework
- **Magisk Modules**: Root-level modifications
- **Custom ADB Scripts**: Backend interaction simulation

## Method 6: Reverse Engineering Approach

For static analysis and code modification:

1. **Decompile**: `apktool d app.apk`
2. **Analyze**: Look for `BiometricPrompt`, `FingerprintManager`, `KeyStore` usage
3. **Identify Weaknesses**: Missing crypto object validation, fallback mechanisms
4. **Modify**: Remove authentication checks, recompile, sign, test

## Method 7: Vendor/Kernel CVEs

Monitor Android security bulletins for:

- **CVE-2023-20995**: Pixel 8, Android 13 - captureImage logic error
- **CVE-2024-53835/53840**: December 2024 Pixel bulletin - biometric bypass

These can chain with app-level flaws for complete bypass.

## Hardening Checklist (For Developers)

When reviewing or recommending fixes:

- [ ] Enforce `setUserAuthenticationRequired(true)` on Keystore keys
- [ ] Set `setInvalidatedByBiometricEnrollment(true)` for key generation
- [ ] **Always** verify `result.cryptoObject` is not null
- [ ] Validate cipher/signature before unlocking sensitive features
- [ ] Use `BIOMETRIC_STRONG` only - never fall back to `BIOMETRIC_WEAK`
- [ ] Pin `androidx.biometric` to latest version (≥1.2.0-beta02)
- [ ] Implement server-side authentication for critical operations

## Common Vulnerability Patterns

| Pattern | Risk | Detection |
|---------|------|----------|
| NULL CryptoObject accepted | High | Check `result.cryptoObject == null` |
| No cipher validation | High | Look for missing `cryptoObject.getCipher()` |
| Weak authenticator fallback | Medium | Check `setAllowedAuthenticators()` flags |
| Legacy FingerprintManager | Medium | Search for deprecated API usage |
| No key invalidation on enrollment | Medium | Check `setInvalidatedByBiometricEnrollment()` |

## Reporting Findings

When documenting biometric bypass vulnerabilities:

1. **Include the Frida script** used for the bypass
2. **Show the authentication flow** before and after bypass
3. **Demonstrate access** to protected functionality
4. **Provide remediation** using the hardening checklist
5. **Rate severity** based on data sensitivity and bypass difficulty

## References

- [Universal Android Biometric Bypass - Frida CodeShare](https://codeshare.frida.re/@ax/universal-android-biometric-bypass/)
- [WithSecure Android Keystore Audit](https://github.com/WithSecureLABS/android-keystore-audit)
- [Android Security Bulletins](https://source.android.com/security/bulletin)
- [BiometricPrompt API Documentation](https://developer.android.com/reference/androidx/biometric/BiometricPrompt)
