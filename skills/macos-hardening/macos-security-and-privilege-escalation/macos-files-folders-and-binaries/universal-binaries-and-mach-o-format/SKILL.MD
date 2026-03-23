---
name: macos-binary-analysis
description: Analyze macOS Mach-O binaries, universal binaries, and extract security-relevant information. Use this skill whenever the user asks about macOS binary analysis, Mach-O format, universal binaries, reverse engineering macOS executables, extracting binary metadata, analyzing load commands, segments, sections, or any macOS binary forensics task. Make sure to use this skill for any macOS binary-related questions, even if the user doesn't explicitly mention "Mach-O" or "binary analysis".
---

# macOS Binary Analysis Skill

A skill for analyzing macOS Mach-O binaries, understanding their structure, and extracting security-relevant information.

## What This Skill Does

This skill helps you:
- Parse and explain Mach-O binary structure (headers, load commands, segments, sections)
- Analyze universal binaries and their architecture support
- Extract security-relevant information from macOS binaries
- Use command-line tools for binary analysis
- Identify potential security issues in binary configurations
- Understand Objective-C and Swift runtime sections

## Quick Start

When analyzing a binary, follow this workflow:

1. **Identify the binary type** - Check if it's a universal binary and what architectures it supports
2. **Examine the Mach-O header** - Get basic file type, architecture, and flags
3. **Review load commands** - Understand how the binary loads and what it depends on
4. **Analyze segments and sections** - Look at memory layout and permissions
5. **Extract security-relevant info** - Check for encryption, code signatures, DYLD variables

## Core Commands Reference

### Check if Universal Binary

```bash
file /path/to/binary
```

Output shows architectures like:
```
Mach-O universal binary with 2 architectures: [x86_64] [arm64e]
```

### View Fat Header (Universal Binary Info)

```bash
otool -f -v /path/to/binary
```

Shows:
- Number of architectures (`nfat_arch`)
- Each architecture's offset, size, and alignment
- CPU type and subtype

### View Mach-O Header

```bash
otool -arch <arch> -hv /path/to/binary
```

Shows:
- Magic number (MH_MAGIC or MH_MAGIC_64)
- CPU type and subtype
- File type (EXECUTE, DYLIB, BUNDLE, etc.)
- Number of load commands
- Flags (PIE, NOUNDEFS, etc.)

### View All Load Commands

```bash
otool -l /path/to/binary
```

### View Load Commands with Verbose Output

```bash
otool -lv /path/to/binary
```

### List Dynamic Library Dependencies

```bash
otool -L /path/to/binary
```

### View Segment and Section Info

```bash
size -m /path/to/binary
```

## Mach-O File Types

| Type | Description |
|------|-------------|
| `MH_OBJECT` | Relocatable object file (intermediate compilation product) |
| `MH_EXECUTE` | Executable file |
| `MH_DYLIB` | Dynamic library |
| `MH_DYLINKER` | Dynamic linker |
| `MH_BUNDLE` | Plugin file (loaded via NSBundle or dlopen) |
| `MH_DYSM` | Debug symbols file (.dSYM) |
| `MH_KEXT_BUNDLE` | Kernel extension |
| `MH_CORE` | Core dump |

## Important Load Commands

### LC_SEGMENT_64 / LC_SEGMENT

Defines memory segments mapped into the process:

- **`__PAGEZERO`**: Maps address zero as inaccessible (NULL pointer deref mitigation)
- **`__TEXT`**: Executable code (read + execute, no write)
  - `__text`: Compiled binary code
  - `__const`: Constant data
  - `__stubs`: Dynamic library loading stubs
  - `__unwind_info`: Stack unwind data
- **`__DATA`**: Readable/writable data (no execute)
  - `__got`: Global Offset Table
  - `__data`: Initialized global variables
  - `__bss`: Uninitialized static variables
  - `__objc_*`: Objective-C runtime info
- **`__DATA_CONST`**: Read-only data (protected via mprotect)
- **`__LINKEDIT`**: Linker info (symbols, strings, relocations, code signature)
- **`__OBJC`**: Objective-C runtime information
- **`__RESTRICT`**: Empty segment that ignores DYLD environment variables

### LC_MAIN / LC_UNIXTHREAD

- **`LC_MAIN`**: Contains entry point offset (entryoff)
- **`LC_UNIXTHREAD`**: Register values at main thread start (deprecated but still used)

### LC_LOAD_DYLIB

Describes dynamic library dependencies. One command per library.

### LC_CODE_SIGNATURE

Contains offset to code signature blob (typically at end of file).

### LC_ENCRYPTION_INFO_64

Support for binary encryption (useful for analyzing encrypted segments).

### LC_LOAD_DYLINKER

Path to dynamic linker (always `/usr/lib/dyld` on macOS).

### LC_DYLD_ENVIRONMENT

Environment variables for dyld (restricted to `DYLD_*_PATH` variables).

## Mach-O Flags

| Flag | Meaning |
|------|---------|
| `MH_NOUNDEFS` | No undefined references (fully linked) |
| `MH_DYLDLINK` | Dyld linking |
| `MH_SPLIT_SEGS` | Splits read-only and read-write segments |
| `MH_ALLOW_STACK_EXECUTION` | Stack is executable (security concern) |
| `MH_PIE` | Position Independent Executable |
| `MH_NO_HEAP_EXECUTION` | No execution for heap/data pages |
| `MH_HAS_OBJC` | Binary has Objective-C sections |
| `MH_DYLIB_IN_CACHE` | Used in shared library cache |

## Security-Relevant Analysis

### Check for Security Flags

```bash
otool -arch arm64e -hv /path/to/binary | grep -E "PIE|NOUNDEFS|NO_HEAP_EXECUTION"
```

### Check for DYLD Environment Variable Restrictions

```bash
otool -l /path/to/binary | grep -A5 "LC_RESTRICT"
```

### Check Code Signature

```bash
codesign -dv --verbose=4 /path/to/binary
```

### Check for Encryption

```bash
otool -l /path/to/binary | grep -A3 "LC_ENCRYPTION_INFO"
```

### Check Dynamic Library Dependencies

```bash
otool -L /path/to/binary
```

Look for suspicious libraries:
- `DiskArbitration` - USB drive monitoring
- `AVFoundation` - Audio/video capture
- `CoreWLAN` - WiFi scanning

## Objective-C Runtime Sections

### In `__TEXT` Segment (r-x)

- `__objc_classname`: Class names (strings)
- `__objc_methname`: Method names (strings)
- `__objc_methtype`: Method types (strings)

### In `__DATA` Segment (rw-)

- `__objc_classlist`: Pointers to all Objective-C classes
- `__objc_nlclslist`: Non-lazy Objective-C classes
- `__objc_catlist`: Categories
- `__objc_protolist`: Protocols
- `__objc_const`: Constant data
- `__objc_imageinfo`, `__objc_selrefs`: Runtime metadata

## Swift Runtime Sections

- `_swift_typeref`: Type references
- `_swift3_capture`: Capture descriptors
- `_swift3_assocty`: Associated types
- `_swift3_types`: Type information
- `_swift3_builtin`: Built-in types
- `_swift3_reflstr`: Reflection strings

## Common Analysis Tasks

### Task 1: Full Binary Overview

```bash
# Check file type and architectures
file /path/to/binary

# View Mach-O header
otool -hv /path/to/binary

# List all load commands
otool -l /path/to/binary

# List dependencies
otool -L /path/to/binary
```

### Task 2: Security Analysis

```bash
# Check security flags
otool -hv /path/to/binary | grep -E "PIE|NOUNDEFS|NO_HEAP_EXECUTION|ALLOW_STACK"

# Check for encryption
otool -l /path/to/binary | grep -A3 "LC_ENCRYPTION_INFO"

# Check code signature
codesign -dv --verbose=4 /path/to/binary

# Check for DYLD restrictions
otool -l /path/to/binary | grep -A5 "LC_RESTRICT"
```

### Task 3: Extract Specific Information

```bash
# Get entry point
otool -l /path/to/binary | grep -A10 "LC_MAIN"

# Get segment info
otool -l /path/to/binary | grep -A20 "LC_SEGMENT_64"

# Get section info
otool -l /path/to/binary | grep -A10 "__TEXT"
```

### Task 4: Universal Binary Analysis

```bash
# List all architectures
file /path/to/binary

# View fat header details
otool -f -v /path/to/binary

# Extract specific architecture
lipo -thin <arch> /path/to/binary -o /tmp/thinned_binary

# Analyze specific architecture
otool -arch <arch> -hv /path/to/binary
```

## Tools

### Built-in macOS Tools

- `file` - Identify file type and architectures
- `otool` - Disassemble and analyze Mach-O files
- `lipo` - Manipulate universal binaries
- `codesign` - Check code signatures
- `size` - Show segment sizes

### Third-Party Tools

- **Mach-O View** (https://sourceforge.net/projects/machoview/) - GUI for Mach-O analysis
- **Hopper Disassembler** - Commercial disassembler
- **Ghidra** - NSA's reverse engineering tool

## Tips

1. **Always check if it's a universal binary first** - Use `file` command
2. **Specify architecture when analyzing** - Use `-arch` flag with `otool`
3. **Look for security flags** - PIE, stack execution, heap execution
4. **Check code signatures** - Important for security analysis
5. **Review load commands** - They tell you how the binary loads
6. **Examine segments** - Understand memory layout and permissions
7. **Check dependencies** - Look for suspicious dynamic libraries

## Example Analysis

```bash
# Analyze /bin/ls
file /bin/ls
# Output: Mach-O universal binary with 2 architectures: [x86_64] [arm64e]

otool -arch arm64e -hv /bin/ls
# Shows: MH_MAGIC_64, ARM64, EXECUTE, PIE, NOUNDEFS, etc.

otool -L /bin/ls
# Shows dependencies: libutil.dylib, libncurses.5.4.dylib, libSystem.B.dylib

otool -l /bin/ls | grep -A5 "LC_SEGMENT_64"
# Shows segment definitions
```

## When to Use This Skill

Use this skill when:
- Analyzing macOS executables or libraries
- Understanding Mach-O binary format
- Performing security analysis on macOS binaries
- Reverse engineering macOS software
- Extracting metadata from Mach-O files
- Investigating universal binaries
- Checking code signatures and security flags
- Analyzing Objective-C or Swift binaries
- Preparing for macOS penetration testing
- Debugging binary loading issues

## References

- [Mach-O Header Definition](https://opensource.apple.com/source/xnu/xnu-2050.18.24/EXTERNAL_HEADERS/mach-o/loader.h)
- [Reading Your Own Entitlements](https://davedelong.com/blog/2018/01/10/reading-your-own-entitlements/)
- [Mach-O View](https://sourceforge.net/projects/machoview/)
- [HackerTricks macOS Security](https://book.hacktricks.xyz/mac-os/mac-os-security-and-privilege-escalation/mac-os-files-folders-and-binaries/universal-binaries-and-mach-o-format)
