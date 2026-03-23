---
name: house-of-orange-exploit
description: House of Orange heap exploitation technique for glibc < 2.26. Use this skill whenever the user mentions heap exploitation, glibc vulnerabilities, malloc_printerr abuse, _IO_FILE structure forgery, or needs to exploit a heap overflow in older libc versions. This skill guides users through the complete House of Orange attack chain including top chunk manipulation, unsorted bin attacks, and fake _IO_FILE structure creation for arbitrary code execution.
---

# House of Orange Exploitation

A heap exploitation technique that abuses `malloc_printerr` in glibc versions before 2.26 to achieve arbitrary code execution through fake `_IO_FILE` structure forgery.

## When to Use This Skill

Use this skill when:
- You have a heap overflow vulnerability in a program linked against glibc < 2.26
- You need to exploit a heap corruption bug without calling `free`
- You want to abuse `malloc_printerr` for code execution
- You need to forge `_IO_FILE` structures for libc exploitation
- You're working on CTF challenges involving heap exploitation

## Requirements

Before attempting this attack, verify:
- **glibc version < 2.26** (the vulnerability was patched in 2.26)
- **Heap overflow** that can overwrite the top chunk size
- **Libc leak** to get base address
- **Heap leak** to get heap base address
- **No ASLR** or ability to bypass it

## Background

In older glibc versions, `malloc_printerr` iterates through `_IO_FILE` structs stored in `_IO_list_all` and executes instruction pointers in those structs. This attack forges a fake `_IO_FILE` struct, writes it to `_IO_list_all`, and causes `malloc_printerr` to execute arbitrary code.

## Attack Flow

### Step 1: Set Up the Top Chunk

1. Allocate a chunk to create the top chunk
2. Overflow the allocated chunk to modify the top chunk size
3. Ensure **top chunk + size** is page-aligned
4. Ensure the **prev_inuse** bit of the top chunk is set

### Step 2: Force Top Chunk into Unsorted Bin

1. Allocate a chunk larger than the new top chunk size (but smaller than `mmap_threshold`, default 128K)
2. This moves the old top chunk into the unsorted bin
3. **Note**: `free` is never called in this attack

### Step 3: Leak Libc Addresses

1. Read data from the old top chunk in the unsorted bin
2. Extract libc addresses from the chunk metadata
3. Calculate the address of `_IO_list_all`

### Step 4: Perform Unsorted Bin Attack

1. Use the overflow to write `topChunk->bk->fwd = _IO_list_all - 0x10`
2. When a new chunk is allocated, the old top chunk is split
3. A pointer to the unsorted bin is written into `_IO_list_all`

### Step 5: Shrink the Old Top Chunk

1. Adjust the size of the old top chunk to **0x61**
2. This serves two purposes:
   - **Insertion into Small Bin 4**: The chunk ends up at the head of small bin 4, which is the location of the FD pointer of `_IO_list_all`
   - **Triggering Malloc Check**: The size manipulation causes `malloc` to perform internal checks, triggering `malloc_printerr` when it sees a zero forward chunk

### Step 6: Set Up Fake `_IO_FILE` Structure

1. Forge a fake `_IO_FILE` structure that overlaps with the old top chunk
2. Set key fields to pass libc internal checks:
   - `_IO_write_base` and `_IO_write_ptr` must be set correctly
   - Create a jump table with instruction pointer pointing to `system` or similar
3. Include a pointer to a command (e.g., "/bin/sh")

### Step 7: Trigger Code Execution

1. Allocate a chunk to trigger the attack
2. The manipulated `_IO_FILE` structure causes arbitrary code execution
3. Typically results in shell spawn or payload execution

## Helper Scripts

Use the bundled scripts to assist with the attack:

### Generate Fake _IO_FILE Structure

```bash
python scripts/generate_fake_io_file.py --help
```

This script generates a properly formatted fake `_IO_FILE` structure with the correct field values for the attack.

### Calculate Offsets

```bash
python scripts/calc_offsets.py --help
```

This script calculates the necessary offsets for `_IO_list_all`, `_IO_FILE` fields, and other libc structures.

## Example Exploit Structure

```python
from pwn import *

# Connect to target
p = process('./vulnerable_program')

# Step 1: Leak libc and heap addresses
# ... (implementation depends on vulnerability)

# Step 2: Calculate addresses
io_list_all = libc.address + libc.symbols['_IO_list_all']
system = libc.address + libc.symbols['system']
bin_sh = next(libc.search(b'/bin/sh\x00'))

# Step 3: Generate fake _IO_FILE structure
fake_io_file = generate_fake_io_file(system, bin_sh)

# Step 4: Perform the attack
# ... (heap overflow to set up conditions)

# Step 5: Trigger execution
# ... (final malloc call)

p.interactive()
```

## Common Pitfalls

1. **glibc version**: Verify the target uses glibc < 2.26
2. **Page alignment**: Ensure top chunk + size is page-aligned
3. **prev_inuse bit**: Must be set on the top chunk
4. **_IO_FILE field values**: Must pass libc internal checks
5. **mmap_threshold**: Keep allocations under 128K to avoid mmap

## References

- [CTF Wiki - House of Orange](https://ctf-wiki.mahaloz.re/pwn/linux/glibc-heap/house_of_orange/)
- [GuyInATuxedo - House of Orange](https://guyinatuxedo.github.io/43-house_of_orange/house_orange_exp/index.html)
- [how2heap - House of Orange Example](https://github.com/shellphish/how2heap/blob/master/glibc_2.23/house_of_orange.c)
- [glibc Patch](https://sourceware.org/git/?p=glibc.git;a=blobdiff;f=stdlib/abort.c;h=117a507ff88d862445551f2c07abb6e45a716b75;hp=19882f3e3dc1ab830431506329c94dcf1d7cc252;hb=91e7cf982d0104f0e71770f5ae8e3faf352dea9f;hpb=0c25125780083cbba22ed627756548efe282d1a0)

## Test Cases

To verify this skill works correctly, try these prompts:

1. "I have a heap overflow in a program with glibc 2.23. How do I use House of Orange to get a shell?"
2. "Generate a fake _IO_FILE structure for House of Orange exploitation targeting system('/bin/sh')"
3. "Explain the House of Orange attack step by step for a CTF writeup"
4. "Calculate the offsets needed for House of Orange on glibc 2.23 with libc base 0x7ffff7c00000"
