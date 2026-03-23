---
name: relro-analysis
description: Analyze RELRO (Relocation Read-Only) protections in ELF binaries, check protection status, and understand bypass techniques. Use this skill whenever the user mentions binary protections, ELF analysis, GOT (Global Offset Table), relocation, checksec, readelf, binary exploitation, or security hardening. Trigger for any questions about Partial RELRO, Full RELRO, -z relro, -z now, BIND_NOW, or how to check/enable RELRO in compiled binaries.
---

# RELRO Analysis Skill

This skill helps you understand, check, and work with **RELRO (Relocation Read-Only)** protections in ELF binaries.

## Quick Reference

```bash
# Check RELRO status (requires checksec/pwntools)
checksec --file ./binary

# Check RELRO with readelf (always available)
readelf -l ./binary | grep GNU_RELRO
readelf -d ./binary | grep BIND_NOW

# Compile with Full RELRO
gcc -fPIE -pie -Wl,-z,relro,-z,now -o binary source.c
```

## Understanding RELRO

**RELRO** (Relocation Read-Only) is a linker mitigation that makes the GOT (Global Offset Table) and related sections read-only after relocations are applied. This prevents attackers from overwriting function pointers via buffer overflows or arbitrary write primitives.

### Two Protection Levels

| Level | Flags | GOT Protection | Bypass Possible |
|-------|-------|----------------|------------------|
| **None** | (default, old) | Writable | Yes - direct GOT overwrite |
| **Partial** | `-Wl,-z,relro` | Non-PLT GOT only | Yes - `.got.plt` still writable |
| **Full** | `-Wl,-z,relro,-z,now` | Entire GOT read-only | Harder - need other primitives |

**Key insight**: Full RELRO requires `-z now` (eager binding) so `.got.plt` never needs runtime writes and can be made read-only.

## Checking RELRO Status

### Method 1: checksec (Recommended)

```bash
checksec --file ./vuln
```

Output interpretation:
- `RELRO: Full` → Complete protection
- `RELRO: Partial` → GOT.plt still writable
- `RELRO: No` → No protection

### Method 2: readelf (Always available)

```bash
# Check for PT_GNU_RELRO segment
readelf -l ./binary | grep GNU_RELRO

# Check for BIND_NOW flag (indicates Full RELRO)
readelf -d ./binary | grep BIND_NOW
```

**Interpretation**:
- `GNU_RELRO` present + `BIND_NOW` absent = **Partial RELRO**
- `GNU_RELRO` present + `BIND_NOW` present = **Full RELRO**
- `GNU_RELRO` absent = **No RELRO**

### Method 3: Check running process

```bash
# For a running process (e.g., setuid binary)
readelf -l /proc/$(pgrep process_name)/exe | grep GNU_RELRO
```

## Enabling RELRO in Compilation

### GCC/Clang

```bash
# Full RELRO with PIE and other hardenings
gcc -fPIE -pie -Wl,-z,relro,-z,now -Wl,--as-needed -D_FORTIFY_SOURCE=2 source.c -o binary

# Breakdown:
# -fPIE -pie          → Position Independent Executable
# -Wl,-z,relro        → Create PT_GNU_RELRO segment
# -Wl,-z,now          → Eager binding (no lazy loading)
# -Wl,--as-needed     → Only link required libraries
# -D_FORTIFY_SOURCE=2 → Buffer overflow protection
```

### CMake (3.18+)

```cmake
set(CMAKE_EXE_LINKER_FLAGS "-Wl,-z,relro,-z,now")
set(CMAKE_SHARED_LINKER_FLAGS "-Wl,-z,relro,-z,now")
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
```

### Makefile

```makefile
LDFLAGS += -Wl,-z,relro,-z,now
CFLAGS += -fPIE
LDFLAGS += -pie
```

## Bypass Techniques

### When GOT is Writable (No/Partial RELRO)

1. **Direct GOT overwrite** - Overwrite `.got.plt` entry to redirect function calls
2. **ret2dlresolve** - Craft fake `Elf64_Rela` and `Elf64_Rsym` to call `_dl_runtime_resolve`
3. **Function pointer overwrite** - Target `.fini_array`, `.init_array`, or `atexit()` handlers

### When GOT is Read-Only (Full RELRO)

1. **Other writable pointers** - C++ vtables, `__malloc_hook` (glibc < 2.34), `__free_hook`, custom `.data` sections
2. **Leak + ROP/SROP** - Use relative read primitives to leak libc, then ROP into libc functions
3. **Format string attacks** - Partial pointer overwrite without touching GOT
4. **Shared library GOT** - libc's own GOT is only Partial RELRO; target it with arbitrary write
5. **LD_PRELOAD/DT_RPATH** - Inject rogue shared objects (if environment is controllable)

### Important Note

> Even with Full RELRO, **shared libraries like libc** have only **Partial RELRO** because they're already mapped when the loader applies relocations. If you have an arbitrary write primitive targeting another shared object's pages, you can still pivot execution by overwriting libc's GOT entries.

## Real-World Example

**2024 CTF - pwn.college "enlightened"**

- Binary had Full RELRO
- Exploit used off-by-one to corrupt heap chunk size
- Leaked libc via tcache poisoning
- Overwrote `__free_hook` (outside RELRO segment) with one-gadget
- **No GOT write required**

## Recent Developments (2022-2025)

| Change | Impact |
|--------|--------|
| **glibc 2.34+** - malloc/free hooks moved to `libc_malloc_debug.so` | Common Full RELRO bypass primitive removed |
| **binutils 2.39+** - RELRO page alignment fix (bug 30612) | Closed "RELRO gap" on 64KB page systems |
| **Debian 12, Fedora 35+** - Full RELRO default | Expect Full RELRO in most modern binaries |

## Common Questions

### "Why does my binary show Partial RELRO?"

You're missing `-z now`. Use both flags: `-Wl,-z,relro,-z,now`

### "Can I still exploit Full RELRO binaries?"

Yes, but you need different primitives:
- Look for writable code pointers outside GOT
- Use format string or partial overwrite
- Target shared library GOT (libc's GOT is Partial RELRO)
- Exploit heap corruption to reach `__free_hook` or similar

### "What's the performance impact?"

- **Partial RELRO**: Negligible
- **Full RELRO**: Measurable startup overhead (all symbols resolved at launch), no runtime overhead

### "Should I enable RELRO?"

**Yes, always.** Modern distributions ship with Full RELRO by default. It's a fundamental hardening measure with minimal cost.

## References

- [Why malloc hooks were removed from glibc](https://developers.redhat.com/articles/2021/08/25/securing-malloc-glibc-why-malloc-hooks-had-go)
- [Binutils bug 30612 - RELRO end alignment](https://lists.gnu.org/archive/html/bug-binutils/2023-08/msg00305.html)
- [checksec documentation](https://github.com/pwncollege/pwntools)
