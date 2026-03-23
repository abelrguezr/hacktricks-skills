---
name: android-anti-instrumentation-bypass
description: Bypass Android anti-instrumentation, root detection, and SSL pinning using Frida, Objection, and related tools. Use this skill whenever you need to analyze Android apps that detect Frida, check for root, enforce TLS pinning, or block dynamic analysis. Trigger this skill for any Android security testing, mobile pentesting, or app reverse engineering task involving detection bypass, SSL unpinning, or instrumentation stealth.
---

# Android Anti-Instrumentation & SSL Pinning Bypass

A practical workflow to bypass Android app protections that detect instrumentation, root, or enforce TLS pinning. Focuses on fast triage, common detections, and copy-pasteable hooks.

## Quick Start

```bash
# Attach to running app (avoids spawn-time detection)
frida -U -n com.example.app

# Spawn with anti-detection script
frida -U -f com.example.app -l anti-frida-detection.js

# List processes
frida-ps -Uai
```

## Detection Surface (What Apps Check)

| Category | Common Checks |
|----------|---------------|
| Root | su binary, Magisk paths, getprop values, root packages |
| Frida/Debugger | Debug.isDebuggerConnected(), /proc scanning, classpath, loaded libs |
| Native Anti-Debug | ptrace(), syscalls, anti-attach, breakpoints |
| Early Init | Application.onCreate() hooks that crash on instrumentation |
| TLS Pinning | Custom TrustManager, OkHttp CertificatePinner, Conscrypt, native pins |

## Step 1: Quick Wins (30 Seconds)

### Hide Root with Magisk DenyList

```bash
# In Magisk app:
# 1. Enable Zygisk
# 2. Enable DenyList
# 3. Add target package
# 4. Reboot and retest
```

Many apps only check for obvious indicators. DenyList often neutralizes naive checks.

### Try Frida Codeshare Scripts

```bash
# Common drop-in scripts
frida -U -f com.example.app -l anti-frida-detection.js
frida -U -f com.example.app -l anti-root-bypass.js
frida -U -f com.example.app -l hide_frida_gum.js
```

**Codeshare**: https://codeshare.frida.re/

### Use Medusa Framework

Medusa provides 90+ ready-made modules:

```bash
git clone https://github.com/Ch0pin/medusa
cd medusa
pip install -r requirements.txt
python medusa.py

# Interactive workflow
show categories
use http_communications/multiple_unpinner
use root_detection/universal_root_detection_bypass
run com.target.app
```

## Step 2: Attach Late to Avoid Init-Time Detection

Many detections only run during process spawn. Attach after UI loads:

```bash
# Launch app normally, wait for UI, then attach
frida -U -n com.example.app

# Or with Objection gadget
objection --gadget com.example.app explore
```

## Step 3: Map Detection Logic (Static Analysis)

Search Jadx for keywords: `frida`, `gum`, `root`, `magisk`, `ptrace`, `su`, `getprop`, `debugger`

**Common Java APIs to hook:**
- `android.os.Debug.isDebuggerConnected`
- `android.app.ActivityManager.getRunningAppProcesses`
- `android.app.ActivityManager.getRunningServices`
- `java.lang.System.loadLibrary`
- `android.os.SystemProperties.get`

## Step 4: Runtime Stubbing with Frida

### Basic Anti-Frida Bypass

```javascript
Java.perform(() => {
  // Neutralize debugger checks
  const Debug = Java.use('android.os.Debug');
  Debug.isDebuggerConnected.implementation = function() { return false; };

  // Kill ActivityManager scans
  const AM = Java.use('android.app.ActivityManager');
  AM.getRunningAppProcesses.implementation = function() {
    return java.util.Collections.emptyList();
  };
  AM.getRunningServices.implementation = function() {
    return java.util.Collections.emptyList();
  };
});
```

### Custom Detection Class Stubbing

```javascript
Java.perform(() => {
  try {
    const Checks = Java.use('com.example.security.Checks');
    Checks.isFridaDetected.implementation = function() { return false; };
    Checks.isRooted.implementation = function() { return false; };
  } catch(e) {
    console.log('Custom check class not found');
  }
});
```

### Log Suspicious Methods

```javascript
Java.perform(() => {
  const Det = Java.use('com.example.security.DetectionManager');
  Det.checkFrida.implementation = function() {
    console.log('[+] checkFrida() called');
    return false;
  };
});
```

### Dump Classes on Crash

```javascript
Java.perform(() => {
  Java.enumerateLoadedClasses({
    onMatch: n => console.log(n),
    onComplete: () => console.log('Done')
  });
});
```

## Step 5: Bypass Emulator/VM Detection

### Spoof Build Fields

```javascript
Java.perform(function() {
  var Build = Java.use('android.os.Build');
  Build.MODEL.value = 'Pixel 7 Pro';
  Build.MANUFACTURER.value = 'Google';
  Build.BRAND.value = 'google';
  Build.FINGERPRINT.value = 'google/panther/panther:14/UP1A.231105.003/1234567:user/release-keys';
  Build.HARDWARE.value = 'panther';
});
```

### Spoof Device Identifiers

```javascript
Java.perform(function() {
  // TelephonyManager
  var TelephonyManager = Java.use('android.telephony.TelephonyManager');
  TelephonyManager.getDeviceId.implementation = function() { return '123456789012345'; };
  TelephonyManager.getSubscriberId.implementation = function() { return '123456789012345'; };
  
  // WiFi MAC
  var WifiInfo = Java.use('android.net.wifi.WifiInfo');
  WifiInfo.getMacAddress.implementation = function() { return '02:00:00:12:34:56'; };
});
```

## Step 6: SSL Pinning Bypass

### Basic SSLContext Hook

```javascript
Java.perform(function() {
  var X509TrustManager = Java.use('javax.net.ssl.X509TrustManager');
  var SSLContext = Java.use('javax.net.ssl.SSLContext');

  // No-op validations
  X509TrustManager.checkClientTrusted.implementation = function() {};
  X509TrustManager.checkServerTrusted.implementation = function() {};

  // Force permissive TrustManagers
  var TrustManagers = [X509TrustManager.$new()];
  var SSLContextInit = SSLContext.init.overload(
    '[Ljavax.net.ssl.KeyManager',
    '[Ljavax.net.ssl.TrustManager',
    'java.security.SecureRandom'
  );
  SSLContextInit.implementation = function(km, tm, sr) {
    return SSLContextInit.call(this, km, TrustManagers, sr);
  };
});
```

### OkHttp4 / Cronet Pinning (2024+)

```javascript
Java.perform(() => {
  try {
    const Pinner = Java.use('okhttp3.CertificatePinner');
    Pinner.check.overload('java.lang.String', 'java.util.List').implementation = function() {};
    Pinner.check$okhttp.implementation = function() {};
  } catch(e) {}

  try {
    const CronetB = Java.use('org.chromium.net.CronetEngine$Builder');
    CronetB.enablePublicKeyPinningBypassForLocalTrustAnchors.overload('boolean').implementation = function() { return this; };
    CronetB.setPublicKeyPins.overload('java.lang.String', 'java.lang.Set', 'boolean').implementation = function() { return this; };
  } catch(e) {}
});
```

### Native BoringSSL Hook (for gRPC/Cronet)

```javascript
const customVerify = Module.findExportByName(null, 'SSL_CTX_set_custom_verify');
if (customVerify) {
  Interceptor.attach(customVerify, {
    onEnter(args) {
      args[1] = ptr(0); // SSL_VERIFY_NONE
      args[2] = NULL;   // disable callback
    }
  });
}
```

## Step 7: Native Detection Bypass

### Trace JNI Entry Points

```bash
frida-trace -n com.example.app -i "JNI_OnLoad"
```

### Neuter ptrace (Anti-Debug)

```javascript
const ptrace = Module.findExportByName(null, 'ptrace');
if (ptrace) {
  Interceptor.replace(ptrace, new NativeCallback(function() {
    return -1; // pretend failure
  }, 'int', ['int', 'int', 'pointer', 'pointer']));
}
```

### Scan Native Libraries

```bash
# List exported symbols & JNI
nm -D libfoo.so | head
objdump -T libfoo.so | grep Java_
strings -n 6 libfoo.so | egrep -i 'frida|ptrace|gum|magisk|su|root'
```

## Step 8: Stealth Frida Server (phantom-frida)

For apps that detect Frida fingerprints, use phantom-frida:

```bash
python3 build.py --version 17.7.2 --name myserver --port 27142 --extended --verify
adb push output/myserver-server-17.7.2-android-arm64 /data/local/tmp/myserver-server
adb shell chmod 755 /data/local/tmp/myserver-server
adb shell /data/local/tmp/myserver-server -D &
adb forward tcp:27142 tcp:27142
frida -H 127.0.0.1:27142 -f com.example.app
```

**phantom-frida**: https://github.com/TheQmaks/phantom-frida

## Step 9: Universal Proxy + TLS Unpinning

Use HTTP Toolkit hooks for comprehensive unpinning + proxy forcing:

```bash
# Download hooks from https://github.com/httptoolkit/frida-interception-and-unpinning
frida -U -f com.vendor.app \
  -l ./android-unpinning-with-proxy.js \
  --no-pause

# mitmproxy listening locally
mitmproxy -p 8080
```

## Step 10: Static TLS Pinning Removal (Fallback)

```bash
apk-mitm app.apk
# Install patched APK and proxy via Burp/mitmproxy
```

**apk-mitm**: https://github.com/shroudedcode/apk-mitm

## Objection Patching

```bash
objection patchapk --source app.apk
```

Requires apktool. Gadget injection enables instrumentation without root.

## Command Cheat Sheet

```bash
# List processes
frida-ps -Uai

# Attach to running app
frida -U -n com.example.app

# Spawn with script
frida -U -f com.example.app -l script.js

# Trace native
frida-trace -n com.example.app -i "JNI_OnLoad"

# Objection runtime
objection --gadget com.example.app explore

# Static TLS removal
apk-mitm app.apk
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| App crashes on spawn | Attach late with `-n` instead of `-f` |
| Zygisk detection | Disable Zygisk temporarily, use KernelSU/APatch |
| Play Integrity blocks | Use PlayIntegrityFix, ReZygisk, or Zygisk-Next |
| TLS still pinned | Add OkHttp4/Cronet hooks, try native BoringSSL hook |
| Native detection | Use ptrace stub, trace JNI_OnLoad, scan .so files |
| Frida detected | Use phantom-frida, try hide_frida_gum.js |

## References

- **Frida Codeshare**: https://codeshare.frida.re/
- **Objection**: https://github.com/sensepost/objection
- **Medusa**: https://github.com/Ch0pin/medusa
- **phantom-frida**: https://github.com/TheQmaks/phantom-frida
- **HTTP Toolkit Hooks**: https://github.com/httptoolkit/frida-interception-and-unpinning
- **apk-mitm**: https://github.com/shroudedcode/apk-mitm
- **Jadx**: https://github.com/skylot/jadx
- **Ghidra**: https://ghidra-sre.org/
- **Magisk**: https://github.com/topjohnwu/Magisk
