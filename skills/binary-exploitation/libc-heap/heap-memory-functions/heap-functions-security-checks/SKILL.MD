---
name: heap-security-checks
description: Reference for libc heap memory function security checks and error messages. Use this skill whenever the user is debugging heap vulnerabilities, analyzing heap exploitation, studying glibc malloc/free internals, or needs to understand what specific heap error messages mean. Trigger on mentions of heap corruption, malloc/free errors, tcache, fastbins, unsorted bins, or any libc heap function security checks.
---

# Heap Security Checks Reference

This skill provides a comprehensive reference for security checks performed by libc heap management functions. Use it to understand error messages, identify exploitation opportunities, and debug heap vulnerabilities.

## Quick Lookup by Error Message

When you see a heap error message, find it below to understand what check failed:

| Error Message | Function | What It Means |
|--------------|----------|---------------|
| `corrupted size vs. prev_size` | `unlink` | Chunk size doesn't match prev_size in next chunk |
| `corrupted double-linked list` | `unlink` | Forward/backward pointers don't match |
| `malloc(): unaligned fastbin chunk detected` | `_int_malloc` | Fastbin chunk address is misaligned |
| `malloc(): memory corruption (fast)` | `_int_malloc` | Fastbin chunk size doesn't match bin index |
| `malloc(): smallbin double linked list corrupted` | `_int_malloc` | Small bin linked list integrity check failed |
| `malloc(): invalid size (unsorted)` | `_int_malloc` | Unsorted bin chunk size is out of range |
| `malloc(): unsorted double linked list corrupted` | `_int_malloc` | Unsorted bin linked list integrity check failed |
| `malloc(): corrupted top size` | `_int_malloc` | Top chunk size exceeds system memory |
| `malloc(): unaligned tcache chunk detected` | `tcache_get_n` | Tcache chunk address is misaligned |
| `realloc(): invalid pointer` | `__libc_realloc` | Realloc pointer is misaligned or size incorrect |
| `free(): invalid pointer` | `_int_free` | Free pointer is not aligned |
| `free(): invalid size` | `_int_free` | Chunk size is too small or misaligned |
| `free(): too many chunks detected in tcache` | `_int_free` | Tcache count exceeds limit |
| `free(): double free detected in tcache 2` | `_int_free` | Chunk already in tcache |
| `double free or corruption (fasttop)` | `_int_free` | Chunk already at top of fastbin |
| `double free or corruption (top)` | `_int_free_merge_chunk` | Attempting to free top chunk |
| `double free or corruption (out)` | `_int_free_merge_chunk` | Next chunk outside arena boundaries |
| `double free or corruption (!prev)` | `_int_free_merge_chunk` | Previous chunk not marked as in-use |
| `free(): invalid next size (normal)` | `_int_free_merge_chunk` | Next chunk size out of range |
| `corrupted size vs. prev_size while consolidating` | `_int_free_merge_chunk` | Prev_size mismatch during consolidation |
| `free(): corrupted unsorted chunks` | `_int_free_create_chunk` | Unsorted bin linked list corrupted |

## Function-by-Function Security Checks

### `unlink`

Performs checks when unlinking chunks from bins:

1. **Size vs prev_size check**
   - Verifies chunk size matches `prev_size` in next chunk
   - Error: `corrupted size vs. prev_size`

2. **Double-linked list integrity**
   - Checks `P->fd->bk == P` and `P->bk->fw == P`
   - Error: `corrupted double-linked list`

3. **Nextsize list integrity (non-small chunks)**
   - Checks `P->fd_nextsize->bk_nextsize == P` and `P->bk_nextsize->fd_nextsize == P`
   - Error: `corrupted double-linked list (not small)`

### `_int_malloc`

#### Fast Bin Search Checks

1. **Chunk alignment**
   - Error: `malloc(): unaligned fastbin chunk detected 2`

2. **Forward chunk alignment**
   - Error: `malloc(): unaligned fastbin chunk detected`

3. **Size vs bin index**
   - Error: `malloc(): memory corruption (fast)`

4. **Tcache fill alignment**
   - Error: `malloc(): unaligned fastbin chunk detected 3`

#### Small Bin Search Checks

1. **Linked list integrity**
   - Checks `victim->bk->fd != victim`
   - Error: `malloc(): smallbin double linked list corrupted`

#### Consolidate Checks (per fast bin chunk)

1. **Chunk alignment**
   - Error: `malloc_consolidate(): unaligned fastbin chunk detected`

2. **Size vs bin index**
   - Error: `malloc_consolidate(): invalid chunk size`

3. **Prev_size consistency**
   - Error: `corrupted size vs. prev_size in fastbins`

#### Unsorted Bin Search Checks

1. **Chunk size range**
   - Error: `malloc(): invalid size (unsorted)`

2. **Next chunk size range**
   - Error: `malloc(): invalid next size (unsorted)`

3. **Prev_size consistency**
   - Error: `malloc(): mismatching next->prev_size (unsorted)`

4. **Linked list integrity**
   - Checks `victim->bck->fd == victim` and `victim->fd == av (arena)`
   - Error: `malloc(): unsorted double linked list corrupted`

5. **Prev_inuse flag**
   - Error: `malloc(): invalid next->prev_inuse (unsorted)`

6. **Nextsize list integrity**
   - Error: `malloc(): largebin double linked list corrupted (nextsize)`

7. **Backward list integrity**
   - Error: `malloc(): largebin double linked list corrupted (bk)`

#### Large Bin Search Checks

1. **By index search**
   - Checks `bck->fd->bk != bck`
   - Error: `malloc(): corrupted unsorted chunks`

2. **Next bigger search**
   - Checks `bck->fd->bk != bck`
   - Error: `malloc(): corrupted unsorted chunks2`

#### Top Chunk Use Checks

1. **Top chunk size**
   - Checks `chunksize(av->top) > av->system_mem`
   - Error: `malloc(): corrupted top size`

### `tcache_get_n`

1. **Chunk alignment**
   - Error: `malloc(): unaligned tcache chunk detected`

### `tcache_thread_shutdown`

1. **Chunk alignment**
   - Error: `tcache_thread_shutdown(): unaligned tcache chunk detected`

### `__libc_realloc`

1. **Pointer validity**
   - Checks alignment and size correctness
   - Error: `realloc(): invalid pointer`

### `_int_free`

#### Initial Checks

1. **Pointer alignment**
   - Error: `free(): invalid pointer`

2. **Size validity**
   - Checks size > MINSIZE and alignment
   - Error: `free(): invalid size`

#### Tcache Checks

1. **Tcache count limit**
   - Checks against `mp_.tcache_count`
   - Error: `free(): too many chunks detected in tcache`

2. **Entry alignment**
   - Error: `free(): unaligned chunk detected in tcache 2`

3. **Double free detection**
   - Error: `free(): double free detected in tcache 2`

#### Fast Bin Checks

1. **Next size validity**
   - Error: `free(): invalid next size (fast)`

2. **Fastbin top check**
   - Error: `double free or corruption (fasttop)`

3. **Top chunk size consistency**
   - Error: `invalid fastbin entry (free)`

### `_int_free_merge_chunk`

1. **Top chunk check**
   - Error: `double free or corruption (top)`

2. **Arena boundary check**
   - Error: `double free or corruption (out)`

3. **Prev_inuse check**
   - Error: `double free or corruption (!prev)`

4. **Next chunk size**
   - Error: `free(): invalid next size (normal)`

5. **Prev_size during consolidation**
   - Error: `corrupted size vs. prev_size while consolidating`

### `_int_free_create_chunk`

1. **Unsorted bin integrity**
   - Checks `unsorted_chunks(av)->fd->bk == unsorted_chunks(av)`
   - Error: `free(): corrupted unsorted chunks`

### `do_check_malloc_state`

1. **Fast bin alignment**
   - Error: `do_check_malloc_state(): unaligned fastbin chunk detected`

### `malloc_consolidate`

1. **Fast bin alignment**
   - Error: `malloc_consolidate(): unaligned fastbin chunk detected`

2. **Fast bin size**
   - Error: `malloc_consolidate(): invalid chunk size`

### `_int_realloc`

1. **Old size validity**
   - Error: `realloc(): invalid old size`

2. **Next size validity**
   - Error: `realloc(): invalid next size`

## Exploitation Implications

### Bypassing Checks

- **unlink checks**: Can be bypassed with controlled heap corruption if you can manipulate fd/bk pointers
- **Alignment checks**: Require proper chunk alignment (typically 8 or 16 bytes)
- **Size checks**: Need to maintain valid size ranges for each bin type
- **Double-linked list checks**: Require consistent forward/backward pointer manipulation

### Common Exploitation Patterns

1. **Use-after-free**: Trigger when freed chunk is reallocated before checks
2. **Double-free**: Exploit before double-free detection triggers
3. **Heap overflow**: Corrupt adjacent chunk metadata to bypass size checks
4. **Tcache poisoning**: Manipulate tcache entries before alignment checks
5. **Fastbin attack**: Exploit fastbin's LIFO nature and limited checks

## Debugging Tips

1. **Read the error message carefully** - It tells you exactly which check failed
2. **Check the function context** - Know which malloc/free path triggered the error
3. **Examine chunk metadata** - Look at size, prev_size, fd, bk fields
4. **Verify alignment** - Most errors relate to misaligned pointers
5. **Check bin membership** - Ensure chunk is in the expected bin type

## Related Resources

- `unlink.md` - Detailed unlink operation analysis
- `malloc-and-sysmalloc.md` - Malloc internals
- `free.md` - Free operation internals
- `references/schemas.md` - JSON structures for evals
