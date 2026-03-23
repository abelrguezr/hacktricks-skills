---
name: arm64-ret2syscall-exploitation
description: How to perform ret2syscall attacks on ARM64 binaries to execute syscalls like execve. Use this skill whenever the user mentions ARM64 exploitation, ret2syscall, syscall exploitation, buffer overflow on ARM64, or wants to execute arbitrary syscalls through ROP chains. This is specifically for ARM64 architecture exploitation scenarios.
---

# ARM64 Ret2Syscall Exploitation

A skill for performing return-to-syscall attacks on ARM64 binaries to execute arbitrary syscalls (typically `execve` for shell access).

## When to Use This Skill

Use this skill when:
- You're working with ARM64/aarch64 binaries with buffer overflow vulnerabilities
- You need to execute syscalls through ROP chains on ARM64
- You want to bypass protections like PIE/ASLR using libc gadgets
- You're doing CTF challenges or security research on ARM64 systems

## Prerequisites

- ARM64 binary with buffer overflow vulnerability
- `pwn` library (pwntools)
- `ROPgadget` or similar for finding gadgets
- Knowledge of ARM64 calling convention

## ARM64 Syscall Convention

For `execve` syscall on ARM64:
- `x8`: syscall number (221 or 0xdd for execve)
- `x0`: pointer to filename (e.g., "/bin/sh")
- `x1`: pointer to argv array (NULL for no args)
- `x2`: pointer to envp array (NULL for no env)

## Exploitation Workflow

### Step 1: Analyze the Binary

```bash
# Check binary architecture
file ./vulnerable_binary

# Check protections
checksec ./vulnerable_binary

# Find /bin/sh in libc
readelf -s /usr/lib/aarch64-linux-gnu/libc.so.6 | grep "/bin/sh"
```

### Step 2: Find ROP Gadgets

Use `ROPgadget` to find gadgets that:
1. Load values into registers from the stack
2. Set x8 to the syscall number
3. Execute `svc #0` (syscall instruction)

```bash
# Find gadgets in libc
ROPgadget --binary /usr/lib/aarch64-linux-gnu/libc.so.6 | grep -E "(ldr|mov|svc|blr)"

# Look for gadgets that load from stack
ROPgadget --binary /usr/lib/aarch64-linux-gnu/libc.so.6 | grep "ldr.*\[sp"
```

### Step 3: Build the ROP Chain

The typical chain structure:
1. **Buffer overflow padding** - Fill to reach return address
2. **Gadget to load registers** - Load x0, x1, x2, x5 from stack
3. **Stack values** - Place /bin/sh address, NULL, NULL, syscall gadget address
4. **Syscall gadget** - Set x8 and execute svc #0

### Step 4: Write the Exploit

Use the `arm64_ret2syscall_template.py` script in this skill's scripts directory as a starting point. Customize:
- Binary path and libc path
- Stack offset (determine via pattern overflow)
- Gadget addresses (from ROPgadget output)
- /bin/sh address (from libc)

## Key Considerations

### Register Preservation
ARM64 ROP gadgets often preserve certain registers. Check gadget instructions carefully:
- `ldp` loads pairs of registers
- `ldr` loads single registers
- `bl`/`blr` make calls

### Stack Alignment
ARM64 requires 16-byte stack alignment. Ensure your ROP chain maintains proper alignment.

### ASLR Handling
- If ASLR is disabled: Use fixed libc addresses
- If ASLR is enabled: Leak libc address first, then calculate offsets

### PIE Handling
- If PIE is disabled: Binary addresses are fixed
- If PIE is enabled: Leak binary base address first

## Common Gadgets

Look for these patterns in libc:

```armasm
; Load registers from stack
ldp x3, x0, [sp, #8]      ; Load x3, x0 from stack
ldp x1, x4, [sp, #0x18]   ; Load x1, x4 from stack
ldr x5, [sp, #0x58]       ; Load x5 from stack
ldr x2, [sp, #0xe0]       ; Load x2 from stack
blr x5                    ; Branch to address in x5

; Syscall gadget
mov x8, #0xdd             ; Set syscall number (execve)
svc #0                    ; Execute syscall
```

## Debugging Tips

1. **Use GDB with pwndbg/gef** for ARM64 debugging
2. **Check register values** before syscall execution
3. **Verify stack layout** matches gadget expectations
4. **Test with known-good addresses** before final exploit

## Security Notes

This skill is for:
- CTF competitions and security research
- Learning exploitation techniques
- Security auditing of your own systems

Do not use on systems you don't own or have explicit permission to test.

## References

- [ARM64 Calling Convention](https://github.com/hacktricks/hacktricks/blob/master/macOS-hardening/macOS-security-and-privilege-escalation/macOS-apps-inspecting-debugging-and-fuzzing/arm64-basic-assembly.md)
- [pwntools Documentation](https://docs.pwntools.com/)
- [ROPgadget](https://github.com/JonathanSalwan/ROPgadget)
