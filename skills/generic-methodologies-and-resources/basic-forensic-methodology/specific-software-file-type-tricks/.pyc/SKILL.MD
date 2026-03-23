---
name: python-binary-decompiler
description: Decompile Python binaries (.exe, ELF) and extract .pyc bytecode to recover source code. Use this skill whenever the user mentions Python executables, .pyc files, PyInstaller, py2exe, decompiling Python, reverse engineering Python binaries, extracting code from compiled Python, or analyzing obfuscated Python (Pyarmor). Trigger even if they don't explicitly say "decompile" — if they have a Python binary and want to understand what it does, this skill applies.
---

# Python Binary Decompiler

A forensic skill for extracting and decompiling Python bytecode from compiled executables.

## When to Use This Skill

Use this skill when:
- You have a Python-compiled binary (`.exe`, ELF) and need to extract the source code
- You have `.pyc` files that need decompilation
- You're analyzing malware or suspicious Python executables
- You need to reverse engineer PyInstaller or py2exe packages
- You're dealing with Pyarmor-protected Python code
- The user asks about "unpacking", "decompiling", or "extracting" Python code from binaries

## Quick Start

```bash
# For ELF binaries (Linux)
pyi-archive_viewer <binary>  # Extract .pyc files

# For Windows .exe
python pyinstxtractor.py <executable.exe>  # Extract .pyc files

# Decompile .pyc to source
uncompyle6 <file.pyc> > decompiled.py
```

## Workflow Overview

1. **Identify the binary type** (ELF, Windows exe, PyInstaller, py2exe)
2. **Extract .pyc bytecode** from the binary
3. **Fix magic number issues** if decompilation fails
4. **Decompile to Python source** using appropriate tools
5. **Handle obfuscation** (Pyarmor, custom encryption) if present

---

## Step 1: Extract .pyc from Compiled Binary

### From ELF Binary (Linux)

Use `pyi-archive_viewer` to list and extract embedded Python modules:

```bash
pyi-archive_viewer <binary>
```

This outputs a list of modules with their offsets. To extract a specific module:

```bash
# View the archive
pyi-archive_viewer binary_name

# Extract to .pyc file
# The tool will prompt for output filename
? X binary_name
to filename? /tmp/binary.pyc
```

### From Windows .exe (PyInstaller/Py2exe)

Use `pyinstxtractor.py`:

```bash
python pyinstxtractor.py executable.exe
```

This extracts all embedded files including `.pyc` bytecode to a directory.

### Using python-exe-unpacker (Automated)

The [python-exe-unpacker](https://github.com/countercept/python-exe-unpacker) tool combines multiple extraction methods:

```bash
# Basic unpacking
python python_exe_unpack.py <executable>

# With prepend option for incomplete bytecode
python python_exe_unpack.py -p <path-to-extracted-file>
```

---

## Step 2: Decompile .pyc to Python Source

### Using uncompyle6

```bash
uncompyle6 binary.pyc > decompiled.py
```

**Important**: The file must have a `.pyc` extension for uncompyle6 to work.

### Using pycdc (Python 3.11+)

```bash
pycdc -c -v 3.11.5 file.pyc > output.py
```

### Using PyLingual

```bash
pylingual file.pyc > output.py
```

---

## Step 3: Fix Magic Number Errors

### Error: Unknown magic number

If you see:
```
Unknown magic number 227 in /tmp/binary.pyc
```

The `.pyc` file is missing or has an incorrect magic header. Fix it:

### Get the correct magic number

```python
import imp
print(imp.get_magic().hex())
```

For Python 3.8, this outputs: `550d0d0a`

### Add the magic header

Use the helper script:

```bash
python scripts/fix_pyc_magic.py <file.pyc> <python-version>
```

Or manually with `printf`:

```bash
# For Python 3.8 (magic: 0x550d0d0a)
printf '\x0d\x55\x0a\x0d\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00' > fixed.pyc
cat original.pyc >> fixed.pyc
```

Verify the fix:

```bash
hexdump fixed.pyc | head
# Should show: 0d55 0a0d 0000 0000 0000 0000 0000 0000
```

---

## Step 4: Analyze Python Assembly (Fallback)

If decompilation fails, disassemble the bytecode directly:

```bash
python scripts/disassemble_pyc.py <file.pyc>
```

This uses Python's `dis` module to show the bytecode instructions:

```python
import dis
import marshal
import struct
import imp

with open('file.pyc', 'rb') as f:
    magic = f.read(4)
    timestamp = f.read(4)
    code = f.read()

# Unmarshal and disassemble
code_obj = marshal.loads(code)
dis.dis(code_obj)
```

---

## Step 5: Handle Pyarmor Obfuscation

Pyarmor adds encryption and obfuscation. Use the helper script:

```bash
python scripts/parse_pyarmor_header.py <binary>
```

### Pyarmor Header Structure

| Offset | Size | Description |
|--------|------|-------------|
| 0x00 | 4 | Signature `PY<license>` |
| 0x09 | 1 | Python major version |
| 0x0a | 1 | Python minor version |
| 0x09 | 1 | Protection type (0x09=BCC enabled, 0x08=otherwise) |
| 0x1c | 8 | ELF start offset |
| 0x38 | 8 | ELF end offset |
| 0x24-0x27 | 4 | AES-CTR nonce (part 1) |
| 0x2c-0x33 | 8 | AES-CTR nonce (part 2) |

### Decrypting Pyarmor Code

1. **Identify encrypted regions**: Look for `LOAD_CONST __pyarmor_enter_*__` ... `LOAD_CONST __pyarmor_exit_*__`
2. **Extract the runtime key** (e.g., `273b1b1373cf25e054a61e2cb8a947b8`)
3. **Derive per-region nonce**: XOR payload-specific key with `__pyarmor_exit_*__` marker bytes
4. **Decrypt with AES-128-CTR**

### Decrypting Mixed Strings

Constants prefixed with `0x81` are AES-128-CTR encrypted. Use the same key with the string nonce (e.g., `692e767673e95c45a1e6876d`).

### BCC Mode

If `--enable-bcc` was used:
- Functions are compiled to a companion ELF
- Python stubs call `__pyarmor_bcc_*__`
- Map constants to ELF symbols using `bcc_info.py`
- Analyze the ELF at reported offsets

---

## Common Issues and Solutions

### ImportError: File doesn't exist

```
ImportError: File name: 'unpacked/malware_3.exe/__pycache__/archive.cpython-35.pyc' doesn't exist
```

**Solution**: Use the prepend option:
```bash
python python_exe_unpack.py -p unpacked/malware_3.exe/archive
```

### co_code should be NoneType

```
class 'AssertionError'>; co_code should be one of the types (<class 'str'>, <class 'bytes'>, <class 'list'>, <class 'tuple'>); is type <class 'NoneType'>
```

**Solution**: The magic number is incorrect. Try a different Python version's magic number.

### Partial decompilation

If only some modules decompile:
- Check if different modules use different Python versions
- Try multiple decompilers (uncompyle6, pycdc, PyLingual)
- Use AST walking for specific constants: `ast.NodeVisitor`

---

## Helper Scripts

### `scripts/fix_pyc_magic.py`

Fixes magic number issues in .pyc files:

```bash
python scripts/fix_pyc_magic.py file.pyc 3.8
```

### `scripts/disassemble_pyc.py`

Disassembles .pyc to bytecode instructions:

```bash
python scripts/disassemble_pyc.py file.pyc
```

### `scripts/parse_pyarmor_header.py`

Parses Pyarmor headers and extracts encryption parameters:

```bash
python scripts/parse_pyarmor_header.py binary
```

---

## References

- [How to decompile any Python binary](https://blog.f-secure.com/how-to-decompile-any-python-binary/)
- [VVS Discord Stealer Using Pyarmor](https://unit42.paloaltonetworks.com/vvs-stealer/)
- [Protecting a Python codebase](https://bits.theorem.co/protecting-a-python-codebase/)
- [python-exe-unpacker](https://github.com/countercept/python-exe-unpacker)
