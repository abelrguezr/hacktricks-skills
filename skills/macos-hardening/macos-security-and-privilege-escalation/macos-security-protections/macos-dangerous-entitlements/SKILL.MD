---
name: macos-entitlements-analyzer
description: Analyze macOS application entitlements for security implications, privilege escalation paths, and dangerous permissions. Use this skill whenever the user needs to audit macOS binaries for entitlements, assess security risks of entitlements, understand what specific entitlements allow, or identify privilege escalation opportunities through entitlement abuse. Trigger on any mention of macOS entitlements, code signing, TCC permissions, SIP bypass, or binary security analysis.
---

# macOS Entitlements Analyzer

A skill for analyzing macOS application entitlements and their security implications.

## When to Use This Skill

Use this skill when:
- Analyzing macOS binaries for dangerous entitlements
- Assessing security risks of code-signed applications
- Investigating privilege escalation paths through entitlements
- Understanding what specific entitlements allow an application to do
- Auditing applications for TCC (TCC database) access
- Checking for SIP (System Integrity Protection) bypass capabilities
- Reviewing entitlements in the context of macOS security research

## Quick Reference: Entitlement Severity

### 🔴 High Severity (Critical Security Impact)

| Entitlement | Impact |
|-------------|--------|
| `com.apple.rootless.install.heritable` | Bypass SIP |
| `com.apple.rootless.install` | Bypass SIP |
| `com.apple.system-task-ports` | Get task port for any process (except kernel) |
| `com.apple.security.get-task-allow` | Allow code injection via debugger |
| `com.apple.security.cs.debugger` | Call task_for_pid() on apps with get-task-allow |
| `com.apple.security.cs.disable-library-validation` | Load unsigned frameworks/libraries |
| `com.apple.private.security.clear-library-validation` | Disable library validation via csops |
| `com.apple.security.cs.allow-dyld-environment-variables` | Use DYLD injection variables |
| `com.apple.private.tcc.manager` | Modify TCC database |
| `system.install.apple-software` | Install software without user permission |
| `com.apple.private.security.kext-management` | Load kernel extensions |
| `com.apple.private.icloud-account-access` | Access iCloud tokens |
| `kTCCServiceSystemPolicyAllFiles` | Full Disk Access |
| `kTCCServiceAppleEvents` | Automate/abuse other applications |
| `kTCCServiceAccessibility` | Control UI, approve dialogs |

### 🟡 Medium Severity (Significant Security Impact)

| Entitlement | Impact |
|-------------|--------|
| `com.apple.security.cs.allow-jit` | Create writable+executable memory |
| `com.apple.security.cs.allow-unsigned-executable-memory` | Patch C code, use deprecated APIs |
| `com.apple.security.cs.disable-executable-page-protection` | Modify own executable on disk |
| `com.apple.private.nullfs_allow` | Mount nullfs filesystem |
| `kTCCServiceAll` | Request all TCC permissions |

## How to Extract Entitlements

### From a Code-Signed Binary

```bash
# Extract entitlements from a binary
codesign -d --entitlements :- /path/to/binary > entitlements.xml

# Or for an app bundle
codesign -d --entitlements :- /path/to/App.app/Contents/MacOS/Executable > entitlements.xml
```

### Parse Entitlements Programmatically

Use the `extract_entitlements.sh` script (see scripts/) to:
- Extract entitlements from a binary
- Check against known dangerous entitlements
- Generate a risk assessment

## Analysis Workflow

### Step 1: Extract Entitlements

```bash
# Run the extraction script
./scripts/extract_entitlements.sh /path/to/binary
```

### Step 2: Review High-Risk Entitlements

Check for these critical entitlements first:

1. **SIP Bypass**: `com.apple.rootless.install*`
2. **Process Injection**: `com.apple.system-task-ports`, `com.apple.security.get-task-allow`
3. **TCC Manipulation**: `com.apple.private.tcc.manager`, `kTCCService*`
4. **Library Loading**: `com.apple.security.cs.disable-library-validation`
5. **Full Disk Access**: `kTCCServiceSystemPolicyAllFiles`

### Step 3: Assess Privilege Escalation Paths

| Entitlement | Escalation Path |
|-------------|----------------|
| `system.install.apple-software` | Install malicious software silently |
| `com.apple.private.security.kext-management` | Load malicious kernel extension |
| `kTCCServiceSystemPolicySysAdminFiles` | Bypass TCC by changing home directory |
| `kTCCServiceAppleEvents` | Abuse other apps' permissions |
| `kTCCServiceAccessibility` | Approve security dialogs programmatically |

### Step 4: Check for Combined Risks

Some entitlement combinations are especially dangerous:

- **`com.apple.security.cs.debugger` + `com.apple.security.get-task-allow`**: Full code injection capability
- **`kTCCServiceAccessibility` + `kTCCServiceAppleEvents`**: Complete UI automation and app control
- **`com.apple.security.cs.disable-library-validation` + `com.apple.security.cs.allow-dyld-environment-variables`**: Multiple code injection vectors

## Common Use Cases

### Case 1: Auditing a Suspicious Application

```bash
# Extract and analyze
codesign -d --entitlements :- /Applications/SuspiciousApp.app/Contents/MacOS/SuspiciousApp > /tmp/entitlements.xml
./scripts/extract_entitlements.sh /Applications/SuspiciousApp.app/Contents/MacOS/SuspiciousApp
```

### Case 2: Checking for iCloud Token Access

Look for `com.apple.private.icloud-account-access` - this allows communication with iCloudHelper XPC service to obtain iCloud tokens. Known to be present in iMovie and GarageBand.

### Case 3: TCC Database Manipulation

Check for:
- `com.apple.private.tcc.manager`
- `com.apple.rootless.storage.TCC`
- `kTCCServiceEndpointSecurityClient`

These allow modification of the TCC database, which controls privacy permissions.

## Important Notes

### Apple-Only Entitlements

Entitlements starting with `com.apple` are typically reserved for Apple. However:
- Enterprise certificates can create custom `com.apple.*` entitlements
- This can bypass protections that check for Apple-signed binaries

### TCC Services

TCC (Transparency, Consent, and Control) services control privacy permissions:

| Service | Permission |
|---------|------------|
| `kTCCServiceSystemPolicyAllFiles` | Full Disk Access |
| `kTCCServiceAppleEvents` | Automate other apps |
| `kTCCServiceAccessibility` | Accessibility/Screen Control |
| `kTCCServiceEndpointSecurityClient` | Write TCC database |
| `kTCCServiceSystemPolicySysAdminFiles` | Change NFS home directory |
| `kTCCServiceSystemPolicyAppBundles` | Modify app bundle contents |

### Trustcache/CDhash Bypass

Some entitlements can bypass Trustcache/CDhash protections that prevent execution of downgraded Apple binaries. Research ongoing.

## Example Analysis Output

```
=== Entitlement Analysis ===
Binary: /Applications/Example.app/Contents/MacOS/Example

🔴 HIGH RISK ENTITLEMENTS FOUND:
- com.apple.security.get-task-allow: Allows code injection
- kTCCServiceAccessibility: Can control UI and approve dialogs

🟡 MEDIUM RISK ENTITLEMENTS:
- com.apple.security.cs.allow-jit: Writable+executable memory

✅ No critical SIP bypass entitlements
✅ No TCC database modification entitlements

RECOMMENDATION: Review code injection capabilities and accessibility permissions
```

## Scripts Available

- `scripts/extract_entitlements.sh` - Extract and analyze entitlements from a binary
- `scripts/check_dangerous_entitlements.sh` - Check for known dangerous entitlements

## References

- [Apple Entitlements Documentation](https://developer.apple.com/documentation/bundleresources/entitlements)
- [Objective-See TCC Research](https://objective-see.org/blog/blog_0x4C.html)
- [Wojciech Regula TCC Bypass](https://wojciechregula.blog/post/play-the-music-and-bypass-tcc-aka-cve-2020-29621/)
- [The Evil Bit - clear-library-validation](https://theevilbit.github.io/posts/com.apple.private.security.clear-library-validation/)
- [JHFTSS - APFS Snapshot Research](https://jhftss.github.io/The-Nightmare-of-Apple-OTA-Update/)
