---
name: atexit-exploitation
description: Guide for exploiting arbitrary write vulnerabilities through atexit handlers, link_map manipulation, and TLS dtor_list overwrites. Use this skill whenever the user mentions atexit, exit handlers, link_map, TLS destructors, PTR_MANGLE, __run_exit_handlers, or needs to convert an arbitrary write primitive into code execution via program exit. Also use when analyzing binaries for exit handler vulnerabilities or crafting exploits that trigger code execution on program termination.
---

# Atexit Exploitation Guide

This skill helps you exploit arbitrary write vulnerabilities by hijacking exit handlers to achieve code execution when a program terminates via `return` or `exit()`.

## When to Use This Skill

Use this skill when:
- You have an arbitrary write primitive and need code execution
- The target program exits via `return` or `exit()` (not `_exit()`)
- You're analyzing binaries for atexit-based vulnerabilities
- You need to understand PTR_MANGLE/PTR_DEMANGLE pointer obfuscation
- You're working with link_map, TLS dtor_list, or exit_function_list structures

## Core Concepts

### Exit Handler Execution Flow

When a program exits via `return` or `exit()`:
1. `__run_exit_handlers()` is called
2. TLS destructors are executed via `__call_tls_dtors()`
3. atexit/on_exit registered functions are called
4. DT_FINI_ARRAY destructors are executed

**Critical**: If the program exits via `_exit()` syscall, exit handlers are NOT executed. Always verify with a breakpoint on `__run_exit_handlers()`.

### Pointer Mangling (x86/x64)

On x86/x64, function pointers in exit handlers are obfuscated:
- XORed with a random `PTR_MANGLE` cookie
- Rotated 17 bits right

```asm
mov    rax, QWORD PTR [rbx]      ; load mangled ptr
ror    rax, 0x11                 ; rotate right 17 bits
xor    rax, QWORD PTR fs:0x30    ; XOR with PTR_MANGLE cookie
```

**Other architectures** (m68k, mips32, mips64, aarch64, arm, hppa) do NOT implement mangling - the pointer is used as-is.

## Exploitation Techniques

### Technique 1: link_map DT_FINI_ARRAY Overwrite

The `link_map` structure contains `l_info[DT_FINI_ARRAY]` which points to an array of destructor functions.

**Attack vectors:**

1. **Fake fini_array**: Overwrite `l_info[DT_FINI_ARRAY]` to point to a fake `Elf64_Dyn` structure in controlled memory (e.g., `.bss`)
   - The fake structure's `d_un.d_ptr` should point to your one_gadget address
   - Account for `map->l_addr` offset in calculations

2. **Stack pointer overwrite**: ld.so leaves a pointer to `link_map` on the stack. Overwrite it to point to a fake fini_array containing your one_gadget.

**Structure layout:**
```c
struct Elf64_Dyn {
    Elf64_Sxval d_tag;  // DT_FINI_ARRAY = 0x1e
    union {
        Elf64_Xword d_val;  // function address (one_gadget)
        Elf64_Addr d_ptr;   // offset from l_addr
    } d_un;
};
```

### Technique 2: TLS dtor_list Overwrite

The `tls_dtor_list` is a linked list of destructor functions stored near the stack canary.

**Structure:**
```c
struct dtor_list {
    dtor_func func;      // function pointer (mangled)
    void *obj;           // argument to function
    struct link_map *map;
    struct dtor_list *next;
};
```

**Exploitation steps:**
1. Overflow to overwrite the PTR_MANGLE cookie with 0x00 (bypasses XOR)
2. Overwrite the stack canary
3. Chain multiple dtor_list entries with your function addresses
4. Account for 17-bit rotation when calculating mangled pointers

**Mangled pointer calculation:**
```python
def mangle_ptr(addr, cookie):
    # Rotate right 17 bits, then XOR with cookie
    rotated = ((addr >> 17) | (addr << (64 - 17))) & 0xffffffffffffffff
    return rotated ^ cookie

def demangle_ptr(mangled, cookie):
    # XOR with cookie, then rotate left 17 bits
    xored = mangled ^ cookie
    return ((xored << 17) | (xored >> (64 - 17))) & 0xffffffffffffffff
```

### Technique 3: exit_function_list Overwrite

The `initial` structure contains an array of exit functions with different flavors:

```c
struct exit_function {
    enum exit_function_flavor flavor;
    union {
        void (*at) (void);           // ef_at
        void (*on) (int, void *);    // ef_on (with arg)
        void (*cxa) (void *, int);   // ef_cxa (with arg)
    } func;
};
```

**Flavors:**
- `ef_at`: atexit() registered function, no arguments
- `ef_on`: on_exit() registered function, takes (status, arg)
- `ef_cxa`: C++ destructor, takes (arg, status)

**Exploitation:**
1. Leak or erase the PTR_MANGLE cookie
2. Overwrite a `cxa` or `on` entry with `system` and `/bin/sh` as argument
3. The function will be demangled and called during exit

## Practical Workflow

### Step 1: Verify Exit Handler Execution

```gdb
# Set breakpoint on exit handler
break __run_exit_handlers
# Run program and verify breakpoint is hit
run
```

If breakpoint is NOT hit, the program uses `_exit()` and these techniques won't work.

### Step 2: Locate Target Structures

```gdb
# Find link_map (usually in ld.so)
info proc mappings | grep ld.so
# Find TLS dtor_list
gef> tls
# Find initial structure
gef> p initial
```

### Step 3: Calculate Mangled Pointers

Use the `calculate_mangled_pointer.py` script (see scripts/) to compute the correct mangled values for your target addresses.

### Step 4: Craft the Exploit

1. **For link_map**: Create fake Elf64_Dyn structure with one_gadget
2. **For TLS**: Chain dtor_list entries with mangled function pointers
3. **For exit_function_list**: Overwrite flavor and function pointer fields

### Step 5: Trigger Exit

Ensure the program exits via `return` or `exit()`, not `_exit()` or `abort()`.

## Architecture Considerations

| Architecture | PTR_MANGLE | Exploitation Difficulty |
|--------------|------------|------------------------|
| x86/x64      | Yes        | Harder (need cookie)   |
| aarch64      | No         | Easier (direct ptr)    |
| arm          | No         | Easier (direct ptr)    |
| mips32/64    | No         | Easier (direct ptr)    |
| m68k         | No         | Easier (direct ptr)    |
| hppa         | No         | Easier (direct ptr)    |

## Common Pitfalls

1. **Program uses _exit()**: Exit handlers won't run. Check with GDB breakpoint.
2. **Wrong mangling calculation**: Remember 17-bit rotation + XOR, not just XOR.
3. **ASLR**: Need to leak libc base to calculate one_gadget addresses.
4. **Stack canary**: TLS technique requires overwriting canary first.
5. **Architecture mismatch**: Mangling only applies to x86/x64.

## References

- [Notes on Abusing Exit Handlers](https://m101.github.io/binholic/2017/05/20/notes-on-abusing-exit-handlers.html)
- [Code Execution on Last libc](https://github.com/nobodyisnobody/docs/blob/main/code.execution.on.last.libc/README.md)
- [DanteCTF 2023 - Sentence To Hell](https://github.com/nobodyisnobody/write-ups/tree/main/DanteCTF.2023/pwn/Sentence.To.Hell)
- [Angstrom CTF 2021 - Wallstreet](https://activities.tjhsst.edu/csc/writeups/angstromctf-2021-wallstreet)

## Scripts

See `scripts/` directory for helper tools:
- `calculate_mangled_pointer.py` - Compute mangled/demangled pointers
- `generate_fake_structures.py` - Create fake Elf64_Dyn and dtor_list structures
- `find_exit_handlers.py` - Analyze binaries for exit handler vulnerabilities
