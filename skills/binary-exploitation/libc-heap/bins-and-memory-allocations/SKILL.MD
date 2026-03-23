---
name: glibc-heap-exploitation
description: A skill for understanding and exploiting glibc heap memory management, including tcache, fast bins, unsorted bins, small bins, large bins, and top chunk manipulation. Use this skill whenever working on binary exploitation challenges involving heap vulnerabilities, analyzing malloc/free behavior, debugging heap corruption issues, or when the user mentions heap exploitation, glibc malloc, memory bins, tcache attacks, fastbin attacks, or any heap-related CTF challenges.
---

# Glibc Heap Exploitation

This skill helps you understand and exploit glibc's heap memory management system. The glibc malloc implementation uses several types of bins to efficiently manage freed memory chunks.

## Quick Reference

| Bin Type | Count | Max Chunks | Size Range (64-bit) | Link Type |
|----------|-------|------------|---------------------|------------|
| Tcache | 64 per thread | 7 | 24-1032 bytes | Singly-linked |
| Fast | 10 | 0x80 | 16-80 bytes | Singly-linked (LIFO) |
| Unsorted | 1 | - | - | Doubly-linked |
| Small | 62 | - | 16-512 bytes | Doubly-linked |
| Large | 63 | - | 512+ bytes | Doubly-linked |

## Core Concepts

### Memory Chunk Structure

Each heap chunk has a header containing:
- **Size field**: Chunk size with flags (PREV_INUSE, IS_MMAPPED, NON_MAIN_ARENA)
- **Next/Prev pointers**: For doubly-linked lists (except fast/tcache bins)

### Bin Selection Flow

When a chunk is freed, it goes through this decision tree:

1. **Tcache check**: Is chunk ≤ 512 bytes (64-bit) AND tcache bin not full (7 chunks)?
   - Yes → Add to tcache bin
   - No → Continue

2. **Fast bin check**: Is chunk ≤ 80 bytes (64-bit)?
   - Yes → Add to fast bin (LIFO)
   - No → Continue

3. **Unsorted bin**: Add to unsorted bin first
   - May merge with adjacent free chunks
   - Later sorted into small/large bins on demand

4. **Small/Large bins**: Based on size thresholds
   - Small: 16-512 bytes (64-bit)
   - Large: 512+ bytes

## Exploitation Techniques

### Tcache Poisoning

**When to use**: When you can control the `next` pointer in a freed chunk.

**Requirements**:
- Target application uses tcache (glibc 2.26+)
- Can free same-size chunks multiple times
- Can control chunk content before free

**Attack pattern**:
```
1. Allocate chunk A (size X)
2. Allocate chunk B (size X)
3. Write fake next pointer to chunk A's content
4. Free chunk A (goes to tcache)
5. Free chunk B (goes to tcache)
6. Allocate chunk C → gets chunk B
7. Allocate chunk D → gets chunk A with fake next
8. Chunk D points to your controlled address
```

**Key insight**: Tcache uses singly-linked lists, so you only need to control the `next` pointer, not `prev`.

### Fastbin Attack

**When to use**: When tcache is disabled or full, and you can control freed chunk content.

**Requirements**:
- Chunk size fits fastbin (16-80 bytes on 64-bit)
- Can control chunk content
- Can trigger double-free or use-after-free

**Attack pattern**:
```
1. Allocate chunk A (fastbin size)
2. Allocate chunk B (fastbin size)
3. Write fake next pointer to chunk A
4. Free chunk A (goes to fastbin)
5. Free chunk B (goes to fastbin)
6. Allocate → gets chunk B
7. Allocate → gets chunk A with fake next
```

**Key insight**: Fastbins use LIFO, so the last freed chunk is allocated first.

### Unsorted Bin Attack

**When to use**: When you need to manipulate chunk sizes or merge chunks.

**Requirements**:
- Chunk too large for fastbin/tcache
- Can control chunk size field
- Can trigger consolidation

**Attack pattern**:
```
1. Allocate chunk A (large size)
2. Allocate chunk B (large size)
3. Free chunk A (goes to unsorted bin)
4. Modify chunk A's size field
5. Allocate chunk C (triggers unsorted bin sorting)
6. Chunk A gets sorted with modified size
```

**Key insight**: Unsorted bin chunks are sorted into small/large bins on demand, allowing size manipulation.

### Small Bin Attack

**When to use**: When you need precise control over chunk placement.

**Requirements**:
- Chunk size in small bin range (16-512 bytes)
- Can control chunk content
- Can trigger bin sorting

**Attack pattern**:
```
1. Allocate multiple chunks of same size
2. Free them all (go to unsorted, then small bin)
3. Modify chunk pointers in small bin
4. Allocate to get controlled chunk
```

**Key insight**: Small bins use doubly-linked lists, requiring control of both `next` and `prev` pointers.

### Large Bin Attack

**When to use**: For large allocations where size manipulation matters.

**Requirements**:
- Chunk size > 512 bytes
- Can control chunk size field
- Understand large bin sorting (by size)

**Attack pattern**:
```
1. Allocate large chunk A
2. Free chunk A (goes to unsorted, then large bin)
3. Modify chunk A's size field
4. Allocate large chunk B (triggers large bin search)
5. Chunk A found with modified size
```

**Key insight**: Large bins sort by size, so modifying size affects search order.

## Analysis Tools

### GEF Commands

```bash
# View all heap bins
heap bins

# View heap chunks
heap chunks

# View specific arena
heap arena

# View malloc state
heap malloc-stats

# Visualize heap
heap visualize
```

### Pwntools Heap Analysis

```python
from pwn import *

# Connect to process
p = process('./vuln')

# Read heap memory
heap_addr = p.libc.symbols['__malloc_hook'] - 0x231000
heap_data = p.read(heap_addr, 0x1000)

# Parse chunk headers
for i in range(0, len(heap_data), 16):
    size = u64(heap_data[i:i+8]) & 0xfffffffffffff
    print(f"Chunk at {hex(heap_addr + i)}: size={hex(size)}")
```

## Common Vulnerabilities

### Use-After-Free (UAF)

**Pattern**: Free a chunk, then use the pointer without reallocating.

**Exploitation**:
1. Trigger UAF on target chunk
2. Allocate new chunk of same size
3. New chunk overwrites freed chunk's memory
4. Use UAF pointer to control new chunk

### Double Free

**Pattern**: Free the same chunk twice.

**Exploitation**:
1. Free chunk A (goes to bin)
2. Free chunk A again (corrupts bin)
3. Bin now has duplicate entries
4. Allocate to get controlled chunk

### Heap Overflow

**Pattern**: Write beyond chunk boundary.

**Exploitation**:
1. Overflow into next chunk's header
2. Modify next chunk's size
3. Free next chunk (triggers consolidation)
4. Control freed chunk's metadata

### Off-by-One

**Pattern**: Write one byte beyond boundary.

**Exploitation**:
1. Overflow into next chunk's PREV_INUSE bit
2. Free next chunk (triggers merge)
3. Merge creates larger chunk
4. Control merged chunk's metadata

## Debugging Tips

### Identify Bin Type

```bash
# In GEF
gef➤  heap bins
# Look for which bin contains your chunk

# Check tcache
Tcachebins[idx=X, size=0xXX, count=Y]

# Check fastbin
Fastbins[idx=X, size=0xXX]

# Check unsorted
Unsorted Bin for arena at 0xXXXX

# Check small/large
Small Bins for arena at 0xXXXX
Large Bins for arena at 0xXXXX
```

### Calculate Bin Index

Use the `calculate_bin_index.py` script (see scripts/) to determine which bin a chunk will go to based on its size.

### Track Allocation Order

```python
# Track malloc/free order
allocations = []
frees = []

# In your exploit
allocations.append(malloc(size))
frees.append(free(ptr))

# Analyze which bin each freed chunk goes to
```

## Best Practices

1. **Always check glibc version**: Tcache was added in 2.26, behavior differs between versions
2. **Understand ASLR**: Heap addresses may be randomized
3. **Check canaries**: Stack canaries don't protect heap, but heap canaries exist
4. **Use debug builds**: Compile with `-g` and run with `gdb` for better analysis
5. **Test on clean environment**: Use `LD_PRELOAD` carefully, it can affect behavior

## References

- [Azeria Labs - Heap Exploitation Part 1](https://azeria-labs.com/heap-exploitation-part-1-understanding-the-glibc-heap-implementation/)
- [Azeria Labs - Heap Exploitation Part 2](https://azeria-labs.com/heap-exploitation-part-2-glibc-heap-free-bins/)
- [CTF Wiki - Glibc Heap](https://ctf-wiki.mahaloz.re/pwn/linux/glibc-heap/)
- [Dhaval Kapil - Heap Exploitation](https://heap-exploitation.dhavalkapil.com/)

## Scripts

See the `scripts/` directory for helper tools:
- `calculate_bin_index.py` - Calculate which bin a chunk size belongs to
- `analyze_heap_dump.py` - Parse and analyze heap memory dumps
- `generate_test_program.py` - Generate test programs for specific bin types
