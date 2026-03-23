---
name: binary-exploitation-core-dumps
description: How to enable and analyze core dump files for binary exploitation debugging and crash analysis. Use this skill whenever the user mentions core dumps, crash analysis, GDB debugging, binary exploitation, reverse engineering, or needs to investigate why a program crashed. Make sure to use this skill when working with CTF challenges, security research, or any situation where understanding a program's crash state is important.
---

# Binary Exploitation: Core Dumps & Crash Analysis

This skill helps you enable core dump generation and analyze crash dumps using GDB for binary exploitation and debugging.

## What are Core Files?

Core files are memory snapshots created when a process crashes. They capture:
- The process's memory state
- Register values
- Program counter (instruction pointer)
- Stack contents
- All variables at the time of crash

This is invaluable for understanding **why** a program crashed and **where** in the code the crash occurred.

## Enabling Core Dump Generation

### Quick Enable (Current Session)

```bash
ulimit -c unlimited
```

This allows unlimited core file size for the current shell session. **Note:** This is not persistent across reboots or new terminal sessions.

### Verify Core Dump is Enabled

```bash
ulimit -c
```

If it returns `unlimited` or a large number, core dumps are enabled. If it returns `0`, they're disabled.

### Persistent Configuration (System-Wide)

To make core dumps permanent across reboots:

1. Edit `/etc/security/limits.conf`
2. Add this line:
   ```
   * soft core unlimited
   ```
3. Reboot or re-login for changes to take effect

### Core File Location

Core files are typically saved in:
- Current working directory (default on many systems)
- `/var/crash/` (systemd-based systems)
- Custom path via `/proc/sys/kernel/core_pattern`

Check the pattern:
```bash
cat /proc/sys/kernel/core_pattern
```

## Analyzing Core Files with GDB

### Basic Analysis

```bash
gdb /path/to/executable /path/to/core_file
```

This loads both the executable and the crash snapshot into GDB.

### Essential GDB Commands for Crash Analysis

Once in GDB:

```gdb
# See where the crash occurred
bt
# or
bt full

# Examine the instruction that caused the crash
x/10i $pc
# or
x/10i $rip

# View register values
info registers

# Examine the stack
x/20gx $sp
# or
x/20gx $rsp

# Look at specific memory addresses
x/16wx 0x7fffffffe000

# Examine variables (if debug symbols exist)
print variable_name

# Disassemble the current function
disas

# Set a breakpoint and continue (if you want to step through)
break function_name
continue
```

### Common Crash Scenarios

#### Segmentation Fault (SIGSEGV)

```gdb
# Check what address caused the fault
info registers
# Look at rdi, rsi, rdx, rax for potential pointers

# Examine the faulting address
x/4wx $rdi  # or whichever register held the bad pointer
```

#### Stack Overflow

```gdb
# Check stack pointer vs base pointer
info registers
# Look at $rsp and $rbp

# Examine stack contents
x/50gx $rsp
```

#### Buffer Overflow Detection

```gdb
# Look for overwritten return addresses
x/20gx $rsp

# Check if canary was overwritten (if ASLR/stack canary enabled)
info registers
# Look for 0x0000000000000000 in stack (canary failure)
```

## Practical Workflow

### Step 1: Enable Core Dumps

```bash
ulimit -c unlimited
```

### Step 2: Run the Vulnerable Program

```bash
./vulnerable_program
# or with input
./vulnerable_program < input.txt
# or with arguments
./vulnerable_program arg1 arg2
```

### Step 3: Locate the Core File

```bash
# Find core files in current directory
ls -la core*

# Or search system-wide
find / -name "core*" -type f 2>/dev/null
```

### Step 4: Analyze with GDB

```bash
gdb ./vulnerable_program core
```

Then run the essential commands above to understand the crash.

## Tips for Binary Exploitation

1. **Always enable core dumps first** - Don't wait until after the crash
2. **Keep the executable** - You need the original binary to analyze the core
3. **Check for debug symbols** - Core analysis is much easier with symbols
4. **Look at the stack** - Most buffer overflows show up in stack memory
5. **Compare registers** - See if registers contain unexpected values
6. **Document findings** - Note the crash address, register values, and stack state

## Common Issues

### "No core file generated"

- Check `ulimit -c` - it might be 0
- Check `/proc/sys/kernel/core_pattern` - might be redirecting to a different location
- Check disk space - core dumps need space
- Check permissions - you need write access to the output directory

### "GDB can't find symbols"

- Recompile with `-g` flag: `gcc -g program.c -o program`
- Or use `strip` to check if symbols were removed

### "Core file is empty or corrupted"

- The process might have crashed before core dump could complete
- Try running with `gdb` directly instead: `gdb ./program`

## Example: Analyzing a Buffer Overflow

```bash
# Enable core dumps
ulimit -c unlimited

# Run the vulnerable program with overflow input
python3 -c "print('A'*1000)" | ./vulnerable_program

# Find and analyze the core
ls -la core*
gdb ./vulnerable_program core

# In GDB:
(gdb) bt
# Shows: #0  0x00007ffff7a23456 in __libc_start_main ()
#        #1  0x0000555555555123 in main ()

(gdb) x/20gx $rsp
# Shows stack contents - look for 'AAAA' patterns

(gdb) info registers
# Check if return address was overwritten
```

## When to Use This Skill

Use this skill when:
- A program crashes and you need to understand why
- You're working on CTF binary exploitation challenges
- You're debugging segmentation faults or other crashes
- You need to analyze buffer overflows or memory corruption
- You're doing reverse engineering and need crash state information
- You want to understand the memory state at the time of a crash
