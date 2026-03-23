---
name: linux-kernel-af-unix-oob-uaf
description: Use this skill when analyzing or researching AF_UNIX MSG_OOB use-after-free vulnerabilities in Linux kernels, particularly CVE-2025-38236. Trigger this skill for kernel exploitation research involving socket buffer (SKB) primitives, arbitrary kernel read/write techniques, page allocator manipulation, or when users mention MSG_OOB, unix_stream_recv_urg, manage_oob, kernel UAF, SKB exploitation, or Chrome renderer-to-kernel escapes. This skill provides methodology for understanding the vulnerability chain, exploitation primitives, and mitigation strategies.
---

# AF_UNIX MSG_OOB UAF Exploitation Research

A specialized skill for analyzing and understanding the AF_UNIX MSG_OOB use-after-free vulnerability (CVE-2025-38236) and related kernel exploitation techniques.

## When to Use This Skill

Use this skill when:
- Researching CVE-2025-38236 or similar AF_UNIX socket vulnerabilities
- Analyzing kernel use-after-free exploitation techniques
- Understanding SKB (socket buffer) manipulation primitives
- Investigating Chrome renderer-to-kernel escape chains
- Studying Linux kernel allocator manipulation (SLUB, buddy allocator)
- Working with arbitrary kernel read/write primitives
- Analyzing kernel stack recycling and KASLR bypass techniques

## ⚠️ Safety Warning

This skill covers advanced kernel exploitation techniques. Use only in:
- Authorized security research environments
- Controlled lab settings with isolated VMs
- Educational contexts with proper permissions
- Never against production systems or without explicit authorization

## Vulnerability Overview

### CVE-2025-38236: The Core Flaw

**Affected Kernels:** Linux >= 6.9 with flawed `manage_oob()` refactor (commit `5aa57d9f2d53`)

**Root Cause:** The `manage_oob()` function assumes only one zero-length SKB exists in the queue. When two consecutive zero-length SKBs are present, the function returns the second empty SKB without properly clearing `u->oob_skb`, leaving a dangling pointer.

### Minimal Trigger Sequence

```c
char byte;
int socks[2];
socketpair(AF_UNIX, SOCK_STREAM, 0, socks);

// Create two zero-length OOB SKBs
for (int i = 0; i < 2; ++i) {
    send(socks[1], "A", 1, MSG_OOB);
    recv(socks[0], &byte, 1, MSG_OOB);
}

// Set up the dangling pointer
send(socks[1], "A", 1, MSG_OOB);   // SKB3, u->oob_skb = SKB3
recv(socks[0], &byte, 1, 0);         // normal recv frees SKB3
recv(socks[0], &byte, 1, MSG_OOB);   // dangling u->oob_skb dereference
```

## Exploitation Primitives

### Primitive 1: 1-Byte Arbitrary Kernel Read

**Mechanism:** `recv(MSG_OOB | MSG_PEEK)` triggers `unix_stream_recv_urg()` → `__skb_datagram_iter()` → `copy_to_user()`

**Requirements:**
- Dangling `u->oob_skb` pointer
- Reallocated SKB page into controlled memory (pipe buffer)
- `MSG_PEEK` flag to preserve dangling pointer

**Capabilities:**
- Repeatable reads from arbitrary kernel addresses
- Works against `.data`, `.bss`, vmemmap, per-CPU vmalloc, kernel stacks
- Respects `__check_object_size()` usercopy hardening
- Returns `-EFAULT` for `.text` and specialized caches (no crash)

### Primitive 2: Constrained Write (+4 GiB Increment)

**Mechanism:** Without `MSG_PEEK`, `UNIXCB(oob_skb).consumed += 1` increments the 32-bit field at offset `0x44`

**Effect:** On 0x100-aligned SKB allocations, this adds +4 GiB to the upper dword of any 64-bit value at offset `0x40`

**Use Case:** Stack corruption when the target value is positioned at the correct offset

## Exploitation Methodology

### Phase 1: Page Allocator Manipulation

1. **Drain order-0/1 unmovable freelists**
   - Map huge read-only anonymous VMA
   - Fault every page to force page-table allocation
   - Fill ~10% of RAM with page tables

2. **Spray SKBs and isolate a slab page**
   - Create dozens of stream socketpairs
   - Queue hundreds of small messages per socket (~0x100 bytes)
   - Free chosen SKBs to control target slab page
   - Monitor `struct page` refcount via read primitive

3. **Return slab page to buddy allocator**
   - Free every object on the page
   - Perform additional allocations/frees to push page out of SLUB per-CPU lists
   - Page becomes order-1 on buddy freelist

4. **Reallocate as pipe buffer**
   - Create hundreds of pipes (each reserves 2×0x1000-byte pages)
   - Buddy allocator splits order-1 page, reusing freed SKB page
   - Write unique markers into fake SKBs in pipe pages
   - Use `recv(MSG_OOB | MSG_PEEK)` to identify which pipe aliases `oob_skb`

### Phase 2: Forge SKB Metadata

Populate the aliased pipe page with fake `struct sk_buff`:

```c
struct sk_buff {
    void *head;           // Point to target kernel address
    void *data;           // Data pointer
    // ... other fields
    struct skb_shared_info *shinfo;  // For frag_list manipulation
};
```

**Key Considerations:**
- x86_64 disables SMAP inside `copy_to_user()`
- User-mode addresses work as staging buffers until kernel pointers known
- Respect usercopy hardening boundaries

### Phase 3: Kernel Introspection

**Break KASLR:**
```c
// Read IDT descriptor from fixed mapping
void *idt = (void *)0xfffffe0000000000;
kernel_base = idt - known_handler_offset;
```

**SLUB/Buddy State:**
- Read global `.data` symbols for `kmem_cache` bases
- Scan vmemmap entries for page type flags and freelist pointers
- Walk per-CPU vmalloc segments for `struct kmem_cache_cpu`
- Predict next allocation addresses for key caches

**Page Tables:**
- Walk global `pgd_list` (`struct ptdesc`)
- Match current `mm_struct` via `cpu_tlbstate.loaded_mm`
- Traverse page tables to map PFNs for pipe buffers and stacks

### Phase 4: Stack Recycling

1. Free controlled pipe page, confirm refcount = 0 via vmemmap
2. Allocate and free four helper pipe pages in reverse order (LIFO)
3. Call `clone()` to spawn helper thread (4 pages = kernel stack)
4. Verify top stack PFN equals recycled SKB PFN via page-table walk
5. Use read primitive to observe stack layout during `pipe_write()`

**KSTACK_OFFSET Oracle:**
- `CONFIG_RANDOMIZE_KSTACK_OFFSET` subtracts random 0x0–0x3f0 from RSP
- Repeated writes with `poll()`/`read()` reveal when writer blocks
- Target: `copy_page_from_iter()` `bytes` argument (R14) at offset `0x40`

### Phase 5: Timing the Increment

**Self-Looping Frag List:**
```c
struct sk_buff *fake_skb2 = user_controlled_memory;
fake_skb2->len = 0;
fake_skb2->next = &fake_skb2;  // Self-loop

fake_skb1->shinfo->frag_list = fake_skb2;
```

**Execution Flow:**
1. `skb_walk_frags()` iterates inside `__skb_datagram_iter()`
2. Iterator never reaches NULL, execution spins indefinitely
3. Change `fake_skb2->next = NULL` from user space
4. Loop exits, `UNIXCB(oob_skb).consumed += 1` executes once
5. +4 GiB increment hits target at offset `0x40`

**Stalling `copy_from_iter()`:**
1. Map giant anonymous RW VMA, fault in fully
2. Punch single-page hole with `madvise(MADV_DONTNEED)`
3. Place hole address inside `iov_iter` for `write(pipefd, user_buf, 0x3000)`
4. Parallel `mprotect()` on entire VMA from another thread
5. Page fault handler blocks on mmap lock, pausing `copy_from_iter()`

### Phase 6: Arbitrary PTE Writes

1. **Fire the increment** while `copy_from_iter()` is stalled
2. **Overflow the copy:** `copy_page_from_iter()` copies >4 GiB
3. **Arrange adjacency:** Force buddy allocator to place PTE page after pipe buffer
4. **Overwrite page tables:** Encode desired PTE entries in extra 0x1000 bytes

**Result:** RW/RWX user mappings of kernel physical memory or SMEP/SMAP disable

## Mitigation Strategies

### Kernel-Level

1. **Apply the fix:** Commit `32ca245464e1479bfea8592b9db227fdc1641705`
2. **Disable AF_UNIX OOB:** `CONFIG_AF_UNIX_OOB` (commit `5155cbcdbf03`)
3. **Harden `manage_oob()`:** Loop until `unix_skb_len() > 0`
4. **Audit other protocols:** Check for similar assumptions

### Sandboxing

1. **Seccomp filtering:** Block `MSG_OOB`/`MSG_PEEK` flags
2. **Broker APIs:** Filter at higher level (Chrome CL `6711812`)
3. **Capability restrictions:** Limit socket operations in unprivileged contexts

### Allocator Defenses

1. **SLUB freelist randomization:** Complicate deterministic page recycling
2. **Per-cache page coloring:** Reduce reallocation reliability
3. **Pipe buffer limits:** Reduce attack surface

### Monitoring

1. **Page-table allocation rate:** High-rate allocation is suspicious
2. **Pipe buffer usage:** Abnormal counts indicate exploitation
3. **AF_UNIX OOB frequency:** Unusual patterns warrant investigation

## Research Workflow

### Step 1: Environment Setup

```bash
# Verify kernel version
uname -r

# Check for vulnerability
# Kernels >= 6.9 with commit 5aa57d9f2d53 but before 32ca245464e1 are affected

# Verify CONFIG_AF_UNIX_OOB
grep CONFIG_AF_UNIX_OOB /boot/config-$(uname -r)
```

### Step 2: Primitive Validation

1. Trigger the UAF with minimal sequence
2. Verify read primitive works with `MSG_PEEK`
3. Confirm write primitive with `+4 GiB` increment
4. Test allocator manipulation reliability

### Step 3: Exploitation Chain

1. Implement page draining and SKB spraying
2. Forge SKB metadata in pipe buffers
3. Implement kernel introspection
4. Set up stack recycling
5. Time the increment with frag list loop
6. Achieve arbitrary PTE writes

## Common Pitfalls

1. **Usercopy hardening:** `.text` and specialized caches return `-EFAULT`
2. **Folio boundaries:** Direct-map pages straddling higher-order folios fail
3. **Timing sensitivity:** KSTACK_OFFSET randomization requires oracle
4. **Allocator variance:** SLUB behavior varies by kernel config
5. **SMAP/SMEP:** Must be disabled or bypassed for full control

## References

- [Project Zero – From Chrome renderer code exec to kernel with MSG_OOB](https://projectzero.google/2025/08/from-chrome-renderer-code-exec-to-kernel.html)
- [Linux fix for CVE-2025-38236](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=32ca245464e1479bfea8592b9db227fdc1641705)
- [Chromium CL 6711812 – block MSG_OOB in renderers](https://chromium-review.googlesource.com/c/chromium/src/+/6711812)
- [CONFIG_AF_UNIX_OOB commit](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=5155cbcdbf03f207095f9a3794942a25aa7e5f58)

## Related Skills

Consider using these skills in conjunction:
- Kernel debugging and analysis
- Memory corruption exploitation
- Bypassing kernel mitigations (KASLR, SMEP, SMAP)
- SLUB allocator internals
- Linux kernel networking stack
