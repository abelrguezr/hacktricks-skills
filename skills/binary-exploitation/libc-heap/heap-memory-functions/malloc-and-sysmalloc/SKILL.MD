---
name: malloc-internals
description: Understand glibc malloc implementation, heap allocation flow, and memory management internals. Use this skill whenever the user asks about malloc, sysmalloc, heap exploitation, glibc memory allocation, binary exploitation heap challenges, or any questions about how malloc works internally. Trigger for: malloc questions, heap vulnerability research, CTF heap challenges, understanding allocation order, fastbin/smallbin/largebin/tcache behavior, security checks in malloc, or any glibc heap-related topics.
---

# Glibc Malloc Internals

This skill provides comprehensive knowledge about glibc's malloc implementation, including allocation flow, bin management, security checks, and system allocation.

## Quick Reference: Allocation Order

When `malloc()` is called, glibc follows this decision tree:

1. **Tcache check** → If available chunk of correct size, return it
2. **Fast bins** → Check for exact size match, fill tcache from remaining
3. **Small bins** → Check for exact size match, fill tcache from remaining
4. **Unsorted bin** → First-fit search, split if needed, bin smaller chunks
5. **Large bins** → Best-fit search from current index, then next larger bins
6. **Top chunk** → Split if large enough
7. **sysmalloc** → Request more memory from system

## Key Functions

### `__libc_malloc(bytes)`

Entry point for all malloc calls.

**What it does:**
- Checks tcache first (if enabled)
- Determines if single-threaded or multi-threaded
- Calls `_int_malloc()` in appropriate arena
- Tags returned pointer with `tag_new_usable()` for security

**Key behavior:**
- Always tags returned pointers (pointer tagging for security)
- In multi-threaded mode, may retry with different arena if first fails
- Tcache is checked before any other allocation path

### `_int_malloc(arena, bytes)`

Main allocation logic that searches all bins.

**Flow:**
1. Convert request size to internal form with `checked_request2size()`
2. If no arena exists, call `sysmalloc()` directly
3. Check fast bins (if size qualifies)
4. Check small bins (if in small bin range)
5. For large requests, call `malloc_consolidate()` to move fast chunks to unsorted
6. Search unsorted bin
7. Search large bins (current index, then larger)
8. Use top chunk or call `sysmalloc()`

### `malloc_consolidate(arena)`

Called for large allocations to prevent fragmentation.

**What it does:**
- Removes all chunks from fast bins
- Merges adjacent free chunks (prev/next if not in use)
- Places consolidated chunks in unsorted bin
- Sets `have_fastchunks = false`

**Security checks performed:**
- `unaligned fastbin chunk detected` - chunk misaligned
- `invalid chunk size` - size doesn't match fastbin index
- `corrupted size vs. prev_size in fastbins` - prev_size mismatch

### `sysmalloc(bytes, arena)`

Requests memory from the system when bins are exhausted.

**When called:**
- No arena exists (first allocation)
- Top chunk too small and no fast chunks to consolidate
- Request size exceeds mmap threshold with mmap available

**Strategies:**
1. Try `sysmalloc_mmap()` for large allocations or when arena is null
2. For non-main arena: extend heap or allocate new heap
3. For main arena: call `MORECORE` (sbrk) to extend heap
4. Fallback to mmap if sbrk fails

## Bin Types and Characteristics

### Tcache

**Purpose:** Thread-local cache for fast allocations

**Behavior:**
- Checked first in `__libc_malloc()`
- Filled from fast bins and small bins during allocation
- Has per-size counts and unsorted limit
- Chunks are singly-linked (fd pointer only)

**Key points:**
- `tcache_count` chunks per bin maximum
- `tcache_unsorted_limit` limits unsorted bin processing
- Filled proactively when other bins are checked

### Fast Bins

**Purpose:** Very fast allocation for small chunks

**Characteristics:**
- Size range: up to `get_max_fast()` (typically 80 bytes)
- Singly-linked list (fd pointer)
- No size verification on removal (security risk)
- One chunk per size index

**Security checks:**
- `unaligned fastbin chunk detected` - misaligned chunk
- `unaligned fastbin chunk detected 2` - misaligned victim
- `unaligned fastbin chunk detected 3` - misaligned tcache fill chunk
- `memory corruption (fast)` - size doesn't match index

**Tcache interaction:** When a fast bin chunk is used, remaining chunks of same size are moved to tcache

### Small Bins

**Purpose:** Fast allocation for small chunks with integrity checks

**Characteristics:**
- Size range: `MINSIZE` to `MAX_SMALLBIN` (typically 80-512 bytes)
- Doubly-linked list (fd/bk pointers)
- One exact size per index
- Security check: `bck->fd == victim`

**Security checks:**
- `smallbin double linked list corrupted` - integrity check failed

**Tcache interaction:** Remaining chunks moved to tcache after allocation

### Unsorted Bin

**Purpose:** Temporary holding for freed chunks before binning

**Characteristics:**
- First-fit search (uses first chunk that fits)
- Chunks are binned here before being sorted to small/large bins
- Maintains `last_remainder` for small allocation locality

**Security checks (per chunk):**
- `invalid size (unsorted)` - size too small or too big
- `invalid next size (unsorted)` - next chunk size invalid
- `mismatching next->prev_size (unsorted)` - prev_size mismatch
- `unsorted double linked list corrupted` - fd/bk integrity
- `invalid next->prev_inuse (unsorted)` - prev_inuse bit wrong

**Special behavior:**
- If exact fit found and tcache not full, add to tcache instead of returning
- `last_remainder` used for small allocations to promote locality
- `MAX_ITERS` (10000) limit on traversal

### Large Bins

**Purpose:** Store larger chunks with best-fit search

**Characteristics:**
- Size range: above small bin maximum
- Doubly-linked with skip list (fd_nextsize/bk_nextsize)
- Sorted by size within bin
- Bitmap (`binmap`) tracks non-empty bins

**Security checks:**
- `largebin double linked list corrupted (nextsize)` - skip list integrity
- `largebin double linked list corrupted (bk)` - main list integrity

**Search strategy:**
1. Check current bin index for smallest fitting chunk
2. If not found, scan larger bins using bitmap
3. Split chunk if remainder >= MINSIZE

## Top Chunk

**Purpose:** Last chunk in arena, can be extended

**Characteristics:**
- Points to end of available memory
- Can be split for allocations
- Extended via `sysmalloc()` when too small

**Security check:**
- `corrupted top size` - size exceeds `system_mem`

**Behavior:**
- If large enough, split and return portion
- If not enough and fast chunks exist, consolidate and retry
- Otherwise call `sysmalloc()`

## Security Checks Summary

| Check | Location | Error Message |
|-------|----------|---------------|
| Fastbin alignment | _int_malloc | `unaligned fastbin chunk detected` |
| Fastbin size | _int_malloc | `memory corruption (fast)` |
| Smallbin integrity | _int_malloc | `smallbin double linked list corrupted` |
| Unsorted size | _int_malloc | `invalid size (unsorted)` |
| Unsorted next size | _int_malloc | `invalid next size (unsorted)` |
| Unsorted prev_size | _int_malloc | `mismatching next->prev_size (unsorted)` |
| Unsorted integrity | _int_malloc | `unsorted double linked list corrupted` |
| Unsorted prev_inuse | _int_malloc | `invalid next->prev_inuse (unsorted)` |
| Largebin nextsize | _int_malloc | `largebin double linked list corrupted (nextsize)` |
| Largebin bk | _int_malloc | `largebin double linked list corrupted (bk)` |
| Top size | _int_malloc | `corrupted top size` |
| Unsorted chunks | _int_malloc | `corrupted unsorted chunks` |
| Consolidate alignment | malloc_consolidate | `unaligned fastbin chunk detected` |
| Consolidate size | malloc_consolidate | `invalid chunk size` |
| Consolidate prev_size | malloc_consolidate | `corrupted size vs. prev_size in fastbins` |

## Common Heap Exploitation Concepts

### Fastbin Attack

**Vulnerability:** Fast bins don't verify chunk size on removal

**Exploitation:**
1. Free chunks to populate fast bin
2. Corrupt chunk size to be larger than index
3. Allocate to get larger chunk than expected
4. Overwrite adjacent chunk's fd pointer

**Mitigation:** Tcache, fastbin size checks (glibc 2.31+)

### Unsorted Bin Attack

**Vulnerability:** Unsorted bin uses first-fit, chunks binned after use

**Exploitation:**
1. Allocate chunk A, free it (goes to unsorted)
2. Allocate chunk B (takes A from unsorted, bins A's remainder)
3. Free chunk C (goes to unsorted)
4. Allocate chunk D (takes C, bins C's remainder)
5. If A's remainder was smaller than C, A's remainder is now in wrong bin

**Mitigation:** Understanding binning behavior

### Tcache Poisoning

**Vulnerability:** Tcache is thread-local, no size verification

**Exploitation:**
1. Fill tcache with controlled chunks
2. Corrupt fd pointers in tcache
3. Allocate to get arbitrary pointer

**Mitigation:** Tcache per-thread, fd pointer checks

## Arena and Multi-threading

**Main Arena:**
- First arena created
- Uses sbrk for memory
- Shared by all threads initially

**Thread Arenas:**
- Created when thread allocates
- Uses mmap for memory
- Reduces lock contention

**Arena Selection:**
- Single-threaded: always main arena
- Multi-threaded: `arena_get()` finds suitable arena
- May retry with different arena if allocation fails

## Memory Alignment

**Key constants:**
- `MALLOC_ALIGNMENT` - typically 16 bytes
- `CHUNK_HDR_SZ` - chunk header size (typically 16 bytes)
- `MINSIZE` - minimum allocatable size
- `pagesize` - system page size (typically 4096 bytes)

**Alignment rules:**
- All returned pointers are MALLOC_ALIGNMENT aligned
- Chunks are aligned to page boundaries when allocated from system
- `front_misalign` handles alignment in mmap'd regions

## Practical Usage

### When to use this skill:

1. **Understanding malloc behavior:** "Why did this allocation come from tcache?"
2. **Heap exploitation:** "How can I exploit a use-after-free in fastbins?"
3. **CTF challenges:** "This heap challenge requires understanding unsorted bin attacks"
4. **Debugging:** "Why is malloc returning chunks in this order?"
5. **Security research:** "What security checks prevent this heap corruption?"
6. **Learning:** "Explain how glibc malloc works"

### How to approach heap problems:

1. **Identify the allocation path:** What size? What bins are involved?
2. **Track chunk state:** What's in each bin? What's the top chunk?
3. **Understand the vulnerability:** Which security check can be bypassed?
4. **Plan the exploitation:** What allocations/frees achieve the goal?
5. **Consider mitigations:** Tcache, ASLR, stack canaries, etc.

### Key questions to ask:

- What size is being allocated?
- Which bin will it come from?
- What security checks apply?
- What's the current heap state?
- Can we control the fd/bk pointers?
- Is tcache enabled?
- Are we in main arena or thread arena?

## References

- glibc malloc source: https://github.com/bminor/glibc/blob/master/malloc/malloc.c
- malloc(3) man page
- Various heap exploitation writeups and tutorials

---

**Note:** This skill covers glibc's ptmalloc2 implementation. Behavior may vary slightly between glibc versions. Always verify against the specific version you're working with.
