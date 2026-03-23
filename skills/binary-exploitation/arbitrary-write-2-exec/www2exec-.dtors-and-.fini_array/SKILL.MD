---
name: binary-exploitation-dtors-fini-array
description: Exploit arbitrary write vulnerabilities using .dtors and .fini_array sections to execute shellcode at program exit. Use this skill whenever the user mentions binary exploitation, arbitrary write vulnerabilities, .dtors, .fini_array, destructor sections, or needs to execute code after main() returns. Also use when the user has write access to a binary's memory and wants to hijack program termination.
---

# Binary Exploitation: .dtors & .fini_array Exploitation

This skill helps you exploit **arbitrary write vulnerabilities** by hijacking the `.dtors` and `.fini_array` sections to execute shellcode when a program terminates.

## When to Use This Technique

Use this approach when:
- You have an **arbitrary write vulnerability** (can write to any address)
- You need to **execute shellcode** but don't have a direct code execution primitive
- The binary has **writable .dtors or .fini_array sections** (check with `objdump` or `rabin2`)
- You want to execute code **after main() returns**

## Understanding the Sections

### .dtors Section

The `.dtors` section contains **destructor function addresses** that execute **before the program finishes** (after `main()` returns).

**Key points:**
- Addresses are stored in the `.dtors` section
- Overwrite `__DTOR_END__` with your shellcode address to execute it
- Look for markers between `0xffffffff` and `0x00000000`
- If you only see these markers, no functions are registered - overwrite the `0x00000000` entry

### .fini_array Section

The `.fini_array` section is similar to `.dtors` - it contains **function addresses called before program termination**.

**Key points:**
- Functions are called in **reverse order** (last entry first)
- Each entry executes **only once** (prevents eternal loops by default)
- Start writing from the **last entry** to control execution order
- With **Full RELRO** or newer **Partial RELRO**, this section is **read-only** (check first!)

## Step-by-Step Exploitation Flow

### Step 1: Inspect the Binary

First, check if the binary has exploitable sections:

```bash
# Check .dtors section
objdump -s -j .dtors ./binary
rabin2 -s ./binary | grep "__DTOR"

# Check .fini_array section
objdump -s -j .fini_array ./binary
rabin2 -s ./binary | grep "__fini"
```

**What to look for:**
- `.dtors`: Values between `0xffffffff` and `0x00000000` (the `0x00000000` is writable)
- `.fini_array`: Function addresses you can overwrite
- **RELRO status**: Check if sections are read-only (not exploitable if they are)

### Step 2: Find a Shellcode Location

You need a **writable and executable** location for your shellcode:

```bash
# Check memory layout
readelf -l ./binary | grep -A 5 "GNU_STACK"

# Look for writable sections
objdump -h ./binary | grep -E "(writable|RW)"

# Common locations:
# - .data section
# - .bss section  
# - Heap (if you can control it)
# - Environment variables (if NX is disabled)
```

### Step 3: Craft the Exploit

**For .dtors:**
1. Find the address of `__DTOR_END__` (the `0x00000000` marker)
2. Place your shellcode in a writable/executable location
3. Use the arbitrary write vulnerability to overwrite `__DTOR_END__` with your shellcode address
4. When the program exits, your shellcode executes

**For .fini_array:**
1. Find the address of the last entry in `.fini_array`
2. Place your shellcode in a writable/executable location
3. Use the arbitrary write vulnerability to overwrite the entry with your shellcode address
4. When the program exits, your shellcode executes

### Step 4: Handle RELRO Protections

**Check RELRO status:**
```bash
readelf -l ./binary | grep -i relro
```

**If Full RELRO or Partial RELRO:**
- `.fini_array` is likely **read-only** - this technique won't work
- Consider alternative techniques:
  - Return-oriented programming (ROP)
  - Format string vulnerabilities
  - Other memory corruption primitives

## Eternal Loop Technique (Advanced)

If you have **at least 2 entries in .fini_array**, you can create an eternal loop:

1. **First write**: Call the vulnerable arbitrary write function again
2. **Second write**: Calculate the return address stored by `__libc_csu_fini` (the function calling `.fini_array` functions) and overwrite it with `__libc_csu_fini`'s address
3. This makes `__libc_csu_fini` call itself again, executing `.fini_array` functions repeatedly
4. You get multiple arbitrary writes to chain exploits

**Reference**: See [guyinatuxedo's insomnihack18 writeup](https://guyinatuxedo.github.io/17-stack_pivot/insomnihack18_onewrite/index.html) for a detailed example.

## Common Pitfalls

1. **Shellcode location**: Make sure your shellcode is in a **writable AND executable** location
2. **RELRO**: Check if sections are read-only before attempting
3. **Entry order**: `.fini_array` entries execute in **reverse order**
4. **Single execution**: Each `.fini_array` entry executes only once (unless you use the eternal loop technique)
5. **Address calculation**: Ensure you're writing to the correct address (the section address, not the function address)

## Example Exploit Structure

```python
from pwn import *

# Connect to target
p = process('./binary')

# Find addresses
binary = ELF('./binary')
dtors_end = binary.symbols['__DTOR_END__']
fini_array = binary.section('.fini_array').address

# Prepare shellcode
shellcode = asm(shellcraft.sh())

# Find writable location (example: .data section)
data_addr = binary.section('.data').address

# Write shellcode to memory
p.send(shellcode)

# Overwrite .dtors or .fini_array with shellcode address
# This depends on your arbitrary write vulnerability
# Example: write to dtors_end
exploit_payload = p64(shellcode_addr)
p.sendline(exploit_payload)

# Wait for program to exit and shellcode to execute
p.interactive()
```

## Debugging Tips

```bash
# GDB debugging
gdb ./binary
(gdb) break main
(gdb) continue
(gdb) info sections | grep -E "(dtors|fini)"
(gdb) x/20wx __DTOR_END__
(gdb) x/20wx __fini_array_end__

# Check if sections are writable
(gdb) info proc mappings
```

## When NOT to Use This Technique

- Binary has **Full RELRO** or **Partial RELRO** with read-only `.fini_array`
- No **arbitrary write vulnerability** available
- **NX/DEP** is enabled and you can't find a writable+executable location
- You need **immediate execution** (this technique only works at program exit)

## Related Techniques

- **ROP chains**: When you can't write shellcode but can chain existing code
- **Format string exploits**: When you have format string vulnerabilities
- **Heap exploitation**: When you have heap corruption primitives
- **Return address overwrites**: Classic stack buffer overflow technique
