---
name: macos-system-extensions
description: Analyze and work with macOS System Extensions including DriverKit, Network Extensions, and Endpoint Security Framework. Use this skill when investigating macOS security, analyzing system extensions, understanding endpoint security bypasses, or working with macOS kernel-level security mechanisms. Make sure to use this skill whenever the user mentions macOS security, system extensions, endpoint security, TCC permissions, or any macOS kernel/user space security architecture.
---

# macOS System Extensions

A skill for understanding and working with macOS System Extensions, including DriverKit, Network Extensions, and the Endpoint Security Framework.

## Overview

Unlike Kernel Extensions (KEXTs), **System Extensions run in user space** instead of kernel space, reducing the risk of system crashes due to extension malfunction. This is a critical architectural change in modern macOS security.

### Three Types of System Extensions

1. **DriverKit Extensions** - Hardware support drivers (USB, Serial, NIC, HID) running in user space
2. **Network Extensions** - Custom network behavior (VPN clients, packet filtering, DNS)
3. **Endpoint Security Extensions** - Security monitoring and control APIs

## DriverKit Extensions

DriverKit replaces kernel extensions for hardware support. Key characteristics:

- Runs in **user space** rather than kernel space
- Includes user space versions of I/O Kit classes
- Kernel forwards I/O Kit events to user space
- Safer environment for device drivers

**Common use cases:** USB drivers, Serial drivers, Network Interface Cards, Human Interface Devices

## Network Extensions

Network Extensions customize network behaviors. Types include:

| Type | Purpose | Traffic Level |
|------|---------|---------------|
| App Proxy | VPN client with flow-oriented protocol | Connection/flow |
| Packet Tunnel | VPN client with packet-oriented protocol | Individual packets |
| Filter Data | Monitor/modify network flows | Flow level |
| Filter Packet | Monitor/modify individual packets | Packet level |
| DNS Proxy | Custom DNS provider | DNS requests/responses |

## Endpoint Security Framework (ESF)

The Endpoint Security Framework provides APIs for security vendors to monitor and control system activity.

### Architecture

**Kernel Component:** `/System/Library/Extensions/EndpointSecurity.kext`

Key components:
- **EndpointSecurityDriver** - Entry point for kernel extension
- **EndpointSecurityEventManager** - Implements kernel hooks for system call interception
- **EndpointSecurityClientManager** - Manages user space client connections
- **EndpointSecurityMessageManager** - Sends event notifications to clients

**Monitored Event Categories:**
- File events
- Process events
- Socket events
- Kernel events (KEXT loading/unloading, I/O Kit device access)

### User-Space Communication

Communication happens through IOUserClient subclasses:

| Client Type | Entitlement Required | Typical User |
|-------------|---------------------|---------------|
| EndpointSecurityDriverClient | `com.apple.private.endpoint-security.manager` | `endpointsecurityd` system process |
| EndpointSecurityExternalClient | `com.apple.developer.endpoint-security.client` | Third-party security software |

**Key Libraries and Daemons:**
- **`libEndpointSecurity.dylib`** - C library for system extensions to communicate with kernel
- **`endpointsecurityd`** - Manages/launches endpoint security extensions during early boot
- **`sysextd`** - Validates and activates system extensions
- **`SystemExtensions.framework`** - Activates/deactivates system extensions

**Early Boot Extensions:** Only extensions marked with `NSEndpointSecurityEarlyBoot` in their `Info.plist` receive early boot treatment.

## Security Considerations

### TCC Permissions and Bypasses

Security applications using ESF require **Full Disk Access permissions**. Historically, this could be bypassed:

```bash
# Reset all TCC permissions (CVE-2021-30965)
tccutil reset All
```

**Note:** This was fixed by introducing `kTCCServiceEndpointSecurityClient` permission managed by `tccd`, which prevents `tccutil` from clearing security app permissions.

### Investigation Commands

Use these commands to investigate system extensions:

```bash
# List loaded system extensions
kextstat | grep -i extension

# Check TCC permissions
tccutil list

# Find endpoint security related files
find /System/Library/Extensions -name "*Endpoint*" 2>/dev/null

# Check for system extension daemons
ps aux | grep -E "(endpointsecurityd|sysextd)"

# View system extension preferences
defaults read /Library/Preferences/com.apple.security.endpoint-security
```

## Common Tasks

### 1. Enumerate System Extensions

```bash
# List all system extensions
kextstat | grep -E "(SystemExtension|DriverKit|NetworkExtension)"

# Check extension status
systemextensionsctl list
```

### 2. Analyze Endpoint Security Framework

```bash
# Check if ESF KEXT is loaded
kextstat | grep EndpointSecurity

# Find ESF-related processes
ps aux | grep -E "(endpointsecurity|sysextd)"

# Check ESF library
ls -la /System/Library/PrivateFrameworks/EndpointSecurity.framework/
```

### 3. Check TCC Permissions

```bash
# List all TCC permissions
tccutil list

# Check specific permission types
tccutil reset All  # WARNING: Resets all permissions
```

### 4. Investigate Network Extensions

```bash
# List network extensions
networkextension list

# Check VPN configurations
scutil --nc list
```

## References

- [OBTS v3.0: "Endpoint Security & Insecurity" - Scott Knight](https://www.youtube.com/watch?v=jaVkpM1UqOs)
- [System Extension Internals - Scott Knight](https://knight.sc/reverse%20engineering/2019/08/24/system-extension-internals.html)
- [OBTS v5.0: "The Achilles Heel of EndpointSecurity" - Fitzl Csaba](https://www.youtube.com/watch?v=lQO7tvNCoTI)

## When to Use This Skill

Use this skill when:
- Investigating macOS security architecture
- Analyzing system extensions for security testing
- Understanding endpoint security bypasses
- Working with macOS kernel/user space security mechanisms
- Enumerating or analyzing DriverKit, Network, or Endpoint Security extensions
- Researching TCC permissions and their implications
- Preparing for macOS penetration testing or red teaming

## Important Notes

- System Extensions are **user space** - this is a key security improvement over KEXTs
- ESF requires specific entitlements for different access levels
- Early boot extensions need `NSEndpointSecurityEarlyBoot` in Info.plist
- TCC permissions are critical for ESF functionality
- Always verify macOS version compatibility for specific features
