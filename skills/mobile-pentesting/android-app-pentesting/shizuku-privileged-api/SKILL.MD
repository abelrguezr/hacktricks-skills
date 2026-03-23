---
name: shizuku-android-pentest
description: Use this skill for Android security testing, privilege escalation analysis, and system API exploration using Shizuku. Trigger when users mention Android pentesting, security auditing, Shizuku, privileged APIs, ADB debugging, mobile security assessments, device forensics, or any Android device security investigation. This skill helps you leverage Shizuku's shell-level privileges without requiring root access.
---

# Shizuku Android Pentesting

This skill enables Android security testing using Shizuku, an open-source service that spawns a privileged Java process using `app_process` and exposes selected Android system APIs over Binder. The process runs with the same `shell` UID capabilities that ADB uses, allowing actions that normally require `WRITE_SECURE_SETTINGS`, `INSTALL_PACKAGES`, file I/O inside `/data`, etc. — **without rooting the device**.

## When to Use This Skill

Use this skill when you need to:
- Perform security auditing on an un-rooted Android device
- Enumerate system processes, sockets, and configurations
- Collect logs, Wi-Fi credentials, or process information for DFIR
- Remove bloatware or debloat system apps
- Automate device configuration from custom apps or scripts
- Test Android application security with elevated shell privileges

## Starting the Shizuku Service

Shizuku can be started in three ways. Choose the method that matches your access level:

### Method 1: Wireless ADB (Android 11+)

Best for remote testing without physical access:

1. Enable **Developer Options → Wireless debugging** on the target device
2. Pair the device and note the pairing code
3. In the Shizuku app, select **"Start via Wireless debugging"**
4. The service persists until reboot (wireless-debugging sessions clear on boot)

### Method 2: USB/Network ADB One-Liner

For devices with ADB access:

```bash
# Push the start script
adb push start.sh /storage/emulated/0/Android/data/moe.shizuku.privileged.api/

# Spawn the privileged process
adb shell sh /storage/emulated/0/Android/data/moe.shizuku.privileged.api/start.sh
```

This also works over network ADB: `adb connect <IP>:5555`

### Method 3: Rooted Devices

If the device is already rooted:

```bash
su -c sh /data/adb/shizuku/start.sh
```

### Verifying the Service is Running

```bash
adb shell dumpsys activity service moe.shizuku.privileged.api | head
```

A successful start returns `Running services (1)` with the PID of the privileged process.

## Using Rish for Elevated Shell Access

The Shizuku settings screen exposes **"Use Shizuku in terminal apps"**. Enable it to download *rish* (`/data/local/tmp/rish`).

### Installing Rish in Termux

```bash
pkg install wget
wget https://rikka.app/rish/latest -O rish && chmod +x rish

# Start elevated shell (inherits the binder connection)
./rish
```

### Verify Privilege Level

```bash
whoami   # → shell
id       # → uid=2000(shell) gid=2000(shell) groups=... context=u:r:shell:s0
```

## Security Testing Commands

### Process Enumeration

List running processes for a specific package:

```bash
ps -A | grep com.facebook.katana
```

### Socket and Network Analysis

Enumerate listening sockets and map them to packages (useful for detecting vulnerabilities like CVE-2019-6447):

```bash
netstat -tuln

# Map PIDs to processes
for pid in $(lsof -nP -iTCP -sTCP:LISTEN -t); do
    printf "%s -> %s\n" "$pid" "$(cat /proc/$pid/cmdline)";
done
```

### Log Collection

Dump application logs with error filtering:

```bash
logcat -d | grep -iE "(error|exception)"
```

### Wi-Fi Credential Extraction (Android 11+)

```bash
cat /data/misc/wifi/WifiConfigStore.xml | grep -i "<ConfigKey>"
```

### Package Management

Bulk debloat system apps:

```bash
pm uninstall --user 0 com.miui.weather2
```

List all installed packages:

```bash
pm list packages -3  # Third-party apps
pm list packages -s  # System apps
```

### Settings Modification

Enable ADB programmatically:

```bash
settings put global adb_enabled 1
```

## Security Considerations

### Detection Vectors

1. **ADB Debugging Required**: Shizuku needs Developer Options → USB/Wireless debugging enabled. Organizations can block this via MDM or `settings put global development_settings_enabled 0`.

2. **Service Registration**: The service registers as `moe.shizuku.privileged.api`. Detection:
   ```bash
   adb shell service list | grep shizuku
   ```

3. **Capability Limits**: Shizuku is limited to `shell` user capabilities — it is **not root**. Sensitive APIs requiring `system` or `root` remain inaccessible.

4. **Session Persistence**: Sessions do **not survive reboot** unless the device is rooted and Shizuku is configured as a startup daemon.

### Mitigation Strategies

- Disable USB/Wireless debugging on production devices
- Monitor for Binder services exposing `moe.shizuku.privileged.api`
- Use SELinux policies (Android enterprise) to block the AIDL interface from unmanaged applications

## Application Integration

Third-party apps can bind to Shizuku by adding to `AndroidManifest.xml`:

```xml
<uses-permission android:name="moe.shizuku.manager.permission.API"/>
```

At runtime, obtain the binder:

```java
IBinder binder = ShizukuProvider.getBinder();
IPackageManager pm = IPackageManager.Stub.asInterface(binder);
```

From this point, the app can invoke any method the `shell` user may call, such as:

```java
pm.installPackage(new Uri("file:///sdcard/app.apk"), null, 0, null);
Settings.Global.putInt(resolver, Settings.Global.ADB_ENABLED, 1);
```

A curated list of 170+ Shizuku-enabled apps is maintained at [awesome-shizuku](https://github.com/timschneeb/awesome-shizuku).

## References

- [Shizuku Official Documentation](https://shizuku.rikka.app/)
- [awesome-shizuku – list of supported apps](https://github.com/timschneeb/awesome-shizuku)
- [rish shell documentation](https://github.com/RikkaApps/Shizuku/blob/master/RISH.md)
- [Mobile Hacker Blog – Shizuku: Unlocking Advanced Android Capabilities Without Root](https://www.mobile-hacker.com/2025/07/14/shizuku-unlocking-advanced-android-capabilities-without-root/)
