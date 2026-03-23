---
name: linux-arm64-kaslr-bypass
description: How to bypass KASLR on arm64 Android kernels using the static linear map. Use this skill whenever the user mentions arm64 kernel exploitation, KASLR bypass, Android kernel exploits, physical to virtual address conversion, linear map, memstart_addr, or needs to calculate stable kernel addresses. This is essential for any arm64 Android kernel exploit that needs to patch kernel data structures without leaking the KASLR slide.
---

# Linux arm64 Static Linear Map KASLR Bypass

This skill helps you bypass KASLR on arm64 Android kernels by exploiting the static linear map. The key insight: **every physical page has a deterministic virtual address independent of KASLR**.

## Core Concept

Android arm64 kernels use `CONFIG_ARM64_VA_BITS=39` (3-level paging) with only 512 GiB of kernel virtual space. The **linear map** is anchored at a fixed virtual address:

- `PAGE_OFFSET = 0xffffff8000000000` (compiled in)
- `PHYS_OFFSET = memstart_addr` (typically `0x80000000` on stock Android)

This creates a **static affine transform** from physical to virtual addresses:

```c
#define phys_to_virt(p) (((unsigned long)(p) - 0x80000000UL) | 0xffffff8000000000UL)
```

**Key implications:**
- Any physical address you know → you know its kernel virtual address
- No KASLR leak needed for data structures
- Linear map is **RW** (read-write), perfect for fake objects
- `.text` is non-executable in linear map (gadget hunting still needs traditional leak)

## Quick Start

### Step 1: Confirm the Setup

Check if the target device uses the static linear map:

```bash
# Read memstart_addr (requires root or kernel read primitive)
grep memstart /proc/kallsyms

# Verify it's 0x80000000 (typical for stock Android)
# Use bpf_arb_read or similar to read the value at that address
```

### Step 2: Calculate Target Addresses

Use the helper script for address calculations:

```bash
# Calculate linear map VA from a physical address
python scripts/phys_to_virt.py --phys 0x81ff2398

# Calculate from a symbol offset (if you know _stext offset)
python scripts/phys_to_virt.py --symbol-offset 0x1fe2398 --phys-base 0x80010000
```

### Step 3: Apply to Your Exploit

Once you have the linear map VA:
- **Arbitrary write primitive**: Directly patch `modprobe_path`, `init_cred`, security ops
- **Heap corruption**: Place fake objects in known pages, pivot pointers to linear map VAs
- **Verification**: Use `bpf_arb_read` to sanity-check before destructive writes

## Two Attack Scenarios

### Scenario A: Fixed Kernel Physbase (e.g., Pixels)

Many Pixels decompress the kernel at `phys_kernel_base = 0x80010000` every boot.

**Workflow:**
1. Get randomized `_stext` and target symbol from `/proc/kallsyms` or `vmlinux`
2. Compute offset: `offset = sym_virt - _stext_virt`
3. Add static physbase: `phys_sym = 0x80010000 + offset`
4. Convert to linear map VA: `virt_sym = phys_to_virt(phys_sym)`

**Example (Pixel 9, `modprobe_path`):**
- `offset = 0x1fe2398`
- `phys = 0x81ff2398`
- `virt = 0xffffff8001ff2398`

This address is **stable across reboots**.

### Scenario B: Randomized Physbase (e.g., Samsung)

When kernel load PFN is randomized, use **PFN spraying**:

1. **Spray user pages**: `mmap()` ~5 GiB, touch every page to fault it in
2. **Harvest PFNs**: Read `/proc/pagemap` for each page to collect backing PFNs
3. **Profile**: Reboot and repeat 100×, build histogram of PFN allocation frequency
4. **Identify hot PFNs**: Some PFNs are allocated 100/100 times shortly after boot
5. **Convert to kernel VA**:
   ```
   phys = (pfn << PAGE_SHIFT) + offset_in_page
   virt = phys_to_virt(phys)
   ```
6. **Forge objects**: Place fake `file_operations`, `cred`, or refcount structures in those pages
7. **Pivot pointers**: Steer victim pointers (UAF, overflow) to the known linear-map addresses

## Practical Exploit Integration

### When You Have Arbitrary Write

```python
# Precomputed stable addresses (example for Pixel 9)
MODPROBE_PATH = 0xffffff8001ff2398
INIT_CRED = 0xffffff8001ffXXXX  # Calculate your offset

# Direct patch without KASLR leak
write_kernel(MODPROBE_PATH, b"/bin/sh\x00")
```

### When You Have Heap Corruption

```python
# Spray pages and find reliable PFNs
reliable_pfns = profile_pfns(iterations=100)

# For each reliable PFN, calculate linear map VA
for pfn in reliable_pfns:
    phys = pfn << 12  # PAGE_SHIFT = 12
    virt = phys_to_virt(phys)
    
    # Place fake object at this address
    place_fake_cred(virt)
    
    # Trigger UAF to pivot pointer here
    trigger_uaf(victim_ptr, virt)
```

## Verification Checklist

Before deploying your exploit:

- [ ] Confirmed `memstart_addr = 0x80000000` (or documented the actual value)
- [ ] Calculated target addresses using the static transform
- [ ] Verified addresses with `bpf_arb_read` or safe read primitive
- [ ] Tested across multiple reboots (for fixed physbase devices)
- [ ] Profiled PFN allocation (for randomized physbase devices)
- [ ] Sanity-checked that computed addresses contain expected bytes

## Common Targets

| Target | Typical Use | Notes |
|--------|-------------|-------|
| `modprobe_path` | Kernel module loading | String, easy to patch |
| `init_cred` | Credential manipulation | Struct, requires careful layout |
| Security ops arrays | LSM hook manipulation | Array of function pointers |
| `file_operations` | Fake syscall handlers | Struct with function pointers |
| Refcount structures | Use-after-free pivots | Simple integer fields |

## Limitations

- **`.text` is non-executable** in linear map: Gadget hunting still requires traditional KASLR leak
- **Requires physical address knowledge**: Either from fixed physbase or PFN spraying
- **Device-specific**: `memstart_addr` and physbase vary by vendor
- **Root or kernel read primitive needed**: To read `/proc/kallsyms` or verify addresses

## References

- [Project Zero - Defeating arm64 Linux KASLR by Exploiting the Static Linear Map](https://projectzero.google/2025/11/defeating-kaslr-by-doing-nothing-at-all.html)
- Linux kernel commit `1db780bafa4c` (arm64 linear map placement)

## Helper Scripts

Run `scripts/phys_to_virt.py --help` for usage examples.

---

**Remember**: This technique eliminates the KASLR-leak stage for data-centric kernel exploits on Android, drastically lowering exploit complexity and improving reliability. Use it whenever you're working on arm64 Android kernel exploitation.
