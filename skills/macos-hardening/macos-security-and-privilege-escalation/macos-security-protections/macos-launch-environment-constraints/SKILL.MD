---
name: macos-launch-constraints
description: macOS security analysis for launch constraints, trust caches, and binary execution restrictions. Use this skill whenever the user asks about macOS security mechanisms, launch constraints, trust cache enumeration, AMFI (Apple Mobile File Integrity), binary execution policies, environment constraints on apps, or analyzing which binaries are constrained vs unconstrained. Also trigger for questions about macOS privilege escalation, system binary security, XPC service protection, or when investigating why a binary won't execute on macOS.
---

# macOS Launch Constraints & Trust Cache Analysis

This skill helps analyze macOS security mechanisms including launch constraints, trust caches, and binary execution restrictions introduced in macOS Ventura and enhanced in Sonoma.

## What This Skill Does

- Explains launch constraint categories and how they work
- Provides commands to enumerate and parse trust cache files
- Analyzes environment constraints on third-party applications
- Identifies unconstrained binaries (LC category 0) that may be security risks
- Explains attack mitigations and limitations of launch constraints

## Quick Reference

### Launch Constraint Types

| Type | Description |
|------|-------------|
| **Self Constraints** | Rules the running binary must satisfy |
| **Parent Process** | Rules the parent process must satisfy (e.g., `launchd`) |
| **Responsible Constraints** | Rules for the process calling via XPC |
| **Library Load** | Rules for which code can be loaded as libraries |

### Trust Cache Locations

```bash
# macOS Trust Cache Files
/System/Volumes/Preboot/*/boot/*/usr/standalone/firmware/FUD/BaseSystemTrustCache.img4
/System/Volumes/Preboot/*/boot/*/usr/standalone/firmware/FUD/StaticTrustCache.img4
/System/Library/Security/OSLaunchPolicyData
```

### Key Commands

```bash
# Check environment constraints on an app
codesign -d -vvvv /path/to/app.app

# Extract IMG4 payload (requires pyimg4)
pyimg4 img4 extract -i file.img4 -p file.im4p
pyimg4 im4p extract -i file.im4p -o file.data

# Parse trust cache (requires trustcache tool)
trustcache info /path/to/cache.data
```

## Workflow: Enumerate Trust Caches

### Step 1: Extract Trust Cache Files

```bash
# Copy trust cache files to working directory
cp /System/Volumes/Preboot/*/boot/*/usr/standalone/firmware/FUD/BaseSystemTrustCache.img4 /tmp/
cp /System/Volumes/Preboot/*/boot/*/usr/standalone/firmware/FUD/StaticTrustCache.img4 /tmp/
cp /System/Library/Security/OSLaunchPolicyData /tmp/
```

### Step 2: Extract IMG4 Payloads

```bash
# Install pyimg4 if needed
python3 -m pip install pyimg4

# Extract payloads
pyimg4 img4 extract -i /tmp/BaseSystemTrustCache.img4 -p /tmp/BaseSystemTrustCache.im4p
pyimg4 im4p extract -i /tmp/BaseSystemTrustCache.im4p -o /tmp/BaseSystemTrustCache.data

pyimg4 img4 extract -i /tmp/StaticTrustCache.img4 -p /tmp/StaticTrustCache.im4p
pyimg4 im4p extract -i /tmp/StaticTrustCache.im4p -o /tmp/StaticTrustCache.data

pyimg4 im4p extract -i /tmp/OSLaunchPolicyData -o /tmp/OSLaunchPolicyData.data
```

### Step 3: Parse Trust Cache Data

```bash
# Install trustcache tool
wget https://github.com/CRKatri/trustcache/releases/download/v2.0/trustcache_macos_arm64
sudo mv ./trustcache_macos_arm64 /usr/local/bin/trustcache
xattr -rc /usr/local/bin/trustcache
chmod +x /usr/local/bin/trustcache

# View cache information
trustcache info /tmp/OSLaunchPolicyData.data | head
```

### Step 4: Analyze Results

The trust cache output format:
```
<cdhash> <hash_type> <flags> <constraint_category>
```

- **Constraint Category 0**: Unconstrained (potential security risk)
- **Constraint Category 1+**: Various levels of restriction

Use the script `scripts/find_unconstrained.py` to identify binaries with LC category 0.

## Understanding Launch Constraint Categories

### Category Structure

Each category defines:
- **Self Constraint**: What the binary itself must satisfy
- **Parent Constraint**: What the parent process must be
- **Responsible Constraint**: What the XPC caller must be

### Example: Category 1

```
Self Constraint: (on-authorized-authapfs-volume || on-system-volume) && launch-type == 1 && validation-category == 1
Parent Constraint: is-init-proc
```

Meaning:
- Binary must be on System or Cryptexes volume
- Must be a system service (LaunchDaemons plist)
- Must be an OS executable
- Parent must be `launchd`

### Common Facts Used in Constraints

| Fact | Description |
|------|-------------|
| `is-init-proc` | Must be `launchd` (init process) |
| `is-sip-protected` | Protected by System Integrity Protection |
| `on-authorized-authapfs-volume` | Loaded from authorized APFS volume |
| `on-system-volume` | Loaded from booted system volume |
| `launch-type` | Type of launch (1 = system service) |
| `validation-category` | OS executable category |

## Security Analysis

### What Launch Constraints Mitigate

- ✅ Execution from unexpected locations
- ✅ Execution by unexpected parent processes
- ✅ Downgrade attacks
- ✅ Unauthorized binary loading

### What They DON'T Mitigate

- ❌ Common XPC abuses (connecting to active services)
- ❌ Electron code injections
- ❌ dylib injections without library validation

### XPC Service Protection (Sonoma+)

In macOS Sonoma, XPC services are responsible for themselves rather than the connecting client. This means:

- **Cannot launch** XPC service via attacker code (if properly constrained)
- **Can connect** to already-running XPC services

**Recommendation**: Validate connecting clients at the application level.

### Electron App Protection

Even with parent constraints requiring LaunchServices, attackers can:
- Use `open` command (can set environment variables)
- Use Launch Services API (can indicate environment variables)

## Environment Constraints for Third-Party Apps

Developers can define environment constraints in:
- `launchd` property list files
- Separate property list files used in code signing

### Check App Constraints

```bash
codesign -d -vvvv /Applications/YourApp.app
```

Look for `Launch Constraints` section in output.

## Tools & Resources

### Required Tools

| Tool | Purpose | Installation |
|------|---------|-------------|
| `pyimg4` | Extract IMG4/IM4P payloads | `pip install pyimg4` |
| `trustcache` | Parse trust cache data | Download from GitHub releases |
| `codesign` | Check app constraints | Built into macOS |

### Reference Links

- [Launch Constraints Deep Dive](https://theevilbit.github.io/posts/launch_constraints_deep_dive/)
- [iOS 16 LC Categories (Reversed)](https://gist.github.com/LinusHenze/4cd5d7ef057a144cda7234e2c247c056)
- [macOS 14 LC Categories (Sonoma)](https://gist.github.com/theevilbit/a6fef1e0397425a334d064f7b6e1be53)
- [Apple Developer Documentation](https://developer.apple.com/documentation/security/defining_launch_environment_and_library_constraints)
- [WWDC 2023 Session 10266](https://developer.apple.com/videos/play/wwdc2023/10266/)

## Common Tasks

### Task 1: Find Unconstrained Binaries

```bash
# Run the helper script
python3 scripts/find_unconstrained.py /tmp/OSLaunchPolicyData.data
```

This identifies binaries with LC category 0 that aren't protected by launch constraints.

### Task 2: Check Specific Binary's Constraints

```bash
# Get the binary's hash
codesign -dv --verbose=4 /path/to/binary

# Search trust cache for that hash
trustcache info /tmp/OSLaunchPolicyData.data | grep <hash>
```

### Task 3: Analyze App's Environment Constraints

```bash
codesign -d -vvvv /Applications/YourApp.app | grep -A 20 "Launch Constraints"
```

## Troubleshooting

### Binary Won't Execute

If an Apple-signed binary refuses to run on Apple Silicon:
1. Check if it's in the trust cache
2. Verify the trust cache hasn't been corrupted
3. Check for SIP violations
4. Verify the binary's code signature

### Trust Cache Extraction Fails

- Ensure you have root access (`sudo`)
- Verify the IMG4 files exist at expected paths
- Check that `pyimg4` is installed and working
- Try alternative tool: `img4tool` from tihmstar

### Permission Denied on Trust Cache Files

```bash
# Copy to /tmp first (writable)
cp /System/Library/Security/OSLaunchPolicyData /tmp/
# Then work with the copy
```

## Next Steps

After analyzing trust caches:
1. Identify unconstrained binaries (LC category 0)
2. Cross-reference with known binaries to find gaps
3. Check if any user-installed apps have environment constraints
4. Review XPC services for proper client validation
5. Consider library load constraints for sensitive operations
