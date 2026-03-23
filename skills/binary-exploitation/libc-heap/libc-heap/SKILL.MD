---
name: libc-heap-exploitation
description: How to understand and exploit libc heap vulnerabilities in glibc and musl allocators. Use this skill whenever the user mentions heap exploitation, malloc/free vulnerabilities, chunk manipulation, arena analysis, bin attacks, or any heap-related binary exploitation tasks. Also trigger for debugging heap corruption, analyzing malloc_state structures, or working with heap chunks in GDB/pwndbg.
---

# Libc Heap Exploitation

A comprehensive guide to understanding and exploiting heap vulnerabilities in glibc and musl memory allocators.

## Quick Reference

### Core Concepts
- **Heap**: Dynamic memory region managed by `malloc`/`free`
- **Chunk**: Individual allocated memory block with metadata headers
- **Arena**: Per-thread heap region (main arena + secondary arenas)
- **Bins**: Free chunk lists (fastbins, smallbins, largebins, unsortedbin)
- **Subheaps**: mmap'd memory regions for secondary arenas

### Key Structures

#### malloc_chunk (glibc)
```c
struct malloc_chunk {
  INTERNAL_SIZE_T mchunk_prev_size;  // Size of previous chunk (if free)
  INTERNAL_SIZE_T mchunk_size;       // Size + flags (PREV_INUSE, IS_MMAPPED, NON_MAIN_ARENA)
  struct malloc_chunk* fd;           // Forward pointer (free chunks only)
  struct malloc_chunk* bk;           // Backward pointer (free chunks only)
  struct malloc_chunk* fd_nextsize;  // Next larger size (large chunks)
  struct malloc_chunk* bk_nextsize;  // Next smaller size (large chunks)
};
```

#### malloc_state (glibc)
```c
struct malloc_state {
  __libc_lock_define(, mutex);       // Thread synchronization
  int flags;                         // NONCONTIGUOUS_BIT, etc.
  int have_fastchunks;
  mfastbinptr fastbinsY[NFASTBINS];  // Fastbin pointers
  mchunkptr top;                     // Top chunk (remaining heap space)
  mchunkptr last_remainder;          // Remainder from last split
  mchunkptr bins[NBINS * 2 - 2];     // Small/large/unsorted bin pointers
  unsigned int binmap[BINMAPSIZE];   // Bin bitmap
  struct malloc_state *next;         // Arena linked list
  struct malloc_state *next_free;    // Free arena list
  INTERNAL_SIZE_T attached_threads;  // Thread count
  INTERNAL_SIZE_T system_mem;        // Total allocated
  INTERNAL_SIZE_T max_system_mem;    // Peak allocation
};
```

### Chunk Size Flags (last 3 bits of mchunk_size)
| Bit | Flag | Meaning |
|-----|------|--------|
| 0x1 | PREV_INUSE | Previous chunk is in use |
| 0x2 | IS_MMAPPED | Chunk obtained via mmap() |
| 0x4 | NON_MAIN_ARENA | Chunk from non-main arena |

## Heap Analysis Workflow

### Step 1: Identify the Allocator

```gdb
# Check if glibc or musl
pwndbg> checksec
pwndbg> version

# For musl (Alpine), use muslheap plugin
pwndbg> mchunkinfo <address>
```

### Step 2: Locate malloc_state

```gdb
# glibc main arena is a global in libc
pwndbg> find libc.so.2 malloc_state
pwndbg> x/20gx $main_arena

# Or via __malloc_hook
pwndbg> p __malloc_hook
pwndbg> x/20gx __malloc_hook-0x10
```

### Step 3: Inspect Chunks

```gdb
# View chunk structure
pwndbg> heap_chunk <address>

# View all chunks in arena
pwndbg> heap

# Check chunk flags
pwndbg> p *(struct malloc_chunk*)<address>

# Get usable size
pwndbg> p memsize(chunk_ptr)
```

### Step 4: Analyze Bins

```gdb
# Fastbins (0-10)
pwndbg> fastbins

# Smallbins (11-124)
pwndbg> smallbins

# Largebins (125-126)
pwndbg> largebins

# Unsortedbin (127)
pwndbg> unsortedbin
```

## Common Exploitation Patterns

### 1. Chunk Metadata Corruption

**Goal**: Overwrite chunk size to merge with adjacent chunks

```c
// Typical scenario: heap overflow into next chunk's header
char *chunk1 = malloc(0x50);
char *chunk2 = malloc(0x50);

// Overflow chunk1 into chunk2's header
memcpy(chunk1, payload, 0x50 + 0x10);  // Overwrite chunk2's size
```

**Key checks**:
- Size must be aligned (16-byte on 64-bit)
- PREV_INUSE bit must be set for next chunk
- Size must be larger than MIN_CHUNK_SIZE

### 2. Use-After-Free (UAF)

**Goal**: Reuse freed chunk with controlled content

```c
char *victim = malloc(0x50);
free(victim);  // Chunk goes to unsortedbin
char *reuse = malloc(0x50);  // Gets the freed chunk
// reuse now points to victim's memory
```

**Detection**:
```gdb
pwndbg> heap
# Look for chunks with same address but different allocation state
```

### 3. Double Free

**Goal**: Create overlapping chunks for arbitrary writes

```c
char *chunk = malloc(0x50);
free(chunk);
free(chunk);  // Double free - chunk added to bin twice
```

**Exploitation**:
- First malloc after double free gets the chunk
- Second malloc gets the same chunk (overlap)
- Write through one pointer affects the other

### 4. Fastbin Attack

**Goal**: Control fastbin linked list for arbitrary write

```c
// 1. Allocate and free chunks to fill fastbin
for (int i = 0; i < 7; i++) {
    chunks[i] = malloc(0x20);
    free(chunks[i]);
}

// 2. Corrupt fastbin fd pointer
*(size_t*)(fake_chunk + 0x10) = target_address;

// 3. Trigger allocation to write to target
malloc(0x20);  // Writes fake_chunk to target_address
```

**Requirements**:
- Fastbin top chunk size must match request
- Fastbin count < 7 (MAX_FASTBIN)
- Target address must be valid write location

### 5. Unsorted Bin Attack

**Goal**: Use unsortedbin consolidation for arbitrary read/write

```c
// 1. Create large chunk in unsortedbin
char *large = malloc(0x100);
free(large);

// 2. Leak libc via bk pointer
char *leak = malloc(0x100);
// leak->bk points to unsortedbin->bk (in malloc_state)

// 3. Use chunk size manipulation for consolidation
```

## Arena and Multithreading

### Arena Creation

```c
// Main arena created at program start
// Secondary arenas created when threads call malloc

pthread_t t1;
pthread_create(&t1, NULL, thread_func, NULL);
// New arena created for thread if needed
```

### Arena Limits

| Architecture | Max Arenas |
|--------------|------------|
| 32-bit | 2 × CPU cores |
| 64-bit | 8 × CPU cores |

### Subheap Behavior

```gdb
# Subheaps use mmap instead of brk
pwndbg> vmmap
# Look for [anon] regions with heap-like patterns

# Subheap size defaults
# 32-bit: 1 MB
# 64-bit: 64 MB
```

## musl mallocng Specifics

### Key Differences from glibc

1. **No arenas**: Single allocator for all threads
2. **Sizeclasses**: Fixed-size allocation classes
3. **Slot cycling**: User data offset may shift on reuse
4. **Guarded metadata**: Cookies and out-of-band metadata

### muslheap GDB Plugin

```gdb
pwndbg> mchunkinfo <address>
# Shows:
# - stride: Allocation class size
# - cycling offset: User data offset shift
# - reserved: Whether chunk is reserved

# Example output:
# stride: 0x140
# cycling offset: 0x1 (userdata --> 0x7ffff7a94e40)
```

### musl Exploitation Tips

1. **Target runtime objects** over allocator metadata (guarded)
2. **Control reuse counts** to predict cycling offsets
3. **Use strides without slack** for predictable offsets
4. **Keep spans mapped** for linear copy attacks

## Debugging Checklist

### Initial Setup

```gdb
# Essential GDB commands
pwndbg> context
pwndbg> heap
pwndbg> bins
pwndbg> checksec

# For musl
pwndbg> mchunkinfo <address>
```

### Common Issues

| Problem | Solution |
|---------|----------|
| Can't find malloc_state | Check if PIE, use `find` command |
| Chunk sizes don't match | Check alignment (16-byte on 64-bit) |
| Fastbin attack fails | Verify chunk size matches fastbin index |
| musl offset unpredictable | Use mchunkinfo to check cycling offset |

### Verification Commands

```gdb
# Verify chunk is in fastbin
pwndbg> fastbins
# Check if chunk address appears in fastbin list

# Verify chunk consolidation
pwndbg> heap
# Check if adjacent chunks merged

# Verify malloc_state leak
pwndbg> x/20gx <leaked_address>
# Should show malloc_state structure
```

## Security Checks

### glibc Heap Checks

1. **malloc_check**: Validates chunk metadata
2. **free_check**: Verifies chunk is valid for freeing
3. **unlink_check**: Validates fd/bk pointers during consolidation

### Bypassing Checks

```c
// For older glibc (< 2.26)
// Unlink check can be bypassed with:
// fd->bk == target && bk->fd == target

// For newer glibc
// Use tcache (if available) or unsortedbin attacks
```

## References

- [Azeria Labs: Heap Exploitation Part 1](https://azeria-labs.com/heap-exploitation-part-1-understanding-the-glibc-heap-implementation/)
- [Azeria Labs: Heap Exploitation Part 2](https://azeria-labs.com/heap-exploitation-part-2-glibc-heap-free-bins/)
- [NCC Group: musl mallocng Exploitation](https://www.nccgroup.com/research-blog/pumping-iron-on-the-musl-heap-real-world-cve-2022-24834-exploitation-on-an-alpine-mallocng-heap/)
- [muslheap GDB Plugin](https://github.com/xf1les/muslheap)
- [GdbLuaExtension](https://github.com/fidgetingbits/GdbLuaExtension)

## Next Steps

After understanding heap basics, explore:
1. **Bin attacks**: Fastbin, smallbin, largebin, unsortedbin exploitation
2. **Heap functions security checks**: How malloc/free validate chunks
3. **Case studies**: Real-world heap exploitation examples
4. **Advanced techniques**: Tcache attacks, heap grooming, heap spraying
