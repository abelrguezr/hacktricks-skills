---
name: glibc-free-analysis
description: Analyze and explain glibc's free() function behavior for heap exploitation. Use this skill whenever the user asks about free(), heap chunk freeing, tcache/fastbin/unsorted bin behavior, double-free detection, safe-linking, tcache poisoning, or any glibc malloc/free internals. This skill explains the complete free() flow from __libc_free through _int_free to bin placement, including all security checks and error messages. Make sure to use this skill when debugging heap issues, analyzing heap exploitation primitives, or understanding why free() triggers specific error messages.
---

# glibc free() Analysis

This skill explains the complete flow of `free()` in glibc's heap allocator, including security checks, bin placement logic, and exploitation considerations.

## Quick Reference: free() Flow

```
free(ptr)
  └─> __libc_free
       ├─> NULL check → return
       ├─> mmaped chunk → munmap → return
       └─> _int_free
            ├─> tcache (if eligible)
            ├─> fastbin (if eligible)
            └─> _int_free_merge_chunk → unsorted bin
```

## Step-by-Step Analysis

### 1. __libc_free Entry Point

When `free(ptr)` is called:

| Check | Action |
|-------|--------|
| `ptr == NULL` | Return immediately (no-op) |
| Pointer tag mismatch | Double-free detection (if `mtag_enabled`) |
| `chunk_is_mmapped(p)` | Call `munmap_chunk(p)` and return |
| Otherwise | Add color, call `_int_free(arena, p, 0)` |

**Key insight**: `free(NULL)` is safe and does nothing.

### 2. _int_free Validation

Before any bin placement, `_int_free` performs critical checks:

| Check | Error Message |
|-------|---------------|
| Pointer not aligned | `free(): invalid pointer` |
| Size < MINSIZE or not aligned | `free(): invalid size` |
| Pointer wraps around address space | `free(): invalid pointer` |

These checks prevent many common heap corruption bugs from silently succeeding.

### 3. Tcache Placement (if eligible)

**Eligibility**: Chunk size fits in tcache bins AND tcache is enabled.

**Checks before insertion**:

| Check | Error Message |
|-------|---------------|
| `tcache->counts[tc_idx] >= mp_.tcache_count` | `free(): too many chunks detected in tcache` |
| Entry not aligned | `free(): unaligned chunk detected in tcache 2` |
| Entry already in tcache (double-free) | `free(): double free detected in tcache 2` |

**Double-free detection**: The code checks if `e->key == tcache_key` and walks the bin looking for the same pointer. This is probabilistic but effective.

**glibc 2.42+ change**: Tcache now accepts much larger chunks via `glibc.malloc.tcache_max_bytes` tunable. This means more frees go to tcache instead of unsorted bins.

### 4. Fastbin Placement (if eligible)

**Eligibility**: `size <= get_max_fast()` AND (if `TRIM_FASTBINS`) chunk doesn't border top.

**Checks before insertion**:

| Check | Error Message |
|-------|---------------|
| Next chunk size invalid | `free(): invalid next size (fast)` |
| Chunk already at fastbin top | `double free or corruption (fasttop)` |
| Fastbin top has different size | `invalid fastbin entry (free)` |

**Safe-linking**: Fastbin `fd` pointers are protected: `PROTECT_PTR(pos, ptr) = ((size_t)pos >> 12) ^ (size_t)ptr`

### 5. Unsorted Bin (via _int_free_merge_chunk)

If chunk doesn't fit tcache or fastbin, it goes through consolidation:

**Checks during consolidation**:

| Check | Error Message |
|-------|---------------|
| Chunk is top chunk | `double free or corruption (top)` |
| Next chunk outside arena | `double free or corruption (out)` |
| Next chunk not marked in-use | `double free or corruption (!prev)` |
| Next chunk size invalid | `free(): invalid next size (normal)` |
| Prev size mismatch during consolidation | `corrupted size vs. prev_size while consolidating` |

**Process**:
1. Check if previous chunk is free → consolidate backward
2. Check if next chunk is free → consolidate forward
3. Place resulting chunk in unsorted bin

## Exploitation Notes

### Safe-Linking Bypass

Tcache and fastbin use safe-linking to protect `fd` pointers:

```python
# To craft a safe-linked fd pointing to TARGET:
# You need a leaked heap address at position POS
protected_fd = TARGET ^ (POS >> 12)
```

**Implication**: You need a heap leak to perform tcache poisoning. The XOR key is derived from the position of the `fd` pointer itself.

### Tcache Double-Free Detection

The detection works by:
1. Checking if `e->key == tcache_key` (probabilistic match)
2. Walking the entire bin up to `mp_.tcache_count` entries
3. Aborting if the same pointer is found

**Bypass consideration**: The key check is probabilistic (1 in 2^size_t chance of false positive), but the pointer walk is deterministic.

### Forcing Specific Bin Behavior

For research/testing, use `GLIBC_TUNABLES` to control tcache:

```bash
# Disable tcache completely (see classic unsorted bin behavior)
GLIBC_TUNABLES=glibc.malloc.tcache_count=0 ./program

# glibc 2.42+: Disable large tcache
GLIBC_TUNABLES=glibc.malloc.tcache_max_bytes=0 ./program
```

### Modern Hook Limitations

`__malloc_hook` and `__free_hook` overwrites are **not viable** on glibc ≥ 2.34. Use alternative targets:
- IO_FILE structures
- Exit handlers
- Virtual tables
- Other GOT/PLT entries

## Common Error Messages Reference

| Error | Cause |
|-------|-------|
| `free(): invalid pointer` | Misaligned or wrapped pointer |
| `free(): invalid size` | Size < MINSIZE or not aligned |
| `free(): too many chunks detected in tcache` | Tcache bin overflow |
| `free(): unaligned chunk detected in tcache 2` | Tcache entry misalignment |
| `free(): double free detected in tcache 2` | Same chunk freed twice (tcache) |
| `free(): invalid next size (fast)` | Next chunk size invalid (fastbin) |
| `double free or corruption (fasttop)` | Chunk already at fastbin top |
| `invalid fastbin entry (free)` | Fastbin size mismatch |
| `double free or corruption (top)` | Freeing top chunk |
| `double free or corruption (out)` | Next chunk outside arena |
| `double free or corruption (!prev)` | Next chunk not marked in-use |
| `free(): invalid next size (normal)` | Next chunk size invalid (normal) |
| `corrupted size vs. prev_size while consolidating` | Prev size field mismatch |

## Practical Analysis Workflow

When analyzing a heap bug involving `free()`:

1. **Identify the chunk size** - Determines which bin it targets
2. **Check tcache eligibility** - Is tcache enabled? Does size fit?
3. **Review security checks** - Which checks might fail?
4. **Consider safe-linking** - Do you need a heap leak?
5. **Plan the primitive** - Tcache poisoning, fastbin attack, unsorted bin manipulation?

## Related Concepts

- **Tcache poisoning**: Overwrite tcache `fd` pointers to control allocation
- **Fastbin attack**: Similar to tcache but with different constraints
- **Unsorted bin attacks**: First-fit behavior, chunk consolidation
- **Double-free primitives**: Modern detection makes this harder
- **Use-after-free**: Often combined with free() manipulation

## References

- GNU C Library NEWS 2.42: https://www.gnu.org/software/libc/NEWS.html#2.42
- Safe-Linking internals: https://developers.redhat.com/articles/2020/05/13/new-security-hardening-gnu-c-library
- glibc malloc source: https://github.com/bminor/glibc/blob/master/malloc/malloc.c
