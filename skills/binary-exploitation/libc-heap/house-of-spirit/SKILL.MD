---
name: house-of-spirit-exploit
description: House of Spirit heap exploitation guide. Use this skill whenever the user mentions heap exploitation, fake chunks, tcache poisoning, fastbin attacks, binary exploitation with heap vulnerabilities, or needs to create fake heap chunks for CTF challenges. This skill helps create fake heap chunks that bypass glibc security checks to achieve arbitrary memory allocation.
---

# House of Spirit Exploitation

A guide for creating fake heap chunks to bypass glibc security checks and achieve arbitrary memory allocation.

## What is House of Spirit?

House of Spirit is a heap exploitation technique where you create fake heap chunks in arbitrary memory locations (stack, BSS, etc.) and trick the allocator into thinking they're real chunks. When freed, these fake chunks enter the fastbin or tcache, allowing you to allocate them back and write to arbitrary addresses.

## When to Use This Attack

- You have a way to control a pointer that will be freed
- You need to allocate memory at a specific address (e.g., to overlap with a target buffer)
- You want to achieve arbitrary write primitives
- You're working with heap vulnerabilities in CTF challenges

## Requirements

### Fastbin Variant (glibc < 2.26 or when tcache is disabled)
- Create **two consecutive fake chunks** with valid sizes
- First chunk's size must be in fastbin range (0x20-0x70 on x64)
- Second chunk's size must also be valid (for next-chunk size check)
- Both chunks must be properly aligned

### Tcache Variant (glibc ≥ 2.26)
- Create **one fake chunk** (simpler!)
- Chunk must be **16-byte aligned**
- Size must be in tcache bin range (0x20-0x410 on x64)
- Size must have `prev_inuse` bit set (`size | 1`)
- Tcache for that bin must not be full (max 7 entries)

## Attack Flow

1. **Create fake chunk(s)** in a controllable memory region (stack, BSS, etc.)
2. **Set up chunk headers** with valid sizes
3. **Overwrite a pointer** to point to your fake chunk's content area
4. **Free the pointer** - fake chunk enters fastbin/tcache
5. **Allocate** - you get a pointer to your fake chunk's content
6. **Write to target** - use the allocated memory to overwrite your target

## Chunk Layout

### Fastbin (2 chunks required)

```
+-------+---------------------+------+  <- fake_chunks[0]
| 0x00: | Chunk #0 prev_size  | 0x00 |
+-------+---------------------+------+
| 0x08: | Chunk #0 size       | 0x60 |
+-------+---------------------+------+
| 0x10: | Chunk #0 content    | 0x00 |
+-------+---------------------+------+
| 0x60: | Chunk #1 prev_size  | 0x00 |
+-------+---------------------+------+
| 0x68: | Chunk #1 size       | 0x40 |
+-------+---------------------+------+
| 0x70: | Chunk #1 content    | 0x00 |
+-------+---------------------+------+
```

### Tcache (1 chunk required)

```
+-------+---------------------+------+  <- fake[0]
| 0x00: | prev_size (ignored) | 0x00 |
+-------+---------------------+------+
| 0x08: | size (with prev_inuse)| 0x41 |
+-------+---------------------+------+
| 0x10: | content starts here | 0x00 |
+-------+---------------------+------+
```

## Code Templates

### Fastbin House of Spirit

```c
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

struct fast_chunk {
  size_t prev_size;
  size_t size;
  struct fast_chunk *fd;
  struct fast_chunk *bk;
  char buf[0x20];
};

int main() {
  struct fast_chunk fake_chunks[2];
  void *ptr, *victim;

  // Allocate to get a pointer we can overwrite
  ptr = malloc(0x30);

  // Set up fake chunk sizes
  fake_chunks[0].size = sizeof(struct fast_chunk);
  fake_chunks[1].size = sizeof(struct fast_chunk);

  // Overwrite pointer to point to fake chunk's content
  ptr = (void *)&fake_chunks[0].fd;

  // Free the fake chunk
  free(ptr);

  // Allocate - returns pointer to fake chunk content
  victim = malloc(0x30);
  printf("Victim: %p\n", victim);

  return 0;
}
```

### Tcache House of Spirit (Simpler!)

```c
#include <stdio.h>
#include <stdlib.h>

int main() {
  // 16-byte aligned array for fake chunk
  unsigned long long fake[6] __attribute__((aligned(0x10)));
  
  // Set fake size (0x40 bin, prev_inuse=1)
  fake[1] = 0x41;
  
  // Pointer to content area (after header)
  void *p = &fake[2];
  
  // Free - goes straight into tcache
  free(p);
  
  // Allocate - returns stack address
  void *q = malloc(0x30);
  printf("Got stack address: %p\n", q);
  
  return 0;
}
```

## Common Use Cases

### 1. Libc Leak
- Create fake chunk overlapping GOT entry
- Allocate and read the GOT entry
- Leak libc address

### 2. Arbitrary Write
- Create fake chunk overlapping target buffer
- Allocate and write to target
- Overwrite function pointers, vtables, etc.

### 3. Overlapping Chunks
- Free fake chunk inside valid chunk
- Allocate to get overlapping memory
- Use for tcache poisoning

## Validation Checklist

Before attempting the attack, verify:

- [ ] You can control a pointer that will be freed
- [ ] You have a writable memory region for fake chunks
- [ ] Chunk sizes are in valid bin ranges
- [ ] Alignment requirements are met (16-byte for tcache)
- [ ] Tcache is not full (if using tcache variant)
- [ ] You understand the target's memory layout

## Debugging Tips

1. **Check alignment**: Use `printf("%p\n", &fake_chunk)` to verify 16-byte alignment
2. **Verify sizes**: Ensure sizes match bin requirements
3. **Use gdb**: Set breakpoints on `free` and `malloc` to trace execution
4. **Check tcache**: Use `info tcache` in gdb to see tcache state

## References

- [heap-exploitation.dhavalkapil.com - House of Spirit](https://heap-exploitation.dhavalkapil.com/attacks/house_of_spirit)
- [guyinatuxedo - House of Spirit](https://guyinatuxedo.github.io/39-house_of_spirit/house_spirit_exp/index.html)
- [shellphish/how2heap - tcache_house_of_spirit.c](https://github.com/shellphish/how2heap/blob/master/glibc_2.34/tcache_house_of_spirit.c)

## Next Steps

1. Identify the vulnerability in your target
2. Choose fastbin or tcache variant based on glibc version
3. Create fake chunk(s) in appropriate memory region
4. Overwrite pointer and free
5. Allocate and use the returned pointer
6. Achieve your goal (leak, write, shellcode execution)
