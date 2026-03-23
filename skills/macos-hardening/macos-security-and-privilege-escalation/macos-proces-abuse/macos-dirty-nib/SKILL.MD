---
name: macos-dirty-nib-analysis
description: Analyze macOS app bundles for Dirty NIB attack surface, enumerate nib-driven apps, validate code signatures, and assess defensive posture. Use this skill whenever the user mentions macOS security research, app bundle auditing, privilege escalation analysis, nib file analysis, or macOS hardening. Also trigger for macOS 13+ protection assessments, TCC permission audits, or when investigating potential nib-based injection vectors.
---

# macOS Dirty NIB Analysis

A skill for analyzing macOS app bundles for Dirty NIB attack surface, enumerating vulnerable targets, and assessing defensive posture.

## What is Dirty NIB

Dirty NIB is a technique that abuses Interface Builder files (`.xib`/`.nib`) inside signed macOS app bundles to execute attacker-controlled logic inside the target process, inheriting its entitlements and TCC permissions.

**Key timeline:**
- **Pre-macOS 13 (Ventura):** Replacing a bundle's `MainMenu.nib` could reliably achieve process injection and privilege escalation
- **macOS 13+ (Ventura/Sonoma/Sequoia):** First-launch deep verification, bundle protection, Launch Constraints, and TCC "App Management" permission largely prevent post-launch nib tampering by unrelated apps

## When to use this skill

Use this skill when:
- Auditing macOS app bundles for security research
- Enumerating nib-driven applications on a system
- Validating code signatures after bundle modifications
- Assessing macOS hardening posture
- Investigating potential nib-based injection vectors
- Understanding macOS 13+ protection mechanisms
- Auditing TCC "App Management" or Full Disk Access permissions

## Core workflows

### 1. Enumerate nib-driven apps on the system

Find applications that load UI from nib files at startup:

```bash
./scripts/enumerate_nib_targets.sh
```

This scans `/Applications` for apps with `NSMainNibFile` in their `Info.plist`.

### 2. Find nib resources in a specific bundle

Locate all `.nib` and `.xib` files within a target app:

```bash
./scripts/find_nib_resources.sh /path/to/target.app
```

### 3. Validate code signatures

Check if an app bundle has been tampered with:

```bash
./scripts/verify_codesign.sh /path/to/target.app
```

This runs `codesign --verify --deep --strict --verbose=4` to detect resource modifications.

## Understanding the attack surface

### How Dirty NIB works (pre-Ventura)

1. **Create malicious .xib** with gadget classes like `NSAppleScript` or `NSTask`
2. **Use Cocoa Bindings** to auto-trigger method calls without user interaction
3. **Replace the app's nib** (e.g., `Contents/Resources/MainMenu.nib`)
4. **Launch the app** - malicious code executes in the target process context

### Modern macOS protections (Ventura+)

| Protection | Impact |
|------------|--------|
| First-launch deep verification | All bundle resources checked on first run |
| Bundle protection | Only same-developer apps or those with App Management can modify |
| Launch Constraints | System/Apple apps can't be copied and launched from non-default locations |
| TCC App Management | Required to write into another app's bundle |
| Python.framework removal (12.3+) | Breaks some privilege-escalation chains |

### Practical implications

- **Third-party apps:** Generally cannot modify without App Management or same Team ID
- **Developer tooling:** Can modify own apps (same developer signature)
- **Terminals with Full Disk Access:** Effectively re-open the attack surface
- **Apple system apps:** Protected by Launch Constraints on macOS 13+

## Detection and monitoring

### File integrity monitoring

Watch for changes to bundle resources:

```bash
# Monitor nib file modifications
find /Applications -name "*.nib" -exec stat -f "%Sm %N" {} \; | sort -k1 -r
```

### Unified logs monitoring

Detect unexpected AppleScript execution in GUI apps:

```bash
log stream --info --predicate '
  processImagePath CONTAINS[cd] ".app/Contents/MacOS/" AND 
  (eventMessage CONTAINS[cd] "AppleScript" OR 
   eventMessage CONTAINS[cd] "loadAppleScriptObjectiveCScripts")'
```

### TCC permission audit

Check which processes have App Management or Full Disk Access:

```bash
# List processes with Full Disk Access
tsql -database /Library/Application\ Support/com.apple.TCC/TCC.db -query "SELECT service, client, authorized FROM access WHERE service = 'kTCCServiceSystemPolicyAllFiles'"

# List processes with App Management
tsql -database /Library/Application\ Support/com.apple.TCC/TCC.db -query "SELECT service, client, authorized FROM access WHERE service = 'kTCCServiceAppManagement'"
```

## Defensive hardening recommendations

### For developers

1. **Limit nib instantiation** - Prefer programmatic UI or restrict what's loaded from nibs
2. **Avoid powerful classes in nibs** - Don't include `NSTask` or similar in nib graphs
3. **Avoid dangerous bindings** - Don't use bindings that invoke selectors on arbitrary objects
4. **Adopt hardened runtime** - Use Library Validation (standard for modern apps)
5. **Self-heal bundle resources** - Make update mechanisms verify and restore bundle integrity
6. **Don't request broad App Management** - Segregate MDM contexts from user-driven shells

### For defenders

1. **Monitor bundle resources** - File integrity monitoring on `Contents/Resources/*.nib`
2. **Audit TCC permissions** - Regularly review App Management and Full Disk Access grants
3. **Remove permissions from general shells** - Don't grant Full Disk Access to general-purpose terminals
4. **Periodic signature verification** - Run `codesign --verify --deep` on critical apps
5. **Monitor for AppleScript in GUI apps** - Alert on unexpected scripting framework usage

## Test cases

### Test 1: Enumerate nib-driven apps

**Prompt:** "Find all applications in /Applications that use nib files for their UI"

**Expected output:** List of apps with their `NSMainNibFile` values

### Test 2: Validate a modified bundle

**Prompt:** "Check if /Applications/SomeApp.app has been tampered with"

**Expected output:** Code signature verification result (pass/fail with details)

### Test 3: Assess macOS protection status

**Prompt:** "What Dirty NIB protections are active on macOS 14 Sonoma?"

**Expected output:** Summary of Ventura+ protections and their impact

## References

- xpn – DirtyNIB (original write-up): https://blog.xpnsec.com/dirtynib/
- Sector7 – Bringing process injection into view(s): https://sector7.computest.nl/post/2024-04-bringing-process-injection-into-view-exploiting-all-macos-apps-using-nib-files/
- macOS Gatekeeper and quarantine: See related macOS security documentation

## Notes

- This skill is for **defensive research and auditing** only
- Modern macOS (13+) has significantly reduced Dirty NIB viability
- Always verify you have authorization before auditing app bundles
- Bundle protection means most attacks require App Management or same-developer signature
