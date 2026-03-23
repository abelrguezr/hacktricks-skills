---
name: libc-protections
description: How to understand and bypass modern libc memory protections including chunk alignment, pointer mangling, safe-linking, and pointer guard. Use this skill whenever working on heap exploitation, binary exploitation challenges, CTF heap tasks, analyzing glibc vulnerabilities, or when you need to understand how to leak and demangle pointers in modern glibc versions (2.32+). Make sure to use this skill when you mention heap, glibc, malloc, fastbin, tcache, pointer guard, safe-linking, or any binary exploitation context.
---

# Libc Protections Guide

A practical guide to understanding and bypassing modern glibc memory protections for binary exploitation and CTF challenges.

## When to Use This Skill

Use this skill when:
- You're working on heap exploitation challenges
- You need to understand glibc memory protections
- You're analyzing a binary with modern glibc (2.32+)
- You need to demangle pointers or understand pointer guard
- You're stuck on a CTF heap challenge
- You need to understand chunk alignment requirements

## Chunk Alignment Enforcement

### What It Is

Malloc allocates memory in **8-byte (32-bit) or 16-byte (64-bit) groupings**. The security feature checks that each chunk aligns correctly before using a pointer from a bin.

### Impact on Exploitation

- **64-bit systems**: Fake chunks can only be placed at 1 out of every 16 addresses
- **32-bit systems**: Fake chunks can only be placed at 1 out of every 8 addresses
- **Fastbin attacks on `__malloc_hook`**: No longer viable due to strict alignment requirements

### Practical Implications

When crafting fake chunks, ensure the address ends in:
- **64-bit**: `0x0` (16-byte aligned)
- **32-bit**: `0x8` (8-byte aligned)

> **Note:** Since glibc 2.34, legacy hooks (`__malloc_hook`, `__free_hook`) are removed from the exported ABI. Modern exploits target tcache per-thread structs, vtable-style callbacks, or use `setcontext` and `_IO_list_all` primitives.

## Pointer Mangling

### The Formula

```
New_Ptr = (L >> 12) XOR P
```

Where:
- **L** = Storage Location of the pointer
- **P** = Actual fastbin/tcache Fd Pointer

### Why It Matters

Pointer mangling prevents:
1. **Partial pointer overwrites** without heap leaks
2. **Relative overwrites** (like House of Roman) without brute-forcing
3. **Tcache/fastbin poisoning** without knowing exact addresses

### Demangling with a Heap Leak

If you have a heap leak, you can recover the original pointer:

```python
def demangle(leaked_fd, storage_location):
    return leaked_fd ^ (storage_location >> 12)
```

### Safe-Linking Bypass

When both the corrupted chunk and victim chunk share the same 4KB page, you can recover the original pointer using just the page offset. If they're on different pages, brute-forcing the 12-bit page offset (0x1000 possibilities) becomes necessary.

```c
// leaked_fd is the mangled Fd read from the chunk on the same page
uintptr_t l = (uintptr_t)&chunk->fd;           // storage location
uintptr_t original = (leaked_fd ^ (l >> 12));  // demangle
```

## Pointer Guard

### What It Does

Pointer guard scrambles function pointers by XORing them with a secret from thread data (`fs:0x30`) and applying a left rotation of 0x11 bits.

### Bypassing with a Leak

1. Find a known function pointer (e.g., `__pthread_attr_destroy`)
2. Read its mangled version from memory
3. Compute the secret: `secret = (mangled >> 0x11) XOR known_address`
4. Use the secret to demangle other pointers

### Practical Attack

```python
def demangle_pointer_guard(mangled, secret):
    # Reverse the rotation
    rotated = ((mangled << 0x11) | (mangled >> (64 - 0x11))) & 0xFFFFFFFFFFFFFFFF
    # XOR with secret
    return rotated ^ secret
```

## GLIBC Tunables

### The Vulnerability

The dynamic loader parses `GLIBC_TUNABLES` before program startup. Mis-parsing bugs here affect libc before most mitigations kick in.

### CVE-2023-4911 (Looney Tunables)

An overlong `GLIBC_TUNABLES` value overflows internal buffers in `ld.so`, enabling privilege escalation on many distros when combined with SUID binaries.

### Exploitation

1. Craft a malicious `GLIBC_TUNABLES` environment variable
2. Invoke the target SUID binary
3. The overflow happens before heap setup, bypassing pointer guard and safe-linking

## Practical Workflow

### Step 1: Identify the Protection

Check glibc version and enabled protections:
```bash
ldd --version  # Check glibc version
```

### Step 2: Get a Heap Leak

Use unmangled pointers from unsorted, small, or large bins.

### Step 3: Demangle Pointers

Apply the demangling formula with your leaked values.

### Step 4: Craft Your Exploit

Account for alignment requirements and pointer mangling in your fake chunks.

## Tools and Resources

- [mdulin2/mangle](https://github.com/mdulin2/mangle) - Pointer mangling implementation
- [shellphish/how2heap](https://github.com/shellphish/how2heap) - Heap exploitation examples
- [Wiz CVE-2023-4911](https://www.wiz.io/vulnerability-database/cve/cve-2023-4911) - Looney Tunables write-up

## Common Pitfalls

1. **Forgetting alignment**: Fake chunks must be properly aligned
2. **Wrong demangling formula**: Remember it's `(L >> 12) XOR P`, not `L XOR (P >> 12)`
3. **Ignoring page boundaries**: Safe-linking bypass requires same-page chunks
4. **Missing the secret**: Pointer guard requires computing the secret first
