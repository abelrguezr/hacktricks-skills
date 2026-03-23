---
name: heap-first-fit-uaf
description: Exploit first-fit heap vulnerabilities in glibc by creating overlapping chunks through unsorted bin splitting. Use this skill whenever the user mentions heap exploitation, use-after-free, glibc malloc, unsorted bins, tcache, CTF challenges involving memory corruption, or needs to create overlapping memory regions. Make sure to use this skill for any heap-based vulnerability analysis, even if the user doesn't explicitly mention 'first-fit' or 'unsorted bin'.
---

# First-Fit Heap Exploitation

This skill helps you exploit first-fit heap vulnerabilities in glibc by creating overlapping memory chunks through unsorted bin splitting.

## When to Use This Skill

Use this skill when:
- You're working on a heap exploitation challenge
- You have a use-after-free vulnerability
- You need to create overlapping chunks in glibc
- You're dealing with unsorted bin or fastbin attacks
- You need to understand tcache behavior in modern glibc (2.26+)
- You're analyzing CTF write-ups involving heap corruption

## Core Concept

When glibc frees memory, it places chunks in different bins. The **unsorted bin** uses a first-fit allocation strategy that can be exploited to create overlapping chunks.

### Unsorted Bin Behavior

1. Freed chunks go to the unsorted bin (if not fastbin-sized)
2. New chunks are added to the **head** of the list
3. Allocation searches from the **tail** for a suitable chunk
4. If a chunk is larger than needed, it gets **split**
5. The split remainder stays in the bin, creating overlap opportunities

### Fastbin Behavior (LIFO)

Fastbins use last-in-first-out behavior:
- Chunks added to head on free
- Chunks removed from head on allocation
- Creates predictable reuse patterns

## Exploitation Recipe

Follow this sequence to create overlapping chunks:

1. **Drain tcache** - Allocate and free 7 chunks of the target size to exhaust tcache
2. **Free a large chunk** - This goes to the unsorted bin
3. **Allocate smaller** - Request a size smaller than the freed chunk to force a split
4. **Allocate again** - The leftover portion overlaps with existing allocations
5. **Exploit the overlap** - Overwrite sensitive data through the overlapping pointer

## Practical Example

```c
// Step 1: Drain tcache for 0x420 size
for(int i = 0; i < 7; i++) {
    char *tmp = malloc(0x420);
    free(tmp);
}

// Step 2: Create adjacent chunks
char *A = malloc(0x420);
char *B = malloc(0x420);
free(A);  // A → unsorted bin

// Step 3: Force split
char *C = malloc(0x400);  // Returns lower half of A

// Step 4: Create overlap
char *C2 = malloc(0x400);  // Overlaps with B!

// Step 5: Exploit
memset(B, 'X', 0x10);
// C2 now contains 'X' - arbitrary write achieved!
```

## Tcache Considerations (glibc 2.26+)

Modern glibc uses tcache before unsorted bins. To reach first-fit behavior:

- Request sizes **> 0x420** (tcache_max on 64-bit), OR
- Exhaust tcache by allocating 7 chunks of the same size

```c
// Drain tcache helper
void drain_tcache(size_t size) {
    char *pool[7];
    for(int i = 0; i < 7; i++) pool[i] = malloc(size);
    for(int i = 0; i < 7; i++) free(pool[i]);
}
```

## Common Attack Patterns

### 1. Function Pointer Overwrite
Overwrite vtable or function pointers in overlapping structures to redirect execution.

### 2. __free_hook Overwrite
Overwrite `__free_hook` to redirect `free()` to your shellcode or ROP chain.

### 3. Heap Leak
Use overlap to leak heap addresses, then calculate libc base.

### 4. GOT Entry Overwrite
Overwrite GOT entries for ROP gadget chaining.

## Mitigations & Hardening

| Mitigation | Effectiveness |
|------------|---------------|
| Safe-linking (glibc ≥ 2.32) | Protects tcache/fastbin only, not unsorted bins |
| Heap pointer encryption (ARM64) | Doesn't affect x86-64 glibc |
| `GLIBC_TUNABLES=glibc.malloc.check=3` | Aborts on inconsistent metadata |
| Future tcache filling (glibc 2.41+) | Would reduce unsorted bin usage |

## Debugging Tips

1. **Check chunk addresses** - Print pointers to verify overlap
2. **Use gdb with heapviz** - Visualize heap state
3. **Enable malloc debugging** - `MALLOC_CHECK_=3` for validation
4. **Trace allocations** - Use `LD_PRELOAD` with malloc hooks

## References

- [heap-exploitation.dhavalkapil.com/attacks/first_fit](https://heap-exploitation.dhavalkapil.com/attacks/first_fit)
- [CTF Wiki - Use After Free](https://ctf-wiki.mahaloz.re/pwn/linux/glibc-heap/use_after_free/)
- [HITCON 2024 Quals Setjmp write-up](https://ctftime.org/writeup/39355)
- [Angstrom CTF 2024 heapify write-up](https://hackmd.io/@aneii11/H1S2snV40)

## Quick Start

Run the template generator to create a customized exploit:

```bash
python scripts/generate_first_fit_template.py 0x420 0x400
```

This generates a complete C exploit template with your specified sizes.
