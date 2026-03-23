---
name: macos-tcc-analyzer
description: Analyze macOS TCC (Transparency, Consent, and Control) permissions, query TCC databases, and assess TCC-based privilege escalation opportunities. Use this skill whenever the user mentions macOS security, TCC permissions, privacy protections, Full Disk Access, accessibility permissions, automation permissions, or any macOS application permission auditing. Trigger for security assessments, penetration testing, or understanding what permissions apps have on macOS systems.
---

# macOS TCC Analyzer

A skill for analyzing macOS TCC (Transparency, Consent, and Control) permissions, querying TCC databases, and identifying potential privilege escalation vectors.

## What is TCC?

TCC is macOS's security framework that regulates application permissions for sensitive features like:
- Location services
- Contacts, photos, microphone, camera
- Accessibility
- Full Disk Access (FDA)
- Automation (Apple Events)

## Quick Start

### Query User TCC Database

```bash
sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db
sqlite> select service, client, auth_value from access;
```

### Query System TCC Database

```bash
sudo sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db
sqlite> select service, client, auth_value from access;
```

### Check Specific App Permissions

```bash
# Approved permissions for an app
sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db \
  "select service, client, auth_value from access where client LIKE '%telegram%' and auth_value=2;"

# Denied permissions
sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db \
  "select service, client, auth_value from access where client LIKE '%telegram%' and auth_value=0;"
```

## TCC Database Locations

| Database | Path | Protection |
|----------|------|------------|
| User TCC | `~/Library/Application Support/com.apple.TCC/TCC.db` | TCC protected (read/write) |
| System TCC | `/Library/Application Support/com.apple.TCC/TCC.db` | SIP + TCC protected |
| Location Services | `/var/db/locationd/clients.plist` | SIP protected |
| REG.db | `~/Downloads/REG.db` | SIP + TCC protected |
| MDMOverrides | `~/Downloads/MDMOverrides.plist` | SIP + TCC protected |
| AllowApplicationsList | `/Library/Apple/Library/Bundles/TCC_Compatibility.bundle/Contents/Resources/AllowApplicationsList.plist` | SIP protected (readable) |

## Auth Values

| Value | Meaning |
|-------|---------|
| 0 | Denied |
| 1 | Unknown |
| 2 | Allowed |
| 3 | Limited |

## Auth Reasons

| Value | Meaning |
|-------|---------|
| 1 | Error |
| 2 | User Consent |
| 3 | User Set |
| 4 | System Set |
| 5 | Service Policy |
| 6 | MDM Policy |
| 7 | Override Policy |
| 8 | Missing usage string |
| 9 | Prompt Timeout |
| 10 | Preflight Unknown |
| 11 | Entitled |
| 12 | App Type Policy |

## Common TCC Services

| Service | Description |
|---------|-------------|
| `kTCCServiceMicrophone` | Microphone access |
| `kTCCServiceCamera` | Camera access |
| `kTCCServiceAddressBook` | Contacts access |
| `kTCCServiceCalendar` | Calendar access |
| `kTCCServicePhotos` | Photos access |
| `kTCCServiceReminders` | Reminders access |
| `kTCCServiceSystemPolicyAllFiles` | Full Disk Access |
| `kTCCServiceSystemPolicyDesktopFolder` | Desktop folder access |
| `kTCCServiceSystemPolicyDocumentsFolder` | Documents folder access |
| `kTCCServiceSystemPolicyDownloadsFolder` | Downloads folder access |
| `kTCCServiceAppleEvents` | Automation/Apple Events |
| `kTCCServicePostEvent` | Post events |
| `kTCCServiceAccessibility` | Accessibility |
| `kTCCServiceEndpointSecurityClient` | Endpoint Security Client (grants FDA) |
| `kTCCServiceSystemPolicySysAdminFiles` | SysAdmin files |
| `kTCCServiceLocation` | Location services |

## TCC Privilege Escalation Vectors

### 1. Automation + Finder → FDA*

If you have `kTCCServiceAppleEvents` over Finder, you can use AppleScript to make Finder copy TCC databases:

```applescript
osascript<<EOD
tell application "Finder"
    set homeFolder to path to home folder as string
    set sourceFile to (homeFolder & "Library:Application Support:com.apple.TCC:TCC.db") as alias
    set targetFolder to POSIX file "/tmp" as alias
    duplicate file sourceFile to targetFolder with replacing
end tell
EOD
```

### 2. System Events + Accessibility → FDA*

With `kTCCServicePostEvent` + `kTCCServiceAccessibility`, you can send keystrokes to processes:

```applescript
tell application "System Events"
    tell application "Finder" to activate
    keystroke "g" using {command down, shift down}
    delay 1
    keystroke "/tmp"
    delay 1
    keystroke return
end tell
```

### 3. Endpoint Security Client → FDA

Having `kTCCServiceEndpointSecurityClient` grants Full Disk Access immediately.

### 4. SIP Bypass → TCC Bypass

If you can bypass SIP, you can:
- Modify system TCC database
- Modify `AllowApplicationsList.plist` to add your app
- Remove protection from TCC databases

## TCC Signature Checks

TCC stores code signing requirements (`csreq`) to verify the requesting app:

```bash
# Get csreq from database
sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db \
  "select service, client, hex(csreq) from access where auth_value=2;"

# Decode csreq
echo "FADE0C00..." | xxd -r -p > csreq.bin
csreq -t -r csreq.bin

# Create new csreq for an app
REQ_STR=$(codesign -d -r- /Applications/YourApp.app 2>&1 | awk -F ' => ' '/designated/{print $2}')
echo "$REQ_STR" | csreq -r- -b /tmp/csreq.bin
```

## Reset TCC Permissions

```bash
# Reset all permissions for an app
tccutil reset All com.example.app

# Reset all permissions for all apps
tccutil reset All
```

## User Intent / com.apple.macl

Files can have extended attributes granting specific app access:

```bash
# Check file's macl attribute
xattr filename

# Read macl details
macl_read filename

# Get app UUID
otool -l /Applications/YourApp.app/Contents/MacOS/YourApp | grep uuid
```

## Helper Scripts

Use the bundled scripts for common tasks:

- `query-tcc-database.sh` - Query TCC databases with filters
- `check-app-permissions.sh` - Check all permissions for a specific app
- `generate-tcc-report.sh` - Generate comprehensive TCC permission report
- `extract-csreq.sh` - Extract and decode csreq from TCC database

## Security Considerations

1. **TCC databases are protected** - User database requires TCC privileges to read/write, system database requires SIP bypass
2. **Signature verification** - Apps must match stored csreq to use granted permissions
3. **Entitlements matter** - Apps need proper entitlements to request certain permissions
4. **Responsible process** - TCC tracks the GUI app responsible, not just the requesting process
5. **Finder always has FDA** - But you can't execute arbitrary code through it

## References

- [macOS TCC DB Deep Dive](https://www.rainforestqa.com/blog/macos-tcc-db-deep-dive)
- [Track and Tackle com.apple.macl](https://www.brunerd.com/blog/2020/01/07/track-and-tackle-com-apple-macl/)
- [Bypassing macOS TCC](https://www.sentinelone.com/labs/bypassing-macos-tcc-user-privacy-protections-by-accident-and-design/)
- [newosxbook.com entitlements](https://newosxbook.com/ent.php)
