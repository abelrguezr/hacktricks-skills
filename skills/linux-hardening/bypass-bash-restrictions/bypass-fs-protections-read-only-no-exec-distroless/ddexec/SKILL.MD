---
name: linux-ddexec-bypass
description: Bypass Linux filesystem protections (read-only, noexec, file whitelisting, hash whitelisting) by hijacking existing processes through /proc/pid/mem. Use this skill whenever you need to execute code on a restricted Linux system, bypass filesystem restrictions, perform authorized security testing on systems with read-only or noexec mounts, or understand process memory manipulation techniques. Make sure to use this skill when the user mentions bypassing filesystem protections, read-only mounts, noexec restrictions, file-based whitelisting, or executing code in constrained Linux environments.
---

# Linux DDexec Bypass

A technique for bypassing common Linux filesystem protections by hijacking existing processes through `/proc/$pid/mem`.

## When to Use

Use this skill when:
- You need to execute code on a system with read-only filesystems
- You're working with noexec mounts that prevent direct execution
- File-based whitelisting or hash-based restrictions are in place
- You're performing authorized security testing or penetration testing
- You need to understand how process memory manipulation works
- You're dealing with distroless containers or minimal Linux environments

## Prerequisites

This technique requires:
- Access to `/proc/$pid/mem` (typically requires same user or root)
- Basic Linux tools available on the system:
  - `dd` (or alternatives: `tail`, `hexdump`, `cmp`, `xxd`)
  - Shell: `bash`, `zsh`, or `ash` (busybox)
  - `head`, `tail`, `cut`, `grep`, `od`, `readlink`, `wc`, `tr`, `base64`
- Understanding of Linux process memory layout
- **Authorization to test the target system**

## How It Works

The core concept: instead of creating a new executable file, hijack an existing process and replace its memory with your payload.

### Key Components

1. **Memory Access**: `/proc/$pid/mem` provides direct access to a process's virtual address space (one-to-one mapping from `0x0000000000000000` to `0x7ffffffffffff000` on x86-64)

2. **File Descriptor Inheritance**: Child processes inherit file descriptors, allowing memory modification through inherited fds

3. **ASLR Bypass**: Read `/proc/$pid/maps` to determine memory layout and find executable regions

4. **Shellcode Injection**: Overwrite the return address with custom shellcode via `/proc/$pid/mem`

### The Process

1. **Parse the target binary and loader** to understand required mappings

2. **Create shellcode** that mimics `execve()` behavior:
   - Create memory mappings
   - Load binary into memory
   - Set permissions
   - Initialize stack with arguments
   - Place auxiliary vector (needed by loader)
   - Jump to loader

3. **Find the syscall return address** from `/proc/$pid/syscall`

4. **Overwrite that address** with shellcode via `/proc/$pid/mem` (can modify unwritable pages)

5. **Pass the target program** via stdin (shellcode reads it)

6. **Let the loader complete** the execution (loads libraries, jumps to program)

## Usage

### Basic Example

```bash
# Using dd as the seeker (default)
ddexec.sh ls -l <<< $(base64 -w0 /bin/ls)

# Using tail as the seeker
SEEKER=tail bash ddexec.sh ls -l <<< $(base64 -w0 /bin/ls)

# Using cmp as the seeker
SEEKER=cmp bash ddexec.sh ls -l <<< $(base64 -w0 /bin/ls)
```

### Custom Seeker

If you have another tool that can seek through files:

```bash
SEEKER=xxd SEEKER_ARGS='-s $offset' zsh ddexec.sh ls -l <<< $(base64 -w0 /bin/ls)
```

### Available Seekers

The script supports these tools for seeking through `/proc/$pid/mem`:
- `dd` (default)
- `tail`
- `hexdump`
- `cmp`
- `xxd`

## Tools

The primary tool for this technique is [DDexec](https://github.com/arget13/DDexec) by arget13.

## Limitations

- Requires access to `/proc/$pid/mem` (permission restrictions apply - typically root or process owner)
- ASLR must be accounted for (use `/proc/$pid/maps`)
- Not all processes are suitable targets (need writable+executable regions)
- May be detected by EDRs monitoring `/proc` access patterns
- Requires specific tools to be available on the target system

## Security Considerations

- **Only use on systems you own or have explicit authorization to test**
- This technique can be detected by security monitoring
- EDRs may flag `/proc/$pid/mem` access patterns
- Consider the ethical implications of your testing
- Document your testing and get proper authorization

## Detection Evasion

EDRs can block this technique by:
- Monitoring `/proc/$pid/mem` access
- Tracking unusual file descriptor inheritance patterns
- Detecting shellcode injection patterns
- Monitoring for base64-encoded binary execution

## References

- [DDexec GitHub](https://github.com/arget13/DDexec)
- [HackTricks - DDexec](https://book.hacktricks.xyz/linux-hardening/bypass-bash-restrictions/bypass-fs-protections-read-only-no-exec-distroless)
