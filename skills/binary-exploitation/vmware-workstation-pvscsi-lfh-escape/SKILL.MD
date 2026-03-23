---
name: vmware-pvscsi-lfh-exploit
description: Analyze and understand the VMware Workstation PVSCSI LFH escape vulnerability (CVE-2025-20947). Use this skill whenever the user mentions VMware Workstation heap exploitation, LFH (Low Fragmentation Heap) attacks, PVSCSI driver vulnerabilities, or Windows 11 kernel escape techniques. Also trigger for discussions about scatter/gather buffer overflows, heap coalescing abuse, or URB-based exploitation primitives.
---

# VMware Workstation PVSCSI LFH Escape Analysis

A skill for understanding and analyzing the VMware Workstation PVSCSI driver vulnerability that enables VM escape on Windows 11.

## Vulnerability Overview

This skill helps analyze the **fixed-size realloc + scattered OOB write** vulnerability in VMware's PVSCSI driver:

- **Trigger**: Guest supplies >1024 scatter/gather entries to `PVSCSI_FillSGI`
- **Root cause**: Static 512-entry buffer (0x2000 bytes) reallocates to fixed 0x4000 bytes, but reallocates on every iteration without growing
- **Effect**: Each entry beyond 1024 writes 16 bytes past the allocated chunk, corrupting adjacent heap metadata
- **Constraint**: Overflow content is `{u64 addr; u64 len}` where `len` is zero-extended from 32-bit, making the last dword always `0x00000000`

## Exploitation Technique: LFH Ping-Pong

### Why LFH Matters

Windows 11 uses the **Low Fragmentation Heap (LFH)** for 0x4000 allocations:
- 16 chunks per bucket with 0x10-byte metadata (keyed checksum)
- Corrupted headers that get reused will crash the process
- LFH returns random free chunks but **prefers the bucket with the most recently freed chunk**

### Deterministic Placement Strategy

Force exactly two free slots to create predictable "Ping-Pong" allocation:

1. **Spray phase**: Allocate all free 0x4000 chunks (32 SVGA shaders) to fill buckets B1 and B2
2. **Free B1 except one**: Keep one shader pinned as **Hole0** so B1 stays active; allocate 15 URBs into B1
3. **Create PONG**: Free one shader in B2, then immediately free Hole0
4. **Result**: LFH alternates between PING (B1) and PONG (B2) slots

**Critical timing**:
- Iteration 1025: Corrupts header after PONG (never touched again)
- Iteration 1026: Hits first 16 bytes of URB after PING (safe metadata bypass)
- Reclaim PING/PONG with placeholder shaders to maintain stable layout

## Reap Oracle: Mapping Contiguous Holes

URBs live in a FIFO queue and are freed when fully reaped. The constrained 16-byte overwrite zeroes `actual_len`, creating a marker:

```
Reap URBs in order → when zeroed actual_len seen → refill slot with recognizable shader
```

This maps **Hole0–Hole3** as four contiguous chunks in known order for adjacency-dependent primitives.

## Coalescing Abuse: Constrained Writes → Arbitrary Overwrite

`PVSCSI` coalesces adjacent entries using `AddrA + LenA == AddrB` and compacts later entries upward.

### Two-Pass Overflow

1. **First pass**: Trigger at PING (odd indices), exit early to skip coalescing
2. **Second pass**: Trigger at PONG (even indices) to fill gaps, continue writing into sprayed shader with fake S/G entries

### Vacuum + Payload Technique

Set entries `[1023..2047]` to `{addr=0, len=0}` so coalescing collapses them into one, creating a logical hole. Payload entries placed afterwards (in the shader) are **moved up** into earlier memory, landing inside the victim URB.

### Adjacency-Check Bypass

By setting `LenA=0`, the condition becomes `AddrA==AddrB`. Craft pairs:

```
{addr = X, len = 0}    // from constrained overflow (even indices)
{addr = X, len = Y}    // from shader (odd indices)
```

Coalescing merges them into `{addr=X, len=Y}`. Result: **arbitrary 16-byte patterns** despite the forced zero dword.

## Hybrid URB Infoleak

### Setup

Arrange contiguous chunks: `[Hole0 (free/PING), URB1 (target), URB2 (valid, actual_len=0), URB3 (leak target)]`

### Execution

1. Fill URB1 with contiguous fake entries (sizes `0xFFFFFFFF`), touching URB2 minimally
2. Coalescing merges them into one entry; sum `0xFFFFFFFF * 0x401` sets upper dword at URB1's `actual_len` offset to **0x400**
3. Compaction copies following data **upward**, pulling **URB2's header into URB1**
4. URB1 now has valid header (pipe/list pointers), `actual_len=0x400`, data pointer at end of URB2's buffer
5. Reaping URB1 copies 0x400 bytes starting just before URB3, yielding **OOB read** of URB3's header/self-references

**Result**: Absolute heap addresses revealed, ASLR defeated for subsequent forged structures.

## Post-Leak Primitives (No Re-Triggering)

### Persistent Fake URB

1. Forge URB structure inside shader occupying **Hole0**
2. Use coalescing "move up" to replace URB1 with forged data
3. Set `URB1.next = Hole0` and increment `refcount`
4. Reaping URB1 puts **Hole0-backed fake URB** at FIFO head
5. Future primitives: just reallocate Hole0 with new fake URBs

### Arbitrary Read

Fake URB with chosen `data_ptr` and `actual_len`, then reap to copy host memory to guest.

### Arbitrary Write (32-bit)

Fake URB whose `pipe` points to controlled memory, abuse UHCI **TDBuffer writeback** to store chosen dword at arbitrary address.

### Arbitrary Call

1. Overwrite USB pipe callback
2. Host calls it with controlled data at `RCX+0x90`
3. Resolve `WinExec` dynamically (guest-side read of Kernel32)
4. Pivot through **CFG-valid gadget inside vmware-vmx** that loads args from `RCX+0x100` before dispatching to `WinExec("calc.exe")`

## LFH Timing Side-Channel

Deterministic Ping-Pong requires knowing the LFH free-chunk offset (which of 16 slots will be hit first).

### Technique

1. Use VMware backdoor instruction (`inl %%dx, %%eax`) with synchronous VMware Tools command `vmx.capability.unified_loop`
2. Pass 0x4000-byte string, forcing **two 0x4000 allocations** per call
3. Time 8 calls (16 allocations) via `gettimeofday`
4. One call shows consistent spike when LFH creates new bucket
5. Repeat with one extra allocation:
   - If spike stays at same index: offset is odd
   - If spike shifts: offset is even
   - Otherwise: restart due to noise

### Caveat

`unified_loop` stores unique strings in unfreeable list, causing **O(n) lookup overhead** and rising noise. Side-channel must converge quickly.

## Analysis Workflow

When analyzing this vulnerability:

1. **Understand the constraint**: 16-byte OOB writes with forced zero dword
2. **Map the heap**: Use LFH timing side-channel to learn bucket offset
3. **Create Ping-Pong**: Force deterministic allocation pattern
4. **Build Reap Oracle**: Map contiguous holes via URB reaping
5. **Exploit coalescing**: Two-pass overflow + vacuum technique for arbitrary writes
6. **Infoleak**: Hybrid URB technique to defeat ASLR
7. **Forge primitives**: Persistent fake URB for arbitrary read/write/call

## Security Research Context

This vulnerability demonstrates:
- **Heap metadata corruption** via fixed-size reallocation bug
- **LFH exploitation** on Windows 11 with checksummed headers
- **Coalescing abuse** to bypass constrained write patterns
- **Timing side-channels** for deterministic heap manipulation
- **VM escape** via driver vulnerability in virtualization software

## References

- [Synacktiv – On the clock: Escaping VMware Workstation at Pwn2Own Berlin 2025](https://www.synacktiv.com/en/publications/on-the-clock-escaping-vmware-workstation-at-pwn2own-berlin-2025.html)

---

**Note**: This skill is for educational and security research purposes. Understanding these vulnerabilities helps improve virtualization security and defensive measures.
