---
name: windows-registry-forensics
description: Analyze Windows Registry hives for forensic investigations. Use this skill whenever you need to extract system information, user activity, USB device history, network configurations, or timeline data from Windows Registry files (SYSTEM, NTUSER.DAT, USRCLASS.DAT, SOFTWARE). Trigger this skill for any Windows forensics task involving registry analysis, malware persistence detection, user activity reconstruction, or incident response investigations.
---

# Windows Registry Forensics

A comprehensive guide for analyzing Windows Registry hives during forensic investigations. This skill helps you extract critical system information, user activity data, and evidence from Windows Registry files.

## Quick Reference: Key Registry Paths

### System Information
| Information | Registry Path |
|-------------|---------------|
| Windows Version & Owner | `Software\Microsoft\Windows NT\CurrentVersion` |
| Computer Name | `System\ControlSet001\Control\ComputerName\ComputerName` |
| Time Zone | `System\ControlSet001\Control\TimeZoneInformation` |
| Shutdown Details | `System\ControlSet001\Control\Windows` |
| Volume Serial Numbers | `System\MountedDevices` |

### User Activity
| Information | Registry Path |
|-------------|---------------|
| Recent Documents | `NTUSER.DAT\Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs` |
| Typed Paths | `NTUSER.DAT\Software\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths` |
| User Assist (App Usage) | `NTUSER.DAT\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist\{GUID}\Count` |
| MRU Lists | `NTUSER.DAT\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32` |
| Shellbags | `NTUSER.DAT` & `USRCLASS.DAT\Software\Microsoft\Windows\Shell` |

### Persistence & Startup
| Information | Registry Path |
|-------------|---------------|
| AutoStart Programs | `NTUSER.DAT\Software\Microsoft\Windows\CurrentVersion\Run` |
| RunOnce Keys | `NTUSER.DAT\Software\Microsoft\Windows\CurrentVersion\RunOnce` |
| System Run Keys | `Software\Microsoft\Windows\CurrentVersion\Run` |

### Network & USB
| Information | Registry Path |
|-------------|---------------|
| Network Interfaces | `System\ControlSet001\Services\Tcpip\Parameters\Interfaces\{GUID}` |
| Network List | `Software\Microsoft\Windows NT\CurrentVersion\NetworkList` |
| USB Device History | `System\ControlSet001\Enum\USBSTOR` |
| USB Devices | `System\ControlSet001\Enum\USB` |
| Last Mounted Device | `System\MountedDevices` |

## Investigation Workflow

### Step 1: Identify Available Hives

First, determine which registry hives you have access to:

- **SYSTEM** - System-wide configuration, boot info, services
- **NTUSER.DAT** - User-specific settings, activity tracking (one per user)
- **USRCLASS.DAT** - User class settings, shellbags
- **SOFTWARE** - Installed software, system-wide settings
- **SAM** - Security accounts (requires special handling)
- **SECURITY** - Security policies (requires special handling)

### Step 2: Extract System Information

Use the `parse-registry-hive.py` script to extract key system information:

```bash
python parse-registry-hive.py --hive SYSTEM --output system-info.json
```

This extracts:
- Windows version and build number
- Computer name and hostname
- Time zone configuration
- Service pack information
- Installation date

### Step 3: Analyze User Activity

For each user hive (NTUSER.DAT), extract activity artifacts:

```bash
python parse-registry-hive.py --hive NTUSER.DAT --user-activity --output user-activity.json
```

This extracts:
- Recent documents accessed
- Typed command paths
- User Assist application usage statistics
- MRU (Most Recently Used) lists
- Shellbag folder access history

### Step 4: Check for Persistence Mechanisms

Identify auto-start programs and potential malware persistence:

```bash
python parse-registry-hive.py --hive NTUSER.DAT --persistence --output persistence.json
```

This checks:
- Run and RunOnce keys
- Scheduled task references
- Service configurations
- Browser helper objects

### Step 5: USB Device Analysis

Extract USB device connection history:

```bash
python parse-registry-hive.py --hive SYSTEM --usb-history --output usb-history.json
```

This extracts:
- Device manufacturer and model
- Connection timestamps
- Serial numbers
- Volume serial numbers
- Associated user accounts

### Step 6: Network Configuration Analysis

Extract network interface and connection data:

```bash
python parse-registry-hive.py --hive SYSTEM --network --output network-config.json
```

This extracts:
- Network interface configurations
- IP address assignments
- Network connection timestamps
- VPN connection history

### Step 7: Generate Comprehensive Report

Create a consolidated forensic report:

```bash
python generate-forensic-report.py \
  --system-hive SYSTEM \
  --user-hives NTUSER.DAT \
  --output forensic-report.html
```

## Common Forensic Questions & Answers

### "When was this system installed?"
Check `Software\Microsoft\Windows NT\CurrentVersion\InstallDate` (Windows file time format)

### "What USB devices were connected?"
Check `System\ControlSet001\Enum\USBSTOR` for device details and timestamps

### "Which user accessed this folder?"
Check Shellbags in `NTUSER.DAT` and `USRCLASS.DAT` under `Software\Microsoft\Windows\Shell` for folder access history

### "What programs run at startup?"
Check `Run` and `RunOnce` keys in both user and system hives

### "What files did the user recently open?"
Check `RecentDocs` and `UserAssist` keys in NTUSER.DAT

### "What is the system's timezone?"
Check `System\ControlSet001\Control\TimeZoneInformation`

### "When was the system last shut down?"
Check `System\ControlSet001\Control\Windows` for shutdown timestamps

## Tools & Resources

### Recommended Tools
- **Shellbag Explorer** - https://ericzimmerman.github.io/#!index.md
- **Registry Explorer** - Built-in Windows tool or third-party alternatives
- **Plaso/Log2Timeline** - For timeline analysis
- **Eric Zimmerman's Tools** - Various registry analysis utilities

### File Time Conversion
Windows Registry timestamps are in Windows File Time format (100-nanosecond intervals since January 1, 1601 UTC). Use the provided scripts to convert these to human-readable dates.

## Best Practices

1. **Always work on copies** - Never analyze registry hives directly from a live system
2. **Document your process** - Keep detailed notes of which hives you analyzed and what you found
3. **Preserve timestamps** - Note the original file timestamps before any analysis
4. **Cross-reference data** - Correlate registry findings with other artifacts (logs, file system, memory)
5. **Consider timezone** - Account for system timezone when interpreting timestamps
6. **Check all ControlSets** - Registry may have multiple ControlSets (001, 002, Current)

## Limitations

- Registry hives from different Windows versions may have different structures
- Some keys may be encrypted or protected
- User hives (NTUSER.DAT) are user-specific and may not exist for all users
- Some forensic artifacts may be cleared by anti-forensic tools
- Live system analysis may modify registry data

## Next Steps

After initial analysis:
1. Correlate findings with file system artifacts
2. Build a timeline of events
3. Identify gaps in the evidence
4. Consider memory forensics for additional context
5. Document all findings for reporting
