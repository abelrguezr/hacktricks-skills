---
name: ios-entitlements-extractor
description: Extract entitlements and mobile provision files from iOS app binaries (IPA files, compiled apps, or jailbroken device binaries). Use this skill whenever the user needs to analyze iOS app permissions, review embedded entitlements, extract plist data from compiled binaries, or perform iOS security testing. Trigger for any request involving iOS app binary analysis, entitlement extraction, mobile provision file recovery, or MASVS-PLATFORM security testing.
---

# iOS Entitlements Extractor

Extract entitlements and mobile provision files from compiled iOS application binaries, even when direct file access isn't available.

## When to Use This Skill

Use this skill when:
- You need to extract `.entitlements` files from an iOS app binary
- You're analyzing an IPA file or installed app on a jailbroken device
- You're performing iOS security testing (MASVS-PLATFORM compliance)
- You need to review embedded permissions in a compiled app
- The entitlements file isn't directly accessible and must be extracted from the binary

## Prerequisites

- Access to the app binary (from IPA, jailbroken device, or decrypted binary)
- One of the following tools installed:
  - `binwalk` (recommended for XML extraction)
  - `radare2` (for string searching)
  - `grep` (for quick searches on jailbroken devices)
- For encrypted binaries: `Clutch`, `frida-ios-dump`, or similar decryption tools

## Extraction Methods

### Method 1: Using Binwalk (Recommended for XML Extraction)

Binwalk can extract all embedded XML files from the binary:

```bash
binwalk -e -y=xml <path-to-binary>
```

**Example:**
```bash
$ binwalk -e -y=xml ./Telegram\ X

DECIMAL       HEXADECIMAL     DESCRIPTION
--------------------------------------------------------------------------------
1430180       0x15D2A4        XML document, version: "1.0"
1458814       0x16427E        XML document, version: "1.0"
```

**What to do next:**
1. Note the hex addresses where XML documents are found
2. Extract the plist at those offsets using a hex editor or `dd` command
3. Look for entitlements-related content (keys like `application-identifier`, `keychain-access-groups`, etc.)

### Method 2: Using Radare2 (String Search)

Radare2 can search for PropertyList strings in the binary:

```bash
r2 -qc 'izz~PropertyList' <path-to-binary>
```

**Example:**
```bash
$ r2 -qc 'izz~PropertyList' ./Telegram\ X

0x0015d2a4 ascii <?xml version="1.0" encoding="UTF-8" standalone="yes"?>...
0x0016427d ascii H<?xml version="1.0" encoding="UTF-8"?>...
```

**What to do next:**
1. Use the hex addresses to extract the full plist content
2. The first occurrence is typically the entitlements file
3. Parse the XML to review embedded permissions

### Method 3: Using Grep (Jailbroken Devices)

On jailbroken devices accessed via SSH, use grep with the `-a` flag to treat binaries as text:

```bash
grep -a -A 5 'PropertyList' /var/containers/Bundle/Application/<app-path>/<binary-name>
```

**Adjusting output:**
- Use `-A <num>` to show more or fewer lines after the match
- Example: `grep -a -A 20 'PropertyList' <binary>` for more context

**Why this works:**
- The `-a` flag treats all files as ASCII text
- Works even on encrypted app binaries
- Verified against multiple App Store apps

## Important Notes

### Don't Use `strings` Directly

Avoid using the `strings` command for this task. It has limitations in finding relevant entitlements information. Instead:
- Use `grep -a` on the binary
- Use radare2's `izz` command
- Use rabin2's `-zz` flag

### Handling Encrypted Binaries

If the above methods fail on encrypted binaries:
1. Use **Clutch** (if compatible with the iOS version)
2. Use **frida-ios-dump** to decrypt and extract the app
3. Then apply the extraction methods above

### Expected Entitlements Content

Look for these common entitlements keys:
- `application-identifier` - App's bundle identifier
- `keychain-access-groups` - Keychain sharing groups
- `com.apple.developer.team-identifier` - Developer team ID
- `com.apple.security.app-sandbox` - Sandbox status
- `com.apple.security.files.user-selected.read-only` - File access permissions
- `com.apple.security.network.client` - Network access

## Quick Reference Script

For automated extraction, use the bundled script:

```bash
./scripts/extract-entitlements.sh <path-to-binary>
```

This script:
1. Checks for available tools (binwalk, radare2, grep)
2. Attempts extraction using the best available method
3. Outputs the extracted entitlements to a readable format

## Security Testing Context

This extraction technique is part of the [OWASP MASVS-PLATFORM](https://mas.owasp.org/MASTG/tests/ios/MASVS-PLATFORM/MASTG-TEST-0069/#review-entitlements-embedded-in-the-compiled-app-binary) security testing guidelines, specifically MASTG-TEST-0069 for reviewing entitlements embedded in compiled app binaries.

## Troubleshooting

**No XML found with binwalk:**
- Try radare2 method instead
- The binary may be heavily obfuscated
- Consider decrypting first if encrypted

**Grep returns nothing:**
- Verify the binary path is correct
- Try `grep -a -i 'entitlement'` as an alternative search
- Check if the app is encrypted and needs decryption first

**Extracted content is garbled:**
- The binary may be encrypted
- Use Clutch or frida-ios-dump to decrypt first
- Verify you're extracting from the correct offset
