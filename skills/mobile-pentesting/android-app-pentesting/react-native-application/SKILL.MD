---
name: react-native-pentest
description: Pentest React Native Android applications. Use this skill whenever analyzing React Native apps, extracting and analyzing index.android.bundle files, hunting for secrets in JS bundles, handling Hermes bytecode, or performing dynamic analysis with Frida. Trigger for any React Native security assessment, bundle analysis, secret extraction, or mobile app testing involving React Native frameworks.
---

# React Native Application Pentesting

A comprehensive skill for security testing React Native Android applications, covering static analysis, secret hunting, Hermes bytecode handling, and dynamic analysis.

## Quick Start

```bash
# Extract bundle from APK
./scripts/extract-bundle.sh <app.apk>

# Hunt for secrets
./scripts/hunt-secrets.sh index.android.bundle

# Enable dev mode with Frida
frida -U -f <package> -l ./scripts/frida-enable-dev.js
```

## 1. Identify React Native Applications

### Extract the Bundle

React Native apps contain JavaScript code in `assets/index.android.bundle`. Extract it:

```bash
# From APK
cp <app>.apk temp.zip
unzip -qq temp.zip -d extracted
find extracted -name "index.android.bundle"

# From AAB (Android App Bundle)
java -jar bundletool.jar build-apks \
  --bundle=app-release.aab \
  --output=app.apks \
  --mode=universal \
  --overwrite
unzip -p app.apks universal.apk > universal.apk
unzip -qq universal.apk -d extracted
```

**Use the extraction script:**
```bash
./scripts/extract-bundle.sh <app.apk>  # or .aab
```

### Verify React Native

Look for these indicators:
- `assets/index.android.bundle` exists
- `com.facebook.react` classes in the APK
- `ReactNativeHost` in the code

## 2. Static Analysis - JavaScript Bundle

### Quick Secret Hunting

Run the secret hunting script to find common credentials:

```bash
./scripts/hunt-secrets.sh index.android.bundle
```

This searches for:
- API endpoints and GraphQL URLs
- Firebase keys (`AIza...`)
- AWS access keys (`AKIA...`)
- Sentry DSNs
- CodePush/Expo deployment keys
- Common backend patterns

### Manual Pattern Searches

```bash
# Backends and crash reporters
strings -n 6 index.android.bundle | grep -Ei "(api\.|graphql|/v1/|/v2/|socket|wss://|sentry\.io|bugsnag|appcenter|codepush|firebaseio\.com|amplify|aws)"

# Firebase keys
strings -n 6 index.android.bundle | grep -Ei "(AIza[0-9A-Za-z_-]{35}|AIzaSy[0-9A-Za-z_-]{33})"

# AWS keys
strings -n 6 index.android.bundle | grep -E "AKIA[0-9A-Z]{16}"

# CodePush/Expo
strings -n 6 index.android.bundle | grep -Ei "(CodePush|codepush:\/\/|DeploymentKey|expo-updates|expo\.io)"

# Sentry
strings -n 6 index.android.bundle | grep -Ei "(Sentry\.init|dsn\s*:|dsn\s*=)"
```

### Webpack Bundle Analysis

If you have `index.android.bundle.map`, use it for unminified source. Otherwise:

1. Create `index.html`:
```html
<script src="./index.android.bundle"></script>
```

2. Open in Chrome, press `Ctrl+Shift+J` (or `Cmd+Option+J` on macOS)
3. Navigate to Sources tab to see the bundle structure

### Decompile Minified Bundle

Use [react-native-decompiler](https://github.com/numandev1/react-native-decompiler) to split the bundle into individual files for easier analysis.

## 3. Hermes Bytecode Analysis

### Detect Hermes

```bash
file index.android.bundle
# Output: "Hermes JavaScript bytecode, version XX"
```

### Disassemble and Decompile

Hermes bytecode requires special tools:

```bash
# hbctool (check version compatibility)
hbctool disasm ./index.android.bundle ./hasm_out
hbctool asm ./hasm_out ./index.android.bundle

# hasmer (supports newer versions)
hasmer disasm ./index.android.bundle -o hasm_out

# hermes-dec (decompiler only, no rebuild)
hbc-disassembler ./index.android.bundle /tmp/output.hasm
hbc-decompiler ./index.android.bundle /tmp/output.js
```

**Important:** Hermes bytecode is versioned. If you get format errors, try updated forks or rebuild matching Hermes tooling.

### Modify and Rebuild (Hermes)

```bash
# 1. Disassemble
hbctool disasm assets/index.android.bundle ./hasm

# 2. Edit .hasm files (change comparisons, constants, feature flags)
#    Example: replace LoadConstUInt8 0 with 1 to force boolean true

# 3. Reassemble
hbctool asm ./hasm assets/index.android.bundle

# 4. Repack and resign APK
zip -r ../patched.apk *
# Then align and sign (see Android signing procedures)
```

## 4. Dynamic Analysis with Frida

### Enable Developer Support

Some apps have togglable dev support. Try forcing it:

```bash
frida -U -f <package> -l ./scripts/frida-enable-dev.js
```

**Warning:** In properly built release builds, debug classes are stripped and this may crash the app.

### Network Interception

React Native uses OkHttp under the hood. For interception:

- Use system proxy + trust user CA
- If Flipper is accidentally bundled, use Flipper Network plugin
- Refer to Android TLS bypass techniques for pinning bypass

### BLE GATT Protocol Discovery

When Hermes blocks static analysis, hook the Android BLE stack:

```bash
frida -U -f <package> -l ./scripts/frida-gatt-logger.js
```

This logs all Bluetooth GATT reads/writes with hex and ASCII dumps.

### Hash Function Tracing

To fingerprint hash-based handshakes:

```bash
frida -U -f <package> -l ./scripts/frida-message-digest.js
```

This traces `java.security.MessageDigest` calls to capture hash inputs and outputs.

## 5. Known Vulnerabilities in Popular Libraries

Check for these known issues:

### react-native-mmkv (CVE-2024-21668)

Versions < 2.11.0 log encryption keys to Android logs.

```bash
grep -R "react-native-mmkv" -n index.android.bundle 2>/dev/null || true
# Check logcat for MMKV encryption key logs
```

### react-native-document-picker

Versions < 9.1.1 vulnerable to path traversal on Android.

```bash
grep -R "react-native-document-picker" -n index.android.bundle 2>/dev/null || true
```

### General Library Checks

If you have access to `package.json` or `yarn.lock`:

```bash
grep -E "(react-native-mmkv|react-native-document-picker)" package.json yarn.lock
```

## 6. Modifying and Rebuilding

### JavaScript Bundle

1. Extract APK as ZIP
2. Modify `index.android.bundle` (or decompiled files)
3. Repack and resign

### Hermes Bundle

1. Disassemble with hbctool/hasmer
2. Edit `.hasm` files
3. Reassemble
4. Repack and resign APK

## References

- [Bug Bounty Writeup: React Native Secrets](https://medium.com/bugbountywriteup/lets-know-how-i-have-explored-the-buried-secrets-in-react-native-application-6236728198f7)
- [Assetnote: Expanding Attack Surface](https://www.assetnote.io/resources/research/expanding-the-attack-surface-react-native-android-applications)
- [Payatu: Mastering React Native Pentesting](https://payatu.com/wp-content/uploads/2023/02/Mastering-React-Native-Application-Pentesting-A-Practical-Guide-2.pdf)
- [CVE-2024-21668 - MMKV Key Logging](https://nvd.nist.gov/vuln/detail/CVE-2024-21668)
- [hbctool](https://github.com/bongtrop/hbctool)
- [hasmer](https://github.com/lucasbaizer2/hasmer)
- [hermes-dec](https://github.com/P1sec/hermes-dec)
