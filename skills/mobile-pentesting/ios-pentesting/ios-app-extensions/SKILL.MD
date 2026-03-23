---
name: ios-app-extensions-pentest
description: iOS app extension security testing. Use this skill whenever the user needs to test iOS app extensions for security vulnerabilities, analyze extension configurations, or perform static/dynamic analysis on iOS app extensions. Trigger for any iOS security testing involving app extensions, custom keyboards, share extensions, Today widgets, or extension-related security assessments. Don't wait for the user to explicitly mention "extensions" - if they're doing iOS app security testing, check for extensions.
---

# iOS App Extensions Security Testing

This skill guides you through security testing of iOS app extensions, which enhance app functionality by interacting with other apps or the system.

## What Are App Extensions?

App extensions provide custom features across apps:
- **Custom Keyboard**: Replaces default iOS keyboard across all apps
- **Share Extension**: Enables sharing to social networks or contacts
- **Today Widget**: Delivers content from Notification Center's Today view
- **iMessage Extension**: Custom messaging features

## Security Model

Understanding the security model is critical:

- Extensions communicate with their containing app via **inter-process communication (IPC)**, not direct memory access
- **Today widgets** can request their app to open via specific methods
- Shared data access requires a **private container** (App Groups)
- Extensions **cannot**:
  - Access HealthKit APIs
  - Start long-running background tasks
  - Access camera or microphone (except iMessage extensions)
  - Directly access the host app's memory

## Static Analysis

### Step 1: Identify App Extensions

**With source code (Xcode):**
```bash
# Search for extension point identifiers
grep -r "NSExtensionPointIdentifier" .
```

**Without source code (app bundle):**
```bash
# Find .appex files (extension bundles)
find . -name "*.appex" -type d

# Or search Info.plist files for extension identifiers
grep -r "NSExtensionPointIdentifier" .
```

**Common extension point identifiers:**
- `com.apple.keyboard-service` - Custom Keyboard
- `com.apple.share-services` - Share Extension
- `com.apple.widget-extension` - Today Widget
- `com.apple.message-payload-service` - iMessage Extension

### Step 2: Analyze Extension Configuration

Check each extension's `Info.plist` for:

**NSExtensionActivationRule** - Determines what data types trigger the extension:
```xml
<key>NSExtensionActivationRule</key>
<dict>
    <key>NSExtensionActivationSupportsText</key>
    <true/>
    <key>NSExtensionActivationSupportsImageWithMaxCount</key>
    <integer>1</integer>
</dict>
```

**NSExtensionAttributes** - Extension-specific configuration:
```xml
<key>NSExtensionAttributes</key>
<dict>
    <key>NSExtensionActivationSupportsWebURLWithMaxCount</key>
    <integer>1</integer>
</dict>
```

**Security implications:**
- Overly permissive activation rules may expose the extension to unexpected data
- Check if the extension accepts sensitive data types (URLs, contacts, files)
- Verify the extension properly validates all input

### Step 3: Check Data Sharing Configuration

Extensions share data with their host app via **App Groups**:

```bash
# Find App Group identifiers in Info.plist
grep -A 2 "com.apple.security.application-groups" Info.plist

# Check for shared container usage
grep -r "NSUserDefaults" . | grep -i "suite"
```

**What to look for:**
- Shared container names (should be in `com.apple.security.application-groups` entitlement)
- How data is passed between app and extension
- Whether sensitive data is stored in shared containers
- If the extension properly sanitizes data from shared containers

### Step 4: Check Extension Restrictions

Apps can restrict extension capabilities:

```bash
# Check for keyboard restrictions
grep -i "restricts" Info.plist

# Look for NSExtensionAttributes restrictions
grep -A 10 "NSExtensionAttributes" Info.plist
```

**Common restrictions:**
- `NSExtensionRestrictsToPrivateContainer` - Limits data access
- Custom keyboard restrictions for sensitive contexts

## Dynamic Analysis

### Step 1: Inspect Shared Items

Use Frida to hook into extension input processing:

```javascript
// Hook NSExtensionContext to see what data extensions receive
var NSExtensionContext = ObjC.classes.NSExtensionContext;

NSExtensionContext.inputItems.implementation = function() {
    console.log("[+] Extension received input items:");
    var items = this.inputItems();
    items.forEach(function(item) {
        console.log("  - " + item.toString());
    });
    return this.inputItems();
};
```

**What to observe:**
- What data types the extension actually receives
- Whether the extension properly validates input
- If sensitive data flows through the extension

### Step 2: Monitor IPC Communication

Extensions communicate via XPC:

```bash
# Use frida-trace to monitor XPC connections
frida-trace -U -n "extension-bundle-name" -S NSXPCConnection

# Or trace specific methods
frida-trace -U -n "extension-bundle-name" -S "-[NSXPCConnection send]"
```

**What to look for:**
- Data passed between extension and host app
- Authentication/authorization checks in IPC
- Potential injection points in IPC messages

### Step 3: Test Extension Activation

**For Share Extensions:**
1. Share various data types (text, images, URLs, contacts)
2. Observe which types trigger the extension
3. Test with malformed or unexpected data
4. Check if the extension crashes or leaks data

**For Custom Keyboards:**
1. Test in different apps (messaging, forms, password fields)
2. Verify the keyboard doesn't capture sensitive input
3. Check clipboard access behavior
4. Test extension persistence across app switches

**For Today Widgets:**
1. Test widget update frequency
2. Check what data the widget displays
3. Verify the widget doesn't expose sensitive information
4. Test the "open app" functionality

## Common Vulnerabilities

### 1. Insecure Data Sharing
- Sensitive data stored in shared containers without encryption
- No validation of data from shared containers
- Overly permissive App Group access

### 2. Input Validation Issues
- Extensions accepting unexpected data types
- No sanitization of user input
- Buffer overflows in extension code

### 3. IPC Security
- Unauthenticated IPC between extension and host app
- Sensitive data transmitted over IPC without encryption
- Missing authorization checks in IPC handlers

### 4. Extension Activation
- Extensions triggered by unexpected data
- No rate limiting on extension activation
- Extensions running with excessive privileges

## Testing Checklist

- [ ] Identify all app extensions in the target app
- [ ] Analyze each extension's Info.plist configuration
- [ ] Check NSExtensionActivationRule for overly permissive rules
- [ ] Verify App Group configuration and shared container usage
- [ ] Test extension with various data types
- [ ] Monitor IPC communication between extension and host app
- [ ] Check for sensitive data exposure in shared containers
- [ ] Verify extension restrictions are properly configured
- [ ] Test extension behavior in different contexts
- [ ] Review extension code for input validation issues

## References

- [OWASP MASTG - Testing Platform Interaction](https://mas.owasp.org/MASTG/iOS/0x06h-Testing-Platform-Interaction/)
- [OWASP MASTG - MASVS-PLATFORM-TEST-0072](https://mas.owasp.org/MASTG/tests/ios/MASVS-PLATFORM/MASTG-TEST-0072/)
- [Apple - App Extension Programming Guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/)
- [Apple - App Groups](https://developer.apple.com/documentation/uikit/app_and_system_services/sharing_data_between_apps_and_extensions)
