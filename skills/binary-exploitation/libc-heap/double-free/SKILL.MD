---
name: double-free-exploitation
description: How to identify, understand, and exploit double-free heap vulnerabilities in C programs. Use this skill whenever the user mentions double-free, heap corruption, memory allocator attacks, fast bin dup, tcache poisoning, or any heap-based vulnerability in C code. Also trigger when users are working on CTF challenges involving heap exploitation, analyzing malloc/free patterns, or debugging memory corruption issues.
---

# Double-Free Heap Exploitation

A skill for understanding and exploiting double-free vulnerabilities in C programs.

## What is a Double-Free?

A double-free occurs when the same memory block is freed more than once. This corrupts the heap allocator's internal data structures and can lead to:

- **Memory corruption**: Allocator metadata gets corrupted
- **Overlapping pointers**: Two pointers reference the same memory location
- **Arbitrary writes**: Attacker can control memory through one pointer affecting another
- **Code execution**: Can lead to ROP chains or shellcode execution

## How It Works

### The Mechanism

1. **First free**: Memory block goes into a free list (fast bin or tcache)
2. **Second free**: If another chunk is freed in between, the double-free check is bypassed
3. **Result**: The same block appears twice in the free list
4. **Exploitation**: When reallocating, you get overlapping pointers

### Fast Bin Dup (Classic Double-Free)

```c
// Fill tcache with 7 freed chunks
free(a); free(b); free(c); free(d); free(e); free(f); free(g);

// Double-free with intervening free
free(h);  // First free of h
free(i);  // Intervening free (bypasses double-free check)
free(h);  // Second free of h - now h is in fast bin twice!

// Reallocate - i1 and i2 get the SAME address
char *i1 = malloc(10);  // Gets h's address
char *i2 = malloc(10);  // Also gets h's address (duplicate!)
```

### Tcache Poisoning Variant

When tcache is involved, you can use null-byte overflows to corrupt size fields:

1. Allocate chunks A, B, C of size 0x110
2. Free B, then free A
3. Reallocate A and overflow with null byte
4. B's size becomes 0x100 instead of 0x111
5. Free B again - now you have two tcache entries pointing to same address

## Identifying Double-Free Vulnerabilities

### Code Patterns to Look For

```c
// Pattern 1: Direct double-free
void *ptr = malloc(100);
free(ptr);
// ... some code ...
free(ptr);  // VULNERABLE

// Pattern 2: Conditional double-free
if (condition) {
    free(ptr);
}
// ... code that might free ptr again ...
free(ptr);  // VULNERABLE if condition was true

// Pattern 3: Function call double-free
void process(void *data) {
    // ... uses data ...
    free(data);  // Frees it
}
// Caller also frees data - VULNERABLE
```

### Debugging with GDB/Pwndbg

```bash
# Set breakpoints on free
break free

# Watch for suspicious patterns
watch *(void **)ptr

# Use pwndbg heap analysis
heap
heap chunks
vmmap
```

## Exploitation Techniques

### Technique 1: Fast Bin Dup for Address Disclosure

When you can't directly overwrite `__malloc_hook`:

1. **Fill tcache** with 7 freed chunks of the same size
2. **Double-free** a chunk (with intervening free)
3. **Reallocate** to get overlapping pointers
4. **Write PIE address** through one pointer
5. **Read through other pointer** to leak address
6. **Calculate base address** and proceed with ROP

### Technique 2: Fast Bin Dup for Code Execution

1. **Target main_arena** (contains PIE addresses, near `__malloc_hook`)
2. **Allocate chunk** at specific offset of main_arena
3. **Continue allocating** until reaching `__malloc_hook`
4. **Overwrite __malloc_hook** with shellcode address
5. **Trigger malloc** to execute shellcode

### Technique 3: Tcache Poisoning

1. **Create double-free** in tcache (not fast bin)
2. **Use overlapping pointers** to corrupt tcache fd pointer
3. **Redirect malloc** to arbitrary address
4. **Overwrite GOT entry** or function pointer

## Practical Example

### Vulnerable Code Analysis

```c
#include <stdio.h>
#include <stdlib.h>

int main() {
    char *a = malloc(10);
    char *b = malloc(10);
    char *c = malloc(10);
    
    free(a);
    free(b);
    free(a);  // DOUBLE FREE - a is now in fast bin twice!
    
    char *a1 = malloc(10);  // Gets a's address
    char *a2 = malloc(10);  // Also gets a's address!
    
    // Now a1 and a2 point to same memory
    strcpy(a1, "controlled");  // Also modifies a2!
    
    return 0;
}
```

### Exploitation Steps

1. **Identify the double-free**: Look for `free(ptr)` called twice on same pointer
2. **Verify with debugger**: Check if addresses overlap after reallocation
3. **Plan the attack**: Decide what you want to overwrite (GOT, function pointer, etc.)
4. **Craft the payload**: Write through one pointer to affect the other
5. **Trigger the exploit**: Call the function or trigger the code path

## Common CTF Patterns

### Dragon Army (HTB)
- Can only allocate fast-bin-sized chunks except 0x70
- Can't directly overwrite `__malloc_hook`
- Use PIE addresses (start with 0x56) as target
- Target `main_arena` offset to reach `__malloc_hook`

### Zero to Hero (PicoCTF)
- Uses tcache bins with null-byte overflow
- Corrupts size field from 0x111 to 0x100
- Creates double-free in tcache
- Leverages tcache poisoning for exploitation

## Prevention and Mitigation

### For Developers

```c
// Always NULL out pointers after freeing
void *ptr = malloc(100);
free(ptr);
ptr = NULL;  // Prevents double-free

// Use smart pointers in C++
std::unique_ptr<char[]> ptr(new char[100]);
// Automatically freed, can't double-free
```

### For Security Testing

1. **Static analysis**: Use tools like AddressSanitizer
2. **Dynamic analysis**: Run with ASan to detect double-frees
3. **Code review**: Look for all `free()` calls and trace pointer ownership

## References

- [Heap Exploitation - Double Free](https://heap-exploitation.dhavalkapil.com/attacks/double_free)
- [Dragon Army HTB Writeup](https://7rocky.github.io/en/ctf/htb-challenges/pwn/dragon-army/)
- [Zero to Hero PicoCTF Writeup](https://7rocky.github.io/en/ctf/picoctf/binary-exploitation/zero_to_hero/)

## Quick Reference

| Technique | When to Use | Key Requirement |
|-----------|-------------|------------------|
| Fast Bin Dup | Classic double-free | 7 freed chunks to fill tcache |
| Tcache Poisoning | Modern glibc | Tcache enabled, size field corruption |
| Address Disclosure | PIE binaries | Need to leak addresses first |
| Code Execution | Full control | Can overwrite function pointers |
