---
name: macos-apple-events
description: How to understand and analyze Apple Events on macOS for security research and privilege escalation. Use this skill whenever the user needs to investigate interprocess communication on macOS, analyze Apple Event permissions, debug Apple Event messages, or understand how applications communicate via the Apple Event Manager. Trigger this skill for any macOS security analysis involving application communication, sandbox escape research, or privilege escalation through Apple Events.
---

# macOS Apple Events Analysis

A skill for understanding and analyzing Apple Events on macOS systems, particularly for security research and privilege escalation scenarios.

## What are Apple Events?

Apple Events are a macOS feature that allows applications to communicate with each other through the **Apple Event Manager**. This system enables one application to send messages to another to request operations like:

- Opening files
- Retrieving data
- Executing commands
- Activating applications

## Core Components

### The Apple Events Daemon

The central daemon managing Apple Events is:

```
/System/Library/CoreServices/appleeventsd
```

This daemon registers the service `com.apple.coreservices.appleevents`.

### How It Works

1. Every application that can receive events registers with the daemon, providing its Apple Event Mach Port
2. When an app wants to send an event, it requests the target app's port from the daemon
3. The daemon facilitates the connection between sender and receiver

## Sandboxed Application Privileges

Sandboxed applications require specific privileges to send Apple Events:

### Required Entitlements

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.temporary-exception.apple-events</key>
<array>
    <string>com.example.target-app</string>
</array>
```

### Required Sandbox Profile Permissions

```bash
allow appleevent-send
allow mach-lookup (global-name "com.apple.coreservices.appleevents")
```

### Private Entitlements

Some scenarios require private entitlements like `com.apple.private.appleevents` for broader access.

## Debugging Apple Events

### Enable Apple Event Debug Logging

Use the `AEDebugSends` environment variable to log information about messages being sent:

```bash
AEDebugSends=1 osascript -e 'tell application "iTerm" to activate'
```

This will output detailed information about the Apple Event being sent, including:
- Event type and ID
- Target application
- Parameters and data being transmitted

### Common Debug Commands

```bash
# Debug a simple activation event
AEDebugSends=1 osascript -e 'tell application "Finder" to activate'

# Debug file opening
AEDebugSends=1 osascript -e 'tell application "TextEdit" to open file "/path/to/file.txt"'

# Debug with verbose output
AEDebugSends=1 osascript -e 'tell application "System Events" to get name of every process'
```

## Security Considerations

### Privilege Escalation Vectors

Apple Events can be a privilege escalation vector when:

1. A privileged application accepts Apple Events from unprivileged senders
2. The privileged application performs actions based on event parameters without proper validation
3. Sandboxed applications can send events to privileged processes through Mach port lookups

### Analysis Checklist

When investigating Apple Events for security:

- [ ] Identify which applications register for Apple Events
- [ ] Check sandbox profiles for `appleevent-send` permissions
- [ ] Review entitlements for `com.apple.security.temporary-exception.apple-events`
- [ ] Test if privileged applications respond to Apple Events from unprivileged contexts
- [ ] Use `AEDebugSends` to trace event flows
- [ ] Examine `/System/Library/CoreServices/appleeventsd` for configuration

### Common Targets

Applications that commonly accept Apple Events and may be worth investigating:

- System applications (Finder, System Events)
- Terminal emulators (iTerm, Terminal)
- Text editors (TextEdit, VS Code)
- Browser applications
- Automation tools (Automator, Script Editor)

## Practical Usage

### Querying Running Applications

```bash
# List all applications that can receive Apple Events
osascript -e 'tell application "System Events" to get name of every application process'
```

### Sending Test Events

```bash
# Activate an application
osascript -e 'tell application "AppName" to activate'

# Check if an application responds to Apple Events
osascript -e 'tell application "AppName" to get name'
```

### Monitoring Apple Event Traffic

```bash
# Enable debug logging and monitor
export AEDebugSends=1
# Then run your test commands
```

## Related macOS Security Topics

- TCC (Transparency, Consent, and Control) database
- Sandbox entitlements and profiles
- Mach port security
- Interprocess communication mechanisms
- Privilege escalation through IPC

## References

- Apple Event Manager documentation
- macOS Sandbox documentation
- Apple Event debugging tools
- Security research on macOS IPC mechanisms
