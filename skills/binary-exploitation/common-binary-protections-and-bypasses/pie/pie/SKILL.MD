---
name: pie-exploitation
description: How to exploit Position Independent Executable (PIE) binaries by leaking addresses and calculating offsets. Use this skill whenever the user mentions PIE binaries, position-independent executables, address randomization, ASLR bypass, binary exploitation, CTF challenges with PIE, or needs to calculate base addresses from leaked addresses. Make sure to use this skill for any binary exploitation task involving memory addresses, even if the user doesn't explicitly mention PIE.
---

# PIE Exploitation Guide

This skill helps you exploit Position Independent Executable (PIE) binaries by understanding how to leak addresses and calculate offsets to bypass address randomization.

## Understanding PIE

**Position Independent Executable (PIE)** means the program can load at different memory locations each time it's executed. This prevents hardcoded addresses from working across runs.

### Key Concept: Relative Addresses

The trick to exploiting PIE binaries is exploiting **relative addresses**—the offsets between parts of the program remain the same even if absolute locations change.

**To bypass PIE, you only need to leak one address**, typically from the stack using vulnerabilities like format string attacks. Once you have an address, you can calculate others by their fixed offsets.

## Base Address Calculation

### Page Alignment Hint

PIE base addresses typically **end in `000`** (hex) because memory pages are the units of randomization, sized at `0x1000` bytes.

**Example:**
- If you leak an address at `0x649e1024`
- The base address is `0x649e1000` (mask off the last 3 hex digits)
- From there, calculate offsets of functions and locations

### Quick Calculation

```
leaked_address = 0x649e1024
base_address = leaked_address & ~0xFFF  # = 0x649e1000
```

## Bypass Methods

### 1. Disabled ASLR

If ASLR is disabled, a PIE binary always loads at the same address, making PIE useless. Check with:

```bash
readelf -l binary | grep "Type"
# or
checksec --file=binary
```

### 2. Given Leak (CTF Challenges)

In easy CTF challenges, you may be given the leak directly. Use it to calculate the base address and proceed with your exploit.

### 3. Brute-Force Stack Values

Brute-force EBP and EIP values in the stack until you leak the correct ones. This is less reliable but can work in some scenarios.

### 4. Format String Vulnerability (Most Common)

Use an arbitrary read vulnerability like format string to leak an address from the stack:

```python
# Example format string leak
payload = "%7$p"  # Leak 7th stack value
response = send_receive(payload)
leaked_addr = parse_address(response)
base_addr = leaked_addr & ~0xFFF
```

## Exploitation Workflow

1. **Identify PIE binary**: Check if the binary is compiled as PIE
2. **Find a leak primitive**: Format string, arbitrary read, or other vulnerability
3. **Leak one address**: Get any address from the binary's memory space
4. **Calculate base address**: Mask off the last 3 hex digits (align to page)
5. **Calculate target addresses**: Add known offsets to base address
6. **Execute exploit**: Use calculated addresses in your payload

## Common Offsets to Know

- **GOT entries**: Usually in `.got.plt` section, fixed offset from base
- **PLT stubs**: In `.plt` section, fixed offset from base
- **Functions**: In `.text` section, fixed offset from base
- **Global variables**: In `.data`/`.bss`, fixed offset from base

Use `readelf -s binary` or `objdump -t binary` to find offsets.

## Debugging Tips

### Check if Base Address is Correct

If your exploit isn't working, verify the base address:
- It should end in `000` (page-aligned)
- Compare with expected ranges for your architecture
- Use GDB to confirm: `info proc mappings`

### GDB Commands for PIE

```gdb
# After the program starts
info proc mappings
# Look for the binary's base address

# Or use
info sections
# Shows section addresses relative to base
```

## Example Exploit Structure

```python
from pwn import *

# Connect to target
p = process('./vuln')

# Leak an address (example: format string)
leaked = leak_address(p)

# Calculate base
base = leaked & ~0xFFF

# Calculate target function address
system_addr = base + 0x4521  # offset from readelf

# Build payload with calculated address
payload = b'A' * 72 + p64(system_addr)

# Send exploit
p.sendline(payload)
```

## When to Use This Skill

Use this skill when:
- You're working with a binary that has PIE enabled
- You need to calculate addresses for an exploit
- You've leaked an address and need to find the base
- You're debugging why an exploit isn't working (check base address alignment)
- You're solving CTF challenges involving PIE binaries
- You need to understand how to bypass address randomization

## References

- [ir0nstone PIE notes](https://ir0nstone.gitbook.io/notes/types/stack/pie)
- [PIE bypass example](https://ir0nstone.gitbook.io/notes/types/stack/pie/pie-bypass)
- [PIE exploit example](https://ir0nstone.gitbook.io/notes/types/stack/pie/pie-exploit)
