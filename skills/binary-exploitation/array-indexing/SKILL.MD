---
name: array-indexing-exploitation
description: How to identify and exploit array indexing vulnerabilities in binary exploitation challenges. Use this skill whenever the user mentions array bounds, index manipulation, off-by-one errors, array overflows, heap corruption through arrays, or any CTF/binary challenge involving array access. This skill covers colliding arrays, size field overwrites, GOT corruption, ROP chains triggered by array bugs, and heap exploitation through index manipulation. Make sure to use this skill for any binary exploitation task involving arrays, even if the user doesn't explicitly mention "array indexing" or "bounds checking".
---

# Array Indexing Exploitation

This skill helps you identify and exploit array indexing vulnerabilities in binary exploitation challenges. These vulnerabilities occur when programs fail to properly validate array indices, allowing attackers to overwrite arbitrary memory locations.

## When to Use This Skill

Use this skill when you encounter:
- Binary exploitation challenges with array-based data structures
- Off-by-one errors in array bounds checking
- Colliding arrays (separate arrays for data and metadata like sizes)
- Heap corruption through array index manipulation
- Stack-based array overflows
- Any CTF writeup or challenge mentioning array indexing, bounds, or index manipulation

## Core Concepts

### What Makes Array Indexing Vulnerable

Array indexing vulnerabilities happen when:
1. **No bounds checking**: The program doesn't verify the index is within valid range
2. **Integer overflow**: Index calculation wraps around to a valid-looking but wrong value
3. **Type confusion**: Different arrays share the same memory space with different interpretations
4. **Off-by-one errors**: Bounds check allows one position past the end

### Common Exploitation Patterns

#### Pattern 1: Colliding Arrays (Data + Size)

**Scenario**: Two parallel arrays - one stores data (addresses), one stores metadata (sizes)

**Exploitation**:
1. Use a negative or large index to write to the size array from the data array (or vice versa)
2. Overwrite a size field with an address (e.g., address of `free` in GOT)
3. Trigger the function at that address (e.g., call `free` with `/bin/sh` as argument)
4. Result: `system("/bin/sh")` if GOT entry was overwritten with `system` address

**Example from SwampCTF 19 DreamHeaps**:
- Two arrays: addresses array and sizes array
- Write arbitrary address as a size value
- Overwrite GOT entry for `free` with `system` address
- Call `free` with `/bin/sh` → shell

#### Pattern 2: Off-by-One on Stack

**Scenario**: Array on stack with off-by-one vulnerability allows writing one byte past the end

**Exploitation**:
1. Identify what's stored after the array (often a pointer or control data)
2. Use the off-by-one to corrupt that data
3. If it's a pointer, you can control where it points
4. Combine with ROP chains for full control

**Example from SecconCTF 2019 Sum**:
- 64-bit, no relro, canary, NX, no PIE
- Off-by-one in stack array controls a pointer
- Overwrite GOT `exit` with `pop rdi; ret`
- Add address to `main` on stack (loops back)
- Use ROP chain with `puts` to leak addresses
- Final ROP chain for ret2lib

#### Pattern 3: Size Field Manipulation (Heap)

**Scenario**: Heap chunks with size fields that can be overwritten through array indexing

**Exploitation**:
1. Overwrite size field to create artificial buffer overflow
2. Craft shellcode that meets size constraints (e.g., sorted, doubled values)
3. Preserve canary position if present
4. Overwrite RIP with return address to shellcode

**Example from CSAW 18 DoubleTrouble**:
- 64-bit, no NX
- Overwrite size to create buffer overflow
- Shellcode must be sorted smallest to biggest
- Canary must stay in position
- Overwrite RIP with `ret` address
- Point to leaked stack address for shellcode

#### Pattern 4: Information Leak + Ret2Lib

**Scenario**: Array indexing allows reading/writing stack data including addresses

**Exploitation**:
1. Use bad indexing to leak libc/heap addresses from stack
2. Calculate offsets to needed functions
3. Use ret2lib to call `system("/bin/sh")`
4. May need heap address to bypass checks

**Example from TU Guestbook**:
- 32-bit, no relro, no canary, NX, PIE
- Bad indexing leaks libc and heap addresses
- Buffer overflow for ret2lib
- Heap address needed to bypass validation check

## Step-by-Step Exploitation Workflow

### Step 1: Identify the Vulnerability

1. **Locate array operations** in the binary:
   - Look for array indexing patterns: `array[index]`, `ptr[index]`
   - Check if `index` comes from user input
   - Verify bounds checking exists and is correct

2. **Determine array location**:
   - Stack-based: Look for local variables, function parameters
   - Heap-based: Look for `malloc`, `calloc`, `new` calls
   - Global: Look for static arrays

3. **Identify what's adjacent**:
   - What data structures are near the array?
   - Are there size fields, pointers, or control data nearby?
   - Check for colliding arrays (data + metadata)

### Step 2: Analyze Protection Mechanisms

Check for:
- **NX/DEP**: Prevents shellcode execution
- **Canary**: Stack canary must be preserved or leaked
- **PIE**: Position Independent Executable requires address leaks
- **RELRO**: Full RELRO prevents GOT overwrites
- **ASLR**: Address Space Layout Randomization requires leaks

### Step 3: Choose Exploitation Strategy

Based on protections and vulnerability type:

| Protections | Strategy |
|-------------|----------|
| No NX, no canary | Shellcode on stack |
| NX, no canary | ROP chain or ret2lib |
| Canary present | Leak canary first, then exploit |
| PIE present | Leak addresses first |
| Full RELRO | Cannot use GOT, use heap or ROP |

### Step 4: Craft the Exploit

#### For Colliding Arrays:

```python
# Pseudocode for colliding array exploitation
# 1. Write address to size field
payload = struct.pack('<Q', got_entry_address)  # Address to write as size
payload += struct.pack('<Q', system_address)    # Address to write as data

# 2. Trigger the function
# When free() is called, it will actually call system()
```

#### For Off-by-One:

```python
# Pseudocode for off-by-one exploitation
# 1. Fill array to the edge
payload = b'A' * (array_size - 1)

# 2. Overwrite the adjacent data (e.g., pointer)
payload += struct.pack('<Q', target_address)

# 3. Trigger the use of corrupted data
```

#### For Size Field Manipulation:

```python
# Pseudocode for size field exploitation
# 1. Overwrite size to create overflow
payload = b'A' * (offset_to_size)
payload += struct.pack('<Q', large_size)

# 2. Craft constrained shellcode
# Must be sorted, doubled, preserve canary
shellcode = create_sorted_shellcode()

# 3. Overwrite RIP
payload += shellcode
payload += struct.pack('<Q', ret_address)
```

### Step 5: Handle Address Leaks

If PIE or ASLR is present:

1. **Find leak primitive**: Use the array bug to read addresses
2. **Calculate offsets**: `libc_base = leaked_address - libc_offset`
3. **Compute target addresses**: `system = libc_base + system_offset`
4. **Two-stage exploit**: Leak first, then exploit

### Step 6: Test and Refine

1. **Test locally**: Run against the binary with your exploit
2. **Check for crashes**: Adjust offsets if needed
3. **Verify shell**: Confirm you get a shell or expected behavior
4. **Handle edge cases**: Different inputs, timing issues

## Common Tools and Techniques

### Debugging

- **GDB with pwndbg/gef**: Essential for binary exploitation
- **Checksec**: Verify protection mechanisms
- **strings**: Find useful strings in the binary
- **objdump**: Disassemble and analyze the binary

### Exploit Development

- **pwntools**: Python library for exploit development
- **ROPgadget**: Find ROP gadgets
- **one_gadget**: Find one-gadget RCE payloads

### Key pwntools Functions

```python
from pwn import *

# Connect to binary
p = process('./vulnerable_binary')
# or
p = remote('target.com', 1337)

# Send data
p.sendline(payload)
p.send(payload)

# Receive data
p.recv()
p.recvline()
p.recvall()

# Pack addresses
p64(address)  # 64-bit little-endian
p32(address)  # 32-bit little-endian

# Calculate libc addresses
libc = ELF('./libc.so.6')
libc.address = leaked_address - libc.symbols['leaked_function']
```

## Example Exploit Template

```python
#!/usr/bin/env python3
from pwn import *

# Configuration
context.arch = 'amd64'
context.os = 'linux'

# Connect
p = process('./vulnerable_binary')
# p = remote('target.com', 1337)

# Load binaries
elf = ELF('./vulnerable_binary')
libc = ELF('./libc.so.6')

# Find addresses
system = libc.symbols['system']
binsh = next(libc.search(b'/bin/sh'))

# Craft payload for array indexing vulnerability
# Adjust offsets based on your analysis
payload = b'A' * offset_to_array
payload += p64(got_entry_to_overwrite)
payload += p64(system)

# Send payload
p.sendline(payload)

# Trigger the vulnerability
p.sendline(trigger_input)

# Get shell
p.interactive()
```

## Red Flags and Common Mistakes

1. **Wrong endianness**: Always use little-endian for x86/x64
2. **Wrong architecture**: 32-bit vs 64-bit packing
3. **Missing canary**: If canary is present, you must leak and preserve it
4. **PIE not handled**: Addresses are randomized, need leaks
5. **Off-by-one in your exploit**: Double-check all offsets
6. **Not testing locally**: Always test before submitting

## When This Skill Applies

Use this skill for:
- CTF challenges with array-based vulnerabilities
- Binary exploitation writeups mentioning index manipulation
- Heap exploitation through array bounds
- Stack-based array overflows
- Any challenge where array indexing is the attack vector

## Related Skills

- Heap exploitation (for heap-based array vulnerabilities)
- ROP chain construction (for NX-protected binaries)
- GOT/PLT exploitation (for non-RELRO binaries)
- Information leak techniques (for PIE/ASLR bypass)

## References

- [SwampCTF 19 DreamHeaps](https://guyinatuxedo.github.io/11-index/swampctf19_dreamheaps/index.html)
- [CSAW 18 DoubleTrouble](https://guyinatuxedo.github.io/11-index/csaw18_doubletrouble/index.html)
- [SecconCTF 2019 Sum](https://faraz.faith/2019-10-20-secconctf-2019-sum/)
- [TU Guestbook](https://guyinatuxedo.github.io/14-ret_2_system/tu_guestbook/index.html)
