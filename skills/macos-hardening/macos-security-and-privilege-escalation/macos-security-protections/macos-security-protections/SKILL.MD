---
name: macos-security-protections
description: Use this skill whenever the user needs to understand, enumerate, or work with macOS security mechanisms including Gatekeeper, SIP, Sandbox, TCC, Launch Constraints, MRT, or Background Task Management. Trigger for macOS security assessments, privilege escalation research, persistence analysis, or when investigating macOS security bypasses. Make sure to use this skill for any macOS security-related tasks, even if the user doesn't explicitly mention security terms.
---

# macOS Security Protections

A comprehensive guide to macOS security mechanisms, enumeration techniques, and bypass methods for authorized security testing.

## Overview

macOS employs multiple layered security mechanisms to protect the system. Understanding these is essential for security assessments, privilege escalation research, and persistence analysis.

## Security Mechanisms

### Gatekeeper (Quarantine + Gatekeeper + XProtect)

Gatekeeper prevents execution of potentially malicious software downloaded from the internet.

**Components:**
- **Quarantine**: Marks downloaded files with extended attributes
- **Gatekeeper**: Verifies code signatures and notarization
- **XProtect**: Scans files against known malware signatures

**Key behaviors:**
- Checks files as they're downloaded via certain applications
- Prevents file opening if malware is detected
- Works preventatively before execution

### System Integrity Protection (SIP)

SIP protects critical system files and processes from modification, even by root.

**Protected areas:**
- `/System` directory
- `/usr` (except `/usr/local`)
- `/bin`, `/sbin`, `/usr/bin`, `/usr/sbin`
- System processes

### Sandbox

Limits applications to only access resources specified in their Sandbox profile.

**Purpose:**
- Restricts application actions to allowed operations
- Ensures apps access only expected resources
- Prevents unauthorized system access

### TCC (Transparency, Consent, and Control)

Manages application permissions for sensitive features.

**Protected features:**
- Location services
- Contacts
- Photos
- Microphone
- Camera
- Accessibility
- Full Disk Access

**Mechanism:** Apps must obtain explicit user consent before accessing these features.

### Launch/Environment Constraints

Regulates process initiation by defining who can launch a process, how, and from where.

**Introduced:** macOS Ventura (extended to third-party apps in Sonoma)

**Constraint types:**
- **Self constraints**: Rules for the process itself
- **Parent constraints**: Rules for the launching process
- **Responsible constraints**: Rules for the responsible process

**Storage:** Trust cache categorizes system binaries into constraint categories.

### MRT (Malware Removal Tool)

Reactive malware removal tool that operates after detection.

**Location:** `/Library/Apple/System/Library/CoreServices/MRT.app`

**Behavior:**
- Runs silently in background
- Activates on system updates or new malware definition downloads
- Removes known malware from infected systems

**Difference from XProtect:**
- XProtect: Preventative (checks files as downloaded)
- MRT: Reactive (removes detected malware)

## Background Task Management (BTM)

macOS alerts users when tools use persistence techniques (Login Items, Daemons, etc.).

### Components

**Daemon:** `/System/Library/PrivateFrameworks/BackgroundTaskManagement.framework/Versions/A/Resources/backgroundtaskmanagementd`

**Agent:** `/System/Library/PrivateFrameworks/BackgroundTaskManagement.framework/Support/BackgroundTaskManagementAgent.app`

**Database:** `/private/var/db/com.apple.backgroundtaskmanagement/BackgroundItems-v4.btm`

**Attributions plist:** `/System/Library/PrivateFrameworks/BackgroundTaskManagement.framework/Versions/A/Resources/attributions.plist`

### Enumeration

**Using sfltool:**
```bash
sfltool dumpbtm
```
Requires user password.

**Using DumpBTM:**
```bash
chmod +x dumpBTM
xattr -rc dumpBTM  # Remove quarantine attribute
./dumpBTM
```
Requires Terminal with Full Disk Access.

### Bypass Techniques

**Event type:** `ES_EVENT_TYPE_NOTIFY_BTM_LAUNCH_ITEM_ADD`

**Bypass methods:**

1. **Reset the database** (requires root):
   ```bash
   sfltool resettbtm
   ```
   Effect: No new persistence alerts until system reboot.

2. **Stop the Agent:**
   ```bash
   # Get PID
   pgrep BackgroundTaskManagementAgent
   
   # Stop it
   kill -SIGSTOP <PID>
   
   # Verify stopped (state shows T)
   ps -o state <PID>
   ```

3. **Process timing bug:** If the process creating persistence exits quickly, the daemon may fail to get information and won't send the alert event.

## Practical Usage

### When to use this skill

- Enumerating macOS security configurations
- Understanding security bypass techniques
- Analyzing persistence mechanisms
- Security assessments on macOS systems
- Privilege escalation research
- Investigating macOS malware behavior

### Important notes

- Always have proper authorization before testing
- Some commands require elevated privileges (root/sudo)
- Some tools require Full Disk Access permissions
- Bypass techniques should only be used in authorized security testing
- System reboots may reset certain configurations

## References

- Apple Deployment Guide: https://support.apple.com/en-gb/guide/deployment/depdca572563/web
- Background Task Management video: https://youtu.be/9hjUmT031tc?t=26481
- DumpBTM tool: https://github.com/objective-see/DumpBTM
