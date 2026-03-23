---
name: blobrunner
description: How to use Blobrunner to load and execute shellcode/blobs in memory for reverse engineering and malware analysis. Use this skill whenever the user needs to execute raw shellcode, analyze PE files, run binary blobs in memory, or debug shellcode execution. Also use when the user mentions shellcode execution, memory-based code execution, or needs to run compiled binaries without traditional loading.
---

# Blobrunner

Blobrunner is a C program that loads binary files (shellcode, PE files, or raw blobs) into memory and executes them. It's useful for reverse engineering, malware analysis, and shellcode testing.

## What Blobrunner Does

1. **Reads a binary file** from disk
2. **Allocates executable memory** using `VirtualAlloc`
3. **Copies the file contents** into that memory
4. **Executes the code** at a specified offset

This bypasses traditional file execution, making it valuable for:
- Testing shellcode without creating executable files
- Analyzing malware behavior in a controlled environment
- Running PE files in memory for debugging
- Reverse engineering exercises

## Compilation

### Prerequisites
- Visual Studio Code with C/C++ extension
- MinGW-w64 or Visual Studio compiler (Windows)

### Steps

1. Create a new C/C++ project in VS Code
2. Copy the source code from `references/blobrunner.c`
3. Build the project

**Note:** The only modification from the original code is line 10 (Windows header inclusion).

## Usage

```bash
blobrunner.exe <inputfile> [options]
```

### Required Arguments

- `<inputfile>`: Path to the binary file to load and execute

### Optional Arguments

| Flag | Description |
|------|-------------|
| `--offset <offset>` | The offset within the file to jump to (hex or decimal) |
| `--nopause` | Don't pause before executing (dangerous - use with caution) |
| `--jit` | Force an exception by removing EXECUTE permission from allocated memory |
| `--debug` | Enable verbose logging |
| `--version` | Print version and exit |

### Examples

**Basic execution:**
```bash
blobrunner.exe shellcode.bin
```

**Execute at specific offset:**
```bash
blobrunner.exe malware.exe --offset 0x1000
```

**Run without pause (for automation):**
```bash
blobrunner.exe payload.bin --nopause
```

**Trigger JIT exception for debugging:**
```bash
blobrunner.exe shellcode.bin --jit
```

**Verbose debugging:**
```bash
blobrunner.exe sample.bin --debug --offset 0x401000
```

## How It Works

### Memory Allocation

Blobrunner uses `VirtualAlloc` with these flags:
- `0x3000` = `MEM_COMMIT | MEM_RESERVE`
- `0x40` = `PAGE_EXECUTE_READWRITE`

This creates executable memory where the binary is loaded.

### Execution Methods

**32-bit:**
- Uses inline assembly `jmp shell_entry` to jump directly to the code

**64-bit:**
- Creates a suspended thread with `CreateThread`
- Allows you to set breakpoints before resuming
- Resumes with `ResumeThread`

### JIT Mode

When `--jit` is used:
1. Memory is allocated as executable
2. First byte's execute permission is removed with `VirtualProtect`
3. This triggers an exception when execution reaches that point
4. Useful for debugging and analysis

## Safety Warnings

⚠️ **Use with extreme caution:**

- **Only run trusted binaries** - Malicious code will execute with your privileges
- **Use in a VM or sandbox** - Never run unknown binaries on your main system
- **Understand the code** - Review the source before using
- **`--nopause` is dangerous** - Execution happens immediately without warning

## Common Use Cases

### 1. Shellcode Testing
```bash
# Test shellcode without creating an executable file
blobrunner.exe shellcode.bin --debug
```

### 2. PE File Analysis
```bash
# Load a PE file and jump to its entry point
blobrunner.exe suspicious.exe --offset 0x1000 --debug
```

### 3. Malware Analysis
```bash
# Run malware in memory with JIT exception for debugging
blobrunner.exe malware.bin --jit --debug
```

### 4. Offset Discovery
```bash
# Test different offsets to find the correct entry point
blobrunner.exe blob.bin --offset 0x0
blobrunner.exe blob.bin --offset 0x100
blobrunner.exe blob.bin --offset 0x200
```

## Troubleshooting

### "Unable to open file"
- Check the file path is correct
- Ensure the file exists and is readable
- Try using absolute paths

### "Error Creating thread" (64-bit)
- Run as administrator if needed
- Check if the binary is valid
- Verify the offset is within file bounds

### Nothing happens after execution
- The code may have exited silently
- Use `--debug` for more information
- Check if the code requires specific conditions

## Source Code Reference

The complete source code is available in `references/blobrunner.c`. Key sections:

- `process_file()`: Reads file and allocates memory
- `execute()`: Handles execution (different for 32/64-bit)
- `main()`: Parses arguments and orchestrates execution

## Related Tools

- **x64dbg/x32dbg**: For detailed debugging
- **Process Hacker**: For monitoring memory allocations
- **Cuckoo Sandbox**: For automated malware analysis
- **Ghidra**: For static analysis before execution

## Next Steps

1. **Compile the tool** following the steps above
2. **Start with simple shellcode** to test basic functionality
3. **Use a VM** for any unknown binaries
4. **Enable debug mode** when learning
5. **Review the source code** to understand the mechanics

---

**Remember:** This tool executes arbitrary code in memory. Always use it responsibly and in appropriate environments.
