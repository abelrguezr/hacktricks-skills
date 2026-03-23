---
name: pixel-bigwave-uaf-analysis
description: Analyze and understand the Pixel BigWave BIGO timeout race UAF vulnerability (CVE-2025-36934). Use this skill when investigating kernel driver vulnerabilities involving timeout races, use-after-free conditions, or MMIO-based write primitives. Also use when analyzing similar vulnerabilities in hardware accelerator drivers, reviewing kernel driver code for race conditions, or studying the mediacodec sandbox escape attack surface. Make sure to use this skill whenever the user mentions kernel driver vulnerabilities, timeout races, UAF in device drivers, MMIO copy operations, or Pixel/Android security research.
---

# Pixel BigWave UAF Analysis

A skill for analyzing the Pixel BigWave BIGO timeout race UAF vulnerability and similar kernel driver vulnerabilities.

## Overview

This skill helps security researchers understand and analyze CVE-2025-36934, a use-after-free vulnerability in the Pixel BigWave AV1 hardware accelerator driver that enables arbitrary kernel writes from the mediacodec sandbox.

## Vulnerability Summary

| Aspect | Details |
|--------|---------|
| **CVE** | CVE-2025-36934 |
| **Component** | `/dev/bigwave` (Pixel AV1 hardware accelerator) |
| **Context** | SELinux-confined `mediacodec` domain |
| **Primitive** | ~2144-byte arbitrary kernel write via `memcpy_fromio()` |
| **Fix** | 2026-01-05 Pixel / 2025-12-01 ASB builds |

## Attack Surface Mapping

### SELinux → Device Node Reachability

The mediacodec context is designed to be isolated (software decoders should stay confined), but `/dev/bigwave` remained reachable, exposing a large attack surface to post-media-RCE code.

**Analysis approach:**
1. Use tools like **DriverCartographer** to enumerate device nodes accessible from a given SELinux domain
2. Map which drivers are reachable from the compromised context
3. Identify drivers with complex ioctl handlers and async worker threads

## Vulnerability Mechanism

### The Race Condition

```
User Thread                    Worker Thread
     |                              |
     |-- ioctl(BIGO_IOCX_PROCESS) --|
     |  - copies user regs to job   |
     |  - queues inline job         |
     |  - wait_for_completion_timeout(16s)
     |                              |-- dequeues job
     |                              |-- inst = container_of(job, ...)
     |                              |-- bigo_push_regs()
     |                              |   (writes to MMIO)
     |                              |
     |  - TIMEOUT (16s elapsed)     |
     |  - tries to dequeue/cancel   |
     |  - returns to userspace      |
     |                              |-- bigo_pull_regs()
     |                              |   (memcpy_fromio to job->regs)
     |                              |
     |-- close(fd)                  |
     |  - frees inst/job            |
     |                              |-- *(job->regs + STAT) = status
     |                              |   (UAF: writes to freed memory)
```

### Key Code Path

```c
// In ioctl handler
wait_for_completion_timeout(&inst->job.completion, 16 * HZ);
// Returns on timeout, but worker may still have job pointer

// In worker thread (continues after timeout)
inst = container_of(job, struct bigo_inst, job);
bigo_push_regs(core, job->regs);
// ... hardware execution ...
bigo_pull_regs(core, job->regs);  // memcpy_fromio(regs, core->base, core->regs_size)
*(u32 *)(job->regs + BIGO_REG_STAT) = status;
```

### The Use-After-Free

1. **Timeout path**: ioctl returns after 16s without waiting for worker completion
2. **No synchronization**: FD lifetime is not tied to worker thread's job pointer
3. **Free while in use**: `close(fd)` frees `struct bigo_inst` (which embeds `struct bigo_job`) while worker still references it
4. **UAF exploitation**: Worker writes to freed memory via `job->regs` pointer

## Exploitation Primitive

### Arbitrary Kernel Write

The `bigo_pull_regs()` function performs:
```c
memcpy_fromio(regs, core->base, core->regs_size);
```

Where:
- `regs` = `job->regs` (pointer in freed struct, can be controlled via slab reclaim)
- `core->base` = MMIO address (hardware register space)
- `core->regs_size` = ~2144 bytes

**Result**: ~2144-byte write from MMIO to attacker-controlled kernel address

### Slab Reclaim Strategy

1. **Backlog + timeout**: Queue enough jobs to delay worker, then trigger 16s timeout
2. **Free while in use**: Close FD immediately after ioctl returns
3. **Reclaim + pointer control**: Spray reclaimers (e.g., Unix domain socket message allocations) to occupy freed slab slot
4. **Overwrite job->regs**: Point to target kernel address
5. **Arbitrary write**: When `bigo_pull_regs()` runs, MMIO data is written to target

### Data Shaping

Because registers are first programmed from user data (`bigo_push_regs`), preconfigure BigWave to idle (set control bits to skip execution) so the copied-back register image stays deterministic and close to attacker-controlled bytes.

## Analysis Framework for Similar Vulnerabilities

### 1. Identify Async Worker Patterns

Look for drivers with:
- Inline per-FD job structures enqueued to async workers
- `wait_for_completion_timeout()` or similar timeout mechanisms
- No reference counting or synchronization between FD lifetime and worker consumption

### 2. Check MMIO Copy Helpers

Any `memcpy_fromio()`/`memcpy_toio()` that uses buffer pointers from jobs should be validated:
- Is the buffer pointer validated before enqueuing?
- Is the buffer duplicated or pinned before async use?
- Can the buffer be freed while the worker still references it?

### 3. Review Timeout/Cancel Paths

```
// Vulnerable pattern
wait_for_completion_timeout(&job->completion, timeout);
// Returns immediately on timeout
// Worker may still be using job pointer

// Safer pattern
wait_for_completion_timeout(&job->completion, timeout);
if (timed_out) {
    // Cancel worker or wait for it to complete
    cancel_work_sync(&worker);
    // Or use reference counting
    put_job(job);
}
```

### 4. SELinux Context Analysis

- Map which device nodes are reachable from each SELinux domain
- Identify drivers that should be isolated but aren't
- Check if driver complexity matches the security context

## Defensive Recommendations

### For Driver Reviewers

1. **Reference counting**: Inline per-FD job structs must hold references that survive timeout/cancel paths
2. **Synchronization**: Closing an FD must synchronize with worker consumption (e.g., `flush_workqueue()`, `cancel_work_sync()`)
3. **Buffer validation**: MMIO copy helpers should validate or duplicate buffer pointers before enqueuing
4. **Timeout handling**: Timeout paths should either cancel the worker or wait for it to complete

### For SELinux Policy

1. **Minimize device node exposure**: Only expose device nodes that are necessary for the domain's function
2. **Audit async drivers**: Drivers with async workers should be carefully reviewed before being exposed to confined contexts
3. **Use DriverCartographer**: Regularly audit device node reachability from each domain

## References

- [Project Zero: Pixel 0-click (Part 2)](https://projectzero.google/2026/01/pixel-0-click-part-2.html)
- [Project Zero issue 426567975](https://project-zero.issues.chromium.org/issues/426567975)
- [CVE-2025-36934 entry](https://www.cybersecurity-help.cz/vulnerabilities/119071/)

## Usage Examples

### Analyzing a similar vulnerability

```
I found a kernel driver with a timeout race. Can you help me analyze if it's vulnerable?
```

### Reviewing driver code

```
Review this driver code for timeout race vulnerabilities:
[driver code]
```

### Understanding the attack surface

```
What device nodes are reachable from the mediacodec context on Pixel devices?
```

### Developing mitigations

```
How should I fix a timeout race UAF in my kernel driver?
```
