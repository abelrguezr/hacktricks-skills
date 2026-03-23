---
name: got-plt-exploitation
description: How to exploit GOT/PLT vulnerabilities in binary exploitation challenges. Use this skill whenever the user mentions GOT overwrites, PLT hijacking, arbitrary write to GOT, libc GOT exploitation, free2system, strlen2system, or any binary exploitation task involving dynamic linking vulnerabilities. Make sure to use this skill for CTF pwn challenges, binary analysis, or when working with dynamically linked binaries that have partial RELRO.
---

# GOT/PLT Exploitation Guide

This skill helps you exploit Global Offset Table (GOT) and Procedure Linkage Table (PLT) vulnerabilities in dynamically linked binaries to achieve arbitrary code execution.

## Understanding GOT and PLT

### GOT (Global Offset Table)
- Stores addresses of external functions resolved at runtime
- Each entry corresponds to a symbol from external libraries
- First call: dynamic linker resolves address and stores in GOT
- Subsequent calls: use cached GOT address (no re-resolution)

### PLT (Procedure Linkage Table)
- Trampoline entries for external function calls
- First call: invokes dynamic linker to resolve address
- After resolution: GOT entry is updated, future calls use GOT directly

**Key insight**: GOT entries are writable (with partial RELRO), making them targets for exploitation.

## Exploitation Workflow

### Step 1: Check Binary Protections

First, determine if GOT exploitation is possible:

```bash
# Check RELRO status
readelf -l ./binary | grep -i relro
# or
checksec --file=./binary
```

- **Full RELRO**: GOT is read-only → GOT overwrite NOT possible
- **Partial RELRO**: GOT is writable → GOT overwrite IS possible
- **No RELRO**: GOT is writable → GOT overwrite IS possible

### Step 2: Locate GOT Entries

```bash
# Get GOT section address
objdump -s -j .got ./binary

# In GEF/pwndbg, examine GOT
gef➤ x/20x 0xADDR_GOT

# Or use GEF's built-in command
gef➤ got
```

### Step 3: Identify PLT Entries

```bash
# List PLT entries
objdump -j .plt -d ./binary

# Find specific function PLT address
objdump -j .plt -d ./binary | grep system
```

### Step 4: Choose Target Function

Select a function to overwrite in GOT:

**Ideal candidates:**
- Functions called with user-controlled parameters
- Functions that will be called after your overwrite
- Common targets: `free`, `strlen`, `printf`, `puts`, `gets`

**If `system` is in PLT:**
- Overwrite target GOT entry with `system` PLT address
- Control the parameter to pass `/bin/sh`

**If `system` is NOT in PLT:**
- First leak `system` address from libc
- Overwrite GOT entry with leaked `system` address

## Common Exploitation Techniques

### Technique 1: Free2System

**When to use:** Heap vulnerabilities where you can control chunk content and overwrite GOT.

**Steps:**
1. Overwrite `free` GOT entry with `system` address
2. Write `/bin/sh\x00` into a heap chunk
3. Trigger `free()` on that chunk
4. Result: `system("/bin/sh")` executes

**Example:**
```python
# Overwrite free GOT with system
payload = p64(system_addr)
# Write /bin/sh in chunk
payload += b'/bin/sh\x00'
# Trigger free on that chunk
```

### Technique 2: Strlen2System

**When to use:** Binary calls `strlen` or `puts` with user input.

**Steps:**
1. Overwrite `strlen` GOT entry with `system` address
2. Send `/bin/sh` as input
3. When `strlen` is called, it executes `system("/bin/sh")`

**Why it works:** `puts` internally calls `strlen` with the same argument.

### Technique 3: Heap-Based GOT Overwrite

**When to use:** Fastbin heap vulnerabilities.

**Steps:**
1. Use fastbin to allocate chunk overlapping GOT
2. Overwrite function pointer (usually `free`) in GOT
3. Point it to `system`
4. Free a chunk containing `/bin/sh`

## Practical Commands Reference

### Binary Analysis
```bash
# Check protections
checksec --file=./binary

# View GOT section
objdump -s -j .got ./binary

# View PLT section
objdump -j .plt -d ./binary

# Find symbol addresses
nm ./binary | grep system
readelf -s ./binary | grep system
```

### Debugging with GEF
```bash
# Start debugging
gdb ./binary

# View GOT table
gef➤ got

# Examine GOT at address
gef➤ x/20x 0xADDR

# Set breakpoint on function
gef➤ break function_name

# Continue execution
gef➤ continue
```

### Finding One Gadget
```bash
# Find one-gadget RCE payloads
one_gadget /lib/x86_64-linux-gnu/libc.so.6

# Filter for specific constraints
one_gadget /lib/x86_64-linux-gnu/libc.so.6 --no-fd
```

## Exploitation Checklist

Before attempting GOT exploitation, verify:

- [ ] Binary has partial or no RELRO (not full RELRO)
- [ ] GOT is writable (confirmed via checksec/readelf)
- [ ] Target function exists in GOT
- [ ] You can control parameters passed to target function
- [ ] You have a way to trigger the function call after overwrite
- [ ] If using `system`, either it's in PLT or you can leak libc address

## Common Pitfalls

1. **Full RELRO**: GOT is read-only, cannot overwrite
2. **ASLR**: Need to leak addresses first if ASLR is enabled
3. **Wrong GOT entry**: Ensure you're overwriting the correct function
4. **Timing**: Overwrite must happen before the function is called
5. **Parameter control**: Target function must accept controllable input

## Next Steps

After GOT exploitation:

1. **If successful**: You have RCE, spawn shell
2. **If failed**: Check if Full RELRO is enabled, try alternative techniques
3. **For libc GOT**: Consider targeting internal libc functions
4. **For heap vulnerabilities**: Combine with fastbin attacks

## References

- [GOT Overwrite Exploitation](https://ir0nstone.gitbook.io/notes/types/stack/got-overwrite/exploiting-a-got-overwrite)
- [One Gadgets and Malloc Hook](https://ir0nstone.gitbook.io/notes/types/stack/one-gadgets-and-malloc-hook)
- [CTF Wiki - Heap Exploitation](https://ctf-wiki.mahaloz.re/pwn/linux/glibc-heap/chunk_extend_overlapping/)
- [Code Execution on Last libc](https://github.com/nobodyisnobody/docs/blob/main/code.execution.on.last.libc/README.md)
