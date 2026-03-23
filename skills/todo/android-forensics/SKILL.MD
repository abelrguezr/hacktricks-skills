---
name: android-forensics
description: How to perform Android device forensics and data extraction. Use this skill whenever the user mentions Android forensics, mobile device investigation, extracting data from Android phones, ADB backups, memory extraction from Android, or any mobile device forensic analysis. This includes locked device handling, data acquisition, partition imaging, and RAM extraction.
---

# Android Forensics

A skill for performing forensic analysis and data extraction from Android devices.

## When to use this skill

Use this skill when:
- Investigating an Android device for forensic purposes
- Extracting data from Android phones or tablets
- Working with ADB (Android Debug Bridge) for forensics
- Need to image Android partitions or extract memory
- Dealing with locked Android devices
- Performing mobile device forensic analysis

## Locked Device Handling

If the Android device is locked, try these approaches:

### 1. Check USB Debugging Status
- Verify if USB debugging is already enabled in Developer Options
- If enabled, you can proceed with ADB commands even on a locked device

### 2. Smudge Attack Analysis
- Examine the screen for smudge patterns that may reveal PIN/password
- Focus on areas with consistent touch marks
- This can help identify frequently used digits or patterns

### 3. Brute-force Considerations
- Only attempt if you have proper authorization
- Modern Android devices have lockout mechanisms after failed attempts
- Consider using specialized hardware tools if available

## Data Acquisition

### ADB Backup Method

Create a backup using ADB and extract it:

```bash
# Create backup
adb backup -noapk -shared -apk -f backup.ab <package-name>

# Extract backup using Android Backup Extractor
java -jar abe.jar unpack backup.ab backup.tar
tar -xvf backup.tar
```

**Note:** The `-noapk` flag excludes app binaries, `-shared` includes shared storage, and `-apk` includes app packages. Adjust flags based on your investigation needs.

### Root Access or Physical Connection

If you have root access or JTAG interface:

#### 1. Discover Partitions
```bash
adb shell cat /proc/partitions
```
Look for the flash memory path (typically `mmcblk0` for the whole flash memory).

#### 2. Check Block Size
```bash
adb shell df /data
```
Note the block size from the output.

#### 3. Create Disk Image
```bash
adb shell dd if=/dev/block/mmcblk0 of=/sdcard/blk0.img bs=4096
adb pull /sdcard/blk0.img ./blk0.img
```

**Important:** Adjust the block device path and block size based on your device's actual configuration.

## Memory Extraction

### Using LiME (Linux Memory Extractor)

LiME is a kernel extension for extracting RAM information:

1. **Load LiME via ADB** (requires root):
```bash
adb push lime.ko /system/lib/modules/
adb shell insmod /system/lib/modules/lime.ko
```

2. **Extract memory to file**:
```bash
adb shell lime dump /sdcard/memory.lime
adb pull /sdcard/memory.lime ./memory.lime
```

3. **Analyze the memory dump** using forensic tools like Volatility or specialized Android memory analysis tools.

## Best Practices

1. **Document everything** - Record all commands, timestamps, and device states
2. **Work on copies** - Never modify the original device or images
3. **Verify integrity** - Calculate and store hashes of all extracted data
4. **Maintain chain of custody** - Document who handled the evidence and when
5. **Use write-blockers** - When possible, use hardware write-blockers for physical connections

## Common Tools

- **ADB** - Android Debug Bridge for device communication
- **Android Backup Extractor (ABE)** - Extract ADB backups
- **LiME** - Linux Memory Extractor for RAM dumps
- **dd** - Create disk images
- **Volatility** - Memory analysis framework

## Troubleshooting

- **ADB not recognizing device**: Check USB debugging is enabled, try different USB cable/port
- **Permission denied**: May need root access or proper ADB authorization
- **Backup fails**: Try with different flags, ensure sufficient storage space
- **Memory extraction fails**: Verify kernel compatibility, check if device supports the operation
