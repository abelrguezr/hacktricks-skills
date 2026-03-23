---
name: cordova-app-pentest
description: Security testing and analysis for Apache Cordova hybrid mobile applications. Use this skill whenever you need to clone, analyze, or pentest Cordova apps (APK/IPA files), identify WebView vulnerabilities, hook JavaScript-to-native bridges with Frida, or harden Cordova applications. Trigger for any Cordova-related security work including: extracting source code from APKs, checking for debuggable builds, auditing plugins for CVEs, setting up Chrome remote debugging, or implementing security hardening measures.
---

# Cordova App Security Testing

A comprehensive skill for security testing Apache Cordova hybrid mobile applications. Cordova apps are built with JavaScript, HTML, and CSS, and use WebView to render the UI. Unlike React Native, Cordova does not compile source code by default, making the HTML/JS accessible even in compiled APK/IPA files.

## Quick Start

```bash
# Install prerequisites
npm install -g cordova@latest

# Clone an APK for analysis
cordova create <new-app-name> <package-name> <app-label>
```

## Workflow Overview

1. **Extract source code** from the APK/IPA
2. **Clone the application** with proper plugins
3. **Perform static analysis** for vulnerabilities
4. **Run dynamic analysis** with Chrome debugging or Frida
5. **Document findings** and recommend hardening

---

## 1. Extracting Source Code

Cordova apps store their source code in the `assets/www` directory within the APK.

### For Android APKs:

```bash
# Unzip the APK (APKs are just ZIP files)
unzip Bank.apk -o bank-extracted/

# Navigate to source code
cd bank-extracted/assets/www/

# View configuration
cat ../res/xml/config.xml
```

### For iOS IPAs:

```bash
# Unzip the IPA
unzip Bank.ipa -o bank-extracted/

# Source code is typically in:
cd bank-extracted/Payload/Bank.app/www/
```

---

## 2. Cloning a Cordova Application

Use the bundled script to automate cloning:

```bash
./scripts/clone-cordova-app.sh <apk-path> <new-app-name>
```

### Manual Cloning Steps:

1. **Create new Cordova project:**
   ```bash
   cordova create bank-new com.android.bank Bank
   cd bank-new
   ```

2. **Copy source files** (exclude Cordova system files):
   ```bash
   cp -r bank-extracted/assets/www/* www/
   # Exclude: cordova_plugins.js, cordova.js, cordova-js-src/, plugins/
   ```

3. **Add platform:**
   ```bash
   cordova platform add android@13.0.0
   ```

4. **Install plugins** from the original `cordova_plugins.js`:
   ```bash
   cordova plugin add cordova-plugin-dialogs@2.0.1
   cordova plugin add https://github.com/moderna/cordova-plugin-cache.git
   ```

5. **Build debug APK:**
   ```bash
   cordova build android --packageType=apk
   ```

> **Note:** Debug APKs enable Chrome remote debugging. Sign the APK before installation if the app has tamper detection.

---

## 3. Static Analysis Checklist

Use the bundled vulnerability checker script:

```bash
./scripts/check-vulnerabilities.sh <www-directory>
```

### Manual Checks:

#### 3.1 Check for Debuggable Builds

```bash
# Decompile and check AndroidManifest.xml
aapt dump badging Bank.apk | grep debuggable
# Or grep the decompiled manifest
grep -r 'android:debuggable="true"' bank-extracted/
```

**Risk:** Debuggable builds expose WebView over `chrome://inspect`, allowing full JavaScript injection.

#### 3.2 Review config.xml Permissions

```bash
cat config.xml | grep -A2 '<access'
```

**Look for:**
- `<access origin="*">` - overly permissive
- Missing CSP meta-tags in `www/index.html`

#### 3.3 Search for Dangerous Patterns

```bash
# Check for eval() and dynamic code execution
grep -rn 'eval(' www/
grep -rn 'new Function(' www/
grep -rn 'innerHTML.*=' www/
```

#### 3.4 Audit Plugins for CVEs

```bash
# Check for known vulnerable plugins
npm audit --production
osv-scanner --lockfile package-lock.json

# Specifically check for:
# - cordova-plugin-acuant (MAL-2024-7845 - malicious code)
# - CleverTap Cordova Plugin ≤ 2.6.2 (CVE-2023-2507 - XSS via deeplinks)
# - cordova-android ≤ 12 (outdated platform)
```

---

## 4. Dynamic Analysis

### 4.1 Chrome Remote Debugging

If the app is debuggable, attach Chrome DevTools:

```bash
# Forward Chrome debugging port
adb forward tcp:9222 localabstract:chrome_devtools_remote

# Open Chrome DevTools
google-chrome --new-window "chrome://inspect/#devices"
```

**Capabilities:**
- Live JavaScript console
- DOM inspector
- Runtime function overwriting
- Network request interception

### 4.2 Frida Hooking

Hook the JavaScript-to-native bridge to monitor or tamper with plugin calls:

```bash
# Run the bundled Frida script
frida -U -f com.vulnerable.bank -l scripts/frida-cordova-hook.js --no-pause
```

**What it hooks:**
- `org.apache.cordova.CordovaPlugin.execute(...)` - all plugin calls
- Logs action names and arguments
- Can tamper with sensitive actions (e.g., encryption keys)

**Custom hooks:** See `scripts/frida-cordova-hook.js` for examples of:
- Logging all plugin invocations
- Modifying arguments before execution
- Bypassing security checks

---

## 5. Common Vulnerabilities (2023-2025)

| Vulnerability | CVE/ID | Impact | Mitigation |
|--------------|--------|--------|------------|
| Malicious NPM Package | MAL-2024-7845 | Full compromise | Audit `package.json`, pin versions |
| Unvalidated Deeplinks | CVE-2023-2507 | XSS/RCE | Update CleverTap ≥ 2.6.3 |
| Outdated Platform | N/A | Missing security features | Upgrade to `cordova-android@13` |
| Debuggable Build | N/A | Full JS injection | Set `debuggable="false"` |
| Weak CSP | N/A | XSS | Add strict CSP meta-tag |
| Cleartext Traffic | N/A | MITM | Set `usesCleartextTraffic="false"` |

---

## 6. Hardening Recommendations

### 6.1 Platform Updates

```bash
# Upgrade to latest platform
cordova platform rm android
cordova platform add android@13.0.0
```

### 6.2 Remove Debug Artifacts

In `AndroidManifest.xml`:
```xml
<application android:debuggable="false" ...>
```

In `MainActivity.java` (if present):
```java
// Remove or disable this line in release builds
// WebView.setWebContentsDebuggingEnabled(true);
```

### 6.3 Enforce Strict CSP

Add to every HTML file in `www/`:
```html
<meta http-equiv="Content-Security-Policy" 
      content="default-src 'self'; img-src 'self' data:; object-src 'none'; frame-ancestors 'none'">
```

### 6.4 Disable Cleartext Traffic

In `AndroidManifest.xml`:
```xml
<application android:usesCleartextTraffic="false" ...>
```

Or create `res/xml/network_security_config.xml`:
```xml
<network-security-config>
    <base-config cleartextTrafficPermitted="false" />
</network-security-config>
```

### 6.5 Plugin Hygiene

```bash
# Pin versions and commit lockfile
npm ci
git add package-lock.json

# Regular audits
npm audit
osv-scanner --lockfile package-lock.json
```

### 6.6 Obfuscation

```bash
# Minify JavaScript
npm install -g terser
terser www/js/*.js -c -m -o www/js/bundle.min.js

# Remove source maps from production
rm -f www/js/*.map
```

---

## 7. Automation Tools

### MobSecco
For automated cloning of Android applications:

```bash
git clone https://github.com/Anof-cyber/MobSecco
cd MobSecco
python mobsecco.py <apk-path>
```

---

## 8. Reporting Template

```markdown
# Cordova App Security Assessment

## Application Details
- Package Name: com.example.app
- APK Version: 1.2.3
- Cordova Platform: android@12.0.0

## Findings

### Critical
- [ ] Debuggable build detected
- [ ] Malicious plugin: cordova-plugin-acuant

### High
- [ ] CVE-2023-2507: CleverTap deeplink XSS
- [ ] Overly permissive access origin

### Medium
- [ ] Missing CSP meta-tag
- [ ] Cleartext traffic allowed

### Low
- [ ] Source maps present in production
- [ ] Unminified JavaScript

## Recommendations
1. Upgrade to cordova-android@13.0.0
2. Remove debuggable flag
3. Implement strict CSP
4. Audit and pin all plugin versions
```

---

## References

- [Apache Cordova Documentation](https://cordova.apache.org/docs/)
- [Cordova-Android 13.0.0 Release Notes](https://cordova.apache.org/announcements/2024/05/13/cordova-android-13.0.0.html)
- [OSV Advisory: MAL-2024-7845](https://osv.dev/vulnerability/MAL-2024-7845)
- [CVE-2023-2507: CleverTap XSS](https://nvd.nist.gov/vuln/detail/CVE-2023-2507)
- [Chrome Remote Debugging](https://developer.chrome.com/docs/devtools/remote-debugging/)
- [Frida Documentation](https://frida.re/docs/)

---

## Bundled Resources

- `scripts/clone-cordova-app.sh` - Automates Cordova app cloning
- `scripts/check-vulnerabilities.sh` - Quick vulnerability scanner
- `scripts/frida-cordova-hook.js` - Frida hooking script for plugin monitoring
