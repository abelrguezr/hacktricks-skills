---
name: macos-library-injection
description: macOS library injection and dylib hijacking analysis. Use this skill whenever the user needs to analyze macOS binaries for library injection vulnerabilities, check DYLD_INSERT_LIBRARIES restrictions, find weak linked libraries, examine rpath configurations, or test for privilege escalation via library loading. Trigger on any request about macOS dyld, library injection, dylib hijacking, dlopen hijacking, or binary security analysis.
---

# macOS Library Injection Analysis

A skill for analyzing macOS binaries for library injection vulnerabilities and understanding dyld behavior.

## When to Use This Skill

Use this skill when:
- Analyzing macOS binaries for library injection vulnerabilities
- Checking if `DYLD_INSERT_LIBRARIES` will work on a binary
- Finding weak linked libraries that could be hijacked
- Examining rpath configurations in Mach-O binaries
- Testing for privilege escalation via library loading
- Understanding macOS dyld restrictions and protections
- Auditing binaries for hardened runtime and library validation

## Core Concepts

### DYLD_INSERT_LIBRARIES

Similar to `LD_PRELOAD` on Linux, this environment variable allows loading a custom library into a process. However, Apple has significantly restricted this since 2012.

**Restrictions that block DYLD_INSERT_LIBRARIES:**
- Binary is setuid/setgid
- Binary has `__RESTRICT`/`__restrict` section
- Binary has hardened runtime without `com.apple.security.cs.allow-dyld-environment-variables` entitlement

### Library Validation

Even if `DYLD_INSERT_LIBRARIES` is allowed, the binary may check library signatures. To load a custom library, the binary needs:
- `com.apple.security.cs.disable-library-validation` entitlement
- `com.apple.private.security.clear-library-validation` entitlement
- OR no hardened runtime flag
- OR the library is signed with the same certificate as the binary

## Quick Checks

### Check Binary Restrictions

```bash
# Check for hardened runtime
codesign --display --verbose <binary>
# Look for flags=0x10000(runtime) in CodeDirectory

# Check entitlements
codesign -dv --entitlements :- <binary>

# Check for setuid/setgid
ls -l <binary>
# Look for 's' in permissions

# Check runtime flags at execution time
csops -status <pid>
# Flag 0x800 indicates CS_RESTRICT
```

### Find Weak Linked Libraries

```bash
# Find LC_LOAD_WEAK_DYLIB entries
otool -l <binary> | grep LC_LOAD_WEAK_DYLIB -A 5

# These libraries can be hijacked if they don't exist
# and the attacker can write to the expected path
```

### Find RPATH Configurations

```bash
# Find rpath and load commands
otool -l <binary> | grep -E "LC_RPATH|LC_LOAD_DYLIB" -A 5

# Look for @rpath references that could be hijacked
# @executable_path = directory containing main executable
# @loader_path = directory containing the Mach-O binary
```

## Attack Vectors

### 1. DYLD_INSERT_LIBRARIES Injection

**Works when:**
- Binary is NOT setuid/setgid
- Binary has NO `__RESTRICT` section
- Binary has `com.apple.security.cs.allow-dyld-environment-variables` entitlement OR no hardened runtime
- Library validation is disabled OR library is properly signed

**Test:**
```bash
DYLD_INSERT_LIBRARIES=/path/to/inject.dylib ./binary
```

### 2. Weak Linked Library Hijacking

**Works when:**
- Binary has `LC_LOAD_WEAK_DYLIB` for a missing library
- Attacker can write to the expected library path
- Library validation restrictions are satisfied

**Find targets:**
```bash
otool -l <binary> | grep LC_LOAD_WEAK_DYLIB -A 5
```

### 3. RPATH Hijacking

**Works when:**
- Binary uses `@rpath` in `LC_LOAD_DYLIB`
- One of the rpath directories is writable by attacker
- Library validation restrictions are satisfied

**Note:** macOS searches rpath directories in order. If a library exists in multiple paths, the first match wins.

### 4. Dlopen Hijacking

**Search order for dlopen (no slash in name):**
1. `$DYLD_LIBRARY_PATH`
2. `LC_RPATH` directories
3. Current working directory (if unrestricted)
4. `$DYLD_FALLBACK_LIBRARY_PATH`
5. `/usr/local/lib/` (if unrestricted)
6. `/usr/lib/`

**Works when:**
- Binary is unrestricted (no setuid, no CS_RESTRICT)
- Attacker can write to one of the search paths
- Library validation restrictions are satisfied

### 5. Relative Path Hijacking

**Works when:**
- Privileged binary loads library via relative path (`@executable_path`, `@loader_path`)
- Library validation is disabled
- Attacker can move the binary or write to the relative path

## Testing Scripts

Use the bundled scripts for automated analysis:

- `scripts/check_binary_restrictions.sh` - Check all restriction flags
- `scripts/find_weak_libraries.sh` - Find weak linked libraries
- `scripts/find_rpath_configs.sh` - Find rpath configurations
- `scripts/test_dyld_injection.sh` - Test DYLD_INSERT_LIBRARIES

## Common Patterns

### SUID Binary Testing

```bash
# Make binary setuid
sudo chown root <binary>
sudo chmod +s <binary>

# Test injection (won't work on setuid)
DYLD_INSERT_LIBRARIES=inject.dylib ./binary

# Remove setuid
sudo chmod -s <binary>
```

### Hardened Runtime Testing

```bash
# Apply runtime protection
codesign -s <cert-name> --option=runtime ./binary

# Apply library validation
codesign -f -s <cert-name> --option=library ./binary

# Sign library with same certificate
codesign -f -s <cert-name> inject.dylib

# Apply CS_RESTRICT
codesign -f -s <cert-name> --option=restrict ./binary
```

### Creating Test Binary with __RESTRICT Section

```bash
gcc -sectcreate __RESTRICT __restrict /dev/null hello.c -o hello-restrict
```

## Important Notes

1. **Environment Variable Pruning**: `DYLD_*` and `LD_LIBRARY_PATH` are removed for restricted binaries by `pruneEnvironmentVariables()` in dyld

2. **Library Validation**: Even if injection is allowed, library signatures may be checked. The library must be signed with the same certificate as the binary, or the binary must have library validation disabled

3. **Universal Binaries**: macOS uses universal files combining 32-bit and 64-bit libraries. There are no separate search paths for different architectures

4. **Dyld Cache**: Most OS dylibs are combined into the dyld cache and don't exist on disk. Use `dlopen_preflight()` instead of `stat()` to check if a dylib exists

5. **Setuid/SGID**: These binaries always have environment variables pruned and are highly restricted

6. **CS_RESTRICT Flag**: Can be applied dynamically at execution time even if not present in the binary's signature

## References

- [dyld source code](https://opensource.apple.com/source/dyld/)
- [Dylib Hijack Scanner](https://objective-see.com/products/dhs.html)
- [DylibHijack CLI](https://github.com/pandazheng/DylibHijack)
- [Virus Bulletin: Dylib Hijacking OS X](https://www.virusbulletin.com/virusbulletin/2015/03/dylib-hijacking-os-x)
- [The Evil Bit: DYLD_INSERT_LIBRARIES Deep Dive](https://theevilbit.github.io/posts/dyld_insert_libraries_dylib_injection_in_macos_osx_deep_dive/)
- [OS Internals, Volume I: User Mode](https://www.amazon.com/MacOS-iOS-Internals-User-Mode/dp/099105556X)
