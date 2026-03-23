---
name: house-of-force-exploit
description: How to perform House of Force heap exploitation attacks. Use this skill whenever the user mentions heap exploitation, House of Force, top chunk manipulation, arbitrary memory allocation, malloc manipulation, or wants to allocate chunks at specific addresses. Also trigger for CTF challenges involving heap overflows, top chunk size overwrites, or when the user needs to calculate evil_size for heap attacks. Make sure to use this skill for any binary exploitation task involving glibc heap manipulation, even if they don't explicitly say "House of Force".
---

# House of Force Exploitation

A heap exploitation technique that allows allocating a chunk at a specific address by manipulating the top chunk size.

## When to Use This Attack

Use House of Force when:
- You have an overflow that can overwrite the top chunk size field
- You can control malloc allocation sizes
- You need to allocate a chunk at a specific address (e.g., to overwrite a GOT entry, function pointer, or other target)
- The target is in the heap or reachable from the heap

## Attack Prerequisites

1. **Overflow vulnerability** - Must be able to overwrite the top chunk header size field (typically with `-1` or `0xffffffffffffffff`)
2. **Allocation size control** - Must be able to specify malloc sizes
3. **Target address** - Know the address you want to allocate at

## Attack Methodology

### Step 1: Overwrite Top Chunk Size

Overwrite the top chunk size with `-1` (or `p64(0xffffffffffffffff)` in Python). This ensures malloc won't use mmap for any allocation since the top chunk will always appear to have enough space.

```python
# Example: overwrite top chunk size with -1
payload = b'A' * offset_to_top_chunk_size + p64(0xffffffffffffffff)
```

### Step 2: Calculate Evil Size

Calculate the allocation size needed to move the top chunk to your target address:

```
evil_size = target_address - current_top_chunk_address - 4 * sizeof(long)
```

**Why 4 longs?**
- 2 longs for the current top chunk metadata (size + flags)
- 2 longs for the new chunk metadata that will be created

**Python calculation:**
```python
from pwn import *

evil_size = target_addr - top_chunk_addr - 4 * 8  # 8 bytes per long on 64-bit
```

### Step 3: Allocate Evil Size

Perform a malloc with the calculated evil_size. This moves the top chunk to the target address.

```python
io.recvuntil(b'prompt>')
io.sendline(str(evil_size).encode())
```

### Step 4: Allocate at Target

Perform another malloc to get a chunk at the target address. Now you can write to that address.

```python
io.recvuntil(b'prompt>')
io.sendline(b'/bin/sh')  # or whatever payload you need
```

## Common Scenarios

### Scenario 1: Overwrite GOT Entry

**Goal:** Redirect function calls to your code

1. Leak libc address (if needed for ASLR)
2. Overwrite top chunk size with `-1`
3. Calculate evil_size to reach GOT entry
4. Allocate evil_size to move top chunk
5. Allocate at GOT address and write function address (e.g., `system`)
6. Trigger the function call

### Scenario 2: Ret2Win Challenge

**Goal:** Modify a function pointer to point to ret2win

1. Overwrite top chunk size with `-1`
2. Calculate distance from top chunk to function pointer
3. Allocate that size to move top chunk
4. Allocate at function pointer address
5. Write ret2win address
6. Trigger the function call

### Scenario 3: Free Hook Overwrite

**Goal:** Overwrite `__free_hook` to call system

1. Leak libc address
2. Overwrite top chunk size with `-1`
3. Calculate evil_size to reach `__free_hook`
4. Allocate evil_size
5. Allocate at `__free_hook` address
6. Write `system` address
7. Free a chunk containing `/bin/sh`

## Helper Script

Use `scripts/calculate_evil_size.py` to compute the evil_size for your attack:

```bash
python scripts/calculate_evil_size.py --target 0x404000 --top-chunk 0x602000
```

## Important Notes

- **Patched in modern glibc** - This technique was patched and produces `malloc(): corrupted top size` error in newer versions. Works on glibc < 2.26 or with specific conditions.
- **Alignment matters** - Ensure your target address is properly aligned for heap chunks
- **Size field format** - The size field includes flags; use `p64(0xffffffffffffffff)` for -1
- **Top chunk location** - The top chunk is typically at the end of the heap arena

## Debugging Tips

1. **Check top chunk location** - Use GDB with `heap` commands or `vmmap` to find the top chunk
2. **Verify size overwrite** - After overflow, check if top chunk size is actually `-1`
3. **Watch for mmap** - If malloc uses mmap, your size calculation is wrong
4. **Use ASLR off** - For testing, disable ASLR to get consistent addresses

## References

- [how2heap - House of Force](https://github.com/shellphish/how2heap/tree/master)
- [CTF Wiki - House of Force](https://ctf-wiki.mahaloz.re/pwn/linux/glibc-heap/house_of_force/)
- [Guy In A Tuxedo - House of Force](https://guyinatuxedo.github.io/41-house_of_force/house_force_exp/index.html)
- [Heap Exploitation Guide](https://heap-exploitation.dhavalkapil.com/attacks/house_of_force)
