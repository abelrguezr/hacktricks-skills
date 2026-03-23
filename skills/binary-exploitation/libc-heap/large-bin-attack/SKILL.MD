---
name: large-bin-attack
description: How to exploit the Large Bin Attack vulnerability in glibc heap management. Use this skill whenever the user mentions heap exploitation, large bins, glibc vulnerabilities, binary exploitation challenges, or needs to overwrite arbitrary addresses in libc. Trigger for CTF challenges involving heap corruption, when global_max_fast manipulation is needed, or when the user asks about heap-based arbitrary write primitives.
---

# Large Bin Attack Exploitation

A heap exploitation technique that leverages glibc's large bin management to achieve arbitrary address overwrites.

## When to Use This Attack

This attack is applicable when:
- You have a heap overflow or use-after-free that can corrupt chunk metadata
- The target glibc version is 2.35 or similar (check for `bk_nextsize` vulnerability)
- You need to overwrite an arbitrary address (commonly `global_max_fast`)
- You can control large chunk allocations (typically > 0x400 bytes)

## Core Vulnerability

In glibc 2.35+, the `P->bk_nextsize` pointer is not properly validated when inserting chunks into large bins. This allows an attacker to control where a chunk's address gets written during bin insertion.

## Required Conditions

1. **Allocate a large chunk** (Chunk1) - this will be your "victim" chunk
2. **Allocate a second large chunk** (Chunk2) - smaller than Chunk1 but in the same bin index
3. **Optional**: Create a chunk to prevent merging with top chunk
4. **Free Chunk1** - it goes to the large bin
5. **Allocate a new chunk larger than Chunk1** - Chunk1 stays in the bin
6. **Free Chunk2** - prepare for the attack
7. **Corrupt Chunk1's `bk_nextsize`** to point to `[target_address - 0x20]`
8. **Allocate a chunk larger than Chunk2** - Chunk2 gets inserted, overwriting `target_address` with Chunk2's address

## The Exploitation Mechanism

When glibc inserts a smaller chunk into a large bin, it executes this logic:

```c
if ((unsigned long)(size) < (unsigned long)chunksize_nomask(bck->bk)) {
    fwd = bck;                    // fwd = Chunk1
    bck = bck->bk;                // bck = Chunk1->bk
    
    victim->fd_nextsize = fwd->fd;                    // Chunk2->fd_nextsize = Chunk1->fd
    victim->bk_nextsize = fwd->fd->bk_nextsize;       // Chunk2->bk_nextsize = Chunk1->fd->bk_nextsize
    
    // THE VULNERABILITY: This line overwrites arbitrary memory
    fwd->fd->bk_nextsize->fd_nextsize = victim;       // Chunk1->fd->bk_nextsize->fd_nextsize = Chunk2
}
```

The key insight: `Chunk1->fd->bk_nextsize->fd_nextsize = Chunk2` means if you control `Chunk1->bk_nextsize`, you control where Chunk2's address gets written.

## Common Use Case: Overwriting global_max_fast

The most common application is overwriting `global_max_fast` to enable fast bin attacks with larger chunks:

1. Calculate the address of `global_max_fast` in libc
2. Set `Chunk1->bk_nextsize = &global_max_fast - 0x20`
3. When Chunk2 is inserted, `global_max_fast` gets overwritten with Chunk2's address
4. Now you can use fast bin attacks with chunks up to the new size

## Step-by-Step Exploitation Guide

### Step 1: Identify the Target Address

```python
# Find global_max_fast address in libc
libc_base = <libc_base_address>
global_max_fast = libc_base + libc.symbols['global_max_fast']
```

### Step 2: Set Up Chunk Layout

```python
# Allocate chunks to create the required layout
chunk1 = malloc(0x410)  # Large chunk 1
chunk2 = malloc(0x400)  # Large chunk 2 (smaller than chunk1)
chunk3 = malloc(0x100)  # Prevent top chunk merge

# Free and reallocate to get chunk1 in large bin
free(chunk1)
chunk4 = malloc(0x420)  # Larger than chunk1, keeps chunk1 in bin

# Free chunk2 for the attack
free(chunk2)
```

### Step 3: Corrupt the Metadata

```python
# Use your overflow/UAF to corrupt chunk1's bk_nextsize
# The target is global_max_fast - 0x20 (to account for fd_nextsize offset)
target = global_max_fast - 0x20

# Write target address to chunk1->bk_nextsize
# This is where your heap overflow or UAF comes in
overflow_data = p64(target)
write_to_chunk1_metadata(overflow_data)
```

### Step 4: Trigger the Overwrite

```python
# Allocate a chunk larger than chunk2 to trigger insertion
chunk5 = malloc(0x410)  # Larger than chunk2 (0x400)

# Now global_max_fast should be overwritten with chunk2's address
```

### Step 5: Verify and Continue

```python
# Verify the overwrite worked
# You should now be able to allocate chunks larger than the original global_max_fast
# and use fast bin attacks
```

## Alternative Scenarios

The core principle: **Add a smaller chunk to a large bin that needs to be inserted before a chunk you can corrupt.**

- The chunk you corrupt (X) must have its `bk_nextsize` controllable
- The chunk being inserted (smaller) will have its address written to `X->bk_nextsize->fd_nextsize`
- This gives you an arbitrary write primitive: `write(X->bk_nextsize->fd_nextsize, smaller_chunk_address)`

## Practical Considerations

### ASLR Bypass
- You'll need to leak an address to calculate libc base
- Common leaks: heap chunk addresses, GOT entries

### glibc Version
- This attack works on glibc 2.35+
- Check the target's glibc version before attempting
- Older versions may have different large bin structures

### Chunk Size Requirements
- Large bins typically start at 0x400 bytes
- Ensure your chunks are in the same bin index
- The "smaller" chunk must be smaller than the "victim" chunk

## Debugging Tips

1. **Use gdb with heap debugging**:
   ```bash
   gdb -q ./binary
   (gdb) set pagination off
   (gdb) call (void*)malloc(0x410)
   (gdb) info proc mappings
   ```

2. **Check chunk metadata**:
   ```bash
   (gdb) x/10gx $chunk_address - 0x10
   ```

3. **Verify the overwrite**:
   ```bash
   (gdb) x/gx &global_max_fast
   ```

## References

- [how2heap - large_bin_attack](https://github.com/shellphish/how2heap/blob/master/glibc_2.35/large_bin_attack.c)
- [guyinatuxedo - Large Bin Attack](https://guyinatuxedo.github.io/32-largebin_attack/largebin_explanation0/index.html)
- [La casa de papel - HackOn CTF 2024](https://7rocky.github.io/en/ctf/other/hackon-ctf/la-casa-de-papel/)

## Related Techniques

- Fast bin attacks (often used after global_max_fast overwrite)
- Unsorted bin attacks
- Tcache poisoning
- House of Force
- FSOP (Fake Stack Oriented Programming) - sometimes needed to complete exploitation
