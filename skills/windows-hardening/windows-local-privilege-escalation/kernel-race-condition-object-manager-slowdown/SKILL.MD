---
name: windows-kernel-race-analysis
description: Analyze Windows kernel race conditions, TOCTOU vulnerabilities, and Object Manager namespace exploitation techniques. Use this skill whenever the user mentions Windows kernel vulnerabilities, race conditions, privilege escalation, Object Manager, NtOpen* calls, TOCTOU bugs, or security research on Windows kernel timing attacks. This skill helps understand, measure, and defend against race-based kernel exploits.
---

# Windows Kernel Race Condition Analysis

A skill for analyzing Windows kernel race conditions, particularly those involving Object Manager namespace lookups and TOCTOU (Time-of-Check-Time-of-Use) vulnerabilities.

## When to use this skill

Use this skill when:
- Analyzing Windows kernel vulnerabilities involving race conditions
- Researching TOCTOU bugs in kernel drivers
- Understanding Object Manager namespace exploitation techniques
- Measuring race windows in kernel code
- Developing defensive strategies against race-based LPEs
- Reviewing kernel code for timing vulnerabilities

## Core Concepts

### The Race Condition Pattern

Many Windows kernel LPEs follow this pattern:
```
check_state();           // Check if operation is allowed
NtOpenX("name");        // Open object (vulnerable window)
privileged_action();     // Perform privileged operation
```

On modern hardware, `NtOpenEvent`/`NtOpenSection` resolves in ~2µs, leaving minimal time to flip state. The goal is to stretch this window.

### Object Manager Namespace (OMNS) Structure

- Names like `\BaseNamedObjects\Foo` resolve directory-by-directory
- Each component triggers directory lookup and Unicode string comparison
- Symbolic links may be traversed during resolution
- `UNICODE_STRING` limit: 65,535 bytes (32,767 UTF-16 codepoints)
- User-writable directories: `\BaseNamedObjects` and similar

## Slowdown Primitives

### Primitive 1: Maximal Component Length

Creating objects with 32KB+ names increases lookup latency from ~2µs to ~35µs.

**Mechanism:** Linear Unicode comparison cost per directory entry.

**Implementation approach:**
```cpp
// Create event with long name
std::wstring long_name = L"\\BaseNamedObjects\\" + std::wstring(32000, 'A');
CreateEvent(long_name);
```

### Primitive 2: Deep Directory Chains

Chaining thousands of directories (`\A\A\A\...`) increases per-hop latency.

**Mechanism:** Each level triggers ACL checks, hash lookups, reference counting.

**Depth limit:** ~16,000 levels (UNICODE_STRING constraint).

### Primitive 3: Shadow Directories + Hash Collisions + Symlink Reparses

Combines three techniques for minute-scale slowdowns:

1. **Shadow directories:** Fallback lookups when primary fails
2. **Hash collisions:** O(n) linear scans within directories
3. **Symlink reparses:** 64-component limit, each restarts parsing

**Result:** Minutes-long lookup times on Windows 11.

## Measurement Framework

### Race Window Measurement

Use this harness to measure lookup latency:

```cpp
double measure_race_window(const std::wstring& name, int iterations) {
    // Create the target object
    HANDLE create_handle = CreateObject(name);
    
    // Measure open latency
    auto start = QueryPerformanceCounter();
    for (int i = 0; i < iterations; i++) {
        HANDLE open_handle;
        NtOpenObject(&open_handle, MAXIMUM_ALLOWED, &object_attributes);
        CloseHandle(open_handle);
    }
    auto end = QueryPerformanceCounter();
    
    return (end - start) / iterations / frequency;
}
```

### Expected Timings (Windows 11 24H2)

| Technique | Latency |
|-----------|---------|
| Baseline (short name) | ~2µs |
| 32KB component | ~35µs |
| 16K directory chain | >35µs |
| Shadow + collision + 63 reparses | ~3 minutes |

## Exploitation Workflow (Analysis)

### Step 1: Locate Vulnerable Open

Trace kernel paths to find `NtOpen*`/`ObOpenObjectByName` calls that:
- Walk attacker-controlled names
- Follow symbolic links in user-writable directories
- Have TOCTOU gaps between check and use

### Step 2: Replace with Slow Path

- Create long component or directory chain under `\BaseNamedObjects`
- Create symbolic link redirecting expected name to slow path
- Verify latency increase with measurement harness

### Step 3: Trigger Race

- Thread A (victim): Executes vulnerable code, blocks in slow lookup
- Thread B (attacker): Flips guarded state while Thread A blocked
- Thread A resumes: Performs privileged action with stale state

### Step 4: Cleanup

- Delete directory chains and symbolic links
- Close all handles to avoid namespace pollution
- Use `NtMakeTemporaryObject` for auto-cleanup

## Defensive Strategies

### For Kernel Developers

1. **Re-validate after open:** Check security-sensitive state *after* `NtOpen*` completes
2. **Take references early:** Hold object references before the check
3. **Enforce path limits:** Reject names exceeding depth/length thresholds
4. **Use atomic operations:** Where possible, combine check and action atomically

### For Defenders

1. **Monitor namespace growth:** ETW `Microsoft-Windows-Kernel-Object` events
2. **Detect suspicious chains:** Thousands of components under `\BaseNamedObjects`
3. **Audit symbolic links:** Unusual symlink patterns in kernel namespace
4. **Rate-limit object creation:** Prevent rapid namespace pollution

## Operational Considerations

### Combining Primitives

- Long names per level in directory chains
- CPU affinity pinning for deterministic scheduling
- Hypervisor-assisted preemption for precise timing

### Side Effects

- Slowdown affects only malicious path
- System performance largely unaffected
- Namespace pollution if cleanup fails

### Filesystem Races

Stack NTFS Oplocks on backing files for additional milliseconds of delay without altering OM graph.

## Scripts

### measure_race_window.py

Measures Object Manager lookup latency for a given path.

### cleanup_namespace.py

Safely removes test objects from `\BaseNamedObjects`.

### analyze_kernel_trace.py

Parses kernel traces to identify potential TOCTOU vulnerabilities.

## References

- [Project Zero – Windows Exploitation Techniques: Winning Race Conditions with Path Lookups](https://projectzero.google/2025/12/windows-exploitation-techniques.html)
- [googleprojectzero/symboliclink-testing-tools](https://github.com/googleprojectzero/symboliclink-testing-tools)

## Usage Examples

### Example 1: Measuring Race Window

**Input:** "I need to measure the race window for a kernel driver that opens \\BaseNamedObjects\\MyEvent"

**Output:** Provides measurement harness code and expected timing analysis.

### Example 2: Defensive Review

**Input:** "Review this kernel code for TOCTOU vulnerabilities"

**Output:** Analyzes code for check-then-use patterns, suggests fixes.

### Example 3: Understanding Slowdown Techniques

**Input:** "How do Object Manager slowdown primitives work?"

**Output:** Explains the three primitives with timing data and mechanisms.

## Important Notes

- This skill is for **security research and defensive analysis**
- All techniques should only be tested in controlled environments
- Proper cleanup is essential to avoid system instability
- Understanding these vulnerabilities helps build more secure systems
