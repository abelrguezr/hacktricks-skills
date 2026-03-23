---
name: macos-bundle-analysis
description: Analyze macOS application bundles for security assessment, code signing verification, and potential exploitation vectors. Use this skill whenever you need to inspect .app bundles, .framework files, or other macOS bundle types for penetration testing, security auditing, or understanding bundle structure. Trigger this when the user mentions macOS apps, bundle inspection, code signing, Info.plist analysis, or any macOS application security task.
---

# macOS Bundle Analysis

A skill for analyzing macOS application bundles, verifying code signatures, and identifying potential security vulnerabilities in bundle structures.

## When to Use This Skill

Use this skill when:
- Inspecting macOS application bundles (.app, .framework, .plugin, .xpc)
- Verifying code signatures on macOS applications
- Analyzing bundle structure for security assessments
- Extracting information from Info.plist files
- Investigating potential bundle-based attack vectors
- Enumerating embedded bundles and frameworks

## Bundle Structure Overview

macOS bundles are container directories that appear as single files in Finder. The standard structure:

```
<application>.app/
├── Contents/
│   ├── _CodeSignature/      # Code signing information
│   ├── MacOS/               # Main executable binary
│   ├── Resources/           # UI resources, images, nib files
│   ├── Frameworks/          # Bundled frameworks (optional)
│   ├── PlugIns/             # Plugins and extensions (optional)
│   ├── XPCServices/         # XPC services (optional)
│   └── Info.plist           # Application configuration
```

## Quick Inspection

### List Bundle Contents

```bash
ls -lR /Applications/<App>.app/Contents
```

### Extract Info.plist Information

```bash
# Get bundle identifier
/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" /Applications/<App>.app/Contents/Info.plist

# Get executable name
/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" /Applications/<App>.app/Contents/Info.plist

# Get minimum system version
/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" /Applications/<App>.app/Contents/Info.plist
```

### Verify Code Signature

```bash
# Deep signature verification
codesign --verify --deep --strict /Applications/<App>.app && echo "Signature OK" || echo "Signature FAILED"

# Check signature details
codesign -dv --verbose=4 /Applications/<App>.app
```

### Analyze Linked Libraries and RPATHs

```bash
# Show rpath entries
otool -l /Applications/<App>.app/Contents/MacOS/<Executable> | grep -A2 RPATH

# Show linked libraries
otool -L /Applications/<App>.app/Contents/MacOS/<Executable>
```

### Enumerate Embedded Bundles

```bash
find /Applications/<App>.app/Contents -name "*.app" -o -name "*.framework" -o -name "*.plugin" -o -name "*.xpc"
```

## Security Assessment Checklist

### Code Signing Verification

1. **Verify signature depth**: Use `codesign --verify --deep --strict`
2. **Check for ad-hoc signing**: Look for `-` in `codesign -dv` output
3. **Inspect entitlements**: `codesign -dv --verbose=4` shows entitlements
4. **Check for library validation**: Look for `com.apple.security.cs.disable-library-validation` in entitlements

### Bundle Identifier Analysis

1. **Extract all bundle IDs**: Check for collisions in embedded bundles
2. **Verify uniqueness**: Multiple targets with same ID can break signature validation
3. **Check for URL scheme hijacking**: Look for `CFBundleURLTypes` in Info.plist

### Resource Security

1. **Check Resources directory**: Look for nib files that could be hijacked
2. **Verify NSMainNibFile**: Check which nib is loaded on startup
3. **Inspect PlugIns directory**: Look for unsigned or weakly signed plugins
4. **Check Frameworks directory**: Look for @rpath vulnerabilities

### RPATH Analysis

1. **List all rpaths**: Use `otool -l | grep -A2 RPATH`
2. **Check for @executable_path**: Indicates relative loading
3. **Check for @rpath**: Indicates runtime path resolution
4. **Identify weak ordering**: Libraries loaded via @rpath may be hijacked

## Common Attack Vectors

### Resource Hijacking (Dirty NIB)

**Applicability**: Pre-Ventura macOS, unquarantined builds

**Steps**:
1. Copy target app to writable location
2. Replace nib files in Contents/Resources/
3. Launch app to execute malicious nib

**Mitigation**: macOS 13+ enforces deep verification on first launch

### Framework/PlugIn Hijacking

**Applicability**: Unsigned or ad-hoc signed bundles, weak LC_RPATH ordering

**Steps**:
1. Drop malicious library in Contents/Frameworks/ or Contents/PlugIns/
2. Modify rpath or load commands with `install_name_tool`
3. Re-sign bundle
4. Launch app

**Mitigation**: Hardened runtime with library validation enabled

### Bundle Identifier Collision

**Applicability**: Multiple embedded targets with same CFBundleIdentifier

**Impact**: Can break signature validation, enable URL-scheme hijacking

**Detection**: Enumerate all embedded bundles and compare IDs

## Using the Helper Scripts

This skill includes helper scripts for common tasks:

- `bundle-inspect.sh` - Quick bundle structure inspection
- `signature-verify.sh` - Comprehensive code signature verification
- `rpath-analyze.sh` - Analyze rpaths and linked libraries
- `info-extract.sh` - Extract and display Info.plist information

Run scripts with:
```bash
./scripts/bundle-inspect.sh /Applications/<App>.app
```

## Important Notes

- **Gatekeeper/App Translocation**: Quarantined bundles run from randomized paths on first launch
- **Ventura+ Changes**: Deep verification on first run, App Management TCC permission required for modifications
- **Hardened Runtime**: Blocks third-party dylibs unless `com.apple.security.cs.disable-library-validation` is present
- **XPC Services**: Often load sibling frameworks - check for persistence vectors

## References

- [Apple Info.plist Key Reference](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Introduction/Introduction.html)
- [Bringing process injection into view(s): exploiting macOS apps using nib files (2024)](https://sector7.computest.nl/post/2024-04-bringing-process-injection-into-view-exploiting-all-macos-apps-using-nib-files/)
- [Dirty NIB & bundle resource tampering write-up (2024)](https://karol-mazurek.medium.com/snake-apple-app-bundle-ext-f5c43a3c84c4)
