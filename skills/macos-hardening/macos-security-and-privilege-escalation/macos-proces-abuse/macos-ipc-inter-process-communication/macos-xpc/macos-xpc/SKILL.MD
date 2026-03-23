---
name: macos-xpc-analysis
description: Analyze macOS XPC (XNU inter-Process Communication) services for security research, privilege escalation assessment, and vulnerability discovery. Use this skill whenever the user needs to enumerate XPC services, analyze XPC plist configurations, understand XPC communication patterns, create XPC test clients/servers, or investigate potential XPC-based privilege escalation vectors on macOS systems. Make sure to use this skill for any macOS security assessment involving inter-process communication, launchd services, or privilege separation analysis.
---

# macOS XPC Analysis Skill

A comprehensive skill for analyzing macOS XPC (XNU inter-Process Communication) services for security research and privilege escalation assessment.

## When to Use This Skill

Use this skill when you need to:
- Enumerate XPC services on a macOS system
- Analyze XPC plist configurations for security issues
- Understand XPC communication patterns and message flows
- Create test XPC clients or servers for research
- Investigate potential XPC-based privilege escalation vectors
- Audit privilege separation in macOS applications
- Sniff or monitor XPC communications
- Analyze Remote XPC configurations

## Core Concepts

### What is XPC?

XPC (XNU inter-Process Communication) is Apple's framework for **safe, asynchronous method calls between processes** on macOS and iOS. It enables:

1. **Security**: Privilege-separated applications where each component runs with only necessary permissions
2. **Stability**: Isolated crashes that don't affect the entire system
3. **Performance**: Easy concurrency through process-level parallelism

### XPC Service Types

#### Application-Specific XPC Services
- Located inside applications: `/Applications/<App>.app/Contents/XPCServices/`
- Extension: `.xpc` (bundle format)
- Only accessible by the parent application
- Example: `/Applications/Safari.app/Contents/XPCServices/com.apple.Safari.SandboxBroker.xpc/`

#### System-Wide XPC Services
- Accessible to all users
- Defined in plist files in:
  - `/System/Library/LaunchDaemons/`
  - `/Library/LaunchDaemons/`
  - `/System/Library/LaunchAgents/`
  - `/Library/LaunchAgents/`
- **Critical**: LaunchDaemons run as root - unprivileged processes communicating with these could escalate privileges

### Key Plist Configuration

```xml
<dict>
    <key>Label</key>
    <string>com.example.service</string>
    <key>MachServices</key>
    <dict>
        <key>com.example.service</key>
        <true/>
    </dict>
    <key>Program</key>
    <string>/path/to/binary</string>
    <key>ServiceType</key>
    <string>System</string>
    <key>_AllowedClients</key>
    <array>
        <string>com.example.client</string>
    </array>
</dict>
```

**Important Keys:**
- `MachServices`: Service name for XPC connections
- `ServiceType`: Application, User, System, or _SandboxProfile
- `_AllowedClients`: Entitlements or IDs required to connect
- `JoinExistingSession`: If true, runs in same security session as caller

## Security Analysis Workflow

### Step 1: Enumerate XPC Services

Use the enumeration script to find all XPC services:

```bash
# Run from skill directory
./scripts/enumerate_xpc_services.sh
```

This searches:
- Application XPCServices directories
- LaunchDaemons and LaunchAgents plists
- System and user-level locations

### Step 2: Analyze Service Configuration

For each service of interest:

```bash
# Analyze a specific plist
./scripts/analyze_xpc_plist.sh /path/to/service.plist
```

The analyzer checks for:
- Missing client restrictions (`_AllowedClients`)
- Root-owned services accessible to unprivileged users
- `JoinExistingSession` configuration
- Program path security (world-writable, symlink risks)
- Sandbox profile presence

### Step 3: Test XPC Communication

Create test clients to probe service behavior:

```bash
# C-based client
./scripts/create_xpc_client.sh <service-name>

# Objective-C based client
./scripts/create_xpc_client_oc.sh <service-name>
```

### Step 4: Monitor XPC Traffic

Use XPC sniffing tools:

```bash
# Using xpcspy (requires Frida)
xpcspy -U -r -W <bundle-id>
xpcspy -U <prog-name> -t 'i:com.apple.*' -t 'o:com.apple.*' -r

# Using XPoCe2
# Download from: https://newosxbook.com/tools/XPoCe2.html
```

## Common Vulnerability Patterns

### 1. Missing Client Authorization

**Issue**: System-wide XPC service without `_AllowedClients` restriction

**Impact**: Any process can connect, potentially executing privileged operations

**Detection**:
```bash
grep -r "MachServices" /Library/LaunchDaemons/*.plist | grep -v "_AllowedClients"
```

### 2. JoinExistingSession Misconfiguration

**Issue**: XPC service with `JoinExistingSession` set to true

**Impact**: Service runs in caller's security context, bypassing privilege separation

**Detection**:
```bash
grep -r "JoinExistingSession" /Applications/*/Contents/XPCServices/*.xpc/Contents/Info.plist
```

### 3. World-Writable Program Path

**Issue**: XPC service binary in world-writable location

**Impact**: Attacker can replace binary and execute arbitrary code with service privileges

**Detection**:
```bash
# Check program paths from plists
find /Library/LaunchDaemons -name "*.plist" -exec grep -H "Program" {} \;
```

### 4. Input Validation Issues

**Issue**: XPC service doesn't validate incoming message types or content

**Impact**: Type confusion, buffer overflows, or logic bypass

**Detection**: Requires code review or fuzzing

## XPC Object Types

| Type | Description |
|------|-------------|
| `xpc_object_t` | Base type for all XPC messages |
| `xpc_pipe` | FIFO pipe for process communication |
| `NSXPC*` | Objective-C high-level abstraction |
| `xpc_dictionary` | Key-value message container |

### Message Structure

```c
// Every XPC message is a dictionary
xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
xpc_dictionary_set_string(message, "key", "value");

// Type checking
xpc_type_t type = xpc_get_type(object);
if (type == XPC_TYPE_DICTIONARY) {
    // Process dictionary
}
```

## Remote XPC Analysis

Remote XPC allows cross-host communication via `RemoteXPC.framework`.

### Detection

```bash
# Find services using Remote XPC
grep -r "UsesRemoteXPC" /System/Library/LaunchDaemons/*.plist

# List remote services
/usr/libexec/remotectl list
/usr/libexec/remotectl show <device>
```

### Network Analysis

```bash
# Monitor XPC-related network traffic
netstat -an | grep -E "(60000|60001|60002)"
nettop -m 1 -d 1000
```

## Practical Examples

### Example 1: Analyze a Suspicious Service

```bash
# 1. Find the service
./scripts/enumerate_xpc_services.sh | grep "suspicious"

# 2. Analyze its configuration
./scripts/analyze_xpc_plist.sh /Library/LaunchDaemons/com.suspicious.service.plist

# 3. Create a test client
./scripts/create_xpc_client.sh com.suspicious.service

# 4. Test communication
./xpc_test_client
```

### Example 2: Audit All System XPC Services

```bash
# Full enumeration
./scripts/enumerate_xpc_services.sh > xpc_inventory.txt

# Analyze all LaunchDaemon plists
for plist in /Library/LaunchDaemons/*.plist; do
    ./scripts/analyze_xpc_plist.sh "$plist"
done > xpc_audit_report.txt
```

## Tools Reference

| Tool | Purpose | Installation |
|------|---------|-------------|
| `xpcspy` | XPC message sniffing | `pip3 install xpcspy` |
| `XPoCe2` | XPC port enumeration | Download from newosxbook.com |
| `supraudit` | Audit XPC proxy actions | Built-in macOS |
| `remotectl` | Remote XPC management | Built-in macOS |

## Best Practices

1. **Always check `_AllowedClients`** - System services should restrict who can connect
2. **Verify program paths** - Ensure binaries aren't in writable locations
3. **Review `JoinExistingSession`** - Understand privilege implications
4. **Test with unprivileged accounts** - Verify actual access restrictions
5. **Monitor with xpcspy** - Understand message flows before exploitation
6. **Check for sandbox profiles** - `_SandboxProfile` provides additional isolation

## Limitations

- Requires macOS system access for enumeration
- Some services may require elevated privileges to analyze
- XPC message formats are application-specific
- Remote XPC requires network access to target devices

## References

- [Apple XPC Documentation](https://developer.apple.com/documentation/xpc)
- [XPC Security Best Practices](https://developer.apple.com/library/archive/documentation/Security/Conceptual/Security_Overview/Articles/SecureCodingBestPractices.html)
- [xpcspy GitHub](https://github.com/hot3eed/xpcspy)
- [XPoCe2 Tool](https://newosxbook.com/tools/XPoCe2.html)
