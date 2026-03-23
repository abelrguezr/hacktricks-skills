---
name: macos-xpc-security
description: macOS XPC security verification and connection hardening. Use this skill whenever you're implementing XPC services, reviewing XPC connection code, auditing macOS IPC security, or need to understand XPC authentication vulnerabilities. Trigger this for any XPC listener implementation, connection validation, audit token usage, or when checking for PID reuse attacks, certificate verification, or hardened runtime requirements.
---

# macOS XPC Security Verification

This skill helps you implement secure XPC (XPC Connection) services on macOS by ensuring proper connection verification and preventing common IPC attacks.

## When to Use This Skill

Use this skill when:
- Implementing `NSXPCListener` with `shouldAcceptNewConnection:`
- Reviewing XPC connection security in existing code
- Auditing macOS applications for IPC vulnerabilities
- Understanding XPC authentication mechanisms
- Checking for PID reuse or audit token spoofing vulnerabilities
- Implementing certificate and entitlement verification

## Core Security Checks

When a connection is established to an XPC service, the server MUST verify the connecting process. Here are the critical checks in order of importance:

### 1. Apple-Signed Certificate Verification

**Why:** Prevents attackers from creating fake certificates to bypass other checks.

**Risk if missing:** An attacker could create a fake certificate matching any other verification criteria.

### 2. Organization/Team ID Verification

**Why:** Ensures only your organization's signed binaries can connect.

**Risk if missing:** Any developer certificate from Apple can be used for signing and connecting to the service.

### 3. Bundle ID Verification

**Why:** Restricts access to specific applications within your organization.

**Risk if missing:** Any tool signed by the same organization could interact with the XPC service.

### 4. Software Version Check

**Why:** Prevents old, vulnerable clients from connecting.

**Risk if missing:** Legacy clients vulnerable to process injection could connect even with other checks in place.

### 5. Hardened Runtime Verification

**Why:** Ensures the client has protections against code injection.

**Risk if missing:** The client might be vulnerable to code injection attacks.

Check for these flags:
- `cs_hard` (0x100): Don't load invalid pages
- `cs_kill` (0x200): Kill process if page is invalid
- `cs_restrict` (0x800): Prevent debugging
- `cs_require_lv` (0x2000): Library Validation
- `cs_runtime` (0x10000): Hardened runtime enabled

### 6. Entitlement Verification (Apple Binaries)

**Why:** For Apple-signed binaries, verify they have the specific entitlement to connect.

### 7. Audit Token vs PID (CRITICAL)

**Why:** Prevents PID reuse attacks.

**Risk if missing:** Attackers can reuse PIDs to impersonate legitimate processes.

**Use:** `xpc_dictionary_get_audit_token` (secure)
**Avoid:** `xpc_connection_get_audit_token` (vulnerable in certain situations)
**Never use:** `processIdentifier` property (vulnerable to PID reuse)

## Implementation Template

### Basic Listener Setup

```objectivec
- (BOOL)listener:(NSXPCListener *)listener 
    shouldAcceptNewConnection:(NSXPCConnection *)newConnection {
    
    // CRITICAL: Implement verification here
    // Never just return YES
    return [self verifyConnection:newConnection];
}
```

### Secure Verification Implementation

```objectivec
- (BOOL)verifyConnection:(NSXPCConnection *)newConnection {
    
    // 1. Get audit token (secure method)
    // Note: auditToken is a private property - use with caution
    // For App Store apps, consider alternative verification methods
    
    SecRequirementRef requirementRef = NULL;
    
    // 2. Define verification requirements
    NSString *requirementString = 
        @"anchor apple generic "
        @"and identifier \"com.yourcompany.service\" "
        @"and certificate leaf [subject.CN] = \"YOURTEAMID\" "
        @"and info [CFBundleShortVersionString] >= \"1.0\"";
    
    // 3. Create requirement
    SecRequirementCreateWithString(
        (__bridge CFStringRef)requirementString,
        kSecCSDefaultFlags,
        &requirementRef
    );
    
    if (!requirementRef) {
        return NO;
    }
    
    // 4. Get SecTaskRef from audit token (secure)
    // This is the recommended approach over PID-based verification
    SecTaskRef taskRef = NULL;
    
    // Note: SecTaskCreateWithAuditToken requires the audit token
    // This is a private API - use carefully
    
    // 5. Validate against requirements
    OSStatus status = SecTaskValidateForRequirement(
        taskRef,
        (__bridge CFStringRef)requirementString
    );
    
    if (status != errSecSuccess) {
        CFRelease(requirementRef);
        return NO;
    }
    
    CFRelease(requirementRef);
    return YES;
}
```

### Hardened Runtime Check (Alternative to Version Check)

If you don't want to check version, at minimum verify the client isn't vulnerable to injection:

```objectivec
- (BOOL)checkHardenedRuntime:(SecCodeRef)code {
    CFDictionaryRef csInfo = NULL;
    SecCodeCopySigningInformation(
        code,
        kSecCSDynamicInformation,
        &csInfo
    );
    
    if (!csInfo) {
        return NO;
    }
    
    uint32_t csFlags = [
        ((__bridge NSDictionary *)csInfo)[
            (__bridge NSString *)kSecCodeInfoStatus
        ]
        intValue
    ];
    
    const uint32_t cs_hard = 0x100;        // Don't load invalid page
    const uint32_t cs_require_lv = 0x2000;  // Library Validation
    
    CFRelease(csInfo);
    
    // Check for hardened runtime protections
    if (csFlags & (cs_hard | cs_require_lv)) {
        return YES; // Accept connection
    }
    
    return NO;
}
```

## Common Vulnerabilities

### PID Reuse Attack

**What:** Attacker terminates a legitimate process and creates a new one with the same PID.

**How it happens:** Using `processIdentifier` property instead of audit tokens.

**Prevention:** Always use audit token-based verification.

### Audit Token Spoofing

**What:** Using `xpc_connection_get_audit_token` instead of `xpc_dictionary_get_audit_token`.

**Risk:** The former can be vulnerable in certain situations.

**Prevention:** Use `xpc_dictionary_get_audit_token` when available.

### Missing Version Check

**What:** Not verifying client version allows old vulnerable clients to connect.

**Prevention:** Include version requirement in SecRequirement string.

### Missing Hardened Runtime Check

**What:** Clients without hardened runtime can be vulnerable to code injection.

**Prevention:** Check csFlags for hardened runtime indicators.

## TrustCache (Apple Silicon)

On Apple Silicon machines, TrustCache stores CDHSAH hashes of Apple binaries to prevent execution of modified or downgraded binaries. This provides an additional layer of protection against downgrade attacks.

## Security Checklist

Before deploying an XPC service, verify:

- [ ] Connection verification is implemented in `shouldAcceptNewConnection:`
- [ ] Audit tokens are used instead of PIDs
- [ ] Apple-signed certificate is verified
- [ ] Team ID is verified
- [ ] Bundle ID is verified
- [ ] Version check is implemented OR hardened runtime is verified
- [ ] Hardened runtime flags are checked
- [ ] Entitlements are verified (for Apple binaries)
- [ ] Private API usage is documented and justified
- [ ] Error cases return NO (deny by default)

## Testing Your Implementation

1. **Test with legitimate client:** Verify your signed client can connect
2. **Test with unsigned client:** Verify unsigned clients are rejected
3. **Test with wrong Team ID:** Verify different team IDs are rejected
4. **Test with wrong Bundle ID:** Verify different bundle IDs are rejected
5. **Test with old version:** Verify version check works
6. **Test PID reuse:** Attempt to reuse PIDs (if possible in your environment)

## References

- Apple's XPC Programming Guide
- SecTaskCreateWithAuditToken documentation
- macOS Code Signing Guide
- Hardened Runtime documentation

## Important Notes

1. **Private APIs:** Audit token APIs are private. For App Store distribution, you'll need to find alternative verification methods or obtain special approval.

2. **API Changes:** Private APIs can change at any time. Design your verification to be resilient to changes.

3. **Defense in Depth:** Implement multiple verification layers. Don't rely on a single check.

4. **Deny by Default:** Always return NO if verification fails or cannot be completed.

5. **Logging:** Log connection attempts (without sensitive data) for security monitoring.

6. **Regular Audits:** Periodically review and update your verification requirements as threats evolve.
