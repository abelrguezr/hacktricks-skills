---
name: android-burp-cert-install
description: How to install Burp Suite CA certificates on Android devices for traffic interception during mobile security testing. Use this skill whenever you need to set up SSL/TLS interception on Android, configure proxy settings, install CA certificates on rooted or non-rooted devices, or handle Android 14+ APEX certificate challenges. Make sure to use this skill when the user mentions Android pentesting, Burp certificate installation, mobile security testing, SSL interception, or any Android device configuration for traffic analysis.
---

# Android Burp Certificate Installation

This skill guides you through installing Burp Suite CA certificates on Android devices for SSL/TLS traffic interception during mobile security assessments.

## Quick Start

1. **Export Burp CA certificate** (DER format) from Burp: Proxy → Options → Import/Export CA certificate
2. **Choose your installation method** based on your device:
   - **AVD/Emulator**: Use `scripts/install-cert-avd.sh`
   - **Rooted device (Magisk)**: Follow Magisk module approach
   - **Android 14+**: Use `scripts/install-cert-android14.sh`
3. **Configure proxy** via ADB

## Installation Methods

### Method 1: AVD/Emulator with Writable System

For Android Virtual Devices, you need to run the emulator with `-writable-system` flag:

```bash
# Windows example
emulator.exe -avd "YourAVDName" -http-proxy 192.168.1.12:8080 -writable-system

# Linux/Mac example
emulator -avd YourAVDName -http-proxy 192.168.1.12:8080 -writable-system
```

Then use the bundled script:

```bash
./scripts/install-cert-avd.sh <path-to-burp_cacert.der>
```

This script:
- Converts DER to PEM format
- Generates the certificate hash name
- Pushes the certificate to `/system/etc/security/cacerts/`
- Sets correct permissions (644)
- Reboots the device

### Method 2: Rooted Device with Magisk

For rooted devices where the filesystem is read-only:

1. **Install as User Certificate**:
   - Copy `burp_cacert.der` to device, rename to `burp_cacert.crt`
   - Go to Settings → Security → Install a certificate → CA certificate
   - Verify in Settings → Security → Trusted credentials → USER

2. **Make System-Trusted** (choose one):

   **Option A: MagiskTrustUserCerts Module**
   ```bash
   # Download and install the module
   # Drag the .zip to device, open Magisk app → Modules → Install from storage
   # Reboot device
   ```

   **Option B: AlwaysTrustUserCerts (Android 7-16)**
   - Better for Android 14+ with Conscrypt Mainline updates
   - Automatically handles bind-mounting for APEX certificates
   - Install as user cert first, then install module and reboot

### Method 3: Android 14+ APEX Certificate Injection

Android 14 moved system certificates to `/apex/com.android.conscrypt/cacerts`, which is immutable. Use the bundled script:

```bash
./scripts/install-cert-android14.sh <path-to-burp_cacert.pem>
```

This script:
- Creates a tmpfs mount over `/system/etc/security/cacerts`
- Copies existing certificates to preserve trust
- Injects your certificate
- Uses `nsenter` to bind-mount into Zygote and all running app namespaces
- Handles both `zygote` and `zygote64` processes

**Important**: If `/system/etc/security/cacerts` contains nested mounts (common with Magisk modules), use `--rbind` instead of `--bind` in the nsenter commands.

## Proxy Configuration

Configure system-wide HTTP proxy via ADB:

```bash
# Set proxy (replace with your Burp listener IP:port)
adb shell settings put global http_proxy 192.168.1.2:8080

# Clear proxy
adb shell settings put global http_proxy :0
```

**Burp Configuration**: Bind your listener to `0.0.0.0` so devices on the LAN can connect (Proxy → Options → Proxy Listeners).

## Verification

After installation, verify the certificate is trusted:

```bash
# Check system certificates
adb shell ls /system/etc/security/cacerts/

# For Android 14+ APEX
adb shell ls /apex/com.android.conscrypt/cacerts/

# Check if certificate hash exists
adb shell openssl x509 -inform PEM -subject_hash_old -in /sdcard/burp_cacert.pem | head -1
```

## Troubleshooting

### Certificate Not Trusted by Apps

- **Android 7+**: Apps only trust user certificates if the app is signed with the same certificate or if you use a Magisk module
- **Android 14+**: Use the APEX injection method or AlwaysTrustUserCerts module
- **Check**: Settings → Security → Trusted credentials → SYSTEM (not USER)

### ADB Commands Fail

```bash
# Ensure ADB can write to system
adb root && sleep 2 && adb remount

# Check ADB connection
adb devices
```

### Emulator Won't Start with -writable-system

- Ensure you're using a system image that supports this
- Try creating a new AVD with a different system image
- Check emulator logs: `emulator -avd YourAVDName -logcat > emulator.log`

## Scripts Reference

| Script | Purpose | Input |
|--------|---------|-------|
| `convert-burp-cert.sh` | Convert DER to PEM with hash name | `burp_cacert.der` |
| `install-cert-avd.sh` | Install cert on writable AVD | `burp_cacert.der` |
| `install-cert-android14.sh` | Inject cert into Android 14+ APEX | `burp_cacert.pem` |
| `setup-proxy.sh` | Configure ADB proxy settings | `IP:PORT` |

## Security Notes

- Only use Burp certificates on devices you own or have explicit authorization to test
- Remove certificates after testing: `adb shell rm /system/etc/security/cacerts/<hash>.0`
- For Android 14+, reverse the APEX injection by remounting original APEX

## References

- [Android 14: Install a system CA certificate on a rooted device](https://httptoolkit.com/blog/android-14-install-system-ca-certificate/)
- [AlwaysTrustUserCerts Magisk module](https://github.com/NVISOsecurity/AlwaysTrustUserCerts)
- [MagiskTrustUserCerts](https://github.com/NVISOsecurity/MagiskTrustUserCerts)
- [Intercepting traffic on Android with Mainline and Conscrypt](https://blog.nviso.eu/2025/06/05/intercepting-traffic-on-android-with-mainline-and-conscrypt/)
