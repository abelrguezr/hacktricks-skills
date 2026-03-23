---
name: android-adb-pentesting
description: Android ADB pentesting and device exploration. Use this skill whenever the user needs to interact with Android devices via ADB, including connecting to devices, managing packages, transferring files, capturing screens, analyzing logs, or performing backup/restore operations. Trigger for any Android device testing, mobile security assessment, or ADB command execution tasks.
---

# Android ADB Pentesting

A comprehensive guide for Android device testing and security assessment using ADB (Android Debug Bridge).

## Connection and Setup

### Locate ADB

Find the ADB binary on your system:

- **Windows**: `C:\Users\<username>\AppData\Local\Android\sdk\platform-tools\adb.exe`
- **macOS**: `/Users/<username>/Library/Android/sdk/platform-tools/adb`
- **Linux**: `~/.local/share/Android/Sdk/platform-tools/adb` or `/usr/bin/adb`

### List Connected Devices

```bash
adb devices
```

This shows all connected devices. If you see "unauthorized", you must:
1. Unlock the mobile device
2. Accept the RSA key fingerprint prompt on the device screen

### Connect via TCP/IP

Start the ADB server on port 5555:

```bash
adb tcpip 5555
```

Then connect to the device:

```bash
adb connect <IP>:<PORT>
```

### Handle Version Mismatches

If you encounter version mismatch errors (common with emulators like Genymotion):

```
adb server version (41) doesn't match this client (36); killing...
```

Find the emulator's ADB binary and use that instead:
- Genymotion: `C:\Program Files\Genymobile\Genymotion\...\adb.exe`

### Multiple Devices

When multiple devices are connected, specify the target:

```bash
adb devices
# Output:
# 10.10.10.247:42135  offline
# 127.0.0.1:5555      device

adb -s 127.0.0.1:5555 shell
```

### Port Tunneling via SSH

Forward ADB port through SSH when only localhost access is available:

```bash
ssh -i ssh_key username@10.10.10.10 -L 5555:127.0.0.1:5555 -p 2222
adb connect 127.0.0.1:5555
```

## Package Management

### Install Applications

```bash
adb install test.apk
```

**Common options:**

| Option | Purpose |
|--------|---------|
| `-l` | Forward lock application |
| `-r` | Replace existing application |
| `-t` | Allow test packages |
| `-s` | Install on SD card |
| `-d` | Allow version downgrade |
| `-p` | Partial install |

### Uninstall Applications

```bash
adb uninstall com.test.app
adb uninstall -k com.test.app  # Keep data and cache directories
```

### List Packages

```bash
adb shell pm list packages [options] [FILTER-STR]
```

**Filter options:**

| Option | Description |
|--------|-------------|
| `-f` | Show associated APK file paths |
| `-d` | Show only disabled packages |
| `-e` | Show only enabled packages |
| `-s` | Show only system packages |
| `-3` | Show only third-party packages |
| `-i` | Show installer information |
| `-u` | Include uninstalled packages |
| `--user <ID>` | Query specific user space |

**Examples:**

```bash
# List all third-party packages with file paths
adb shell pm list packages -f -3

# Find packages containing "facebook"
adb shell pm list packages facebook

# List system packages only
adb shell pm list packages -s
```

### Get Package Path

```bash
adb shell pm path com.android.phone
```

### Clear Package Data

```bash
adb shell pm clear com.test.abc
```

## File Operations

### Pull Files (Device → Computer)

```bash
adb pull /sdcard/demo.mp4 ./
```

### Push Files (Computer → Device)

```bash
adb push test.apk /sdcard/
```

## Screen Capture and Recording

### Screenshot

```bash
adb shell screencap /sdcard/screen.png
adb pull /sdcard/screen.png ./
```

### Screen Recording

```bash
adb shell screenrecord /sdcard/demo.mp4
```

**Recording options:**

| Option | Description |
|--------|-------------|
| `--size <WIDTHxHEIGHT>` | Set resolution |
| `--bit-rate <RATE>` | Set video bitrate |
| `--time-limit <TIME>` | Max duration in seconds (default: 180) |
| `--rotate` | Rotate 90 degrees |
| `--verbose` | Show verbose output |

**Stop recording**: Press `Ctrl-C`

**Download the recording:**

```bash
adb pull /sdcard/demo.mp4 ./
```

## Shell Commands

### Enter Device Shell

```bash
adb shell
```

### Execute Single Command

```bash
adb shell ls
adb shell whoami
```

### Common Shell Commands

```bash
pm list packages          # List installed packages
pm path <package>         # Get APK path
am start [options]        # Start an activity
am startservice [options] # Start a service
am broadcast [options]    # Send a broadcast
input text <text>         # Send text input
input keyevent <code>     # Send key event
```

## Process Management

### List All Processes

```bash
adb shell ps
```

### Get Application PID

```bash
adb shell pidof com.your.application
```

## System Commands

### Restart ADB as Root

```bash
adb root
```

**Note**: Requires unlocked bootloader. Reconnect after running this command.

### Sideload Updates

```bash
adb sideload update.zip
```

## Logging and Debugging

### Logcat Basics

```bash
adb logcat
```

**Stop monitoring**: Press `Ctrl-C`

### Filter by Application PID

```bash
# Linux/macOS
adb logcat | grep 4526

# Windows
adb logcat | findstr 4526
```

### Logcat Priority Levels

| Level | Command | Description |
|-------|---------|-------------|
| `V` | `adb logcat *:V` | Verbose (lowest) |
| `D` | `adb logcat *:D` | Debug |
| `I` | `adb logcat *:I` | Info |
| `W` | `adb logcat *:W` | Warning |
| `E` | `adb logcat *:E` | Error |
| `F` | `adb logcat *:F` | Fatal |
| `S` | `adb logcat *:S` | Silent (highest) |

### Logcat Buffers

```bash
adb logcat -b radio   # Radio/telephony messages
adb logcat -b event   # Event-related messages
adb logcat -b main    # Default buffer
```

### Logcat Utilities

```bash
adb logcat -c              # Clear entire log
adb logcat -d              # Dump log and exit
adb logcat -f test.logs    # Write to file
adb logcat -g              # Print buffer size
adb logcat -n <count>      # Set max rotated logs
```

### Dumpsys Commands

```bash
adb shell dumpsys           # List all dumpsys options
adb shell dumpsys meminfo   # Memory information
adb shell dumpsys battery   # Battery status
```

### Battery Statistics

**Collect battery data:**

```bash
adb shell dumpsys batterystats > batterystats.txt
```

**Visualize with Battery Historian:**

```bash
python historian.py batterystats.txt > batterystats.html
```

**Reset battery stats:**

```bash
adb shell dumpsys batterystats --reset
```

### Activity Dump

```bash
adb shell dumpsys activity
```

## Backup and Restore

### Create Backup

```bash
adb backup -f myapp_backup.ab -apk com.myapp
```

**Backup options:**

| Option | Description |
|--------|-------------|
| `-apk` | Include APK files |
| `-shared` | Include removable storage |
| `-system` | Include system applications |
| `-all` | Include all applications |

### Restore Backup

```bash
adb restore myapp_backup.ab
```

### Inspect Backup Contents

```bash
( printf "\x1f\x8b\x08\x00\x00\x00\x00\x00" ; tail -c +25 myapp_backup.ab ) | tar xfvz -
```

## Common Pentesting Workflows

### 1. Initial Device Reconnaissance

```bash
# Connect and verify
adb devices

# Get device info
adb shell getprop

# List all packages
adb shell pm list packages -f -3

# Check for root
adb shell whoami
```

### 2. Application Analysis

```bash
# Find target app
adb shell pm list packages | grep target_app

# Get APK path
adb shell pm path com.target.app

# Pull APK
adb pull /path/to/app.apk ./

# Clear app data
adb shell pm clear com.target.app
```

### 3. Log Analysis

```bash
# Start monitoring with error level
adb logcat *:E

# Filter for specific app
adb shell pidof com.target.app
adb logcat | grep <PID>

# Save logs to file
adb logcat -d > app_logs.txt
```

### 4. Screen Recording for Evidence

```bash
# Record 60 seconds at 1080p
adb shell screenrecord --size 1920x1080 --time-limit 60 /sdcard/evidence.mp4

# Download
adb pull /sdcard/evidence.mp4 ./
```

## Tips and Best Practices

1. **Always verify device authorization** before running commands
2. **Use specific device IDs** when multiple devices are connected
3. **Filter logcat output** to reduce noise and find relevant information
4. **Save logs to files** for later analysis rather than scrolling through terminal
5. **Test commands on emulators first** before using on production devices
6. **Document findings** with screenshots and screen recordings
7. **Clear app data** between test iterations for consistent results

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "unauthorized" | Unlock device and accept RSA key |
| "device not found" | Check USB connection and USB debugging enabled |
| Version mismatch | Use emulator's ADB binary |
| Permission denied | Try `adb root` (requires unlocked bootloader) |
| Connection refused | Verify port 5555 is open and ADB server is running |
