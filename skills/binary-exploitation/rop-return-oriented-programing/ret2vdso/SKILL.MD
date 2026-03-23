---
name: ret2vdso-exploitation
description: How to perform Ret2vDSO (Return-to-vDSO) attacks in binary exploitation challenges. Use this skill whenever the user mentions vDSO, vdso, virtual dynamic shared object, kernel gadgets, AT_SYSINFO_EHDR, or needs to exploit gadgets in the kernel-mapped vDSO region. Also trigger when working with binary exploitation challenges where standard ROP gadgets aren't available but vDSO gadgets might be, or when ASLR bypass via vDSO is mentioned. This skill helps dump vDSO regions, locate gadgets, and build exploitation chains using vDSO addresses.
---

# Ret2vDSO Exploitation

A skill for performing Return-to-vDSO attacks in binary exploitation challenges.

## What is vDSO?

The vDSO (virtual Dynamic Shared Object) is a small ELF DSO mapped by the kernel to provide fast user-space implementations of some kernel helpers. It's mapped at a fixed or semi-fixed address and contains gadgets that can be used for ROP attacks.

## When to Use This Skill

- Binary exploitation challenges where standard ROP gadgets are insufficient
- When you need to dump and analyze the vDSO region
- When ASLR bypass via vDSO is possible (CONFIG_COMPAT_VDSO)
- When you have access to `/proc/<pid>/auxv` or can leak vDSO addresses
- ARM64 SROP exploitation via vDSO

## Core Methodology

### Step 1: Locate the vDSO Base Address

The vDSO base address is passed in the auxiliary vector as `AT_SYSINFO_EHDR`. You can recover it by:

1. **Reading `/proc/<pid>/auxv`** (if accessible):
   ```bash
   cat /proc/<pid>/auxv
   ```

2. **Using `getauxval` in a helper process**:
   ```c
   #include <sys/auxv.h>
   #include <stdio.h>
   int main() {
       void *vdso = (void*)getauxval(AT_SYSINFO_EHDR);
       printf("vDSO base: %p\n", vdso);
       return 0;
   }
   ```

3. **From memory maps** (look for `[vdso]`):
   ```bash
   cat /proc/<pid>/maps | grep vdso
   ```

### Step 2: Dump the vDSO Region

Once you have the base address, dump the vDSO from the process memory:

```bash
# Find the vDSO address range
cat /proc/<pid>/maps | grep vdso
# Example output: f7ffc000-f7ffe000 r-xp 00000000 00:00 0 [vdso]

# Calculate size and dump
BASE=0xf7ffc000
SIZE=$((0xf7ffe000 - 0xf7ffc000))
dd if=/proc/<pid>/mem of=vdso bs=1 skip=$BASE count=$SIZE

# Or use the helper script
python scripts/dump_vdso.py <pid>
```

### Step 3: Analyze the vDSO for Gadgets

```bash
# Check file type
file vdso

# Find gadgets using ROPgadget
ROPgadget --binary vdso | grep -E 'pop|ret|mov|add|sub|xor'

# Look for specific syscall gadgets
ROPgadget --binary vdso | grep 'int 0x80'      # x86 syscall
ROPgadget --binary vdso | grep 'syscall'       # x86_64 syscall
ROPgadget --binary vdso | grep 'svc'           # ARM64 syscall

# Or use the helper script
python scripts/find_vdso_gadgets.py vdso
```

### Step 4: Identify Exported Symbols

The vDSO exports specific symbols depending on architecture:

**x86 32-bit:**
- `__kernel_vsyscall`
- `__kernel_sigreturn`
- `__kernel_rt_sigreturn`

**x86_64:**
- `__vdso_clock_gettime`
- `__vdso_gettimeofday`
- `__vdso_time`

**ARM64:**
- `__kernel_rt_sigreturn`
- `__kernel_vsyscall`

Use `readelf` or `objdump` to find symbol offsets:

```bash
readelf -Ws vdso | grep -E 'FUNC|__kernel|__vdso'
objdump -d vdso | grep -A5 '<__kernel'
```

### Step 5: Build the Exploitation Chain

Once you have gadgets, calculate their absolute addresses:

```python
vdso_base = 0xf7ffc000  # From auxv or memory leak

# Example gadgets (offsets from readelf/ROPgadget)
gadgets = {
    'pop_edx_pop_ecx_ret': vdso_base + 0x57a,
    'mov_dword_ptr_edx_ecx': vdso_base + 0xcca,
    'pop_ebx_pop_esi_pop_ebp': vdso_base + 0x15cd,
}

# Build ROP chain
rop_chain = [
    gadgets['pop_edx_pop_ecx_ret'],
    target_address,
    value_to_write,
    gadgets['mov_dword_ptr_edx_ecx'],
    # ... rest of chain
]
```

## Architecture-Specific Notes

### x86/x86_64

- vDSO typically contains syscall-related gadgets
- Look for `int 0x80` (x86) or `syscall` (x86_64) instructions
- Common gadgets involve `pop` instructions for register setup

### ARM64

- vDSO gadgets are more limited on ARM64
- Primary use case: SROP (Sigreturn-Oriented Programming)
- Look for `__kernel_rt_sigreturn` for SROP chains
- Check for gadgets that can control `x30` (link register)

## ASLR Bypass Considerations

**Important:** If the kernel is compiled with `CONFIG_COMPAT_VDSO`, the vDSO address may not be randomized, allowing ASLR bypass:

- 32-bit processes on 64-bit kernels often have fixed vDSO addresses
- Check kernel config: `grep CONFIG_COMPAT_VDSO /boot/config-$(uname -r)`
- If fixed, you can use hardcoded vDSO addresses in your exploit

## Common Pitfalls

1. **Symbol versioning:** vDSO uses symbol versioning. Match the expected version when resolving symbols.

2. **Address randomization:** On modern kernels, vDSO may still be ASLR'd. Always verify the address at runtime.

3. **Architecture mismatch:** Ensure you're analyzing the correct architecture's vDSO (32-bit vs 64-bit).

4. **Permissions:** You need appropriate permissions to read `/proc/<pid>/mem` and `/proc/<pid>/auxv`.

## Example Workflow

```bash
# 1. Find target process
ps aux | grep target_binary

# 2. Get vDSO address from maps
cat /proc/<pid>/maps | grep vdso
# f7ffc000-f7ffe000 r-xp 00000000 00:00 0 [vdso]

# 3. Dump vDSO
python scripts/dump_vdso.py <pid>

# 4. Find useful gadgets
python scripts/find_vdso_gadgets.py vdso | grep -E 'pop|syscall|ret'

# 5. Build exploit using discovered gadgets
# (use your preferred exploit framework or custom code)
```

## References

- [Linux vDSO man page](https://man7.org/linux/man-pages/man7/vdso.7.html)
- [Kernel vDSO documentation](https://www.kernel.org/doc/Documentation/ABI/stable/vdso)
- [vDSO ASLR bypass vulnerability](https://vigilance.fr/vulnerability/Linux-kernel-bypassing-ASLR-via-VDSO-11639)
- [HTB Maze of Mist writeup](https://7rocky.github.io/en/ctf/other/htb-cyber-apocalypse/maze-of-mist/)

## Scripts

This skill includes helper scripts:

- `scripts/dump_vdso.py` - Dump vDSO from a running process
- `scripts/find_vdso_gadgets.py` - Find and list gadgets in a vDSO dump

Run them with `--help` for usage information.
