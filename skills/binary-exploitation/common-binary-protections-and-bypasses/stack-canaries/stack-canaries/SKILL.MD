---
name: stack-canary-exploitation
description: How to understand, detect, and bypass stack canary protections in binary exploitation. Use this skill whenever the user mentions stack canaries, stack smashing, buffer overflow protections, __stack_chk_fail, or any CTF/pwn challenge involving stack-based mitigations. Also trigger when analyzing binaries with -fstack-protector, discussing canary leaks, or working on challenges where the stack protection is preventing exploitation.
---

# Stack Canary Exploitation

This skill covers understanding and bypassing stack canary protections in binary exploitation challenges.

## What Are Stack Canaries?

Stack canaries are a defense mechanism against buffer overflow attacks. A special random value (the "canary") is placed on the stack before the return address. Before a function returns, the program checks if the canary is still intact. If it's been modified, the program calls `__stack_chk_fail()` and terminates.

### Key Properties

**x64 binaries:**
- Canary is 8 bytes (qword)
- First 7 bytes are random
- Last byte is null (`0x00`)
- Stored at `fs:0x28`

**x86 binaries:**
- Canary is 4 bytes (dword)
- First 3 bytes are random
- Last byte is null (`0x00`)
- Stored at `gs:0x14`

> The null byte is least significant because it comes first on the stack (lower addresses). String functions stop at null bytes, so they won't read past the canary.

## Detection

### Check if canaries are enabled

```bash
# Using checksec
checksec --file=binary

# Look for __stack_chk_fail in symbols
nm binary | grep stack_chk
objdump -t binary | grep stack_chk

# Check compilation flags
readelf -p .comment binary | grep -i stack
```

### Identify protected functions

```bash
# Find functions with stack protector
objdump -d binary | grep -A 20 "<function_name>"
# Look for canary check patterns in disassembly
```

## Bypass Techniques

### 1. Leak the Canary

If you can read memory, leak the canary value and preserve it during your overflow.

**Common leak sources:**
- Format string vulnerabilities
- Arbitrary read primitives
- Information disclosure bugs
- Debug symbols in the binary

**Leak from TLS (x64):**
```python
# Canary is at fs:0x28
# Use a read primitive to read from this address
```

**Leak from TLS (x86):**
```python
# Canary is at gs:0x14
```

### 2. Brute-Force (Forked Processes)

If the binary uses `fork()` without `execve()`, child processes inherit the same canary. You can brute-force it byte-by-byte:

1. Send payload with first byte of canary
2. If program doesn't crash, that byte is correct
3. Repeat for remaining bytes
4. x86: 3 random bytes = 2^24 attempts worst case
5. x64: 7 random bytes = 2^56 attempts (not feasible)

**When this works:**
- Web servers using `fork()`
- Interactive programs that fork for each input
- Programs that don't call `execve()` after `fork()`

### 3. Modify GOT Entry of `__stack_chk_fail`

If the binary has **Partial RELRO** (not Full RELRO), you can overwrite the GOT entry:

1. Find `__stack_chk_fail` in GOT
2. Use arbitrary write to change it to a NOP or dummy function
3. Now canary checks won't terminate the program

**Check RELRO status:**
```bash
readelf -l binary | grep -i relro
# "RELRO" without "Full" means Partial RELRO
```

### 4. Master Canary Forgery (Threaded Binaries)

In multi-threaded programs, you might be able to modify the master canary in TLS:

1. Overflow a buffer in a thread's stack
2. Reach the TLS memory region (also mmap'd)
3. Modify the master canary value
4. The check compares two identical (modified) canaries

This works because thread stacks and TLS are both allocated via `mmap()`.

### 5. Overwrite Stack Pointers

Instead of reaching the return address, overwrite pointers stored on the stack:

- Function pointers
- String pointers
- File descriptors
- Any address stored in local variables

This bypasses the canary entirely by redirecting execution before the check.

## Practical Workflow

### Step 1: Analyze the Binary

```bash
# Check protections
checksec --file=binary

# Look for canary-related symbols
nm binary | grep -E "(stack_chk|__stack)"

# Check for format strings (potential leak)
grep -r "printf\|scanf\|gets" source.c 2>/dev/null
```

### Step 2: Identify Attack Surface

- Are there format string vulnerabilities? → Leak canary
- Is there arbitrary read/write? → Leak or modify GOT
- Does it fork without exec? → Brute-force (x86 only)
- Is it multi-threaded? → Master canary forgery
- Are there stack-stored pointers? → Pointer redirection

### Step 3: Choose Bypass Method

| Scenario | Best Bypass |
|----------|-------------|
| Format string vuln | Leak canary |
| Arbitrary read | Leak from TLS |
| Partial RELRO | Modify GOT |
| Fork without exec (x86) | Brute-force |
| Multi-threaded | Master canary forgery |
| Stack pointers present | Pointer redirection |

### Step 4: Implement the Exploit

**Template for canary leak + overflow:**

```python
from pwn import *

context.binary = elf = ELF('./binary')
context.arch = 'x64'  # or 'i386'

# Connect
p = process(elf.path)

# Leak canary (example via format string)
# Adjust based on actual vulnerability
leak = p.recvuntil(b'%p')
canary = u64(p.recv(8).ljust(8, b'\x00'))
print(f"Leaked canary: {hex(canary)}")

# Craft payload preserving canary
payload = b'A' * offset_to_canary
payload += p64(canary)  # Preserve canary
payload += b'B' * padding
payload += p64(rop_chain)  # Your actual payload

# Send exploit
p.sendline(payload)
p.interactive()
```

## Common Pitfalls

1. **Wrong canary size:** x64 = 8 bytes, x86 = 4 bytes
2. **Endianness:** Use `p64()`/`p32()` for proper encoding
3. **Null byte:** Remember the last byte is null, don't overwrite it
4. **TLS addresses:** `fs:0x28` (x64), `gs:0x14` (x86)
5. **Fork semantics:** `fork()` shares canary, `execve()` doesn't

## Tools

- **checksec:** Check binary protections
- **nm/objdump:** Find canary-related symbols
- **GDB:** Debug and inspect stack
- **pwntools:** Automate exploitation

## References

- [Guy In A Tuxedo - Stack Canaries](https://guyinatuxedo.github.io/7.1-mitigation_canary/index.html)
- [7rocky - Robot Factory Writeup](http://7rocky.github.io/en/ctf/htb-challenges/pwn/robot-factory/#canaries-and-threads)
- [7rocky - Scrambler Writeup](https://7rocky.github.io/en/ctf/other/securinets-ctf/scrambler/)
- [Code Blue - Master Canary Forging](https://www.slideshare.net/codeblue_jp/master-canary-forging-by-yuki-koike-code-blue-2015)
