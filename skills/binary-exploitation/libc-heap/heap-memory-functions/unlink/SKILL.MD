---
name: heap-unlink-exploitation
description: How to analyze and exploit the unlink operation in glibc heap management. Use this skill whenever the user mentions heap exploitation, unlink attacks, glibc malloc, heap chunks, double-linked lists, heap leaks, libc leaks, or any CTF challenge involving heap memory corruption. This skill helps understand the unlink mechanism, security checks, and how to leak addresses from unlinked chunks.
---

# Heap Unlink Exploitation

This skill helps you understand and exploit the `unlink` operation in glibc's heap management system. The unlink function is critical for heap exploitation because it's where many vulnerabilities manifest.

## When to Use This Skill

Use this skill when:
- You're working on a CTF challenge involving heap exploitation
- You need to understand how glibc's malloc handles chunk removal
- You want to leak libc or heap addresses through unlink operations
- You're analyzing heap corruption vulnerabilities
- You need to understand the security checks in unlink

## The Unlink Operation

### What is Unlink?

When a chunk is freed, glibc removes it from its bin list using the `unlink_chunk` function. This operation manipulates the doubly-linked list pointers (`fd` and `bk`) to remove the chunk from the list.

### The Core Unlink Logic

```c
mchunkptr fd = p->fd;
mchunkptr bk = p->bk;

fd->bk = bk;
bk->fd = fd;
```

This is the dangerous part: **unlink writes to memory at `fd` and `bk` without verifying they point to valid locations**. If you can control these pointers through heap corruption, you can write arbitrary values to arbitrary addresses.

### Visual Representation

```
Before unlink:
[fd] <-> [P] <-> [bk]
  |       |       |
  v       v       v
  bk      P       fd

After unlink:
[fd] <-> [bk]
  |       |
  v       v
  bk      fd
```

## Security Checks

Modern glibc versions include several checks to prevent exploitation:

### 1. Size Check
```c
if (chunksize(p) != prev_size(next_chunk(p)))
    malloc_printerr("corrupted size vs. prev_size");
```
- Verifies the chunk's size matches the `prev_size` field in the next chunk
- **Bypass**: Ensure size consistency when crafting exploits

### 2. Double-Linked List Integrity
```c
if (fd->bk != p || bk->fd != p)
    malloc_printerr("corrupted double-linked list");
```
- Confirms the pointers form a valid doubly-linked list
- **Bypass**: Maintain pointer consistency in your fake chunks

### 3. Nextsize Checks (for non-small bins)
```c
if (p->fd_nextsize->bk_nextsize != p || p->bk_nextsize->fd_nextsize != p)
    malloc_printerr("corrupted double-linked list (not small)");
```
- Additional checks for large bins with nextsize pointers
- **Bypass**: Handle nextsize pointers if targeting large bins

## Address Leaks Through Unlink

Unlinked chunks don't clean their pointers, making them valuable for information leaks.

### Libc Address Leaks

| Chunk Position | Pointer | Leaks |
|----------------|---------|-------|
| Head of list | `bk` | `malloc_state` in libc |
| End of list | `fd` | `malloc_state` in libc |
| Only chunk in list | `fd` and `bk` | `malloc_state` in libc |

### Heap Address Leaks

| Chunk Position | Pointer | Leaks |
|----------------|---------|-------|
| Head of list | `fd` | Next available heap chunk |
| End of list | `bk` | Previous available heap chunk |
| Middle of list | `fd` and `bk` | Adjacent heap chunks |

## Exploitation Patterns

### Pattern 1: Arbitrary Write via Unlink

If you can corrupt `fd` and `bk` pointers:

1. Allocate chunks A, B, C in sequence
2. Corrupt B's `fd` to point to `target_addr - 8`
3. Corrupt B's `bk` to point to `target_addr - 16`
4. Free B (triggers unlink)
5. Result: `target_addr` gets overwritten with controlled value

### Pattern 2: Libc Leak

1. Allocate a chunk in a bin
2. Free it (it becomes unlinked but pointers remain)
3. Read the chunk's `fd` or `bk` pointer
4. Calculate libc base from the leaked `malloc_state` address

### Pattern 3: Heap Leak

1. Allocate multiple chunks
2. Free one chunk (unlinked)
3. Read its `fd`/`bk` to discover other heap addresses
4. Use this to calculate heap base or find other allocations

## Practical Workflow

### Step 1: Identify the Vulnerability

Look for:
- Use-after-free bugs
- Heap buffer overflows
- Double-free vulnerabilities
- Off-by-one errors in heap allocations

### Step 2: Map the Heap Layout

1. Determine chunk sizes and positions
2. Identify which bin each chunk belongs to
3. Understand the doubly-linked list structure

### Step 3: Plan the Exploit

1. Decide your goal (arbitrary write, leak, etc.)
2. Calculate required pointer values
3. Ensure all security checks will pass
4. Craft the payload

### Step 4: Execute and Verify

1. Trigger the unlink operation
2. Verify the write/leak succeeded
3. Proceed with the rest of the exploit

## Common Pitfalls

1. **Size mismatches**: Ensure `chunksize` matches `prev_size` in next chunk
2. **Alignment issues**: Heap chunks must be properly aligned (typically 8 or 16 bytes)
3. **Bin selection**: Different bins have different checks (small vs. large bins)
4. **Top chunk**: Don't try to unlink the top chunk
5. **In-use chunks**: Can only unlink free chunks in bins

## Debugging Tips

### Using GDB with Heap Analysis

```gdb
# Load the binary
gdb ./vulnerable_program

# Enable heap debugging
set follow-fork-mode child

# Use heap tools
heap
heap chunks
heap bins
```

### Using Pwntools

```python
from pwn import *

# Connect to the target
p = process('./vulnerable')

# Use heap analysis
from pwn import heap
heap(p)
```

## Example Scenario

**Challenge**: A program has a use-after-free vulnerability in a heap-allocated buffer.

**Goal**: Leak libc address to bypass ASLR.

**Approach**:
1. Allocate chunk A (victim)
2. Allocate chunk B (to corrupt)
3. Free A (it goes to a bin)
4. Overwrite A's `fd`/`bk` through B's overflow
5. Free B (triggers unlink on A)
6. Read A's pointers to leak libc

## Related Concepts

- **Heap bins**: tcache, smallbins, largebins, unsortedbin
- **Chunk structure**: size, prev_size, fd, bk, fd_nextsize, bk_nextsize
- **Other heap attacks**: House of Force, House of Spirit, Tcache poisoning
- **Memory protection**: ASLR, PIE, Stack canaries, Heap canaries

## References

- [glibc malloc source](https://github.com/bminor/glibc/blob/master/malloc/malloc.c)
- [CTF Wiki - Heap Exploitation](https://ctf-wiki.mahaloz.re/pwn/linux/glibc-heap/)
- [HackTricks - Heap Exploitation](https://book.hacktricks.xyz/pentesting/heap-exploitation)

---

**Remember**: Heap exploitation is complex and version-dependent. Always verify your assumptions against the target's glibc version and configuration.
