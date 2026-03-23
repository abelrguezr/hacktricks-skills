---
name: android-tapjacking-test
description: Test Android applications for tapjacking vulnerabilities. Use this skill whenever you're doing Android app security testing, pentesting, or analyzing exported activities for clickjacking risks. Trigger when the user mentions tapjacking, clickjacking, overlay attacks, exported activities, or Android UI security testing.
---

# Android Tapjacking Testing

A skill for detecting and testing tapjacking vulnerabilities in Android applications.

## What is Tapjacking

Tapjacking is an attack where a malicious application positions itself on top of a victim application, tricking users into interacting with the victim app while believing they're interacting with the overlay. This effectively blinds users to their actual actions.

## When to Use This Skill

Use this skill when:
- Testing Android apps for UI security vulnerabilities
- Analyzing exported activities in Android manifests
- Investigating overlay-based attack vectors
- Reviewing Android app security posture
- Preparing penetration test reports for Android applications

## Detection Workflow

### Step 1: Analyze the Android Manifest

Check for exported activities that could be vulnerable:

```bash
# Extract and analyze the manifest
unzip -p app.apk AndroidManifest.xml | grep -A 5 "<activity"
```

Look for:
- Activities with `intent-filter` (exported by default)
- Activities without `android:exported="false"`
- Activities protected only by custom permissions

### Step 2: Check Minimum SDK Version

```bash
# Check minSdkVersion in manifest
unzip -p app.apk AndroidManifest.xml | grep "minSdkVersion"
```

**Risk assessment:**
- `minSdkVersion < 30`: Higher risk (older default behaviors)
- `minSdkVersion >= 31`: Android 12+ has default blocking

### Step 3: Runtime Detection (Android 12+)

Monitor for blocked touches during testing:

```bash
# Watch for occlusion warnings
adb logcat | grep -i "untrusted touch\|occlusion"
```

Look for: `Untrusted touch due to occlusion by <package>`

### Step 4: Check for Protection Flags

Search the decompiled code for protection mechanisms:

```bash
# Check for filterTouchesWhenObscured
strings app.apk | grep -i "filterTouchesWhenObscured"

# Check for onFilterTouchEventForSecurity override
strings app.apk | grep -i "onFilterTouchEventForSecurity"
```

## Exploitation Testing

### Using Tapjacking-ExportedActivity Tool

The most recent tool for testing exported activity tapjacking:

1. Clone the repository:
   ```bash
   git clone https://github.com/carlospolop/Tapjacking-ExportedActivity
   ```

2. Build and install the test APK

3. Run against the target app's exported activities

### Manual Testing Approach

1. **Identify target activities** from manifest analysis
2. **Create overlay app** with transparent or semi-transparent UI
3. **Position overlay** to match target UI elements
4. **Test touch forwarding** to verify vulnerability

### Testing Android 12+ Bypass

Android 12 blocks overlays with opacity ≥0.8. Test bypass:

```bash
# Disable blocking for PoC testing (requires root/adb)
adb shell am compat disable BLOCK_UNTRUSTED_TOUCHES com.example.victim

# Re-enable after testing
adb shell am compat reset BLOCK_UNTRUSTED_TOUCHES com.example.victim
```

## Protection Recommendations

### For Developers

1. **Set filterTouchesWhenObscured** on sensitive views:
   ```xml
   <Button android:text="Confirm"
           android:filterTouchesWhenObscured="true"
           ... />
   ```

2. **Override onFilterTouchEventForSecurity** in activities:
   ```java
   @Override
   public boolean onFilterTouchEventForSecurity(MotionEvent event) {
       if ((event.getFlags() & MotionEvent.FLAG_WINDOW_IS_PARTIALLY_OBSCURED) != 0) {
           return false; // Drop tap when partially obscured
       }
       return super.onFilterTouchEventForSecurity(event);
   }
   ```

3. **Use FLAG_SECURE** for sensitive screens:
   ```java
   getWindow().setFlags(
       WindowManager.LayoutParams.FLAG_SECURE,
       WindowManager.LayoutParams.FLAG_SECURE
   );
   ```

4. **Android 14+**: Set `android:accessibilityDataSensitive="accessibilityDataPrivateYes"` on sensitive views

### For Security Teams

1. **Audit exported activities** in all app releases
2. **Test with overlay tools** before production
3. **Monitor for accessibility service abuse** in production apps
4. **Review minSdkVersion** and update if below 30

## Modern Threat Context

### Recent Malware Techniques

- **Hook/Ermac variants**: Use alpha < 0.8 overlays to bypass Android 12 blocking
- **Anatsa/TeaBot**: Full-screen "maintenance" overlays with ATS automation
- **Hidden-VNC RATs**: Brief phishing overlays + covert VNC for replay

### Accessibility Overlay Phishing

Modern banking trojans (ToxicPanda, BrasDex, Sova) use:
1. `BIND_ACCESSIBILITY_SERVICE` permission
2. `TYPE_ACCESSIBILITY_OVERLAY` windows
3. WebView overlays with touch forwarding
4. `FLAG_NOT_FOCUSABLE | FLAG_NOT_TOUCH_MODAL` flags

### Detection Commands

```bash
# Check for apps with accessibility service
adb shell pm list packages -3 -e | grep -i accessibility

# List apps with BIND_ACCESSIBILITY_SERVICE
adb shell pm list packages -3 -e BIND_ACCESSIBILITY_SERVICE
```

## Reporting

When documenting findings:

1. **Vulnerability**: Tapjacking / Clickjacking
2. **CVSS Vector**: Consider UI manipulation, data exposure, action hijacking
3. **Affected Activities**: List specific exported activities
4. **Proof of Concept**: Include overlay app or tool output
5. **Remediation**: Reference protection recommendations above

## References

- [Android Developers – Tapjacking risk & mitigations](https://developer.android.com/privacy-and-security/risks/tapjacking)
- [Tapjacking-ExportedActivity Tool](https://github.com/carlospolop/Tapjacking-ExportedActivity)
- [FloatingWindowApp Example](https://github.com/aminography/FloatingWindowApp)
- [Qark Security Scanner](https://github.com/linkedin/qark)
