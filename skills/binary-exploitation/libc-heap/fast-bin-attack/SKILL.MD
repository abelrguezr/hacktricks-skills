---
name: fast-bin-attack
description: How to perform fast bin heap exploitation attacks. Use this skill whenever the user mentions heap exploitation, fast bin attacks, use-after-free vulnerabilities, malloc manipulation, or wants to allocate chunks at arbitrary addresses. This skill covers the core fast bin attack pattern, common CTF techniques, and variations like global_max_fast manipulation. Make sure to use this skill when analyzing heap vulnerabilities, planning exploitation strategies, or working with malloc/free primitives.
---

# Fast Bin Attack

A fast bin attack exploits the singly-linked list structure of fast bins in glibc's malloc implementation. By modifying the `next` pointer of a freed chunk, you can cause `malloc` to return a pointer to an arbitrary memory address.

## Core Attack Pattern

### Prerequisites
- Use-after-free (UAF) vulnerability to write to freed chunks
- Ability to control chunk contents (overflow, write primitive, etc.)
- Fast bin sizes: typically 0x10-0x80 (varies by configuration)
- Tcache must be full or disabled for fast bins to be used

### Basic Exploitation Flow

```
1. Allocate two chunks of the same size (e.g., 0x20)
   ptr0 = malloc(0x20)
   ptr1 = malloc(0x20)

2. Free both chunks (they go to fast bin)
   free(ptr0)
   free(ptr1)

3. Use UAF to modify ptr1's next pointer
   *ptr1 = (unsigned long)&<target_address>

4. Allocate to consume ptr0
   ptr2 = malloc(0x20)  // Gets ptr0

5. Allocate to get chunk at target address
   ptr3 = malloc(0x20)  // Gets chunk at &<target_address>
```

### Why This Works

Fast bins are singly-linked lists with minimal validation:
- No size checks on the `next` pointer
- No forward/backward consistency checks
- The `next` pointer is simply the first 8 bytes of the freed chunk
- When you allocate, malloc returns the address stored in `next`

## Common Attack Scenarios

### 1. Overwrite GOT Entry

Use fast bin attack to allocate a chunk at `&free@got` or `&printf@got`, then write a one-gadget address:

```
1. Leak libc address (via unsorted bin or other technique)
2. Calculate &free@got = libc_base + free_offset
3. Fast bin attack to allocate chunk at &free@got
4. Write system() address to that chunk
5. Call free() on a chunk containing "/bin/sh"
```

### 2. Overwrite __malloc_hook

Allocate a chunk at `&__malloc_hook - 0x10` (to account for chunk header), then write a one-gadget:

```
1. Leak libc address
2. Calculate &__malloc_hook = libc_base + __malloc_hook_offset
3. Fast bin attack to allocate at &__malloc_hook - 0x10
4. Write one-gadget address to the chunk
5. Trigger malloc to execute the gadget
```

### 3. Overwrite Function Pointers

If the target has a global array of function pointers or chunk pointers:

```
1. Leak address of the pointer array
2. Fast bin attack to allocate chunk at the array
3. Overwrite pointers to controlled addresses
4. Trigger the function call
```

### 4. global_max_fast Manipulation

If you can't use fast bins due to size restrictions:

```
1. Use unsorted bin attack to leak libc
2. Overwrite global_max_fast with a large value (e.g., 0x1000)
3. Now larger chunks go to fast bins instead of unsorted bins
4. Perform fast bin attack with larger chunks
```

Note: This works only 1/16 times due to ASLR (need to match 12 bits out of 16).

## Implementation Template

Use the `scripts/generate_fastbin_exploit.py` script to create a basic exploit template:

```bash
python scripts/generate_fastbin_exploit.py \
  --chunk-size 0x30 \
  --target-address 0x404040 \
  --output exploit.py
```

## Key Considerations

### Fast Bin vs Tcache
- Tcache is checked before fast bins
- If tcache is not full, freed chunks go there instead
- To force fast bin usage:
  - Free 7+ chunks of the same size (fills tcache)
  - Or disable tcache in the binary

### Size Constraints
- Fast bins only accept chunks up to `global_max_fast` (default 0x80)
- Chunk size includes the 8-byte header
- Actual payload size = requested_size - 8

### Alignment
- Allocations are 8-byte aligned
- Target address must be properly aligned
- If targeting `&__malloc_hook`, allocate at `&__malloc_hook - 0x10`

### Double Free Protection
- Fast bins don't check for double frees
- This can be exploited to have the same chunk appear twice in the list
- Useful for creating overlapping chunks

## Common CTF Patterns

### Pattern 1: Infoleak + Fast Bin
1. Use unsorted bin attack to leak libc address
2. Calculate target addresses
3. Perform fast bin attack to overwrite GOT/hook
4. Execute shellcode or one-gadget

### Pattern 2: UAF + Fast Bin
1. Trigger UAF to get write primitive
2. Modify freed chunk's next pointer
3. Allocate to get arbitrary write
4. Overwrite function pointer or GOT

### Pattern 3: Overflow + Fast Bin
1. Use overflow to create fake prev_size
2. Consolidate chunks to leak addresses
3. Use leaked addresses for fast bin attack
4. Overwrite malloc hook or GOT

## Debugging Tips

### Check Fast Bin State
```gdb
# In GDB with pwndbg/gef
heap_analysis
fastbins
```

### Verify Chunk Contents
```gdb
# After freeing, check what's in the chunk
x/10gx ptr0
x/10gx ptr1
```

### Confirm Attack Success
```gdb
# After allocation, verify you got the target address
p ptr3
# Should equal your target address
```

## Safety Notes

- Only use this skill for authorized security research and CTF challenges
- Fast bin attacks are specific to glibc's malloc implementation
- Modern systems may have additional protections (ASLR, PIE, etc.)
- Always verify your target environment before attempting exploitation

## References

- [Guy In A Tuxedo - Fastbin Attack](https://guyinatuxedo.github.io/28-fastbin_attack/explanation_fastbinAttack/index.html)
- [0CTF Babyheap Walkthrough](https://guyinatuxedo.github.io/28-fastbin_attack/0ctf_babyheap/index.html)
- [CSAW 17 Auir Walkthrough](https://guyinatuxedo.github.io/28-fastbin_attack/csaw17_auir/index.html)
- [BlackHat MEA Robot Factory](https://7rocky.github.io/en/ctf/other/blackhat-ctf/robot-factory/)
