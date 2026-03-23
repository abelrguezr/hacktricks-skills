---
name: uninitialized-variable-analysis
description: Analyze C code for uninitialized stack variable vulnerabilities, detect information disclosure risks, and provide exploitation or mitigation guidance. Use this skill whenever the user mentions uninitialized variables, stack variables, C security, memory leaks, info disclosure, binary exploitation, or asks about analyzing C code for security vulnerabilities. Make sure to use this skill when reviewing C code for security issues, even if the user doesn't explicitly mention 'uninitialized' - partial struct initialization, copy_to_user calls, and stack buffer issues often indicate this vulnerability class.
---

# Uninitialized Variable Analysis

A skill for identifying, analyzing, and exploiting uninitialized stack variable vulnerabilities in C code.

## When to Use This Skill

Trigger this skill when:
- User asks about uninitialized variables in C
- User wants to analyze C code for security vulnerabilities
- User mentions stack variables, memory disclosure, or info leaks
- User is doing binary exploitation research
- User asks about compiler flags related to stack initialization
- User wants to understand how uninitialized variables can be exploited
- User is reviewing kernel/driver code for security issues

## Core Concepts

### What Are Uninitialized Variables?

Uninitialized stack variables contain whatever data was previously at that memory location. They don't automatically get zeroed out, which means they can leak sensitive information or be exploited to control program behavior.

**Key insight**: When you declare `int x;` without initialization, `x` contains whatever bytes were last written to that stack slot - potentially sensitive data from previous function calls.

### Security Risks

1. **Data Leakage**: Sensitive information (passwords, keys, personal data) can be exposed
2. **Information Disclosure**: Memory layout details can aid attackers in developing exploits
3. **Crashes and Instability**: Undefined behavior from uninitialized data
4. **Arbitrary Code Execution**: In some cases, can lead to ROP or function pointer overwrites

## Detection Patterns

### Code Review Patterns

Look for these patterns in C code:

```c
// Pattern 1: Partial struct initialization
struct msg {
    char data[0x20];
    uint32_t len;
};

ssize_t handler(int fd) {
    struct msg m;              // never fully initialized
    m.len = read(fd, m.data, sizeof(m.data));
    write(1, &m, sizeof(m));   // leaks padding + stale stack
    return m.len;
}
```

**Red flags**:
- Struct declared but only some fields initialized
- `copy_to_user`, `write`, or `memcpy` of entire struct
- Debug helpers that print local structs
- Error paths where initialization is skipped

### Compiler Diagnostics

Build with these flags to catch issues:

```bash
# GCC/Clang warnings
gcc -Wall -Wextra -Wuninitialized program.c
clang -Wall -Wextra -Wuninitialized program.c

# C++ specific
clang-tidy -checks=cppcoreguidelines-init-variables
```

### Dynamic Analysis Tools

- **MemorySanitizer (MSan)**: `clang -fsanitize=memory program.c`
- **Valgrind**: `valgrind --track-origins=yes ./program`

These tools reliably flag reads of uninitialized stack bytes during execution.

## Exploitation Patterns

### Classic Read-Before-Write

When a struct is partially initialized and then copied to userland:

1. **Identify the struct** - Look for structs with padding or unused fields
2. **Find the leak** - Look for `copy_to_user`, `write`, or `memcpy` of the whole struct
3. **Determine what's leaked** - Stack canaries, saved frame pointers, kernel pointers
4. **Plan the exploit** - Use leaked info to bypass ASLR or canaries

### Practical Attack Surfaces (2024-2025)

1. **Partially initialized structs**: Kernel/driver code that `memset` only length fields
2. **Uninitialized indexes/lengths**: `size_t len;` used to bound reads/writes
3. **Compiler padding**: Even when members are initialized, padding bytes aren't
4. **Debug helpers**: Functions that copy local structs to stdout for debugging
5. **ROP/Canary disclosure**: Uninitialized padding can reveal stack canaries

### Minimal PoC Pattern

```c
struct msg {
    char data[0x20];
    uint32_t len;
};

ssize_t handler(int fd) {
    struct msg m;              // never fully initialized
    m.len = read(fd, m.data, sizeof(m.data));
    write(1, &m, sizeof(m));   // leaks padding + stale stack
    return m.len;
}
```

## Mitigations

### Compiler Options

- **Clang/GCC**: `-ftrivial-auto-var-init=zero` or `-ftrivial-auto-var-init=pattern`
  - Fills every automatic (stack) variable with zeros or poison pattern (0xAA / 0xFE)
  - Closes most uninitialized-stack info leaks

- **Linux kernel**: `CONFIG_INIT_STACK_ALL` or `CONFIG_INIT_STACK_ALL_PATTERN`
  - Zero/pattern-initialize every stack slot at function entry
  - Common in 6.8+ hardening configs

### Code Fixes

```c
// Bad
struct msg m;
m.len = read(fd, m.data, sizeof(m.data));

// Good - zero-initialize entire struct
struct msg m = {0};
m.len = read(fd, m.data, sizeof(m.data));

// Or explicit initialization
struct msg m;
memset(&m, 0, sizeof(m));
m.len = read(fd, m.data, sizeof(m.data));
```

### Opt-out Attributes (Watch for These)

Clang allows `__attribute__((uninitialized))` on specific locals/structs to keep performance-critical areas uninitialized. Review such annotations carefully - they often mark deliberate attack surface.

## Analysis Workflow

When analyzing code for uninitialized variable vulnerabilities:

1. **Identify stack variables** - Look for local variables in functions
2. **Check initialization** - Verify all fields are initialized before use
3. **Find disclosure points** - Look for `copy_to_user`, `write`, `memcpy` of structs
4. **Assess impact** - Determine what sensitive data could leak
5. **Recommend fixes** - Suggest proper initialization or compiler flags

## Example Analysis

### Input
```c
struct request {
    char buffer[64];
    int flags;
    void (*callback)(void);
};

void process_request(int fd) {
    struct request req;
    req.flags = read(fd, req.buffer, sizeof(req.buffer));
    send_response(fd, &req, sizeof(req));
}
```

### Analysis Output

**Vulnerability Found**: Uninitialized stack variable

**Location**: `process_request()` function

**Issue**: `req` struct is not fully initialized before being sent

**Leaked Data**:
- `req.callback` (function pointer) - 8 bytes
- Padding between `buffer` and `flags` - 4 bytes
- Padding between `flags` and `callback` - 4 bytes

**Impact**: Information disclosure of stack contents, potential ROP chain construction

**Fix**:
```c
void process_request(int fd) {
    struct request req = {0};  // Zero-initialize
    req.flags = read(fd, req.buffer, sizeof(req.buffer));
    send_response(fd, &req, sizeof(req));
}
```

## ARM64 Considerations

Uninitialized variable vulnerabilities work the same on ARM64 - local variables are still managed on the stack. The exploitation patterns and mitigations are identical to x86/x64.

## References

- [CONFIG_INIT_STACK_ALL_PATTERN documentation](https://www.kernelconfig.io/config_init_stack_all_pattern)
- [GHSL-2024-197: GStreamer uninitialized stack variable](https://securitylab.github.com/advisories/GHSL-2024-197_GStreamer/)
- [ARM64 Uninitialized Variable Exploitation](https://8ksec.io/arm64-reversing-and-exploitation-part-6-exploiting-an-uninitialized-stack-variable-vulnerability/)
