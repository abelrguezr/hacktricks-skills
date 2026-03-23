#!/bin/bash
# Generate XPC verification template for a new service
# Usage: ./generate-xpc-verification-template.sh <bundle-id> <team-id> <min-version>

set -e

if [ $# -ne 3 ]; then
    echo "Usage: $0 <bundle-id> <team-id> <min-version>"
    echo "Example: $0 com.example.myservice ABC123DEF4 1.0.0"
    exit 1
fi

BUNDLE_ID="$1"
TEAM_ID="$2"
MIN_VERSION="$3"

cat << EOF
// XPC Connection Verification Template
// Generated for: $BUNDLE_ID
// Team ID: $TEAM_ID
// Minimum Version: $MIN_VERSION

#import <Foundation/Foundation.h>
#import <Security/Security.h>

@interface XPCSecurityVerifier : NSObject
- (BOOL)verifyConnection:(NSXPCConnection *)connection;
@end

@implementation XPCSecurityVerifier

- (BOOL)verifyConnection:(NSXPCConnection *)connection {
    // CRITICAL: This is a template. Review and customize for your needs.
    // Private APIs used here may not be allowed in App Store apps.
    
    SecRequirementRef requirementRef = NULL;
    
    // Verification requirements:
    // - Signed by Apple
    // - Correct bundle ID
    // - Correct team ID
    // - Minimum version
    NSString *requirementString = [
        @"anchor apple generic "
        @"and identifier \"$BUNDLE_ID\" "
        @"and certificate leaf [subject.CN] = \"$TEAM_ID\" "
        @"and info [CFBundleShortVersionString] >= \"$MIN_VERSION\""
    ];
    
    OSStatus status = SecRequirementCreateWithString(
        (__bridge CFStringRef)requirementString,
        kSecCSDefaultFlags,
        &requirementRef
    );
    
    if (status != errSecSuccess || !requirementRef) {
        NSLog(@"Failed to create security requirement");
        return NO;
    }
    
    // TODO: Implement audit token verification
    // Note: SecTaskCreateWithAuditToken is a private API
    // For App Store apps, consider alternative approaches
    
    // Example (requires private API):
    // SecTaskRef taskRef = SecTaskCreateWithAuditToken(NULL, auditToken);
    // status = SecTaskValidateForRequirement(taskRef, (__bridge CFStringRef)requirementString);
    
    CFRelease(requirementRef);
    
    // For now, return NO until verification is implemented
    return NO;
}

@end

// Usage in your XPC listener:
//
// - (BOOL)listener:(NSXPCListener *)listener 
//     shouldAcceptNewConnection:(NSXPCConnection *)newConnection {
//     XPCSecurityVerifier *verifier = [[XPCSecurityVerifier alloc] init];
//     return [verifier verifyConnection:newConnection];
// }
EOF

echo "Template generated. Review and customize before use."
echo "Important: This template uses private APIs. Check App Store guidelines."
