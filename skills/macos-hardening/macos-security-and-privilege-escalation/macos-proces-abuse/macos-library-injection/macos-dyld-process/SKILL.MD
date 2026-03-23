---
name: macos-dyld-analysis
description: Analyze macOS dynamic linker (dyld) internals, debug library loading, examine Mach-O binary structure, and identify potential security implications. Use this skill whenever the user needs to understand how macOS loads executables, debug dyld behavior, analyze library injection vectors, examine stub sections, or investigate privilege escalation through the dynamic linker. Trigger for any questions about dyld environment variables, Mach-O segments, lazy vs non-lazy binding, or macOS binary internals.
---

# macOS Dyld Analysis

A skill for analyzing macOS dynamic linker internals, debugging library loading, and understanding Mach-O binary structure.

## What this skill does

This skill helps you:
- Understand how macOS loads and links executables via dyld
- Debug library loading with dyld environment variables
- Analyze Mach-O binary structure (stubs, GOT, lazy/non-lazy symbols)
- Identify potential security implications of dyld behavior
- Examine the `apple[]` argument vector and dyld internals

## When to use this skill

Use this skill when you need to:
- Debug why a macOS binary isn't loading correctly
- Understand library injection mechanisms (`DYLD_INSERT_LIBRARIES`)
- Analyze Mach-O binary structure for security research
- Investigate privilege escalation vectors through dyld
- Examine how symbols are resolved (lazy vs non-lazy binding)
- Debug dyld behavior with environment variables
- Understand the `apple[]` argument vector in macOS

## Core Concepts

### Dyld Loading Flow

1. **dyldbootstrap::start** loads dyld and sets up stack canary
2. **dyld::_main()** runs `configureProcessRestrictions()` (restricts `DYLD_*` vars)
3. Maps dyld shared cache (prelinked system libraries)
4. Loads libraries in order:
   - `DYLD_INSERT_LIBRARIES` (if allowed)
   - Shared cached libraries
   - Imported libraries (recursively)
5. Runs library initializers (`__attribute__((constructor))`)
6. Executes binary entry point

### Mach-O Stub Sections

| Section | Purpose |
|---------|--------|
| `__TEXT.__[auth_]stubs` | Pointers from `__DATA` sections |
| `__TEXT.__stub_helper` | Code invoking dynamic linking |
| `__DATA.__[auth_]got` | Global Offset Table (resolved at load time) |
| `__DATA.__nl_symbol_ptr` | Non-lazy symbol pointers |
| `__DATA.__la_symbol_ptr` | Lazy symbol pointers (bound on first access) |

> **Note**: Modern dyld loads everything as non-lazy. `auth_` prefixed sections use pointer authentication (PAC).

### Key Environment Variables

#### Debug Variables

| Variable | Purpose |
|----------|--------|
| `DYLD_PRINT_LIBRARIES=1` | Print each library as it loads |
| `DYLD_PRINT_SEGMENTS=1` | Show segment mappings |
| `DYLD_PRINT_INITIALIZERS=1` | Show when initializers run |
| `DYLD_PRINT_BINDINGS=1` | Print symbol bindings |
| `DYLD_PRINT_ENV=1` | Print environment seen by dyld |
| `DYLD_PRINT_TO_FILE=path` | Write debug output to file |

#### Behavior Variables

| Variable | Purpose |
|----------|--------|
| `DYLD_INSERT_LIBRARIES=path` | Inject library (restricted on signed binaries) |
| `DYLD_LIBRARY_PATH=path` | Library search path |
| `DYLD_FRAMEWORK_PATH=path` | Framework search path |
| `DYLD_BIND_AT_LAUNCH=1` | Resolve lazy bindings at launch |
| `DYLD_FORCE_FLAT_NAMESPACE=1` | Single-level symbol namespace |
| `DYLD_DISABLE_PREFETCH=1` | Disable data prefetching |

### The apple[] Argument Vector

macOS main() receives 4 arguments instead of 3:
```c
int main(int argc, char **argv, char **envp, char **apple)
```

The `apple[]` vector contains sensitive values like:
- `executable_path` - Path to the executable
- `stack_guard` - Stack canary value
- `malloc_entropy` - Memory allocator entropy
- `executable_cdhash` - Code directory hash
- `executable_boothash` - Boot hash
- `ptr_munge` - Pointer munging value

> **Warning**: These values are sanitized before reaching main() to prevent data leaks.

## Common Tasks

### 1. List Loaded Libraries

```bash
DYLD_PRINT_LIBRARIES=1 ./your_binary
```

### 2. Examine Segment Mappings

```bash
DYLD_PRINT_SEGMENTS=1 ./your_binary
```

### 3. Analyze Stub Sections

```bash
# List sections
objdump --section-headers ./binary

# Disassemble stubs
objdump -d --section=__stubs ./binary
```

### 4. Find All DYLD Environment Variables

```bash
strings /usr/lib/dyld | grep "^DYLD_" | sort -u
```

### 5. Debug Before main() Entry

```bash
lldb ./binary
(lldb) process launch -s
(lldb) mem read $sp
(lldb) x/55s <stack_address>
```

### 6. Examine dyld_all_image_infos

The `dyld_all_image_infos` structure (exported by dyld) contains:
- Version information
- Pointer to `dyld_image_info` array
- Image notifier callback
- Shared cache detachment status
- libSystem initializer status
- dyld's own Mach header pointer

## Security Considerations

### Privilege Escalation Risk

If dyld contains vulnerabilities, they can be exploited before any binary executes, including privileged ones. This is because:
- dyld runs before the target binary
- dyld has no dependencies (uses syscalls directly)
- dyld handles all library loading

### Library Injection Restrictions

`DYLD_INSERT_LIBRARIES` is restricted on:
- System binaries
- Signed executables
- Processes with hardened runtime

### Pointer Authentication (PAC)

On arm64e:
- `auth_` prefixed sections use in-process encryption keys
- `BLRA[A/B]` verifies pointers before following
- `RETA[A/B]` replaces `RET` for authenticated returns
- `__TEXT.__auth_stubs` uses `braa` instead of `bl`

## References

- [OS Internals, Volume I: User Mode](https://www.amazon.com/MacOS-iOS-Internals-User-Mode/dp/099105556X) by Jonathan Levin
- [dyld Source Code](https://opensource.apple.com/source/dyld/)
- [Mach-O Format Documentation](https://developer.apple.com/library/archive/documentation/DeveloperTools/Conceptual/MachORuntime/Articles/MachOFiles.html)

## Scripts

See the `scripts/` directory for helper tools:
- `list_dyld_env_vars.sh` - Extract all DYLD_* environment variables from dyld
- `analyze_macho_sections.sh` - List and analyze Mach-O sections
- `debug_dyld_loading.sh` - Quick debug script for dyld behavior
