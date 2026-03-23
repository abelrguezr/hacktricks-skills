---
name: mte-memory-tagging
description: Memory Tagging Extension (MTE) analysis and bypass for ARM binary exploitation. Use this skill whenever working with ARM binaries, analyzing memory protections, debugging MTE-related crashes (SIGSEGV with SEGV_MTESERR/SEGV_MTEAERR), investigating use-after-free or buffer overflow vulnerabilities on ARM systems, or when the user mentions MTE, memory tagging, ARM security, KASAN, or hardware memory protections. This skill covers MTE fundamentals, detection, and bypass techniques including speculative execution attacks like TikTag.
---

# Memory Tagging Extension (MTE) Analysis & Bypass

A comprehensive guide to understanding, detecting, and bypassing ARM's Memory Tagging Extension for binary exploitation.

## What is MTE?

**Memory Tagging Extension (MTE)** is a hardware-based memory protection mechanism in ARM architecture that detects and prevents memory-related errors like buffer overflows and use-after-free vulnerabilities.

### Core Concept

MTE works by:
1. **Dividing memory into 16-byte blocks**, each assigned a 4-bit tag
2. **Storing tags in unused pointer bits** (top byte of 64-bit pointers)
3. **Checking tag matches** on every memory access
4. **Raising exceptions** when tags don't match

```
Pointer structure (64-bit ARM):
┌─────────────────────────────────────────────────────────────┐
│ 31-28: TAG (4 bits) │ 27-0: Address bits                    │
└─────────────────────────────────────────────────────────────┘
```

## MTE Checking Modes

| Mode | Behavior | Performance | Security |
|------|----------|-------------|----------|
| **Sync** | Immediate check, raises SIGSEGV (SEGV_MTESERR) | Slowest | Highest |
| **Async** | Deferred check, sets exception bit, SIGSEGV (SEGV_MTEAERR) | Faster | Lower |
| **Mixed** | Per-core preferences via `/sys/devices/system/cpu/cpu*/mte_tcf_preferred` | Variable | Variable |

### Detection via Syscall

```bash
# Check if MTE is enabled on the system
cat /sys/devices/system/cpu/cpu*/mte_tcf_preferred

# Check process MTE status
cat /proc/<pid>/auxv | grep -i mte
```

## MTE in Kernel (KASAN)

The kernel implements MTE through **Hardware Tag-Based KASAN**:

### How Kernel MTE Works

1. **kmalloc()** allocates memory and assigns a random tag (0-13)
2. **Tag is attached** to both memory granules and returned pointer
3. **Only requested size is tagged** - remaining granules get invalid tag (0xE)
4. **kfree()** retags memory with invalid tag (0xE)

### Tag Values

| Tag | Meaning |
|-----|---------|
| 0x0-0xD | Valid random tags (14 values) |
| 0xE | Invalid tag (unallocated memory) |
| 0xF | Match-all tag (bypasses MTE) |

### Critical Limitations

1. **7% Tag Collision Rate**: With only 14 usable tags, probability of tag reuse is ~1/17 (7%)
2. **Last Granule Bug**: If you request 35 bytes, you get 48 bytes (3 granules). Bytes 36-47 use the same tag but aren't detected as OOB
3. **Use-After-Free Bypass**: If freed chunk is reallocated with the same tag, UAF isn't detected (~7% chance)
4. **Limited Coverage**: Only `slab` and `page_alloc` use MTE; `vmalloc`, `stack`, and `globals` may still be exploitable

## Exploitation Scenarios

### Scenario 1: Buffer Overflow with MTE

**Challenge**: Writing past allocated buffer

**MTE Behavior**:
- If overflow stays within tagged granules: **Not detected**
- If overflow hits untagged granule (0xE): **Detected, kernel panic**
- If overflow hits different tag: **Detected, kernel panic**
- If overflow hits same tag (7%): **Not detected**

**Bypass Strategy**:
```
1. Map memory layout to find granule boundaries
2. Exploit within last granule (bytes 36-47 in 35-byte allocation)
3. Or rely on 7% tag collision probability
4. Or use speculative execution (TikTag) to leak tags
```

### Scenario 2: Use-After-Free with MTE

**Challenge**: Accessing freed memory

**MTE Behavior**:
- Freed memory gets invalid tag (0xE)
- Access with old pointer tag: **Detected**
- Reallocation with same tag (7%): **Not detected**

**Bypass Strategy**:
```
1. Trigger UAF immediately after free (before reallocation)
2. Control allocation to get same tag
3. Use heap spraying to increase collision probability
4. Or leak tag via TikTag and craft matching pointer
```

## TikTag: Speculative Execution Bypass

**TikTag (2024)** demonstrated that MTE can be bypassed via speculative execution side channels.

### Attack Overview

1. **Leak 4-bit allocation tag** in <4 seconds with >95% success
2. **Speculatively touch cache lines** and observe prefetch-induced timing
3. **Derandomize tags** for Chrome, Android services, or Linux kernel
4. **Craft pointers with leaked tag** to bypass MTE
5. **Pivot to retagging fake slabs** for full exploitation

### Impact

- **Collapses probabilistic assumptions**: 7% false-negative becomes near-100% reliability
- **Classic heap exploits work**: UAF, OOB regain full effectiveness
- **Hardware tagging schemes vulnerable**: Speculative side channels remain viable bypass path

### Mitigation

- Disable speculative execution features
- Use constant-time tag operations
- Combine with other mitigations (ASLR, stack canaries)

## Practical Detection Checklist

When analyzing an ARM binary or system:

```bash
# 1. Check MTE support
grep -i mte /proc/cpuinfo

# 2. Check MTE mode
cat /sys/devices/system/cpu/cpu*/mte_tcf_preferred

# 3. Check for MTE-related crashes
# SIGSEGV with SEGV_MTESERR = sync MTE violation
# SIGSEGV with SEGV_MTEAERR = async MTE violation

# 4. Check kernel MTE (KASAN)
dmesg | grep -i mte
dmesg | grep -i kasan

# 5. Check process MTE status
cat /proc/<pid>/auxv | grep -i mte
```

## Bypass Decision Tree

```
Is MTE enabled?
├─ No → Standard exploitation
└─ Yes
   ├─ Can you stay within tagged granules?
   │  └─ Yes → Exploit within last granule
   ├─ Can you control allocation?
   │  ├─ Yes → Heap spray for tag collision (7%)
   │  └─ No → Try speculative execution (TikTag)
   ├─ Is it async mode?
   │  └─ Yes → Complete attack before exception
   └─ Can you leak tags?
      └─ Yes → Craft matching pointers
```

## Key Takeaways

1. **MTE is probabilistic**: 7% tag collision rate means it's not 100% effective
2. **Last granule is exploitable**: Unrequested bytes in final granule aren't protected
3. **Async mode is weaker**: Gives attackers time to complete attacks
4. **TikTag breaks assumptions**: Speculative execution can leak tags and bypass MTE
5. **Not all memory is tagged**: vmalloc, stack, and globals may still be vulnerable

## References

- [ARM MTE Tutorial Video](https://www.youtube.com/watch?v=UwMt0e_dC_Q)
- [TikTag: Breaking ARM's Memory Tagging Extension with Speculative Execution](https://arxiv.org/abs/2406.08719)
- [ARM MTE Documentation](https://developer.arm.com/documentation/102476/)

## When to Use This Skill

Use this skill when:
- Analyzing ARM binaries with memory protections
- Debugging SIGSEGV crashes with MTE error codes
- Investigating use-after-free or buffer overflow vulnerabilities on ARM
- Researching hardware memory protections
- Developing exploits for ARM systems with MTE enabled
- Understanding KASAN and kernel memory protections
- Working with ARM security features in general
