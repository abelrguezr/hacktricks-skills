---
name: heap-freed-chunk-exploitation
description: How to exploit heap vulnerabilities that allow overwriting freed chunks. Use this skill whenever the user mentions heap exploitation, use-after-free, double-free, heap overflow, off-by-one overflow, freed chunk manipulation, tcache attacks, fastbin attacks, or any binary exploitation involving heap memory management. This skill covers techniques to overwrite pointers in freed chunks for exploitation.
---

# Heap Freed Chunk Exploitation

This skill covers heap exploitation techniques that involve overwriting pointers inside freed chunks. These are fundamental to many heap-based attacks in binary exploitation.

## Core Concept

Several heap exploitation techniques require the ability to **overwrite pointers inside freed chunks**. The goal is to understand what vulnerabilities grant this access and how to leverage them.

## Vulnerability Types

### 1. Simple Use After Free (UAF)

**What it is:** The attacker can write data into a chunk that has already been freed.

**How it works:**
- A chunk is freed but the program still holds a reference to it
- Attacker writes malicious data to the freed chunk
- When the chunk is reallocated, the attacker controls its contents
- This allows overwriting critical pointers

**When to use:** Look for cases where freed memory is still accessible through dangling pointers.

### 2. Double Free

**What it is:** The same chunk is freed twice, potentially with other frees in between.

**How it works:**
1. Free the same chunk twice (possibly with other frees between them)
2. The chunk ends up in the same bin twice
3. Allocate the chunk later to get a reference
4. Write the needed pointers to it
5. Allocate it again to trigger the attack (fastbin attack, tcache attack, etc.)

**When to use:** When you can trigger multiple frees on the same allocation.

### 3. Heap Overflow

**What it is:** Overflowing an allocated chunk that has a freed chunk as its neighbor.

**How it works:**
- Allocate a chunk with a freed chunk immediately after it in memory
- Overflow the allocated chunk
- Modify headers/pointers of the freed chunk
- When the freed chunk is reallocated, your modified pointers take effect

**When to use:** When you have a buffer overflow adjacent to freed heap memory.

### 4. Off-by-One Overflow

**What it is:** Writing one byte past the end of a buffer, modifying the size field of the next chunk.

**How it works:**
1. Overflow by one byte to modify the size of the following chunk
2. Make an allocated chunk appear larger than it really is
3. Free the chunk - it gets added to a bin of the (fake) larger size
4. Allocate a chunk of the fake size
5. You now have access to a chunk larger than its real size
6. This creates an overlapping chunks situation
7. Exploit the overlap the same way as a heap overflow

**When to use:** When you can write exactly one byte past a buffer boundary.

## Attack Patterns

### Fastbin Attack
- Exploits the fastbin allocator's lack of validation
- Requires double free or UAF to control the fd pointer
- When a chunk is allocated from fastbin, the fd pointer becomes the next chunk's address

### Tcache Attack
- Similar to fastbin but for tcache (glibc 2.26+)
- Tcache has a limit of 7 chunks per bin
- Can be exploited with UAF or double free

## Practical Considerations

### Memory Layout
- Understand the heap layout: chunks are allocated sequentially
- Each chunk has headers (size, flags) before the data
- The `prev_size` and `size` fields are critical for exploitation

### Chunk Structure
```
[prev_size][size][data...][prev_size][size][data...]
```

### Key Pointers to Overwrite
- `fd` (forward) pointer in bins
- `bk` (backward) pointer in bins
- `prev_size` in chunk headers
- `size` field to control chunk boundaries

## Debugging Tips

1. **Use GDB with heap debugging:**
   - `heap` command to view heap state
   - `vmmap` to see memory regions
   - `x/20wx $heap` to examine chunk headers

2. **Track allocations:**
   - Note which chunks are freed
   - Monitor which bins chunks go to
   - Watch for double frees or UAF conditions

3. **Check for:**
   - Dangling pointers after free
   - Multiple frees of same address
   - Buffer boundaries and adjacent chunks

## When This Skill Applies

Use this skill when:
- Analyzing heap vulnerabilities in CTF challenges
- Debugging memory corruption bugs
- Learning heap exploitation techniques
- Working with glibc malloc implementations
- Preparing for binary exploitation competitions

## Related Techniques

- Heap Feng Shui (controlling heap layout)
- Unlink attacks (older glibc versions)
- House of X attacks (various heap exploitation patterns)
- Tcache poisoning
- Fastbin corruption

## Safety Note

These techniques are for educational purposes and authorized security research only. Always ensure you have permission before testing exploitation techniques on systems you don't own.
