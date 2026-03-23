---
name: adreno-a7xx-exploitation
description: How to exploit CVE-2025-21479 on Qualcomm Adreno A7xx GPUs to achieve kernel R/W via GPU SMMU takeover. Use this skill whenever the user mentions Adreno A7xx, GPU SMMU exploitation, SDS privilege bypass, kernel physical memory access, or wants to understand/reproduce the CVE-2025-21479 vulnerability chain. Also use when discussing GPU microcode bugs, IB level masking issues, or dirty pagetable pivots on Android devices with Snapdragon chipsets.
---

# Adreno A7xx SDS→RB Privilege Bypass Exploitation

This skill guides you through exploiting CVE-2025-21479 on Qualcomm Adreno A7xx GPUs to achieve arbitrary kernel memory read/write via GPU SMMU takeover and dirty pagetable pivot.

## Vulnerability Overview

**CVE-2025-21479**: A microcode logic bug in Adreno A7xx firmware where register `$12` (IB level tracker) is masked with `0x3` instead of `0x7`, causing Set Draw State (SDS) at IB4 to be misidentified as IB0 (kernel ringbuffer), allowing privileged CP packets from user-controlled SDS.

### Key Facts

| Aspect | Details |
|--------|---------|
| **Affected** | Qualcomm Adreno A7xx GPU firmware (pre-fix) |
| **Primitive** | Execute privileged CP packets from SDS |
| **Outcome** | Arbitrary kernel physical/virtual R/W, SELinux disable, root |
| **Prerequisite** | KGSL GPU context creation (normal app capability) |
| **Devices** | Samsung S23 and other Snapdragon A7xx devices |

## IB Level Masking Bug

The kernel maintains a ringbuffer (RB=IB0). Userspace submits IB1 via `CP_INDIRECT_BUFFER`, chaining to IB2/IB3. SDS is a special command stream:

- **A6xx**: SDS treated as IB3
- **A7xx**: SDS moved to IB4

Microcode tracks current IB level in register `$12` and gates privileged packets to IB0 only. The bug:

```
A6XX                | A7XX
RB  & 3       == 0  |  RB  & 3       == 0
IB1 & 3       == 1  |  IB1 & 3       == 1
IB2 & 3       == 2  |  IB2 & 3       == 2
IB3 (SDS) & 3 == 3  |  IB3 & 3       == 3
                    |  IB4 (SDS) & 3 == 0   <-- misread as IB0!
```

**Fix**: Mask changed from `0x3` to `0x7` in microcode.

## Exploitation Chain

### Phase 1: GPU SMMU Takeover

1. **Spray fake GPU pagetable** into shared memory (allocator grooming)
2. **Enter SDS** and execute privileged packets:
   - `CP_SMMU_TABLE_UPDATE` → switch to fake pagetable
   - `CP_MEM_WRITE` / `CP_MEM_TO_MEM` → implement R/W primitives
   - `CP_SET_DRAW_STATE` with run-now flags

### Phase 2: Physical Memory R/W Primitives

Using the fake pagetable:

- **Write**: `CP_MEM_WRITE` to attacker-chosen GPU VA mapped to target PA
- **Read**: `CP_MEM_TO_MEM` copies 4/8 bytes from target PA to userspace buffer

### Phase 3: Find Kernel Physical Base (Samsung KASLR)

Samsung randomizes kernel physical base within known region. Brute-force for `_stext` signature:

```c
while (!ctx->kernel.pbase) {
  offset += 0x8000;
  uint64_t d1 = kernel_physread_u64(ctx, base + offset);
  if (d1 != 0xd10203ffd503233f) continue;   // first 8 bytes of _stext
  uint64_t d2 = kernel_physread_u64(ctx, base + offset + 8);
  if (d2 == 0x910083fda9027bfd) {           // second 8 bytes
    ctx->kernel.pbase = base + offset - 0x10000;
    break;
  }
}
```

Compute kernel virtual via linear map:
```
_stext = 0xffffffc008000000 + (Kernel Code & ~0xa8000000)
```

### Phase 4: Dirty Pagetable Pivot (Fast CPU-side R/W)

GPU R/W is slow. Pivot to fast primitive by corrupting process PTEs:

1. Locate `task_struct → mm_struct → mm_struct->pgd` using GPU R/W
2. `mmap` two adjacent userspace pages A and B (e.g., at `0x1000`)
3. Walk `PGD→PMD→PTE` to resolve A/B's PTE physical addresses
4. Overwrite B's PTE to point to last-level pagetable managing A/B with RW attributes
5. Write via B's VA to mutate A's PTE to map target PFNs
6. Read/write kernel memory via A's VA, flushing TLB until sentinel flips

## Implementation Helpers

Use the bundled scripts for common tasks:

- `scripts/generate_sds_commands.py` - Build SDS command sequences
- `scripts/find_kernel_physbase.py` - Brute-force kernel physical base
- `scripts/dirty_pagetable_pivot.py` - Template for dirty pagetable technique

## Detection & Mitigation

### Detection

- Alert if `CP_SMMU_TABLE_UPDATE` appears outside RB/IB0, especially in SDS
- Monitor anomalous bursts of 4/8-byte `CP_MEM_TO_MEM`
- Watch for excessive TLB flush patterns

### Mitigation

- Update GPU microcode to use `0x7` mask for register `$12`
- Validate IB level before accepting privileged CP packets
- Monitor GPU command submission for SDS privilege escalation attempts

## Important Notes

- **Excessive GPU traffic** can cause UI blackouts and reboots
- **Reads are small** (4/8 bytes) and sync is slow by default
- **Each Android process** gets a KGSL context (`IOCTL_KGSL_GPU_CONTEXT_CREATE`)
- **Firmware variations** exist - use freedreno's afuc/packet docs for exact encodings

## References

- [CVE-2025-21479 Details](https://xploitbengineer.github.io/CVE-2025-21479)
- [Mesa freedreno afuc disassembler](https://gitlab.freedesktop.org/mesa/mesa/-/blob/c0f56fc64cad946d5c4fda509ef3056994c183d9/src/freedreno/afuc/README.rst)
- [Google Project Zero: Attacking Qualcomm Adreno GPU](https://googleprojectzero.blogspot.com/2020/09/attacking-qualcomm-adreno-gpu.html)
- [Dirty pagetable technique](https://web.archive.org/web/20240425043203/https://yanglingxi1993.github.io/dirty_pagetable/dirty_pagetable.html)
