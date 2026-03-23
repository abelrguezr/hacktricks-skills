---
name: tcache-exploitation
description: How to identify and exploit Tcache bin attacks in heap vulnerabilities. Use this skill whenever the user mentions heap exploitation, tcache, malloc, free, heap overflow, double free, use-after-free, libc leaks, malloc_hook, free_hook, or any heap-related binary exploitation challenge. This skill covers Tcache poisoning, Tcache index attacks, and common CTF patterns for Glibc 2.26+.
---

# Tcache Exploitation Skill

A comprehensive guide for identifying and exploiting Tcache vulnerabilities in binary exploitation challenges.

## When to Use This Skill

Use this skill when working with:
- Heap exploitation challenges (CTF, security research, vulnerability analysis)
- Binaries compiled with Glibc 2.26 or newer (Tcache introduced in 2.26)
- Vulnerabilities involving `malloc`, `free`, double free, use-after-free, or heap overflow
- Challenges requiring libc address leaks or arbitrary writes
- Any mention of `tcache`, `malloc_hook`, `free_hook`, or heap bin manipulation

## Core Concepts

### What is Tcache?

Tcache (thread cache) was introduced in Glibc 2.26 to improve memory allocation performance. It maintains per-thread caches of freed chunks before returning them to the main heap.

**Key properties:**
- Per-thread cache (not shared across threads)
- Stores up to 7 chunks per size class by default
- Uses a singly-linked list (FD pointer only)
- No size validation on allocation (unlike fast bins)
- No alignment checks in older versions (error: `malloc(): unaligned tcache chunk detected` in newer versions)

### Tcache Poisoning Attack

The Tcache attack (also called Tcache poisoning) is similar to fast bin attacks:

**Goal:** Overwrite the `next` pointer (FD) in a freed chunk to point to an arbitrary address, then allocate that address.

**Basic flow:**
1. Allocate a chunk and free it (adds to tcache)
2. Overflow/modify the freed chunk's FD pointer to point to target address
3. Allocate a chunk of the same size → returns the target address
4. Use the returned chunk to overwrite critical data (e.g., `__malloc_hook`)

**Important:** The target address must be aligned (8-byte aligned on 64-bit systems). If not aligned, you may need to run the binary multiple times or find an aligned target.

### Tcache Index Attack

The tcache structure itself contains metadata that can be exploited:

**Tcache structure layout:**
- Array of chunk counts per size index
- Array of head pointers for each tcache bin

**Attack pattern:**
1. Modify the tcache metadata (chunk count or head pointer)
2. Make a tcache bin's head pointer point to a desired address (e.g., `__malloc_hook`)
3. Allocate a chunk of that size → returns the target address
4. Overwrite the target (e.g., write one-gadget to `__malloc_hook`)

## Common Attack Patterns

### Pattern 1: Double Free Tcache Poisoning

**Vulnerability:** Double free of the same chunk

**Exploitation:**
1. Allocate chunk A
2. Free chunk A (A → NULL in tcache)
3. Free chunk A again (A → A in tcache, self-referential)
4. Allocate chunk A (returns A, tcache head now points to A's FD)
5. Modify A's FD to point to `__free_hook`
6. Allocate again → returns chunk at `__free_hook`
7. Write `system` address to `__free_hook`
8. Free a chunk containing "/bin/sh" → shell

### Pattern 2: Heap Overflow + Size Manipulation

**Vulnerability:** 1-byte heap overflow allowing size header modification

**Exploitation:**
1. Allocate chunk A (small size)
2. Overflow to increase A's size header
3. Free chunk A (goes to tcache of fake larger size)
4. Allocate chunk of fake size → returns A but with larger apparent size
5. Use the extra space to overwrite next chunk's FD pointer
6. Point FD to `__malloc_hook`
7. Allocate twice: first gets legit chunk, second gets `__malloc_hook`
8. Write one-gadget to `__malloc_hook`
9. Trigger malloc → shell

### Pattern 3: Tcache Index Corruption

**Vulnerability:** Ability to free arbitrary heap addresses

**Exploitation:**
1. Allocate and free a chunk of specific size that creates value 0x100 in tcache metadata
2. The tcache stores chunk counts in specific bytes, creating exploitable values
3. Free the address 0x100 (looks like a valid chunk)
4. This adds 0x100 to the tcache index for size 0x100
5. Allocate size 0x100 → returns address 0x100
6. Use this to overwrite other tcache indexes
7. Point an index to `__malloc_hook`, allocate that size, write one-gadget

### Pattern 4: Libc Leak via Unsorted Bin

**Vulnerability:** Use-after-free or double free

**Exploitation:**
1. Fill all tcaches (7 chunks per size class)
2. Add one more chunk → goes to unsorted bin
3. Empty the tcache (allocate all cached chunks)
4. Re-allocate the unsorted bin chunk
5. Overwrite only first 8 bytes, leaving second address intact
6. The second address is a libc pointer → leak libc base

## Step-by-Step Exploitation Workflow

### Step 1: Identify the Vulnerability

Look for:
- Double free vulnerabilities
- Use-after-free conditions
- Heap overflow (especially 1-byte overflows)
- Arbitrary free capabilities
- Uninitialized pointers in heap chunks

### Step 2: Determine Glibc Version

Check if Tcache is available:
- Glibc 2.26+ has Tcache
- Use `ldd --version` or check binary's linked libc
- Tcache errors: `malloc(): unaligned tcache chunk detected`

### Step 3: Map the Heap Layout

Understand:
- Where chunks are allocated
- Where tcache metadata is stored
- Distance between chunks and targets (`__malloc_hook`, `__free_hook`)
- Alignment requirements (8-byte on 64-bit)

### Step 4: Choose Attack Pattern

Based on vulnerability type:
- **Double free** → Pattern 1 (self-referential tcache)
- **Heap overflow** → Pattern 2 (size manipulation)
- **Arbitrary free** → Pattern 3 (tcache index corruption)
- **Need libc leak** → Pattern 4 (unsorted bin leak)

### Step 5: Craft the Exploit

1. **Fill tcaches** if needed (7 chunks per size class)
2. **Trigger the vulnerability** (double free, overflow, etc.)
3. **Manipulate FD pointers** to point to targets
4. **Allocate chunks** to get control over target addresses
5. **Write payloads** (one-gadget, system address, etc.)
6. **Trigger the payload** (malloc, free, etc.)

### Step 6: Handle Alignment

If getting `unaligned tcache chunk detected`:
- Find aligned target addresses
- Run binary multiple times until alignment works
- Use heap feng-shui to control alignment

## Key Addresses to Target

| Address | Purpose | How to Exploit |
|---------|---------|----------------|
| `__malloc_hook` | Called on malloc | Write one-gadget, trigger malloc |
| `__free_hook` | Called on free | Write system, free "/bin/sh" |
| `stdout` | File pointer | FSOP (File Stream Oriented Programming) |
| `tcache` metadata | Tcache structure | Corrupt to control allocations |

## Common One-Gadgets

Find one-gadgets in libc:
```bash
one_gadget /path/to/libc.so.6
```

Common patterns:
- `ret; pop rdi; ret` + `/bin/sh` address
- `execve` gadgets
- `system` gadgets

## Debugging Tips

### Check Tcache State

Use GDB with `heap` commands:
```gdb
heap analyze
heap chunks
heap tcache
```

### Common Errors

- `malloc(): unaligned tcache chunk detected` → Address not 8-byte aligned
- `double free or corruption` → Tcache not being used, or older Glibc
- `corrupted size vs. prev_size` → Size header corruption

### Verify Exploit

1. Check if libc leak works (compare with `ldd` output)
2. Verify FD pointer overwrites (GDB `x/gx` command)
3. Confirm hook addresses are writable
4. Test one-gadget execution

## Learning Resources

### CTF Writeups (Study These Patterns)

1. **DCQuals19 Babyheap** - Libc leak + Tcache attack with 1-byte overflow
   - https://guyinatuxedo.github.io/29-tcache/dcquals19_babyheap/index.html

2. **Plaid19 Cpp** - Double free Tcache poisoning
   - https://guyinatuxedo.github.io/29-tcache/plaid19_cpp/index.html

3. **CSAW19 Popping Caps0** - Tcache index attack
   - https://guyinatuxedo.github.io/44-more_tcache/csaw19_popping_caps0/index.html

4. **CSAW19 Popping Caps1** - Optimized tcache index attack
   - https://guyinatuxedo.github.io/44-more_tcache/csaw19_popping_caps1/index.html

5. **HTB Math Door** - Write-after-free + heap feng-shui
   - https://7rocky.github.io/en/ctf/other/htb-cyber-apocalypse/math-door/

### Reference Material

- **Guy In A Tuxedo Tcache Explanation** - Comprehensive Tcache guide
  - https://guyinatuxedo.github.io/29-tcache/tcache_explanation/index.html

- **Bins and Memory Allocations** - Heap bin fundamentals
  - See: `bins-and-memory-allocations.md`

## Quick Reference

### Tcache Size Classes

Tcache has 7 chunks per size class. Common sizes:
- 0x20, 0x30, 0x40, 0x50, 0x60, 0x70, 0x80, 0x90, 0xa0, 0xb0, 0xc0, 0xd0, 0xe0, 0xf0, 0x100

### Chunk Structure (64-bit)

```
[prev_size: 8 bytes]
[size: 8 bytes] (includes prev_inuse flag)
[FD pointer: 8 bytes] (tcache only, no BK)
[payload: size - 16 bytes]
```

### Exploit Checklist

- [ ] Identify vulnerability type
- [ ] Confirm Glibc 2.26+
- [ ] Map heap layout
- [ ] Choose attack pattern
- [ ] Fill tcaches if needed
- [ ] Trigger vulnerability
- [ ] Overwrite FD pointers
- [ ] Allocate target chunks
- [ ] Write payload
- [ ] Trigger payload
- [ ] Handle alignment issues

## When This Skill Applies

Use this skill for:
- CTF heap exploitation challenges
- Security research on heap vulnerabilities
- Binary analysis involving malloc/free
- Learning heap exploitation techniques
- Writing exploit code for Tcache vulnerabilities

Do NOT use this skill for:
- Non-heap vulnerabilities (stack, format string, etc.)
- Glibc versions before 2.26 (no Tcache)
- Non-Glibc allocators (jemalloc, tcmalloc, etc.)
- High-level application bugs without heap primitives
