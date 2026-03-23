---
name: macos-code-signing-analyzer
description: Analyze macOS code signatures, entitlements, and requirements in Mach-O binaries. Use this skill whenever the user needs to inspect code signing information, extract entitlements, analyze signature blobs, understand code signing flags, or work with Security.framework APIs. Trigger for tasks involving binary analysis, security research, privilege escalation assessment, or understanding how macOS validates executables.
---

# macOS Code Signing Analyzer

A skill for analyzing macOS code signatures, entitlements, and security requirements in Mach-O binaries.

## What This Skill Does

This skill helps you:
- Parse and analyze code signature structures in Mach-O binaries
- Extract and interpret entitlements from signed binaries
- Decode code signing flags and their security implications
- Analyze requirements expressions that control binary execution
- Work with Security.framework APIs for code signing operations
- Understand the relationship between signatures, entitlements, and privilege escalation

## When to Use This Skill

Use this skill when you need to:
- Inspect code signing information in macOS binaries
- Extract entitlements from applications or system binaries
- Analyze why a binary has certain security restrictions
- Understand code signing flags like `CS_HARD`, `CS_KILL`, `CS_RESTRICT`
- Work with requirements expressions for code validation
- Research privilege escalation vectors related to code signing
- Debug code signing issues in macOS applications

## Core Concepts

### Code Signature Structure

Mach-O binaries contain a load command `LC_CODE_SIGNATURE` that points to signature data at the end of the binary. The signature uses a SuperBlob structure:

```
CS_SuperBlob:
  - magic: 0xFADE0CC0 (embedded) or 0xFADE0CC1 (detached)
  - length: total blob length
  - count: number of index entries
  - index[]: array of blob type/offset pairs
```

Common blob types:
- **Code Directory** - Contains hash of hashes for binary pages
- **Requirements** - Execution requirements the binary must satisfy
- **Entitlements** - Special permissions granted to the binary
- **CMS** - Cryptographic Message Signature

### Code Directory

The Code Directory is the heart of the signature. It contains:

| Field | Description |
|-------|-------------|
| `magic` | `CSMAGIC_CODEDIRECTORY` |
| `version` | Format version (e.g., 0x20400) |
| `hashType` | Hash algorithm (2 = SHA256) |
| `hashSize` | Hash size in bytes (32 for SHA256) |
| `pageSize` | Log2 of page size (12 = 4096 bytes) |
| `nCodeSlots` | Number of code page hashes |
| `nSpecialSlots` | Number of special slot hashes |
| `codeLimit` | End of signed code range |

### Special Slots

Special slots (negative indices) contain hashes of external resources:

| Slot | Content |
|------|---------|
| -1 | `Info.plist` hash |
| -2 | Requirements blob hash |
| -3 | Resource Directory hash |
| -4 | Application-specific (unused) |
| -5 | Entitlements blob hash |
| -6 | DMG code signature |
| -7 | DER Entitlements (iOS) |

### Code Signing Flags

Key flags that affect binary behavior:

| Flag | Value | Effect |
|------|-------|--------|
| `CS_VALID` | 0x00000001 | Signature is valid |
| `CS_ADHOC` | 0x00000002 | Ad-hoc signed |
| `CS_GET_TASK_ALLOW` | 0x00000004 | Has get-task-allow entitlement |
| `CS_HARD` | 0x00000100 | Don't load invalid pages |
| `CS_KILL` | 0x00000200 | Kill if signature becomes invalid |
| `CS_RESTRICT` | 0x00000800 | Restricted execution mode |
| `CS_ENFORCEMENT` | 0x00001000 | Require enforcement |
| `CS_RUNTIME` | 0x00010000 | Hardened runtime enabled |
| `CS_PLATFORM_BINARY` | 0x04000000 | Platform binary (trusted) |

### Requirements Expressions

Requirements are special grammar expressions that must be satisfied for execution:

```bash
# Example requirement
designated => identifier "com.apple.ls" and anchor apple
```

Common requirement components:
- `identifier` - Bundle identifier
- `anchor` - Trust anchor (apple, apple generic, etc.)
- `certificate` - Certificate field requirements
- `team` - Team ID requirements

## Analysis Workflow

### Step 1: Basic Signature Inspection

```bash
# Get detailed signature information
codesign -d -vvvvvv /path/to/binary

# Get requirements
codesign -d -r- /path/to/binary

# Check validity
codesign -v /path/to/binary
```

### Step 2: Extract Entitlements

```bash
# Using codesign
codesign -d --entitlements :- /path/to/binary

# Using plutil for Info.plist
plutil -p /path/to/binary/Contents/Info.plist
```

### Step 3: Deep Analysis with disarm

```bash
# Full signature dump
disarm -vv --sig /path/to/binary

# Extract specific blobs
disarm -e /path/to/binary
```

### Step 4: Manual Hash Verification

```bash
# Get page size from codesign output
PAGESIZE=4096

# Calculate page hashes
for i in $(seq 0 $PAGES); do
    dd if=$BINARY of=/tmp/page.$i bs=$PAGESIZE skip=$i count=1
    openssl sha256 /tmp/page.$i
done
```

## Security Framework APIs

### Checking Validity

```objc
// Check code validity against requirements
SecStaticCodeCheckValidity(codeRef, options, requirement);

// Validate running task against requirement
SecTaskValidateForRequirement(task, requirementString);
```

### Creating Requirements

```objc
// Create requirement from string
SecRequirementCreateWithString(requirementString, options, &reqRef);

// Create requirement from binary data
SecRequirementCreateWithData(binaryData, &reqRef);
```

### Accessing Signing Information

```objc
// Get static code reference from path
SecStaticCodeCreateWithPath(path, &codeRef);

// Copy signing information
SecCodeCopySigningInformation(codeRef, kSecCSSigningInformation, &info);

// Get signing identifier
SecCodeCopySigningIdentifier(codeRef, &identifier);
```

## Common Use Cases

### 1. Check if Binary is Platform Binary

```bash
# Platform binaries have special protections
codesign -d -vvvvvv /bin/ps | grep -i platform

# Check csb_platform_binary flag in cs_blob
```

### 2. Extract All Entitlements

```bash
# Get entitlements in XML format
codesign -d --entitlements :- /path/to/app.app

# Parse specific entitlements
grep -E "(get-task-allow|com.apple.security.*)" entitlements.xml
```

### 3. Analyze Requirements

```bash
# Get designated requirement
codesign -d -r- /path/to/binary

# Compile custom requirements
csreq -b output.csreq -r='identifier "com.example.app" and anchor apple'
```

### 4. Check Hardened Runtime Status

```bash
# Check if hardened runtime is enabled
codesign -d -vvvvvv /path/to/binary | grep -i runtime

# Look for CS_RUNTIME flag (0x00010000)
```

### 5. Verify Signature Integrity

```bash
# Verify signature
codesign -v /path/to/binary

# Check for invalid pages
codesign -d -vvvvvv /path/to/binary | grep -i invalid
```

## Privilege Escalation Considerations

### Platform Binary Exploitation

Platform binaries have special protections. Making a binary a platform binary (via re-signing) can:
- Grant SEND rights to task ports
- Bypass certain security checks
- Enable access to protected resources

### Entitlement Abuse

Key entitlements to check:
- `com.apple.security.get-task-allow` - Allows task port access
- `com.apple.security.app-sandbox` - Sandbox status
- `com.apple.security.cs.allow-jit` - JIT compilation allowed
- `com.apple.security.cs.allow-unsigned-executable-memory` - Unsigned memory allowed

### Requirements Bypass

Requirements can be bypassed if:
- The binary is re-signed with modified requirements
- The anchor is weakened (e.g., `anchor apple generic`)
- Certificate requirements are removed

## Troubleshooting

### Signature Not Found

```bash
# Check if binary is signed
file /path/to/binary

# Look for LC_CODE_SIGNATURE load command
otool -l /path/to/binary | grep -A2 CODE_SIGNATURE
```

### Invalid Signature

```bash
# Check for modification
codesign -v /path/to/binary

# Re-sign if needed
codesign -s - /path/to/binary
```

### Entitlements Not Showing

```bash
# Check special slot -5
disarm -vv --sig /path/to/binary | grep -i entitlement

# Try alternative extraction
plutil -p /path/to/binary/Contents/Info.plist | grep -i entitlement
```

## References

- [Apple Code Signing Documentation](https://developer.apple.com/documentation/security/codesigning)
- [xnu cs_blobs.h](https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/kern/cs_blobs.h)
- [*OS Internals Volume III](https://newosxbook.com/home.html)
- [Security Framework Reference](https://developer.apple.com/documentation/security)

## Tools

| Tool | Purpose |
|------|---------|
| `codesign` | Apple's code signing utility |
| `disarm` | Third-party signature analyzer |
| `MachOView` | GUI for Mach-O inspection |
| `otool` | Mach-O binary inspection |
| `plutil` | Property list manipulation |
| `csreq` | Compile requirements expressions |
