---
name: android-accessibility-pentest
description: Android Accessibility Service security analysis and pentesting. Use this skill whenever the user mentions Android security testing, accessibility service abuse, RAT detection, malware analysis, ClayRat, PlayPraetor, overlay phishing, credential harvesting, or any Android app security assessment involving AccessibilityService APIs. This skill helps detect malicious accessibility services, analyze abuse patterns, and harden apps against accessibility-based attacks.
---

# Android Accessibility Service Pentesting

A skill for analyzing, detecting, and testing Android Accessibility Service abuse patterns in security assessments.

## When to use this skill

Use this skill when:
- Analyzing Android apps for malicious accessibility services
- Testing for overlay phishing or credential harvesting vulnerabilities
- Investigating RATs like ClayRat, PlayPraetor, SpyNote, BrasDex, SOVA, ToxicPanda
- Assessing banking app security against accessibility-based attacks
- Detecting on-device fraud (ODF) automation patterns
- Reviewing APK manifests for suspicious accessibility configurations
- Hardening apps against accessibility service abuse
- Understanding Android RAT command & control workflows

## Core Concepts

### What is AccessibilityService Abuse?

`AccessibilityService` was designed to help users with disabilities interact with Android devices. However, the same powerful automation APIs can be weaponized by malware to gain **complete remote control** of the handset without root privileges.

**Key capabilities attackers exploit:**
- Capture every UI event and text on screen
- Inject synthetic gestures (`dispatchGesture`)
- Perform global actions (`performGlobalAction`)
- Draw full-screen overlays using `TYPE_ACCESSIBILITY_OVERLAY` (no `SYSTEM_ALERT_WINDOW` prompt!)
- Silently grant additional runtime permissions by clicking system dialogs

### The Attack Recipe

1. **Social engineering** → Victim enables rogue accessibility service (requires explicit user action for `BIND_ACCESSIBILITY_SERVICE` permission)
2. **Leverage the service** → Capture UI events, inject gestures, draw overlays, auto-grant permissions
3. **Exfiltrate or perform ODF** → Real-time fraud while user sees a normal screen

## Detection Methods

### 1. Check Enabled Accessibility Services

```bash
# List all enabled accessibility services
adb shell settings get secure enabled_accessibility_services

# Detailed accessibility dump
adb shell dumpsys accessibility | grep "Accessibility Service"

# Check for suspicious services in Settings
# Settings → Accessibility → Downloaded services
# Look for apps NOT from Google Play
```

### 2. Analyze APK Manifest

Look for these patterns in `AndroidManifest.xml`:

```xml
<!-- Suspicious accessibility service declaration -->
<service
    android:name="com.evil.rat.EvilService"
    android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE"
    android:exported="false">
    
    <intent-filter>
        <action android:name="android.accessibilityservice.AccessibilityService" />
    </intent-filter>
    
    <meta-data android:name="android.accessibilityservice"
        android:resource="@xml/evil_accessibility_config"/>
</service>
```

**Red flags in accessibility config XML:**
- `android:canPerformGestures="true"` - Can inject gestures
- `android:canRetrieveWindowContent="true"` - Can read screen content
- `android:accessibilityEventTypes="typeAllMask"` - Captures all events
- `android:notificationTimeout="200"` - Very low timeout (aggressive monitoring)

### 3. Runtime Detection

```bash
# Check running services
adb shell dumpsys activity services | grep -i accessibility

# Check for overlay windows
adb shell dumpsys window windows | grep -i overlay

# Check device admin receivers
adb shell dumpsys device_policy
```

## Abuse Patterns to Detect

### Pattern 1: Overlay Phishing (Credential Harvesting)

**What it does:** Transparent/opaque WebView added via `TYPE_ACCESSIBILITY_OVERLAY` to capture credentials while real app receives gestures.

**Detection indicators:**
- `WindowManager.LayoutParams` with `TYPE_ACCESSIBILITY_OVERLAY`
- `FLAG_NOT_FOCUSABLE | FLAG_NOT_TOUCH_MODAL` flags
- WebView or custom view added to WindowManager
- No `SYSTEM_ALERT_WINDOW` permission requested

**ClayRat commands:**
- `show_block_screen` / `hide_block_screen` - Toggle overlay templates
- Downloads overlay templates from C2
- Can black out screen, show fake system updates, or display interactive PIN pad

### Pattern 2: On-Device Fraud Automation

**What it does:** Real-time unauthorized transactions via WebSocket commands translated to low-level gestures.

**Detection indicators:**
- Persistent WebSocket connection (often port 8282)
- Commands like `init`, `update`, `alert_arr`, `report_list`
- Banking app navigation patterns in logs
- `dispatchGesture` calls with banking app coordinates

**Malware families:** PlayPraetor, ClayRat

### Pattern 3: Screen Streaming & Monitoring

**What it does:** VNC-like remote desktop via MediaProjection + Accessibility auto-click.

**Detection indicators:**
- `MediaProjection` token creation
- `VirtualDisplay` with `ImageReader`
- Foreground service for frame capture
- JPEG/PNG encoding with quality parameter
- HTTP→WebSocket upgrade with custom user-agent (e.g., `ClayRemoteDesktop`)

**ClayRat commands:**
- `turbo_screen` - Triggers MediaProjection consent (auto-clicked)
- `start_desktop` / `stop_desktop` - Manage capture threads
- `screen_tap`, `screen_swipe`, `input_text` - Replay gestures
- `set_quality` - Adjust encoding quality (default 60)

### Pattern 4: Lock-Screen Credential Theft

**What it does:** Captures PIN, password, or pattern from lock screen and enables auto-unlock.

**Detection indicators:**
- Subscribes to `TYPE_WINDOW_CONTENT_CHANGED` / `TYPE_VIEW_TEXT_CHANGED`
- Listens to `com.android.systemui` (Keyguard) events
- Stores credentials in `SharedPreferences` under `lock_password_storage`
- `auto_unlock` command triggers `unlock_device` / `screen_on`

**Capture methods:**
- **PIN:** Watches keypad button presses
- **Password:** Concatenates strings from focused password field
- **Pattern:** Records ordered node indices from gesture coordinates

### Pattern 5: Notification Phishing & Harvesting

**What it does:** Notification Listener dumps OTP/MFA messages and crafts fake notifications.

**Detection indicators:**
- `NotificationListenerService` registered
- `get_push_notifications` command dumps visible notifications
- `notifications_enabled` flag for real-time streaming
- `send_push_notification` crafts fake interactive notifications

### Pattern 6: Telephony & SMS Command Channel

**What it does:** Complete modem control after setting RAT as default SMS app.

**Detection indicators:**
- Default SMS app permission granted
- Commands: `send_sms`, `retransmishion`, `messsms`, `make_call`
- `get_sms_list`, `get_sms`, `get_call_log`, `get_calls`
- Contacts database iteration for worm-like propagation

### Pattern 7: Discovery, Collection & Proxying

**What it does:** Environment mapping and C2 resilience.

**Detection indicators:**
- `get_apps` / `get_apps_list` - Enumerate installed packages (ATT&CK T1418)
- `get_device_info` - Model, OS version, battery state (T1426)
- `get_cam` / `get_camera` - Front-camera stills
- `get_keylogger_data` - Lock PINs, passwords, view descriptions
- `get_proxy_data` - Proxy WebSocket URL for HTTP/HTTPS tunneling (T1481.002 / T1646)

## Packed Accessibility Droppers

**ClayRat v3.0.8 pattern (ATT&CK T1406.002):**

1. Streams encrypted blob from `assets/*.dat`
2. Decrypts with hard-coded AES/CBC key + IV
3. Writes plaintext DEX to app's private dir
4. Loads via `DexClassLoader` (spyware classes only in memory)

**Detection:**
- Look for `assets/*.dat` or similar encrypted blobs
- Search for AES/CBC decryption patterns in decompiled code
- `DexClassLoader` instantiation with temp DEX files
- `getCodeCacheDir()` usage for loading

## C2 Workflow Analysis

### PlayPraetor Command & Control

1. **HTTP(S) heartbeat** - Iterate hard-coded domains until one answers `POST /app/searchPackageName`
2. **WebSocket (port 8282)** - Bidirectional JSON commands:
   - `update` - Push new config/APKs
   - `alert_arr` - Configure overlay templates
   - `report_list` - Send targeted package names
   - `heartbeat_web` - Keep-alive
3. **RTMP (port 1935)** - Live screen/video streaming
4. **REST exfiltration:**
   - `/app/saveDevice` - Fingerprint
   - `/app/saveContacts` | `/app/saveSms` | `/app/uploadImageBase64`
   - `/app/saveCardPwd` - Bank credentials

## Hardening Recommendations

### For App Developers

1. **Mark sensitive views:**
   ```xml
   android:accessibilityDataSensitive="accessibilityDataPrivateYes"
   ```
   (API 34+)

2. **Prevent tap/overlay hijacking:**
   ```java
   setFilterTouchesWhenObscured(true);
   window.setFlags(FLAG_SECURE, FLAG_SECURE);
   ```

3. **Detect overlays:**
   ```java
   // Poll display flags
   WindowManager.getDefaultDisplay().getFlags();
   // Or use ViewRootImpl API
   ```

4. **Refuse operation when suspicious:**
   ```java
   if (Settings.canDrawOverlays() || hasUntrustedAccessibilityService()) {
       // Block sensitive operations
   }
   ```

### For Enterprise/MDM

- Enforce `ACCESSIBILITY_ENFORCEMENT_DEFAULT_DENY` (Android 13+) to block sideloaded services
- Monitor `enabled_accessibility_services` setting changes
- Alert on non-Play Store accessibility services

## Testing Checklist

When assessing an app for accessibility abuse:

- [ ] Check manifest for `BIND_ACCESSIBILITY_SERVICE` permission
- [ ] Review accessibility config XML for dangerous flags
- [ ] Test if app operates when suspicious accessibility service is enabled
- [ ] Check for overlay detection mechanisms
- [ ] Verify sensitive data is marked `accessibilityDataSensitive`
- [ ] Test with `FLAG_SECURE` enabled
- [ ] Monitor for `dispatchGesture` and `performGlobalAction` calls
- [ ] Check for MediaProjection abuse patterns
- [ ] Review network traffic for C2 patterns (WebSocket 8282, RTMP 1935)
- [ ] Analyze assets for encrypted payloads

## References

- [Return of ClayRat: Expanded Features and Techniques](https://zimperium.com/blog/return-of-clayrat-expanded-features-and-techniques)
- [ClayRat v3 IoCs (Zimperium)](https://github.com/Zimperium/IOC/tree/master/2025-12-ClayRatv3)
- [PlayPraetor's evolving threat](https://www.cleafy.com/cleafy-labs/playpraetors-evolving-threat-how-chinese-speaking-actors-globally-scale-an-android-rat)
- [Android accessibility documentation](https://developer.android.com/guide/topics/ui/accessibility/service)
- [The Rise of RatOn: From NFC heists to remote control](https://www.threatfabric.com/blogs/the-rise-of-raton-from-nfc-heists-to-remote-control-and-ats)
- [GhostTap/NFSkate – NFC relay cash-out tactic](https://www.threatfabric.com/blogs/ghost-tap-new-cash-out-tactic-with-nfc-relay)
