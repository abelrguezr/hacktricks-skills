---
name: elf-binary-analysis
description: Analyze ELF binary files for reverse engineering, security research, and exploitation. Use this skill whenever the user needs to understand ELF structure, analyze program headers, section headers, symbols, relocations, GOT/PLT, or identify binary protections like RELRO, stack canaries, and PIE. Trigger on any request involving ELF files, binary analysis, readelf output interpretation, or exploitation reconnaissance.
---

# ELF Binary Analysis

A comprehensive guide for analyzing ELF (Executable and Linkable Format) binaries for reverse engineering, security research, and exploitation.

## Quick Start

When analyzing an ELF binary, start with this reconnaissance sequence:

```bash
# Basic file info
file <binary>

# Program headers (memory layout, protections)
readelf -lW <binary>

# Section headers (detailed structure)
objdump -h <binary>

# Symbols (functions, variables)
readelf -sW <binary>

# Dynamic section (dependencies, relocations)
readelf -d <binary>

# Relocations (GOT/PLT entries)
readelf -r <binary>
```

## Program Headers

Program headers tell the loader how to map the binary into memory. Use `readelf -lW` to view them.

### Key Program Header Types

| Type | Purpose | Exploitation Relevance |
|------|---------|------------------------|
| **PHDR** | Program header table itself | Contains metadata about the binary structure |
| **INTERP** | Dynamic loader path | Missing in static binaries; affects ret2dlresolve feasibility |
| **LOAD** | Memory segments to load | Shows memory layout, permissions (R/W/X), and sizes |
| **DYNAMIC** | Dynamic linking info | Contains NEEDED libraries, relocations, flags |
| **NOTE** | Metadata (build-id, properties) | May contain CPU features like CET (IBT/SHSTK) |
| **GNU_EH_FRAME** | Stack unwind tables | Used by debuggers, C++ exceptions |
| **GNU_STACK** | Stack execution flag | `RW` = executable stack (rare), `R` = non-executable |
| **GNU_RELRO** | Relocation read-only | Partial vs Full RELRO affects GOT overwrite attacks |
| **TLS** | Thread-local storage | Per-thread variable storage |

### LOAD Segment Analysis

Each LOAD segment specifies:
- **Offset**: Where in the file to read from
- **VirtAddr**: Virtual address in memory
- **FileSiz**: Bytes to copy from file
- **MemSiz**: Total memory size (may be larger for .bss)
- **Flg**: Permissions (R=read, W=write, E=execute)

Example interpretation:
```
LOAD           0x000000 0x0000000000000000 0x0000000000000000 0x003f7c 0x003f7c R E 0x10000
```
This segment loads 0x3f7c bytes from file offset 0 to virtual address 0x0 with read+execute permissions.

### GNU_STACK - Stack Executability

Check if the stack is executable:
```bash
readelf -l ./binary | grep GNU_STACK
```

- `RW` = executable stack (vulnerable to shellcode on stack)
- `R` = non-executable stack (NX/DEP enabled)

Toggle for testing:
```bash
execstack -c ./binary  # Clear executable flag
execstack -s ./binary  # Set executable flag
```

### GNU_RELRO - Relocation Read-Only

RELRO marks certain memory regions as read-only after dynamic linking:

- **Partial RELRO**: `.plt.got` remains writable (GOT overwrite possible)
- **Full RELRO**: All GOT entries are read-only (GOT overwrite blocked)

Check RELRO status:
```bash
readelf -l ./binary | grep GNU_RELRO
readelf -d ./binary | grep FLAGS
```

Look for `BIND_NOW` or `NOW` flag for Full RELRO.

## Section Headers

Section headers provide detailed information about binary contents. Use `objdump -h` or `readelf -S`.

### Important Sections

| Section | Contents | Exploitation Relevance |
|---------|----------|------------------------|
| **.text** | Executable code | ROP gadget hunting, shellcode placement |
| **.data** | Initialized globals | Data structures, potential targets |
| **.bss** | Uninitialized globals | Zero-initialized, writable |
| **.rodata** | Read-only data | Strings, constants |
| **.got** | Global Offset Table | Function addresses (writable if Partial RELRO) |
| **.got.plt** | PLT GOT entries | Lazy binding targets |
| **.plt** | Procedure Linkage Table | Lazy function call stubs |
| **.init/.fini** | Init/fini functions | Early/late execution hooks |
| **.init_array/.fini_array** | Constructor/destructor arrays | Hijackable under Partial RELRO |
| **.dynamic** | Dynamic linking info | NEEDED libs, relocations, flags |
| **.tdata/.tbss** | Thread-local data | Per-thread variables |

### Section Flags

- **ALLOC**: Section occupies memory at runtime
- **LOAD**: Section is loaded from file
- **READONLY**: Read-only at runtime
- **CODE**: Contains executable code
- **DATA**: Contains data

## Symbols

Symbols are named locations (functions, variables) in the binary. Use `readelf -sW`.

### Symbol Table Structure

```
Num:    Value          Size Type    Bind   Vis      Ndx Name
  3: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND strlen@GLIBC_2.17
```

| Field | Meaning |
|-------|--------|
| **Num** | Symbol index |
| **Value** | Address (or 0 for undefined) |
| **Size** | Symbol size in bytes |
| **Type** | FUNC, OBJECT, SECTION, NOTYPE, TLS, GNU_IFUNC |
| **Bind** | LOCAL, GLOBAL, WEAK |
| **Vis** | DEFAULT, HIDDEN, PROTECTED |
| **Ndx** | Section index (UND = undefined/external) |
| **Name** | Symbol name (may include version) |

### Symbol Binding

- **LOCAL**: Visible only within the binary
- **GLOBAL**: Visible to other binaries/libraries
- **WEAK**: Can be overridden by strong symbols

### GNU IFUNC (Indirect Functions)

IFUNC symbols have resolvers that select implementations at load time:

```bash
readelf -sW ./binary | rg -i "IFUNC"
```

Common for CPU dispatch (e.g., optimized string functions).

### Symbol Versioning

Modern glibc uses versioned symbols: `strlen@GLIBC_2.17`

For manual relocations (ret2dlresolve), you must supply the correct version index.

## Dynamic Section

The dynamic section contains information for the dynamic linker. Use `readelf -d`.

### Key Dynamic Entries

| Tag | Purpose |
|-----|--------|
| **NEEDED** | Required shared libraries |
| **INIT/FINI** | Init/fini function addresses |
| **INIT_ARRAY/FINI_ARRAY** | Constructor/destructor arrays |
| **INIT_ARRAYSZ/FINI_ARRAYSZ** | Array sizes |
| **PLTGOT** | GOT/PLT base address |
| **PLTRELSZ/PLTREL/JMPREL** | PLT relocation info |
| **RELA/RELASZ/RELAENT** | Relocation table info |
| **FLAGS** | BIND_NOW, NOW (Full RELRO) |
| **VERNEED/VERNEEDNUM/VERSYM** | Symbol versioning |
| **RPATH/RUNPATH** | Library search paths |

### Library Search Order

The dynamic linker searches for libraries in this order:

1. `LD_LIBRARY_PATH` (ignored for setuid/secure-execution)
2. `DT_RPATH` (only if `DT_RUNPATH` absent)
3. `DT_RUNPATH`
4. `ld.so.cache`
5. Default directories (`/lib64`, `/usr/lib64`, etc.)

Check RPATH/RUNPATH:
```bash
readelf -d ./binary | egrep -i 'r(path|unpath)'
```

Test library resolution:
```bash
LD_DEBUG=libs ./binary 2>&1 | grep -i find
```

## Relocations

Relocations adjust addresses after the binary is loaded. Use `readelf -r`.

### Relocation Types

| Type | Purpose |
|------|--------|
| **RELATIVE** | Adjust addresses based on load bias |
| **GLOB_DAT** | Global data symbol (write address to GOT) |
| **JUMP_SLOT** | Function symbol (PLT lazy binding) |
| **IRELATIVE** | Runtime relocation with resolver |

### GOT (Global Offset Table)

The GOT stores addresses of external functions and variables. Key points:

- **Lazy binding**: First call to a function resolves it via PLT, then updates GOT
- **GOT overwrite**: If Partial RELRO, you can overwrite GOT entries to redirect calls
- **Full RELRO**: GOT is read-only, GOT overwrite attacks blocked

### PLT (Procedure Linkage Table)

The PLT enables lazy function binding:

1. Call `func@plt` → jumps to PLT stub
2. First call: PLT stub resolves address via GOT, updates GOT, calls real function
3. Subsequent calls: Direct call via GOT entry

### Modern Linking Behaviors

| Flag | Effect |
|------|--------|
| **`-z now`** | Full RELRO, disables lazy binding |
| **`-fno-plt`** | Direct GOT calls instead of PLT stubs |
| **`-z pack-relative-relocs`** | Compact relative relocations (DT_RELR) |

Check for packed relocations:
```bash
readelf -d ./binary | egrep -i "DT_RELR|RELRSZ|RELRENT"
```

## Program Initialization

The program doesn't always start at `main`. Initialization order:

1. Load binary into memory, initialize `.data` and zero `.bss`
2. Initialize dependencies and perform dynamic linking
3. Execute `PREINIT_ARRAY` functions (if present)
4. Execute `INIT_ARRAY` functions
5. Call `INIT` function (if present)
6. Call entry point (`main` for programs)

### Constructor/Destructor Attributes

```c
__attribute__((constructor))  // Runs before main
__attribute__((destructor))   // Runs after main
```

These functions are added to `INIT_ARRAY` and `FINI_ARRAY`.

### Exploitation Note

Under **Partial RELRO**, `INIT_ARRAY` and `FINI_ARRAY` are writable before `ld.so` marks them read-only. You can hijack control flow by overwriting entries with your function addresses.

## Thread-Local Storage (TLS)

TLS variables have per-thread storage:

```c
__thread int my_var;           // C
__thread_local int my_var;     // C++
```

- Stored in `.tdata` (initialized) and `.tbss` (uninitialized)
- Each thread has its own copy
- `__TLS_MODULE_BASE` points to the TLS base address

## Auxiliary Vector (auxv)

The kernel passes an auxiliary vector with runtime information:

| Entry | Purpose |
|-------|--------|
| **AT_RANDOM** | 16 random bytes (stack canary seed) |
| **AT_SYSINFO_EHDR** | vDSO base address |
| **AT_EXECFN** | Executable path |
| **AT_BASE** | Dynamic linker base |
| **AT_PAGESZ** | System page size |

Access from code:
```c
#include <sys/auxv.h>
printf("AT_RANDOM=%p\n", (void*)getauxval(AT_RANDOM));
printf("AT_SYSINFO_EHDR=%p\n", (void*)getauxval(AT_SYSINFO_EHDR));
```

From `/proc`:
```bash
cat /proc/$(pidof target)/auxv | xxd
```

## Common Analysis Commands

### Full Reconnaissance

```bash
# File type and architecture
file ./binary

# Check protections
checksec --file=./binary  # If available

# Program headers
readelf -lW ./binary

# Section headers
objdump -h ./binary
readelf -S ./binary

# Symbols
readelf -sW ./binary
nm ./binary

# Dynamic section
readelf -d ./binary

# Relocations
readelf -r ./binary

# Disassembly
objdump -d ./binary
```

### Protection Detection

```bash
# PIE
readelf -h ./binary | grep Type
# DYN = PIE, EXEC = non-PIE

# Stack executable
readelf -l ./binary | grep GNU_STACK

# RELRO
readelf -l ./binary | grep GNU_RELRO
readelf -d ./binary | grep -E "BIND_NOW|NOW"

# Canary (check for __stack_chk_fail)
readelf -sW ./binary | grep stack_chk

# FORTIFY_SOURCE (check for _chk functions)
readelf -sW ./binary | grep _chk

# CET (Control-flow Enforcement Technology)
readelf -n ./binary | grep -i "ibt\|shstk"
```

### Finding Useful Symbols

```bash
# System call functions
readelf -sW ./binary | grep -E "sys_|__kernel_"

# Memory functions
readelf -sW ./binary | grep -E "malloc|free|memcpy|strcpy"

# String functions
readelf -sW ./binary | grep -E "str|printf|scanf"

# File I/O
readelf -sW ./binary | grep -E "open|read|write|close"

# Process functions
readelf -sW ./binary | grep -E "fork|exec|exit"
```

## Exploitation Considerations

### When GOT/PLT is Available (Partial RELRO)

- **GOT overwrite**: Redirect function calls to shellcode or ROP chain
- **ret2dlresolve**: Force dynamic linker to resolve arbitrary symbols
- **PLT stubs**: Use for ROP gadgets (call + ret sequences)

### When GOT/PLT is Not Available (Full RELRO)

- **ROP/SROP**: Use existing code gadgets
- **Format string**: Leak addresses, overwrite memory
- **Heap exploitation**: Use heap corruption techniques
- **Other writable pointers**: Look for function pointers in data structures

### PIE Considerations

- **Address randomization**: Need to leak an address to calculate offsets
- **Common leak sources**: Format strings, heap metadata, infoleaks
- **vDSO**: `AT_SYSINFO_EHDR` provides a stable base for gadgets

### Static vs Dynamic Binaries

| Type | Characteristics |
|------|----------------|
| **Dynamic (ET_DYN + INTERP)** | Uses loader, has PLT/GOT, standard exploitation |
| **Static-PIE (ET_DYN, no INTERP)** | No loader, relocations applied by kernel, no PLT resolution |
| **Static (ET_EXEC)** | Fixed addresses, no ASLR, no dynamic linking |

## References

- [GNU ELF Format](https://refspecs.linuxfoundation.org/elf/elf.pdf)
- [readelf Manual](https://man7.org/linux/man-pages/man1/readelf.1.html)
- [ld.so(8) - Dynamic Loader](https://man7.org/linux/man-pages/man8/ld.so.8.html)
- [getauxval(3) - Auxiliary Vector](https://man7.org/linux/man-pages/man3/getauxval.3.html)
- [GCC Function Attributes](https://gcc.gnu.org/onlinedocs/gcc/Common-Function-Attributes.html)
