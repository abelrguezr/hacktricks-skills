---
name: z3-smt-reversing
description: Use Z3 SMT solver to solve constraints from reversing tasks, crackmes, and binary analysis. Use this skill whenever you need to solve symbolic constraints, reverse engineer license checks, find valid inputs for binaries, or work with bit-vector arithmetic from decompiled code. Trigger this skill for any task involving constraint solving, symbolic execution, or finding values that satisfy conditions extracted from binaries.
---

# Z3 SMT Solver for Reversing

Use Z3 to solve constraints extracted from binaries, crackmes, and decompiled code. This skill helps you find valid inputs, solve license checks, and reverse engineer validation logic.

## When to Use This Skill

Use this skill when:
- You have constraints from decompiled code or disassembly that need solving
- You're reversing a crackme with validation checks
- You need to find inputs that satisfy bit-vector arithmetic conditions
- You're working with symbolic execution output (angr, etc.)
- You need to enumerate multiple valid solutions for a challenge

## Quick Start

```python
from z3 import *

# Install: pip3 install z3-solver

# Basic pattern
s = Solver()
x = BitVec('x', 32)  # 32-bit variable
s.add(x + 5 == 10)
if s.check() == sat:
    print(s.model())
```

## Core Patterns

### 1. Byte-Based Checks (Most Common)

When reversing crackmes with password/serial validation, model each byte as an 8-bit vector:

```python
from z3 import *

# Model a flag as bytes
flag = [BitVec(f'flag_{i}', 8) for i in range(8)]
s = Solver()

# Constrain to printable ASCII
for c in flag:
    s.add(c >= 0x20, c <= 0x7e)

# Add constraints from the binary
# Example: flag[0] + flag[5] == 0x90
s.add((ZeroExt(24, flag[0]) + ZeroExt(24, flag[5])) == 0x90)

# Example: XOR chain
s.add((flag[1] ^ flag[2] ^ flag[3]) == 0x5a)

# Example: rotation and XOR
w0 = Concat(flag[3], flag[2], flag[1], flag[0])  # little-endian
w1 = Concat(flag[7], flag[6], flag[5], flag[4])
s.add(RotateLeft(w0, 7) ^ w1 == BitVecVal(0x4f625a13, 32))

if s.check() == sat:
    m = s.model()
    result = bytes(m[c].as_long() for c in flag)
    print(result)
```

### 2. Word Reconstruction from Bytes

When the binary operates on 32-bit words built from bytes:

```python
from z3 import *

b0, b1, b2, b3 = BitVecs('b0 b1 b2 b3', 8)

# Little-endian: b0 is lowest byte
eax = Concat(b3, b2, b1, b0)

# Extract parts
low_byte = Extract(7, 0, eax)        # AL register
high_word = Extract(31, 16, eax)     # Upper 16 bits

# Sign/zero extension (common in x86)
signed_b0 = SignExt(24, b0)          # movsx eax, byte ptr [...]
unsigned_b0 = ZeroExt(24, b0)        # movzx eax, byte ptr [...]
```

### 3. Shift Operations

**Critical:** Use the correct shift operator:

```python
from z3 import *

eax = BitVec('eax', 32)

# Logical right shift (shr instruction)
logical = LShR(eax, 3)

# Arithmetic right shift (sar instruction) - signed
arith = eax >> 3

# Left shift (same for both)
left = eax << 3

# Rotate
rot = RotateLeft(eax, 13)  # rol eax, 13
rot_right = RotateRight(eax, 5)  # ror eax, 5
```

### 4. Signed vs Unsigned Comparisons

```python
from z3 import *

x, y = BitVecs('x y', 32)

# Signed comparisons (default operators)
solve(x > 0, y < 0)

# Unsigned comparisons (use U-prefixed operators)
solve(ULT(x, y))  # x < y (unsigned)
solve(ULE(x, y))  # x <= y (unsigned)
solve(UGT(x, y))  # x > y (unsigned)
solve(UGE(x, y))  # x >= y (unsigned)

# Unsigned division/modulo
solve(UDiv(x, y) == 5)
solve(URem(x, y) == 0)
```

### 5. Incremental Solving with push/pop

Test hypotheses without rebuilding the solver:

```python
from z3 import *

x = BitVec('x', 32)
s = Solver()
s.add((x & 0xff) == 0x41)  # Base constraint

# Test hypothesis 1: x > 0x1000 (unsigned)
s.push()
s.add(UGT(x, 0x1000))
print("Hypothesis 1:", s.check())
s.pop()

# Test hypothesis 2: x == 0x41
s.push()
s.add(x == 0x41)
print("Hypothesis 2:", s.check())
if s.check() == sat:
    print(s.model())
s.pop()
```

### 6. Enumerating Multiple Solutions

When a challenge accepts many valid inputs:

```python
from z3 import *

xs = [BitVec(f'x{i}', 8) for i in range(4)]
s = Solver()

# Constrain to digits
for x in xs:
    s.add(And(x >= 0x30, x <= 0x39))

# Add constraints
s.add(xs[0] + xs[1] == xs[2] + 1)
s.add(xs[3] == xs[0] ^ 3)

# Enumerate all solutions
while s.check() == sat:
    m = s.model()
    print(''.join(chr(m[x].as_long()) for x in xs))
    # Block this solution, find next
    s.add(Or([x != m.eval(x, model_completion=True) for x in xs]))
```

### 7. Advanced Tactics for Complex Formulas

For decompiler-generated formulas with many equalities:

```python
from z3 import *

# Build solver with tactics for bit-vector problems
t = Then('simplify', 'solve-eqs', 'bit-blast', 'sat')
s = t.solver()

# Add your constraints
x = BitVec('x', 32)
s.add(x & 0xff == 0x41)
s.add(UGT(x, 0x100))

if s.check() == sat:
    print(s.model())
```

## Common Pitfalls

| Issue | Wrong | Correct |
|-------|-------|--------|
| Logical shift | `x >> 3` | `LShR(x, 3)` |
| Unsigned compare | `x < y` | `ULT(x, y)` |
| Unsigned div | `x / y` | `UDiv(x, y)` |
| Unsigned mod | `x % y` | `URem(x, y)` |
| Sign extension | `x` | `SignExt(24, x)` |
| Zero extension | `x` | `ZeroExt(24, x)` |
| Little-endian concat | `Concat(b0, b1, b2, b3)` | `Concat(b3, b2, b1, b0)` |

## Workflow for Reversing Tasks

1. **Extract constraints** from decompiled code or disassembly
2. **Model variables** as appropriate bit-widths (8-bit for bytes, 32/64 for registers)
3. **Add alphabet constraints** early (printable ASCII, digits, etc.)
4. **Rebuild arithmetic** exactly as the binary does (watch for extensions, shifts)
5. **Solve and verify** the result against the original binary
6. **Use push/pop** to test alternative interpretations
7. **Enumerate** if multiple solutions are expected

## Integration with Other Tools

- **angr**: Use for symbolic execution to extract constraints automatically
- **Ghidra/IDA**: Use decompiler output as starting point for manual constraint extraction
- **Binary Ninja**: Similar workflow - extract logic, translate to Z3

## Examples

### Simple License Check

```python
from z3 import *

# Serial format: XXXX-XXXX-XXXX-XXXX
serial = [BitVec(f's{i}', 8) for i in range(16)]
s = Solver()

# Alphanumeric
for c in serial:
    s.add(Or(
        And(c >= ord('0'), c <= ord('9')),
        And(c >= ord('A'), c <= ord('Z')),
        And(c >= ord('a'), c <= ord('z'))
    ))

# Example constraint: sum of first 4 bytes == 0x123
s.add(ZeroExt(24, serial[0]) + ZeroExt(24, serial[1]) + 
      ZeroExt(24, serial[2]) + ZeroExt(24, serial[3]) == 0x123)

if s.check() == sat:
    m = s.model()
    result = ''.join(chr(m[c].as_long()) for c in serial)
    print(result)
```

### CRC32-Like Check

```python
from z3 import *

# Model input as bytes
input_bytes = [BitVec(f'b{i}', 8) for i in range(32)]
s = Solver()

# ASCII constraint
for b in input_bytes:
    s.add(And(b >= 0x20, b <= 0x7e))

# Model CRC state as bit-vector
crc = BitVec('crc', 32)
# ... add CRC computation constraints ...

# Final check
crc_final = BitVec('crc_final', 32)
s.add(crc_final == BitVecVal(0xDEADBEEF, 32))

if s.check() == sat:
    m = s.model()
    print(bytes(m[b].as_long() for b in input_bytes))
```

## References

- [Z3Py Tutorial](https://ericpony.github.io/z3py-tutorial/guide-examples.htm)
- [Z3 Bit-Vectors Guide](https://microsoft.github.io/z3guide/docs/theories/Bitvectors/)
- [Programming Z3](https://theory.stanford.edu/~nikolaj/programmingz3.html)
- [angr for symbolic execution](https://angr.io/)
