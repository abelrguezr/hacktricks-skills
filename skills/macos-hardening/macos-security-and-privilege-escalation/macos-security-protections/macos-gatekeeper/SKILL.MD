---
name: macos-gatekeeper-analysis
description: Analyze macOS Gatekeeper security mechanisms, check application signatures and notarization status, examine quarantine attributes, and assess Gatekeeper bypass vulnerabilities. Use this skill whenever the user needs to audit macOS application security, investigate blocked applications, analyze code signatures, check quarantine extended attributes, understand Gatekeeper behavior, or assess macOS security posture. Trigger for any macOS security analysis involving Gatekeeper, spctl, codesign, quarantine attributes, or XProtect.
---

# macOS Gatekeeper Security Analysis

A comprehensive skill for analyzing macOS Gatekeeper security mechanisms, application signatures, quarantine attributes, and potential bypass vectors.

## When to Use This Skill

Use this skill when you need to:
- Check if an application is properly signed and notarized
- Investigate why an application is blocked by Gatekeeper
- Analyze quarantine extended attributes on files
- Audit macOS security posture
- Research Gatekeeper bypass techniques for security testing
- Understand XProtect and system policy enforcement
- Prepare security assessments for macOS environments

## Core Concepts

### Gatekeeper Overview

Gatekeeper is macOS's primary application security gate. It validates software from sources outside the App Store by:
1. **Verifying code signatures** - Ensuring the app is signed by a recognized developer
2. **Checking notarization** - Confirming Apple has scanned the app for malware
3. **Prompting user approval** - Asking users to approve first-time execution of downloaded apps

**Key insight**: Gatekeeper only checks files with the `com.apple.quarantine` extended attribute. Files without this attribute bypass Gatekeeper entirely.

### Application Signatures

Code signatures verify:
- **Developer identity** - Who signed the application
- **Code integrity** - Whether the app has been modified since signing
- **Notarization status** - Whether Apple has approved the app

### Quarantine Attributes

The `com.apple.quarantine` extended attribute marks files downloaded from untrusted sources. Gatekeeper only performs security checks on quarantined files.

## Quick Reference Commands

### Check Application Signature

```bash
# Get signer information
codesign -vv -d /path/to/app 2>&1 | grep -E "Authority|TeamIdentifier"

# Verify signature integrity
codesign --verify --verbose /path/to/app

# Check if signature is valid (Gatekeeper assessment)
spctl --assess --verbose /path/to/app

# Get entitlements from binary
codesign -d --entitlements :- /path/to/app
```

### Check Quarantine Status

```bash
# List extended attributes on a file
xattr /path/to/file

# View quarantine attribute value
xattr -l /path/to/file | grep -A 5 "com.apple.quarantine"

# Remove quarantine attribute (requires sudo)
sudo xattr -d com.apple.quarantine /path/to/file

# Find all quarantined files in directory
find /path/to/dir -exec xattr -l {} \; 2>/dev/null | grep -B 1 "com.apple.quarantine"
```

### Gatekeeper Status

```bash
# Check Gatekeeper status
spctl --status

# Assess if an app will be allowed
spctl --assess -v /path/to/app

# List Gatekeeper rules (macOS 14 and earlier)
spctl --list
```

### XProtect Information

```bash
# Check XProtect version
system_profiler SPInstallHistoryDataType 2>/dev/null | grep -A 4 "XProtectPlistConfigData" | tail -n 5

# View XProtect logs
log show --last 2h --predicate 'subsystem == "com.apple.XProtectFramework" || category CONTAINS "XProtect"' --style syslog

# View Gatekeeper/provenance events
log stream --style syslog --predicate 'process == "syspolicyd"'
```

## Detailed Analysis Procedures

### Procedure 1: Full Application Security Audit

When auditing an application, follow this sequence:

1. **Check basic signature**
   ```bash
   codesign --verify --verbose /path/to/app
   ```

2. **Get detailed signer info**
   ```bash
   codesign -vv -d /path/to/app 2>&1 | grep -E "Authority|TeamIdentifier|Identifier"
   ```

3. **Check Gatekeeper assessment**
   ```bash
   spctl --assess -v /path/to/app
   ```

4. **Examine quarantine status**
   ```bash
   xattr -l /path/to/app 2>/dev/null | grep -A 5 "com.apple.quarantine"
   ```

5. **Check provenance (macOS Ventura+)**
   ```bash
   xattr -p com.apple.provenance /path/to/app 2>/dev/null | hexdump -C
   ```

6. **Review entitlements**
   ```bash
   codesign -d --entitlements :- /path/to/app
   ```

### Procedure 2: Investigate Blocked Application

When an application is blocked by Gatekeeper:

1. **Confirm the block**
   ```bash
   spctl --assess -v /path/to/app
   ```

2. **Check signature validity**
   ```bash
   codesign --verify --verbose /path/to/app
   ```

3. **Examine quarantine attribute**
   ```bash
   xattr -l /path/to/app
   ```

4. **Check for notarization**
   ```bash
   codesign -dv --verbose /path/to/app | grep -i "notarized"
   ```

5. **Review system logs**
   ```bash
   log show --last 1h --predicate 'process == "syspolicyd" && eventMessage CONTAINS[cd] "GK scan"' --style syslog
   ```

### Procedure 3: Quarantine Attribute Analysis

To understand quarantine behavior:

1. **Check if file is quarantined**
   ```bash
   xattr /path/to/file | grep "com.apple.quarantine"
   ```

2. **Parse quarantine metadata**
   ```bash
   xattr -p com.apple.quarantine /path/to/file | xxd
   ```
   The quarantine attribute contains:
   - Flags (e.g., `0x0040` = user approved)
   - Timestamp
   - Downloading application name
   - Unique identifier

3. **Find all quarantined files**
   ```bash
   find /path/to/search -type f -exec xattr -l {} \; 2>/dev/null | grep -B 1 "com.apple.quarantine"
   ```

4. **Remove quarantine (for testing)**
   ```bash
   sudo xattr -d com.apple.quarantine /path/to/file
   ```

### Procedure 4: System Policy Database Analysis

For advanced analysis of Gatekeeper rules:

```bash
# Open the SystemPolicy database (requires root)
sqlite3 /var/db/SystemPolicy

# View allowed authority rules
SELECT requirement,allow,disabled,label FROM authority WHERE label != 'GKE' AND disabled=0;

# View GKE (Gatekeeper) hash rules
SELECT requirement,allow,disabled,label FROM authority WHERE label = 'GKE' LIMIT 10;

# Exit
.quit
```

## Security Considerations

### macOS Version Differences

**macOS 15 (Sequoia) and later:**
- `spctl --master-disable` and `spctl --global-disable` are no longer accepted
- Gatekeeper policy is configured via System Settings or MDM profiles
- The Finder "Ctrl+Open" bypass has been removed
- Users must allow blocked apps via System Settings → Privacy & Security

**macOS 14 (Sonoma) and earlier:**
- `spctl` can modify Gatekeeper configuration
- Traditional bypass methods may still apply

### Known Bypass Vectors (Historical)

Be aware of these CVEs when assessing security:

| CVE | Description | Fixed In |
|-----|-------------|----------|
| CVE-2021-1810 | Archive Utility path length bypass | macOS 11.4 |
| CVE-2021-30990 | Automator symlink bypass | macOS 11.4 |
| CVE-2022-22616 | Safari ZIP quarantine bypass | macOS 12.3 |
| CVE-2022-32910 | Archive Utility AAR bypass | macOS 12.3 |
| CVE-2022-42821 | AppleDouble ACL bypass | macOS 12.6 |
| CVE-2023-27943 | Chrome quarantine bypass | macOS 13.2 |
| CVE-2023-27951 | AppleDouble hidden file bypass | macOS 13.2 |
| CVE-2023-41067 | Crafted app bypass | macOS 14.0 |
| CVE-2024-27853 | libarchive ZIP handling | macOS 14.4 |
| CVE-2024-44128 | Automator Quick Action bypass | macOS 13.7/14.7/15 |

### Best Practices

1. **Always verify signatures** before trusting applications
2. **Check quarantine attributes** on downloaded files
3. **Keep macOS updated** to patch known bypasses
4. **Use MDM profiles** for enterprise Gatekeeper management
5. **Monitor syspolicyd logs** for security events
6. **Test in isolated environments** when researching bypasses

## Common Use Cases

### Use Case 1: Enterprise Security Audit

```bash
# Audit all applications in /Applications
for app in /Applications/*.app; do
  echo "=== $app ==="
  codesign --verify --verbose "$app" 2>&1 | head -5
  spctl --assess -v "$app" 2>&1
  echo ""
done
```

### Use Case 2: Investigate Suspicious Application

```bash
# Full investigation of a suspicious app
APP_PATH="/path/to/suspicious.app"

echo "=== Signature Check ==="
codesign -vv -d "$APP_PATH" 2>&1 | grep -E "Authority|TeamIdentifier|Identifier"

echo "=== Gatekeeper Assessment ==="
spctl --assess -v "$APP_PATH"

echo "=== Quarantine Status ==="
xattr -l "$APP_PATH" 2>/dev/null | grep -A 5 "com.apple.quarantine"

echo "=== Entitlements ==="
codesign -d --entitlements :- "$APP_PATH"

echo "=== Recent Gatekeeper Events ==="
log show --last 1h --predicate 'process == "syspolicyd" && eventMessage CONTAINS[cd] "GK scan"' --style syslog | head -20
```

### Use Case 3: Remove Quarantine for Testing

```bash
# Remove quarantine from all files in a directory
find /path/to/dir -type f -exec xattr -d com.apple.quarantine {} \; 2>/dev/null

# Verify removal
find /path/to/dir -type f -exec xattr -l {} \; 2>/dev/null | grep -c "com.apple.quarantine"
```

## Troubleshooting

### "source=no usable signature"

This means the application is not signed or the signature is invalid. Check:
```bash
codesign --verify --verbose /path/to/app
codesign -dv --verbose /path/to/app
```

### "source=not accepted" 

The app is signed but not notarized or from an unidentified developer. Check:
```bash
spctl --assess -v /path/to/app
codesign -dv --verbose /path/to/app | grep -i "notarized"
```

### Quarantine Attribute Not Present

If a downloaded file lacks the quarantine attribute:
- It may have been downloaded via a client that doesn't set it (e.g., some torrent clients)
- It may have been extracted from an archive with a bypass vulnerability
- The attribute may have been manually removed

### spctl Commands Not Working (macOS 15+)

On macOS Sequoia and later, `spctl` is read-only for policy changes. Use:
- System Settings → Privacy & Security for user-level changes
- MDM profiles with `com.apple.systempolicy.control` payload for enterprise management

## References

- [Apple Platform Security Documentation](https://developer.apple.com/security/)
- [macOS Gatekeeper Technical Note](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/Introduction/Introduction.html)
- [Apple Security Updates](https://support.apple.com/en-us/HT214084)
- [Eclectic Light: macOS Provenance Tracking](https://eclecticlight.co/2023/05/10/how-macos-now-tracks-the-provenance-of-apps/)

## Scripts

For automated analysis, use the bundled scripts:

- `scripts/check-signature.sh` - Comprehensive signature and notarization check
- `scripts/analyze-quarantine.sh` - Quarantine attribute analysis
- `scripts/gatekeeper-audit.sh` - Full Gatekeeper security audit

Run with `./scripts/<script-name>.sh <path-to-app>` for detailed analysis.
