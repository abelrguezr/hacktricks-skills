---
name: house-of-rabbit
description: House of Rabbit heap exploitation technique for creating overlapping or fake chunks by manipulating fast bin metadata. Use this skill whenever the user mentions heap exploitation, fast bin attacks, chunk manipulation, malloc_consolidate, overlapping chunks, fake chunks, or binary exploitation involving heap corruption. This is essential for CTF challenges and real-world heap vulnerabilities where you can modify chunk metadata.
---

# House of Rabbit Exploitation

The **House of Rabbit** is a heap exploitation technique that creates overlapping or fake chunks by manipulating fast bin metadata. This allows you to forge legitimate chunks in the heap for further exploitation.

## When to Use This Technique

Use House of Rabbit when you have:
- **A write primitive** that can modify fast bin chunk metadata (size or fd pointer)
- **Ability to trigger `malloc_consolidate`** (via large allocation or top chunk merge)
- **Fast bin chunks** in the heap that you can manipulate

## Prerequisites

1. **Fast bin access**: You must be able to modify either:
   - The `fd` (forward) pointer of a chunk in the fast bin
   - The size field of a fast bin chunk

2. **Consolidate trigger**: You need a way to call `malloc_consolidate`, typically by:
   - Allocating a large chunk (larger than `MALLOC_ALIGNMENT`)
   - Merging with the top chunk

## Attack Variants

### Variant 1: Size Manipulation (Overlapping Chunks)

This variant creates overlapping chunks by modifying the size field of a fast bin chunk.

#### Step-by-Step

1. **Allocate two chunks of the same size**
   ```c
   unsigned long* chunk1 = malloc(0x40);  // 0x602000
   unsigned long* chunk2 = malloc(0x40);  // 0x602050
   malloc(0x10);                          // Change fastbin state
   ```

2. **Free both chunks**
   ```c
   free(chunk1);  // Goes to fastbin
   free(chunk2);  // Goes to fastbin
   ```

3. **Modify chunk1's size metadata**
   ```c
   chunk1[-1] = 0xa1;  // Set size to 0xa0 (0xa1 with PREV_INUSE bit)
   ```
   The size is stored just before the chunk data. Setting it to 0xa1 makes the allocator think chunk1 is larger than it actually is.

4. **Trigger consolidation**
   ```c
   malloc(0x1000);  // Large allocation triggers malloc_consolidate
   ```

5. **Result**: chunk1 now overlaps with chunk2, allowing you to write into chunk2's memory through chunk1.

### Variant 2: FD Pointer Manipulation (Fake Chunks)

This variant creates fake chunks by manipulating the forward pointer in the fast bin.

#### Step-by-Step

1. **Allocate chunks of different sizes**
   ```c
   unsigned long* chunk1 = malloc(0x40);  // 0x602000
   unsigned long* chunk2 = malloc(0x100); // 0x602050
   ```

2. **Create fake chunk metadata inside chunk2**
   ```c
   chunk2[1] = 0x31;  // Fake chunk size (0x30 + PREV_INUSE)
   chunk2[7] = 0x21;  // Next fake chunk size
   chunk2[11] = 0x21; // Next-next fake chunk size
   ```
   This simulates multiple small chunks within chunk2's memory.

3. **Free chunk1**
   ```c
   free(chunk1);  // Adds to fastbin
   ```

4. **Modify chunk1's fd pointer**
   ```c
   chunk1[0] = 0x602060;  // Point to fake chunk inside chunk2
   ```
   The fd pointer is at chunk1[0] (first 8 bytes of chunk data).

5. **Trigger consolidation**
   ```c
   malloc(5000);  // Large allocation triggers malloc_consolidate
   ```

6. **Result**: The fake chunk becomes part of the fastbin list and can be allocated as a legitimate chunk.

## Key Concepts

### Fast Bin Structure

Fast bins are single-linked lists. Each chunk in a fast bin has:
- `fd` pointer at offset 0 (points to next chunk in the bin)
- Size metadata at offset -1 (just before the chunk)

### malloc_consolidate

This function is called when:
- A large chunk is allocated (larger than `MALLOC_ALIGNMENT`)
- The top chunk needs to be merged

During consolidation, fast bin chunks are merged into the top chunk. If you've manipulated metadata, this creates the overlap or fake chunk.

### Size Field Format

The size field includes flags:
- Bit 0: `PREV_INUSE` (set to 1 if previous chunk is in use)
- Bit 1: `NON_MAIN_ARENA` (set if not main arena)
- Bit 2: `IS_MMAPPED` (set if mmapped)

For a 0x40 byte chunk, the size field should be `0x41` (0x40 + PREV_INUSE).

## Common Pitfalls

1. **Alignment**: Chunk addresses must be 16-byte aligned
2. **Size validation**: The size must be valid (proper alignment, not too large)
3. **Fast bin limits**: Fast bins have a maximum of 10 chunks per bin
4. **Top chunk**: Don't corrupt the top chunk or you'll crash

## Practical Tips

- **Use GDB with pwndbg**: The `heap` command shows chunk layout
- **Check fastbin state**: Use `heap_analysis` to see fast bin contents
- **Test incrementally**: Verify each step before proceeding
- **Understand the heap layout**: Know where chunks are located before manipulating

## Example Exploitation Flow

```
1. Leak heap addresses (if ASLR is on)
2. Identify target chunks to manipulate
3. Use write primitive to corrupt metadata
4. Trigger malloc_consolidate
5. Allocate to get overlapping/fake chunk
6. Use the overlap to corrupt function pointers or other targets
```

## Related Techniques

- **House of Force**: Manipulates top chunk for arbitrary writes
- **Unsorted Bin Attack**: Uses unsorted bin properties for exploitation
- **Tcache Poisoning**: Similar concept but for tcache (glibc 2.26+)

## References

- [HackTricks House of Rabbit](https://book.hacktricks.xyz/pentesting/ctf/write-ups-ctf/house-of-rabbit)
- [glibc malloc source](https://sourceware.org/git/?p=glibc.git;a=blob;f=malloc/malloc.c)
- [pwndbg heap commands](https://github.com/pwndbg/pwndbg/wiki/Heap-Commands)
