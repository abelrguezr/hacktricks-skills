---
name: cet-shadow-stack
description: Control Flow Enforcement Technology (CET) and Shadow Stack analysis for binary exploitation. Use this skill whenever the user mentions CET, shadow stack, control flow integrity, ROP/JOP attacks, binary security protections, or needs to understand how modern CPU features prevent control-flow hijacking. Trigger for security research, binary analysis, exploitation learning, or when discussing hardware-level security mitigations.
---

# CET & Shadow Stack Analysis

A skill for understanding and analyzing Control Flow Enforcement Technology (CET) and Shadow Stack security features in binary exploitation contexts.

## What This Skill Covers

- **CET fundamentals**: How Control Flow Enforcement Technology works at the hardware level
- **Shadow Stack mechanics**: The dedicated return address protection mechanism
- **Attack prevention**: How CET mitigates ROP and JOP attacks
- **Practical analysis**: Identifying and working with CET-protected binaries

## Core Concepts

### Control Flow Enforcement Technology (CET)

CET is a hardware-level security feature designed to prevent control-flow hijacking attacks like Return-Oriented Programming (ROP) and Jump-Oriented Programming (JOP).

**Two main components:**

1. **Indirect Branch Tracking (IBT)**
   - Ensures indirect jumps and calls target only valid destinations
   - Uses new instruction markers to designate legal branch targets
   - Prevents arbitrary code execution through gadget chaining

2. **Shadow Stack**
   - Maintains a protected, hidden copy of return addresses
   - Separate from the regular call stack
   - Validates return addresses before function returns
   - Detects and blocks return address tampering

### How Shadow Stack Works

The shadow stack is a **dedicated stack used solely for storing return addresses**.

**Key properties:**
- Works alongside the regular stack but remains protected
- Hidden from normal program execution
- Difficult for attackers to tamper with
- Provides integrity verification for return addresses

**Protection mechanism:**
1. When a function is called, the return address is pushed to both the regular stack AND the shadow stack
2. When the function returns, the CPU compares the return address from the regular stack against the shadow stack
3. If they don't match, the program terminates or takes security measures
4. This prevents attackers from overwriting return addresses to hijack control flow

### Attack Prevention

**ROP and JOP attacks** work by:
- Hijacking control flow through vulnerabilities
- Overwriting pointers or return addresses on the stack
- Directing execution to existing code gadgets
- Chaining gadgets to perform arbitrary operations

**How CET stops these attacks:**

| Attack Vector | CET Countermeasure |
|--------------|-------------------|
| Arbitrary gadget execution | IBT requires explicit target markers |
| Return address overwrite | Shadow stack detects discrepancies |
| Control flow hijacking | Hardware-level validation blocks invalid branches |

## Practical Analysis

### Identifying CET-Protected Binaries

When analyzing a binary, look for these indicators:

**ELF headers and sections:**
- Check for CET-related sections in the binary
- Look for ENDBRANCH instructions (0xF3 0x0F 0x1E 0xFA)
- Examine the `.note.gnu.property` section for CET flags

**Command-line tools:**
```bash
# Check for CET support
readelf -n binary | grep -i cet

# Look for ENDBRANCH instructions
objdump -d binary | grep -i endbranch

# Check binary properties
readelf -p binary | grep -i property
```

### Understanding the Protection Model

**What CET protects:**
- ✅ Return addresses from stack corruption
- ✅ Indirect calls/jumps to invalid targets
- ✅ ROP chain execution
- ✅ JOP chain execution

**What CET does NOT protect:**
- ❌ Direct memory corruption (use ASLR, DEP, etc.)
- ❌ Format string vulnerabilities
- ❌ Integer overflows
- ❌ Logic vulnerabilities

### Working with CET in Exploitation

**When analyzing CET-protected targets:**

1. **First, verify CET is actually enabled**
   - Check compilation flags
   - Verify runtime enforcement
   - Some binaries may have CET compiled but not enforced

2. **Understand the attack surface**
   - CET only protects control flow, not data integrity
   - Look for vulnerabilities that don't require control flow hijacking
   - Consider partial overwrites or data-only attacks

3. **Consider bypass scenarios**
   - Shadow stack corruption (requires separate vulnerability)
   - IBT bypass through valid ENDBRANCH targets
   - Side-channel attacks (research-level)

## Common Questions

### "What is CET?"
CET is Intel's Control Flow Enforcement Technology, a hardware security feature that prevents control-flow hijacking attacks through Indirect Branch Tracking and Shadow Stack mechanisms.

### "How does shadow stack differ from regular stack?"
The shadow stack is a protected, CPU-managed stack that stores only return addresses. It's separate from the regular stack and cannot be accessed or modified by normal program instructions.

### "Can CET be bypassed?"
CET significantly raises the bar for exploitation but isn't invulnerable. Bypasses typically require:
- Additional vulnerabilities to corrupt the shadow stack
- Finding valid ENDBRANCH targets for IBT bypass
- Exploiting implementation bugs in CET itself

### "Should I use CET in my binaries?"
Yes. CET provides strong protection against common exploitation techniques with minimal performance overhead. Enable it via compiler flags (`-fcf-protection=full` for GCC/Clang).

## Related Protections

CET works alongside other security features:

| Protection | What It Does | Works With CET? |
|------------|-------------|-----------------|
| ASLR | Randomizes memory addresses | ✅ Yes |
| DEP/NX | Marks memory as non-executable | ✅ Yes |
| Stack Canaries | Detects stack buffer overflows | ✅ Yes |
| PIE | Position-independent executable | ✅ Yes |

## Research Context

**When to use this skill:**
- Analyzing binaries for security research
- Learning about modern CPU security features
- Understanding exploitation limitations
- Security assessment of software
- Academic study of control flow integrity

**Key references:**
- Intel CET documentation
- Binary exploitation tutorials covering modern mitigations
- Security research papers on control flow integrity

## Quick Reference

**CET Components:**
- IBT: Validates indirect branch targets
- Shadow Stack: Protects return addresses

**Attack Prevention:**
- Blocks ROP/JOP chains
- Detects return address corruption
- Requires valid ENDBRANCH markers

**Analysis Commands:**
- `readelf -n binary` - Check CET properties
- `objdump -d binary | grep endbranch` - Find ENDBRANCH instructions
- `checksec --file=binary` - View all protections

---

**Remember:** CET is a powerful defense but not a silver bullet. Always consider the full security context and look for vulnerabilities that don't rely on control flow hijacking.
