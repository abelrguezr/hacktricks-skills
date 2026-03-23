---
name: reverse-shell-defense
description: Security education skill for understanding reverse shell techniques to improve defensive security posture. Use this skill when users ask about reverse shells, shell connections, or need to understand how attackers establish remote access for authorized security testing, incident response, or defensive hardening. This skill focuses on detection, prevention, and authorized testing only.
---

# Reverse Shell Defense & Detection

> **⚠️ AUTHORIZED USE ONLY**: This skill is for security professionals conducting authorized penetration testing, incident response, or defensive security work. Never use these techniques on systems you don't own or have explicit written permission to test.

## Overview

Reverse shells are a common technique in security assessments where a compromised system initiates a connection back to an attacker-controlled listener. Understanding these techniques is essential for:

- **Detection**: Identifying malicious activity in logs and network traffic
- **Prevention**: Hardening systems against shell-based attacks
- **Incident Response**: Recognizing and responding to active compromises
- **Authorized Testing**: Conducting legitimate penetration tests

## Common Shell Types

### Bash/Shell-Based Shells

Bash provides built-in TCP capabilities via `/dev/tcp/` that can establish reverse connections:

**Detection indicators:**
- Process spawning with `/dev/tcp/` in command line
- Unusual file descriptor redirections (`>&`, `0>&1`)
- Commands containing IP addresses and port numbers

**Prevention:**
- Monitor for `/dev/tcp/` usage in process monitoring
- Restrict bash capabilities in containers
- Use AppArmor/SELinux to limit network access

### Netcat-Based Shells

Netcat (`nc`) is frequently used for reverse shells due to its simplicity:

**Detection indicators:**
- `nc -e` or `nc -c` flags in process listings
- Netcat connecting to external IPs on unusual ports
- FIFO pipes (`mkfifo`) combined with netcat

**Prevention:**
- Remove or restrict netcat access
- Monitor for FIFO creation in `/tmp`
- Network segmentation to limit egress

### Python-Based Shells

Python reverse shells use socket and subprocess modules:

**Detection indicators:**
- Python processes with `socket`, `pty`, `subprocess` imports
- Environment variables like `RHOST`, `RPORT`
- `os.dup2()` calls in process memory

**Prevention:**
- Restrict Python execution in sensitive environments
- Monitor for socket creation in Python processes
- Use application whitelisting

### Other Languages

Reverse shells can be crafted in many languages:
- **Perl**: Uses Socket module
- **Ruby**: Uses TCPSocket
- **PHP**: Uses fsockopen or proc_open
- **Java**: Uses Runtime.exec() with bash
- **Node.js**: Uses net and child_process modules
- **Go**: Uses net and os/exec packages

## Detection Strategies

### Process Monitoring

Watch for these patterns in process listings:

```bash
# Check for suspicious shell processes
ps aux | grep -E 'nc|netcat|bash.*tcp|python.*socket'

# Look for unusual parent-child relationships
pstree -p | grep -E 'bash|sh|python'

# Monitor for /dev/tcp usage
lsof -i | grep ESTABLISHED
```

### Network Monitoring

**Egress filtering indicators:**
- Outbound connections to unknown IPs
- Connections on non-standard ports (4444, 5555, 1337, etc.)
- Long-lived TCP connections from shell processes

**Tools:**
- `tcpdump` for packet capture
- `netstat`/`ss` for connection monitoring
- IDS/IPS systems for pattern detection

### Log Analysis

**Key log sources:**
- `/var/log/auth.log` - authentication attempts
- `/var/log/syslog` - system events
- Application logs - unusual command execution
- Network logs - connection attempts

**Search patterns:**
- Commands containing IP addresses
- Shell spawning with redirections
- Unusual user activity

## Prevention Techniques

### System Hardening

1. **Principle of Least Privilege**
   - Run services with minimal permissions
   - Use dedicated service accounts
   - Restrict sudo access

2. **Network Controls**
   - Implement egress filtering
   - Use firewalls to limit outbound connections
   - Segment networks to contain breaches

3. **Application Security**
   - Validate and sanitize all inputs
   - Use parameterized queries
   - Implement proper authentication

### Container Security

```yaml
# Docker security best practices
security_opt:
  - no-new-privileges:true
  - seccomp:unconfined
read_only: true
cap_drop:
  - ALL
cap_add:
  - NET_BIND_SERVICE
```

### Monitoring & Alerting

**Set up alerts for:**
- New outbound connections to unknown destinations
- Shell processes spawned by web services
- Unusual command execution patterns
- File creation in `/tmp` with execute permissions

## Incident Response

### When You Detect a Reverse Shell

1. **Contain**
   - Isolate the affected system from the network
   - Preserve evidence (memory dump, logs)
   - Document the timeline

2. **Analyze**
   - Identify the entry point
   - Determine what data was accessed
   - Check for persistence mechanisms

3. **Eradicate**
   - Remove malicious files and processes
   - Close unauthorized access points
   - Patch the vulnerability

4. **Recover**
   - Restore from clean backups
   - Implement additional security controls
   - Monitor for re-infection

### Forensic Collection

```bash
# Capture network connections
netstat -tulpn > /evidence/connections.txt

# List all processes with full details
ps auxww > /evidence/processes.txt

# Capture open files
lsof > /evidence/open_files.txt

# Memory dump (if available)
# dd if=/dev/mem of=/evidence/memory.dump bs=1M
```

## Authorized Testing

### Setting Up a Test Environment

**Requirements:**
- Isolated network (no production systems)
- Written authorization
- Clear scope and rules of engagement
- Proper documentation

**Safe Testing Practices:**
1. Use dedicated test systems
2. Document all activities
3. Have an exit strategy
4. Report findings responsibly

### Common Test Scenarios

1. **Web Application Testing**
   - Test for RCE vulnerabilities
   - Verify WAF effectiveness
   - Check input validation

2. **Network Testing**
   - Test firewall rules
   - Verify egress filtering
   - Check IDS/IPS detection

3. **Endpoint Testing**
   - Test EDR detection
   - Verify application whitelisting
   - Check process monitoring

## References

- [OWASP Testing Guide](https://owasp.org/www-project-web-security-testing-guide/)
- [SANS Incident Response](https://www.sans.org/incident-response/)
- [MITRE ATT&CK - Command and Control](https://attack.mitre.org/tactics/TA0011/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)

## Legal & Ethical Considerations

**Always ensure:**
- Written authorization before any testing
- Clear scope and boundaries
- Compliance with applicable laws
- Responsible disclosure of findings
- Protection of sensitive data

**When in doubt:**
- Consult with legal counsel
- Get explicit written permission
- Document all activities
- Report findings through proper channels
