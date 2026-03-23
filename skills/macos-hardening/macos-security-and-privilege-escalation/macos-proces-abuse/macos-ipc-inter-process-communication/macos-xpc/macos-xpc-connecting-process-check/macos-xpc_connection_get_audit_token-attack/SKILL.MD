---
name: macos-xpc-audit-token-spoofing
description: macOS XPC audit token spoofing vulnerability research and exploitation. Use this skill whenever the user mentions XPC, audit tokens, macOS privilege escalation, IPC vulnerabilities, Mach ports, xpc_connection_get_audit_token, or any macOS inter-process communication security issues. This skill helps identify, analyze, and understand XPC audit token race condition vulnerabilities including the two main variants: async audit token checks and reply forwarding attacks.
---

# macOS XPC Audit Token Spoofing

A skill for researching and understanding XPC audit token spoofing vulnerabilities on macOS. This covers the race condition class of bugs where an attacker can manipulate which process's audit token is used during authorization checks.

## Core Concepts

### Mach Messages
- Mach ports are **single receiver, multiple sender** communication channels
- Multiple processes can send messages to a mach port, but only one can read from it
- Ports are kernel-managed integers that processes use to communicate

### XPC Connection Audit Tokens
- XPC's abstraction is **one-to-one connection**, but built on Mach's **multiple sender** technology
- An XPC connection's audit token is **copied from the most recently received message**
- Audit tokens are critical for security checks and authorization decisions

### The Vulnerability
The core issue: **XPC connections can have their audit token overwritten by messages from different senders** under specific timing conditions.

**Not vulnerable:**
- Checks before accepting a connection (in `-listener:shouldAcceptNewConnection:`)
- Inside XPC event handlers (synchronous handling prevents overwrite)

**Vulnerable patterns:**
- `xpc_connection_get_audit_token` called **outside** the event handler (e.g., in `dispatch_async`)
- Reply message parsing concurrent with event handler execution

## Attack Variant 1: Async Audit Token Check

### Requirements
1. Two Mach services **A** and **B** that you can both connect to
2. Service **A** has an authorization check for an action that **B** can pass but you cannot
3. Service **A** obtains the audit token **asynchronously** (e.g., from `dispatch_async`)

### Exploitation Flow
1. Connect to service **A** (e.g., `smd`)
2. Connect to service **B** (e.g., `diagnosticd` running as root)
3. **Duplicate the send right** of your A connection and use it as B's client port
4. Messages from B are now delivered to A's connection
5. Trigger B to send messages while you request the privileged action from A
6. **Race condition**: B's audit token overwrites yours during A's authorization check

### Real-World Example: smd + diagnosticd
- **Service A**: `smd` (System Management Daemon)
- **Service B**: `diagnosticd` (runs as root, sends frequent monitoring messages)
- **Privileged action**: `SMJobBless` to install privileged helper tools as root
- **Attack**: Flood `smd` with messages while `diagnosticd` sends monitoring data, causing `smd` to use `diagnosticd`'s root audit token

## Attack Variant 2: Reply Forwarding

### Requirements
1. Two Mach services **A** and **B**
2. Service **A** sends a message expecting a reply
3. You can send a message to **B** that it will respond to

### Exploitation Flow
1. Wait for service **A** to send a message expecting a reply
2. **Hijack the reply port** instead of replying directly to A
3. Send the reply port to service **B**
4. Dispatch your privileged action request to A
5. **Race condition**: B's reply overwrites the audit token while your request is being parsed

### Key Insight
- `xpc_connection_send_message_with_reply`: processed on designated queue
- `xpc_connection_send_message_with_reply_sync`: processed on current dispatch queue
- Reply packets can be parsed **concurrently** with event handler execution
- `_xpc_connection_set_creds` locks only the audit token, not the entire connection object

## Discovery Techniques

### Static Analysis
1. Search for `xpc_connection_get_audit_token` calls
2. Look for calls reachable from `dispatch_async`/`dispatch_after` blocks
3. Find authorization helpers mixing per-connection and per-message state:
   - `xpc_connection_get_pid` (per-connection) + `xpc_connection_get_audit_token` (per-connection)
4. In NSXPC code, verify checks use per-message audit tokens

### Dynamic Analysis
Use the Frida hook script to detect vulnerable patterns:

```bash
# Run the Frida hook on a target process
frida -U -f <process-name> -l scripts/xpc-audit-token-hook.js --no-pause
```

The script flags `xpc_connection_get_audit_token` calls outside the event handler path.

### Tooling
- **gxpc**: Open-source XPC sniffer for enumerating connections and observing traffic
  ```bash
  gxpc -p <PID> --whitelist <service-name>
  ```
- **Frida**: Dynamic instrumentation for hooking XPC functions
- **IDA/Ghidra**: Static analysis of Mach service binaries
- **dyld interposing**: Log call sites and stacks during black-box testing

## Exploitation Primitives

### Multi-Sender Setup (Variant 1)
Duplicate a SEND right to route B's messages through A's connection:

```c
// Duplicate a SEND right you already hold
mach_port_t dup;
mach_port_insert_right(mach_task_self(), a_client, a_client, MACH_MSG_TYPE_MAKE_SEND);
dup = a_client; // Use `dup` when crafting B's connect packet
```

### Reply Hijack (Variant 2)
Capture the send-once right from A's pending request and use it for B's reply:

```c
// Extract reply port from A's message
mach_port_t reply_port = /* from A's message header */;

// Send to B using A's reply port
xpc_connection_send_message_with_reply(b_connection, message, reply_port);
```

## The Fix

Apple's fix for CVE-2023-32405 in `smd`:
- Replace `xpc_connection_get_audit_token` with `xpc_dictionary_get_audit_token`
- The dictionary function retrieves the audit token **directly from the mach message**
- This prevents race conditions since the token is tied to the specific message

**Note**: `xpc_dictionary_get_audit_token` is not part of the public API.

## Current Status (2024-2025)

- The issue persists in iOS 17 and macOS 14
- Apple has not implemented a broader fix (possibly due to legitimate audit token changes in `setuid` scenarios)
- Focus on authorization performed outside message event handlers or concurrently with reply processing

## References

- [Sector 7 – Don't Talk All at Once!](https://sector7.computest.nl/post/2023-10-xpc-audit-token-spoofing/)
- [Apple – macOS Ventura 13.4 Security Content (CVE-2023-32405)](https://support.apple.com/en-us/106333)

## Quick Start

To begin researching XPC audit token vulnerabilities:

1. **Identify target services** using `gxpc` or by examining Mach ports
2. **Run the Frida hook** to detect vulnerable `xpc_connection_get_audit_token` calls
3. **Analyze the call stack** to determine if the check is outside the event handler
4. **Map the authorization flow** to understand what privileges are being checked
5. **Identify a second service** (B) with higher privileges that can send messages to the target
6. **Craft the exploit** using the appropriate variant based on the vulnerability pattern
