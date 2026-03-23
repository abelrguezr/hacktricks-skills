---
name: android-avd-pentest
description: How to set up and configure Android Virtual Devices (AVD) for mobile application security testing. Use this skill whenever the user needs to create Android emulators for testing APKs, wants to configure emulators with proxy settings for traffic interception, needs writable system images for certificate installation, or is doing any mobile pentesting that requires Android emulation. Make sure to use this skill for any Android emulator setup, AVD creation, or mobile app testing scenarios.
---

# Android AVD Pentest Setup

This skill helps you set up Android Virtual Devices (AVD) for mobile application security testing, including creating emulators, configuring network interception, and enabling root access.

## Quick Start

### Option 1: GUI (Android Studio)

1. Open Android Studio → **Tools** → **AVD Manager**
2. Click **Create Virtual Device**
3. Select a device (choose one with Play Store icon if needed)
4. Download and select an Android image
5. Click **Next** → **Finish**
6. Click **Start** to run the emulator

### Option 2: Command Line (Recommended for Pentesting)

Use the bundled scripts for quick setup:

```bash
# Quick setup (Linux/macOS)
./scripts/setup-avd.sh

# Create a pentest-ready AVD
./scripts/create-pentest-avd.sh PixelRootX86

# Run with proxy for Burp
./scripts/run-avd.sh PixelRootX86 --proxy 127.0.0.1:8080
```

## Prerequisites

### Install Android SDK Tools

**macOS (Homebrew):**
```bash
brew tap homebrew/cask
brew install --cask android-sdk
export JAVA_HOME=/Applications/Android\ Studio.app/Contents/jbr/Contents/Home
```

**Linux:**
```bash
mkdir -p ~/Android/cmdline-tools/latest
wget https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip
unzip commandlinetools-linux-13114758_latest.zip -d ~/Android/cmdline-tools/latest
export ANDROID_HOME=$HOME/Android
export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH
```

**Windows:**
- Install Android Studio
- SDK Tools location: `C:\Users\<UserName>\AppData\Local\Android\Sdk\tools`

## Creating AVDs

### List Available Devices

```bash
avdmanager list device
```

### List Available System Images

```bash
sdkmanager --list
```

### Install System Images

```bash
# Debuggable image (allows adb root)
sdkmanager "system-images;android-30;google_apis;x86_64"

# Play Store image (not rootable by default)
sdkmanager "system-images;android-30;google_apis_playstore;x86_64"
```

### Create AVD

```bash
avdmanager create avd -n "AVD_NAME" -k "system-images;android-30;google_apis;x86_64" -d "pixel"
```

## Running AVDs

### Basic Run

```bash
emulator -avd "AVD_NAME"
```

### Pentest Configuration

```bash
# With HTTP proxy for Burp Suite
emulator -avd "AVD_NAME" -http-proxy 127.0.0.1:8080

# With writable system (for certificate installation)
emulator -avd "AVD_NAME" -writable-system

# With both proxy and writable system
emulator -avd "AVD_NAME" -http-proxy 127.0.0.1:8080 -writable-system

# With network traffic capture
emulator -avd "AVD_NAME" -tcpdump /path/to/capture.cap

# With custom DNS
emulator -avd "AVD_NAME" -dns-server 8.8.8.8,8.8.4.4
```

## Root Access

### Debuggable Images (google_apis)

```bash
# After starting emulator with -writable-system
adb root
adb remount
adb shell whoami  # Should return: root
```

### Play Store Images (google_apis_playstore)

Play Store images are production builds and block root by default. To root:

1. Use [rootAVD](https://github.com/newbit1/rootAVD) with [Magisk](https://github.com/topjohnwu/Magisk)
2. Follow guides like [this video](https://www.youtube.com/watch?v=Wk0ixxmkzAI)

## Snapshots

### Save Snapshot

```bash
adb -s emulator-5554 emu avd snapshot save my_clean_setup
```

### Boot from Snapshot

```bash
emulator -avd "AVD_NAME" -snapshot my_clean_setup
```

### List Snapshots

```bash
emulator -avd "AVD_NAME" -snapshot-list
```

## Important Options Reference

### Network

| Option | Description |
|--------|-------------|
| `-http-proxy IP:PORT` | Set HTTP proxy (useful for Burp) |
| `-tcpdump FILE` | Capture all traffic to file |
| `-dns-server IP1,IP2` | Set DNS servers |
| `-netdelay MS` | Set network latency |
| `-port PORT` | Set console/adb port |

### System

| Option | Description |
|--------|-------------|
| `-writable-system` | Enable writable system image |
| `-selinux disabled|permissive` | Set SELinux mode |
| `-timezone TZ` | Set timezone |
| `-screen touch|multi-touch|o-touch` | Set touch mode |

### Boot

| Option | Description |
|--------|-------------|
| `-snapshot NAME` | Start from snapshot |
| `-snapshot-list` | List available snapshots |

## System Image Types

| Type | Root Access | Play Services | Use Case |
|------|-------------|---------------|----------|
| `google_apis` | ✅ Yes | ❌ No | Pentesting (recommended) |
| `google_apis_playstore` | ❌ No (requires Magisk) | ✅ Yes | Apps requiring Play Services |
| `aosp/default` | ✅ Yes | ❌ No | Lightweight testing |

## ARM App Compatibility

Android 11+ Google APIs images support per-app ARM-to-x86 translation:
- Most ARM-only apps run quickly on x86_64 hosts
- Full-system ARM64 emulation is unsupported from API 28+
- Use Google APIs x86/x86_64 images for best compatibility

## Common Pentest Workflow

1. **Create AVD** with debuggable image (`google_apis`)
2. **Run with** `-writable-system` and `-http-proxy` for Burp
3. **Install Burp certificate** (see `install-burp-certificate.md`)
4. **Take snapshot** of clean state
5. **Test APK** with traffic interception
6. **Restore snapshot** for clean state

## Troubleshooting

### "adbd cannot run as root in production builds"

- Use `google_apis` images instead of `google_apis_playstore`
- Or root with Magisk (see Rooting section)

### Proxy not working

- Try configuring proxy inside Android settings
- Use apps like "Super Proxy" or "ProxyDroid"
- Verify emulator started with `-http-proxy` option

### Slow performance

- Use x86_64 images on x86_64 hosts
- Enable hardware acceleration in BIOS
- Use snapshots to avoid full boot

## References

- [Android Emulator Command Line](https://developer.android.com/studio/run/emulator-commandline)
- [Run ARM apps on Android Emulator](https://android-developers.googleblog.com/2020/03/run-arm-apps-on-android-emulator.html)
- [Build a Repeatable Android Bug Bounty Lab](https://www.yeswehack.com/learn-bug-bounty/android-lab-mobile-hacking-tools)
