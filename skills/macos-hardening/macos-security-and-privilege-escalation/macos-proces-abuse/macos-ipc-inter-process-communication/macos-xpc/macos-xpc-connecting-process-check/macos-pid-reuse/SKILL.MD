---
name: macos-xpc-pid-reuse-audit
description: Audit macOS XPC services for PID reuse vulnerabilities. Use this skill whenever you need to analyze XPC connection code, review process authentication patterns, identify race condition risks in macOS IPC, or harden XPC services against PID-based authentication attacks. Trigger this skill for any macOS security audit involving XPC, process verification, or inter-process communication security.
---

# macOS XPC PID Reuse Vulnerability Audit

This skill helps security researchers and developers identify and remediate PID reuse vulnerabilities in macOS XPC services.

## Understanding the Vulnerability

### What is PID Reuse?

When a macOS XPC service authenticates callers by checking the **Process ID (PID)** instead of the **audit token**, it's vulnerable to a race condition attack. An attacker can:

1. Send a malicious XPC message to the service
2. Immediately execute `posix_spawn()` with an authorized binary
3. The authorized binary inherits the same PID
4. The XPC service checks the PID **after** `posix_spawn()` and incorrectly authenticates the malicious message

### Why Audit Tokens Matter

Audit tokens are kernel-level identifiers that cannot be reused or forged. PIDs are recycled and can be manipulated through race conditions. Always prefer audit token verification over PID checks.

## Identifying Vulnerable Code

### Red Flags in XPC Connection Code

Look for these patterns in `shouldAcceptNewConnection` or connection validation methods:

```objectivec
// VULNERABLE: Using processIdentifier (PID)
- (BOOL)shouldAcceptNewConnection:(NSXPCConnection *)newConnection {
    pid_t pid = newConnection.processIdentifier;
    return (pid == expected_pid);  // ❌ Vulnerable to PID reuse
}

// SECURE: Using auditToken
- (BOOL)shouldAcceptNewConnection:(NSXPCConnection *)newConnection {
    audit_token_t token;
    newConnection.getAuditToken(&token);
    return [self verifyAuditToken:token];  // ✅ Secure
}
```

### Common Vulnerable Patterns

1. **Direct PID comparison**
   ```objectivec
   if (connection.processIdentifier == kExpectedPID) { ... }
   ```

2. **PID stored in whitelist**
   ```objectivec
   if ([allowedPIDs containsObject:@(connection.processIdentifier)]) { ... }
   ```

3. **PID used for authorization decisions**
   ```objectivec
   AuthorizationRef authRef;
   AuthorizationCreate(NULL, NULL, kAuthorizationEmptyFlags, &authRef);
   // Using PID instead of audit token for auth
   ```

## Audit Checklist

### 1. Connection Validation

- [ ] Does `shouldAcceptNewConnection` use `processIdentifier`?
- [ ] Is there any PID-based authentication logic?
- [ ] Are audit tokens being retrieved and verified?

### 2. XPC Service Configuration

- [ ] Is the service using `NSXPCConnectionPrivileged`?
- [ ] Are connection options properly configured?
- [ ] Is there proper error handling for connection failures?

### 3. Process Verification

- [ ] Are authorized processes verified by audit token?
- [ ] Is there a secure allowlist of authorized callers?
- [ ] Are there fallback mechanisms if token verification fails?

### 4. Race Condition Analysis

- [ ] Is there any time gap between message receipt and verification?
- [ ] Could `posix_spawn` be exploited in the verification window?
- [ ] Are there any synchronous operations that could be manipulated?

## Remediation Guide

### Secure XPC Connection Pattern

```objectivec
- (BOOL)shouldAcceptNewConnection:(NSXPCConnection *)newConnection {
    // Get the audit token from the connection
    audit_token_t token;
    if (!newConnection.getAuditToken(&token)) {
        return NO;
    }
    
    // Verify the audit token against authorized processes
    return [self isAuthorizedAuditToken:token];
}

- (BOOL)isAuthorizedAuditToken:(audit_token_t)token {
    // Use security framework to verify the token
    // Check code signature, entitlements, or other secure attributes
    // Never rely on PID alone
    return YES; // Replace with actual verification logic
}
```

### Using Security Framework for Token Verification

```objectivec
#import <Security/Security.h>

- (BOOL)verifyAuditToken:(audit_token_t)token {
    // Get the process serial number from the audit token
    task_port_t task = mach_task_self();
    
    // Use task_for_pid or other secure methods to verify
    // This is a simplified example - implement proper verification
    return YES;
}
```

## Testing for Vulnerabilities

### Static Analysis

1. Search for `processIdentifier` in XPC connection code
2. Look for PID comparisons in `shouldAcceptNewConnection`
3. Check for any PID-based authorization logic
4. Review XPC service configuration files

### Dynamic Analysis

1. Monitor XPC connections with `dtrace` or `osxtrace`
2. Check if the service accepts connections from unexpected processes
3. Verify audit token handling in the connection flow

## Security Best Practices

1. **Always use audit tokens** for process authentication in XPC
2. **Never trust PIDs** for security-critical decisions
3. **Implement proper code signature verification** for authorized callers
4. **Use entitlements** to restrict XPC service access
5. **Log all connection attempts** for security monitoring
6. **Fail securely** - deny access if verification fails

## References

- [Wojciech Regula - Learn XPC Exploitation Part 2: Say No to the PID](https://wojciechregula.blog/post/learn-xpc-exploitation-part-2-say-no-to-the-pid/)
- [Saelo - Don't Trust the PID (WARCON 2018)](https://saelo.github.io/presentations/warcon18_dont_trust_the_pid.pdf)
- [Apple - NSXPCConnection Documentation](https://developer.apple.com/documentation/foundation/nsxpcconnection)
- [Apple - Security Programming Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/SecurityProgrammingGuide/)

## When to Use This Skill

Use this skill when:
- Auditing macOS applications for XPC security vulnerabilities
- Reviewing XPC service code for proper authentication
- Hardening macOS applications against privilege escalation
- Investigating potential PID reuse attacks
- Learning about macOS IPC security best practices
- Preparing security assessments for macOS software

## Limitations

- This skill provides educational and auditing guidance only
- Actual exploitation requires specific conditions and should only be performed in authorized security research
- Always obtain proper authorization before testing systems
- Follow responsible disclosure practices when reporting vulnerabilities
