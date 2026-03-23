---
name: arbitrary-write-2-exec
description: Binary exploitation skill for arbitrary write to code execution attacks. Use this skill whenever the user mentions arbitrary write vulnerabilities, write primitives, GOT overwrites, function pointer overwrites, or needs to convert a write primitive into code execution. Also trigger for CTF challenges involving memory corruption, heap exploits, or when the user asks about turning write access into shellcode execution.
---

# Arbitrary Write to Code Execution

This skill helps you convert arbitrary write primitives into code execution in binary exploitation challenges. An arbitrary write vulnerability lets you write any value to any memory address - this skill shows you how to weaponize that into RCE.

## Core Concept

An arbitrary write primitive is dangerous because you can overwrite:
- **GOT entries** - Redirect function calls to your shellcode
- **Function pointers** - Hijack control flow directly
- **Return addresses** - Classic stack-based exploitation
- **vtable pointers** - In C++ applications
- **Global variables** - That affect program logic

## Attack Patterns

### Pattern 1: GOT Overwrite (Most Common)

When you can write to the Global Offset Table, overwrite a function's entry to point to your shellcode or `system()`.

**Steps:**
1. Find a function that gets called after your write primitive (e.g., `puts`, `printf`)
2. Get the address of that function's GOT entry
3. Overwrite it with the address of `system()` or your shellcode
4. Trigger the function call

**Example:**
```
# Overwrite puts@GOT with system@plt
write(puts_got_addr, system_plt_addr)
puts(";id;#")  # Now calls system(";id;#")
```

### Pattern 2: Function Pointer Overwrite

If the binary has global function pointers, overwrite them directly.

**Steps:**
1. Identify function pointers in the binary (look for `call [addr]` instructions)
2. Overwrite the pointer with your shellcode address
3. Trigger the call

### Pattern 3: Return Address Overwrite

Classic stack smashing - if you can write to the stack, overwrite the return address.

**Steps:**
1. Find the offset to the return address
2. Overwrite it with your shellcode or ROP chain address
3. Return from the function

## Finding Write Primitives

Look for these vulnerability patterns:

| Vulnerability | Write Primitive |
|--------------|------------------|
| Format string | `%n` writes to stack |
| Heap overflow | Can corrupt adjacent data |
| Use-after-free | Can control freed chunk metadata |
| Integer overflow | Can cause out-of-bounds writes |
| Off-by-one | Can corrupt next structure |

## Shellcode Placement

You need a place to put your shellcode:

1. **BSS section** - Writable, but not executable by default
2. **Heap** - Writable, may need to make executable
3. **Stack** - Writable, may need to make executable
4. **mmap()** - Allocate RWX memory explicitly

**Making memory executable:**
```c
// Use mprotect via ROP
mprotect(addr & ~0xfff, 0x2000, PROT_READ | PROT_WRITE | PROT_EXEC)
```

## ROP Chain Construction

When you can't execute shellcode directly, use Return-Oriented Programming:

1. Find gadgets in the binary (instructions ending in `ret`)
2. Chain them to set up registers and call `system()`
3. Use the write primitive to place the ROP chain
4. Redirect execution to it

**Common gadgets:**
- `pop rdi; ret` - Set first argument
- `pop rsi; ret` - Set second argument
- `pop rax; ret` - Set syscall number
- `mov rax, 0x3b; ret` - execve syscall

## Practical Workflow

### Step 1: Analyze the Binary

```bash
# Check protections
checksec --file vulnerable_binary

# Find GOT entries
objdump -R vulnerable_binary | grep puts

# Find function pointers
radare2 -c "afl" vulnerable_binary
```

### Step 2: Identify the Write Primitive

- What can you write?
- Where can you write?
- What constraints exist (size, alignment, null bytes)?

### Step 3: Choose Your Target

- GOT entry? (easiest if available)
- Function pointer? (direct control)
- Return address? (classic)
- vtable? (C++ specific)

### Step 4: Craft the Payload

Use the scripts in this skill to generate payloads:
- `scripts/got_overwrite.py` - GOT overwrite payloads
- `scripts/rop_chain.py` - ROP chain generation
- `scripts/find_gadgets.py` - Gadget discovery

### Step 5: Test and Iterate

- Test with gdb/pwndbg
- Check for ASLR issues
- Verify NX/PIE constraints

## Common Pitfalls

1. **ASLR** - If enabled, you need to leak an address first
2. **NX** - Can't execute shellcode on stack/heap without mprotect
3. **PIE** - Addresses are randomized, need to leak base
4. **Canaries** - Stack canaries prevent return address overwrites
5. **Null bytes** - Some functions stop at null bytes

## Debugging Tips

```bash
# Set breakpoints on GOT entries
break *puts@GOT

# Watch for writes to specific addresses
watch *(long*)0x404000

# Trace execution
traceexec ./vulnerable
```

## When to Use This Skill

Use this skill when:
- You have a write primitive and need RCE
- You're solving CTF challenges with memory corruption
- You need to understand GOT overwrites
- You want to convert heap vulnerabilities to code execution
- You're analyzing binaries for write-based vulnerabilities

## Next Steps

After mastering arbitrary write to exec:
1. Learn heap exploitation (heap grooming, tcache poisoning)
2. Study format string vulnerabilities
3. Practice with pwnable.kr and similar platforms
4. Learn advanced ROP techniques (JOP, SIP, ROPgadget)

## References

- [HackTricks - Arbitrary Write](https://book.hacktricks.xyz/pentesting/writing-payloads/arbitrary-write)
- [Pwn.college - Memory Corruption](https://pwn.college/)
- [ROP Emporium](https://ropemporium.com/)
- [pwntools Documentation](https://docs.pwntools.com/)
