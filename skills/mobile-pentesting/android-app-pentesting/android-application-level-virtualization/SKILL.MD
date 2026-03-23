---
name: android-app-virtualization-detection
description: Detect and analyze Android application-level virtualization (app cloning/container frameworks like DroidPlugin). Use this skill whenever you need to investigate suspicious Android apps, analyze potential app virtualization abuse, check for permission escalation via shared UIDs, or detect stealthy code loading. Trigger this skill for any Android security analysis involving app containers, plugin frameworks, or when you suspect an app is running multiple APKs under a single process.
---

# Android App Virtualization Detection

This skill helps you detect and analyze Android application-level virtualization frameworks (app cloning, container frameworks like DroidPlugin) that run multiple APKs inside a single host app.

## When to Use This Skill

Use this skill when:
- Investigating suspicious Android apps for virtualization/container frameworks
- Analyzing potential permission escalation via shared UIDs
- Detecting stealthy code loading or runtime instrumentation
- Performing Android security assessments or penetration testing
- Checking if an app is running multiple APKs under a single process
- Investigating apps that behave unusually (crash tampering, hidden functionality)

## Understanding App Virtualization

### Normal vs Virtualized Execution

**Normal install:**
- Package Manager extracts APK to `/data/app/<rand>/com.pkg-<rand>/base.apk`
- System assigns a **unique UID** to each app
- Zygote forks a process that loads `classes.dex`

**Virtualized launch:**
- Host starts a process under **its own UID**
- Loads guest's `base.apk`/dex with a custom class loader
- Exposes lifecycle callbacks via Java proxies
- Guest storage API calls are remapped to host-controlled paths

### Common Abuse Patterns

1. **Permission escalation via shared UID**: Guests run under the host UID and inherit all host-granted permissions, even if not declared in the guest manifest
2. **Stealthy code loading**: Host hooks `openDexFileNative`/class loaders to inject, replace, or instrument guest dex at runtime
3. **Malicious host**: Acts as dropper/executor, instruments/filters guest behavior, tampers with crashes
4. **Malicious guest**: Abuses shared UID to reach other guests' data, ptrace them, or leverage host permissions

## Detection Methodology

### Step 1: Identify Target Process

First, identify the process you want to investigate:

```bash
# List running processes
adb shell ps -A | grep <package-name>

# Get PID for a specific app
adb shell pidof <package-name>
```

### Step 2: Check for Multiple base.apk Files

A container often maps several APKs in the same PID. This is a strong indicator of virtualization:

```bash
# Check for multiple base.apk files in process maps
adb shell "cat /proc/<pid>/maps | grep base.apk"
```

**Suspicious indicators:**
- Multiple `base.apk` entries from different packages
- Host base.apk + unrelated packages mapped together
- APKs from packages not installed on the device

### Step 3: Detect Hooking/Instrumentation Artifacts

Search for known instrumentation libraries in process maps:

```bash
# Check for Frida
adb shell "cat /proc/<pid>/maps | grep frida"

# Check for Xposed
adb shell "cat /proc/<pid>/maps | grep -i xposed"

# Check for other common hooking frameworks
adb shell "cat /proc/<pid>/maps | grep -E '(frida|xposed|cydia|substrate|hook)'
```

Verify on disk:

```bash
adb shell "file /data/app/..../lib/arm64/libfrida-gadget.so"
```

### Step 4: Crash-Tamper Probe

Intentionally trigger an exception and observe whether the process dies normally. Hosts that intercept lifecycle/crash paths may swallow or rewrite crashes:

```bash
# Trigger a NullPointerException
adb shell am broadcast -a com.example.test -e trigger "crash"

# Or use a test app that throws exceptions
adb shell "am start -n <package>/<activity>"
```

**Normal behavior:** Process crashes and restarts
**Suspicious behavior:** Process survives, crash is swallowed, or behavior is rewritten

### Step 5: Analyze Permission Inheritance

Check if guests are running with unexpected permissions:

```bash
# List permissions granted to the host app
adb shell dumpsys package <host-package> | grep -A 100 "Granted permissions"

# Check what permissions the guest should have
adb shell dumpsys package <guest-package> | grep -A 100 "Granted permissions"
```

If the guest is running under the host UID, it will have access to all host permissions.

## Automated Detection Scripts

Use the bundled scripts for faster analysis:

### `check_virtualization.sh`
Checks for multiple base.apk files and common virtualization indicators in a process.

```bash
./check_virtualization.sh <pid>
```

### `detect_hooks.sh`
Scans process maps for known hooking/instrumentation libraries.

```bash
./detect_hooks.sh <pid>
```

### `analyze_permissions.sh`
Compares declared vs effective permissions to detect permission escalation.

```bash
./analyze_permissions.sh <host-package> <guest-package>
```

## Hardening Recommendations

If you're developing apps and want to protect against virtualization abuse:

1. **Server-side attestation**: Enforce sensitive operations behind [Play Integrity](https://developer.android.com/google/play/integrity) tokens so only genuine installs (not dynamically loaded guests) are accepted server-side

2. **Use stronger isolation**: For highly sensitive code, prefer **Android Virtualization Framework (AVF)**/TEE-backed execution instead of app-level containers that share a UID

3. **Runtime integrity checks**: Implement checks for:
   - Unexpected process mappings
   - Hooking libraries in memory
   - Modified crash handlers
   - Unusual permission grants

## References

- [Android Application-Level Virtualization (App Cloning) — How It Works, Abuse, and Detection](https://blog.azzahid.com/posts/android-app-virtualization/)
- [Play Integrity API](https://developer.android.com/google/play/integrity)
- [Android Virtualization Framework](https://developer.android.com/topic/architecture/virtualization)

## Quick Reference

| Indicator | Command | Suspicious Result |
|-----------|---------|-------------------|
| Multiple APKs | `cat /proc/<pid>/maps \| grep base.apk` | Multiple base.apk from different packages |
| Hooking libs | `cat /proc/<pid>/maps \| grep frida` | Frida, Xposed, or other hooking libraries |
| Permission mismatch | `dumpsys package <pkg>` | Guest has host's permissions |
| Crash tampering | Trigger exception | Process survives or behavior changes |
