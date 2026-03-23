---
name: android-ime-abuse-detection
description: Detect and analyze malicious InputMethodService (IME) abuse in Android apps. Use this skill whenever investigating Android malware, reviewing APKs for suspicious keyboard services, analyzing banking trojans with keylogging capabilities, or triaging apps that may be capturing keystrokes. Trigger when the user mentions IME, InputMethodService, malicious keyboards, keylogging, Android keyboard abuse, or needs to detect credential harvesting via input methods.
---

# Android IME / InputMethodService Abuse Detection

A skill for detecting and analyzing malicious keyboard implementations that abuse Android's InputMethodService to capture keystrokes across all apps.

## What This Skill Covers

- Understanding how IME abuse works in Android malware
- Static analysis techniques to detect malicious keyboards in APKs
- Runtime detection methods using ADB and system settings
- Triage workflows for suspicious apps
- Mitigation strategies for users and organizations

## How IME Abuse Works

Android allows third-party keyboards via `InputMethodService`. Once a user **enables** a keyboard and selects it as the **current input method**, the IME can observe and influence **all text input** across apps on the device.

This is why Android banking trojans often bundle a "secure keyboard" feature: the malicious IME receives keystrokes even from apps that never embed a `WebView` (banking apps, chat apps, crypto wallets, etc.).

### Key Technical Details

- `android.permission.BIND_INPUT_METHOD` is declared on the IME service so only the system can bind to it
- Declaring this permission doesn't grant special privileges by itself
- The critical step is getting the victim to **enable/select** the keyboard in Settings

## Manifest Declaration Pattern

A keyboard is exposed via a service with the `android.view.InputMethod` intent action and an IME configuration XML:

```xml
<!-- AndroidManifest.xml -->
<service
    android:name=".SpyKeyboard"
    android:permission="android.permission.BIND_INPUT_METHOD"
    android:exported="false">

    <intent-filter>
        <action android:name="android.view.InputMethod" />
    </intent-filter>

    <meta-data
        android:name="android.view.im"
        android:resource="@xml/spy_ime" />
</service>
```

**Hunting tip:** A non-keyboard-looking app that declares an `InputMethodService` is a strong red flag.

## Data Collection Points

At runtime, an IME learns:

1. **The target app** being typed into (via `EditorInfo`, e.g., `attribute.packageName` in `onStartInput`)
2. **The text being entered** (through the IME's interaction with the current `InputConnection` and/or key events)

### High-Signal Hook Point

```java
public class SpyKeyboard extends InputMethodService {
  @Override public void onStartInput(EditorInfo attribute, boolean restarting) {
    // attribute.packageName identifies the foreground app receiving input
  }
}
```

## Common Enablement & Collection Workflow

Observed patterns in the wild:

1. The APK is marketed as a "secure keyboard" or the keyboard is embedded inside a broader trojan
2. The malware drives the victim into system keyboard settings (e.g., by launching `Settings.ACTION_INPUT_METHOD_SETTINGS` and/or using UI automation)
3. The IME is enabled and set as default
4. Keystrokes are buffered per-app and exfiltrated via the malware's existing C2 channel
5. Often combined with other data sources (e.g., `WebView` man-in-the-browser telemetry)

## Detection Methods

### On-Device Checks

#### Settings Inspection
- Navigate to: **Settings > System > Languages & input > Virtual keyboard**
- Look for unknown IMEs that don't match expected keyboard apps
- Check which keyboard is set as default

#### ADB Commands

```bash
# List all input methods
adb shell dumpsys input_method

# List all IMEs (active and inactive)
adb shell ime list -a

# Get IME help/status
adb shell ime help
```

### Static Triage of an APK

When analyzing a suspicious APK:

1. **Look for InputMethodService classes**
   - Decompile the APK (using `apktool`, `jadx`, or similar)
   - Search for classes extending `InputMethodService`

2. **Check the manifest for the intent filter**
   - Look for `<action android:name="android.view.InputMethod" />`
   - Verify the service has `android.permission.BIND_INPUT_METHOD`

3. **Inspect IME configuration XML**
   - Find the resource referenced by `android.view.im` meta-data
   - Check `@xml/*` files for IME configuration

4. **Verify app functionality matches**
   - Does the app's stated purpose match shipping a full keyboard UI?
   - Are there keyboard layout resources, key images, etc.?
   - A calculator app with an IME service is suspicious

## Triage Decision Tree

```
App declares InputMethodService?
├── NO → Not an IME abuse vector (check other vectors)
└── YES → Continue
    ├── App is a known keyboard app (Gboard, SwiftKey, etc.)?
    │   ├── YES → Likely legitimate (still verify permissions)
    │   └── NO → Suspicious
    │       ├── App has keyboard UI/resources?
    │       │   ├── YES → Could be legitimate custom keyboard
    │       │   └── NO → HIGH SUSPICION - likely malicious
    │       ├── App requests excessive permissions?
    │       │   ├── YES → HIGH SUSPICION
    │       │   └── NO → Medium suspicion, investigate further
    │       └── App has C2/network exfiltration code?
    │           ├── YES → CONFIRMED MALICIOUS
    │           └── NO → Still suspicious, monitor behavior
```

## Mitigation Strategies

### User/MDM Level

- **Allowlist trusted keyboards**: Only permit known-good IMEs (Gboard, SwiftKey, device default)
- **Block unknown IMEs**: Use MDM policies to prevent installation of apps with IME services
- **Managed profiles**: Restrict IME installation in managed device profiles
- **User education**: Warn users about "secure keyboard" prompts from unknown apps

### App-Side (High-Risk Apps)

- **Prefer phishing-resistant auth**: Use passkeys, biometrics, hardware tokens
- **Avoid relying on "secret text entry"**: A malicious IME sits below the app UI and can capture everything
- **Input validation**: Validate sensitive data server-side, don't trust client input
- **Behavioral monitoring**: Detect unusual input patterns that might indicate keylogging

## Red Flags Summary

| Indicator | Risk Level |
|-----------|------------|
| Non-keyboard app with InputMethodService | HIGH |
| IME service + network permissions | HIGH |
| IME service + accessibility permissions | HIGH |
| IME service + C2 communication | CONFIRMED MALICIOUS |
| Unknown keyboard in Settings | MEDIUM-HIGH |
| App prompts to enable "secure keyboard" | MEDIUM-HIGH |
| IME service in legitimate keyboard app | LOW (verify permissions) |

## Investigation Checklist

When investigating potential IME abuse:

- [ ] Check installed keyboards in Settings
- [ ] Run `adb shell ime list -a` to enumerate all IMEs
- [ ] Decompile APK and search for `InputMethodService`
- [ ] Review manifest for `android.view.InputMethod` intent filter
- [ ] Inspect IME configuration XML files
- [ ] Check for keyboard UI resources (layouts, key images)
- [ ] Analyze network traffic for exfiltration patterns
- [ ] Review app permissions for excessive access
- [ ] Check for UI automation code that might force IME enablement
- [ ] Verify app's stated functionality matches IME implementation

## Related Vectors

IME abuse is often combined with:

- **WebView man-in-the-browser**: Intercepting and modifying web content
- **Accessibility service abuse**: Automating UI interactions
- **Notification listener abuse**: Reading sensitive notifications
- **Device admin abuse**: Preventing uninstallation

When IME abuse is detected, investigate for these additional vectors as they often appear together in sophisticated trojans.

## References

- Android InputMethodService documentation
- Android security best practices for input methods
- Malware analysis reports on banking trojans with IME components
- ADB input method management commands
