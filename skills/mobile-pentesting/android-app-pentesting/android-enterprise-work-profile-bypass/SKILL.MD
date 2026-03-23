---
name: android-work-profile-bypass
description: Android Enterprise Work Profile security testing and bypass techniques. Use this skill whenever the user mentions Android Work Profiles, MDM bypass, Intune required apps, BYOD security testing, CVE-2023-21257, or any scenario involving Android Enterprise device management security assessment. This skill covers reconnaissance, exploitation chains, and post-exploitation opportunities for Work Profile environments.
---

# Android Enterprise Work Profile Bypass

A skill for testing Android Enterprise Work Profile security, specifically targeting MDM required-app enforcement and CVE-2023-21257 bypass techniques.

## When to use this skill

Use this skill when:
- Testing BYOD (Bring Your Own Device) Android Enterprise security
- Assessing MDM (Microsoft Intune, etc.) required-app enforcement
- Investigating Work Profile isolation and data access controls
- Performing authorized security assessments on Android Enterprise deployments
- Researching CVE-2023-21257 and related Work Profile vulnerabilities

## Prerequisites

Before attempting any bypass:
- **Physical access** to an unlocked BYOD device
- **Developer Options** enabled with USB debugging active
- **ADB access** to the device
- **Authorization** for security testing (this is for authorized assessments only)

## Reconnaissance

### 1. Identify user layout

First, confirm the multi-user structure and identify Work Profile user IDs:

```bash
adb shell pm list users
```

Expected output shows:
- `User 0`: Personal/Owner profile
- `User 1+`: Work Profile(s) (number may vary if multiple profiles exist)

### 2. Verify policy restrictions

Test that direct installs into the work user are blocked (this confirms the policy is active):

```bash
adb install --user 1 test.apk
```

Expected error:
```
java.lang.SecurityException: Shell does not have permission to access user 1
```

### 3. Identify target package

Find the package name of a Work Profile app marked as *required* by the MDM. Common targets include:
- Company Portal apps
- Enterprise email clients
- Productivity apps (Workday, Salesforce, etc.)
- Custom enterprise applications

Use these commands to enumerate installed packages:

```bash
# List all packages for work user
adb shell pm list packages --user 1

# Get package details
adb shell dumpsys package <package-name>
```

## Exploitation Chain

### Step 1: Prepare malicious payload

Build a malicious APK with the **same package name** as the managed app but with a **significantly higher versionCode**. This tricks the PackageManager and Finsky into treating it as a newer release.

**Gradle configuration:**

```gradle
android {
    namespace = "<target-package-name>"
    defaultConfig {
        applicationId = "<target-package-name>"
        versionCode = 900000004  // Much higher than legitimate version
        versionName = "9000000004.0"
    }
}
```

**Why this works:** The versionCode is the primary factor Finsky uses to determine which APK to install. A higher versionCode signals a newer release, bypassing version checks.

### Step 2: Deploy via Android Studio

Android Studio's deployment mechanism uses the `INSTALL_ALL_USERS` flag, which can still push builds to all users even when policies restrict direct ADB installs.

**Configuration:**
1. Open Run/Debug configuration
2. Enable *Deploy as instant app*
3. Select *Install for all users*
4. Deploy the malicious APK

**What happens:**
1. **Personal user (0)**: Malicious package installs normally
2. **Work Profile user (1)**: APK stages in temporary area, install is denied due to policy, but the legitimate managed app is marked as uninstalled and the staged APK remains cached

### Step 3: Trigger MDM auto-reinstall

Wait for the MDM policy refresh interval (typically 1-10 minutes). The MDM will:

1. Detect the *required* package is missing from the Work Profile
2. Trigger the Work-Profile Finsky instance to reinstall it
3. Finsky compares:
   - Play Store metadata for the package
   - The locally staged APK from the previous install attempt
4. Because the local build has the **highest versionCode**, Finsky installs it into the restricted Work Profile **without re-applying policy checks**

**Result:** The malicious binary now resides inside the Work Profile under the genuine package name and is considered compliant by the MDM.

## Post-Exploitation Opportunities

### Work Profile Data Access

Other enterprise apps trust Intents and content providers bound to the replaced package. This enables:
- Internal data theft from the Work Profile
- Covert exfiltration to attacker infrastructure
- Access to enterprise data stores

### Per-App VPN Hijack

If the replaced package is mapped to an Intune per-app VPN (MS Tunnels + Defender):
- The malicious build automatically inherits the VPN profile
- Direct access to internal hosts from attacker-controlled process
- Bypass of network segmentation controls

### Persistence

Because the MDM believes the required app is installed:
- It will **reinstall the malicious build** whenever removed
- Provides long-term foothold on BYOD Work Profiles
- Survives user-initiated app removal

## Verification

Confirm successful bypass:

```bash
# Check if malicious package is installed in work profile
adb shell pm list packages --user 1 | grep <package-name>

# Verify package details
adb shell dumpsys package <package-name> | grep -A 5 "User 1"

# Check installation source
adb shell dumpsys package <package-name> | grep "installer"
```

## Cleanup and Remediation

For authorized testing, document findings and recommend:

1. **MDM Policy Updates**: Review and tighten `DISALLOW_INSTALL_APPS` and `DISALLOW_DEBUGGING_FEATURES` policies
2. **App Signing Verification**: Implement certificate pinning and signature verification
3. **Version Code Monitoring**: Alert on unexpected versionCode changes
4. **Physical Access Controls**: Limit physical access to BYOD devices
5. **Regular Security Audits**: Periodic assessment of Work Profile configurations

## References

- [Bypassing CVE-2023-21257 via Intune Required-App Auto-Install](https://jgnr.ch/sites/android_enterprise.html)
- Android Enterprise Device Policy Controller documentation
- Microsoft Intune Work Profile configuration guide

## Important Notes

- **Authorization Required**: Only use these techniques on devices you own or have explicit authorization to test
- **Legal Compliance**: Ensure compliance with local laws and organizational policies
- **Documentation**: Document all testing activities and findings
- **Responsible Disclosure**: Report findings to appropriate security teams
