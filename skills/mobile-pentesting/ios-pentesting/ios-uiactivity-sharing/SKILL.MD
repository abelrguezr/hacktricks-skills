---
name: ios-uiactivity-sharing-analysis
description: Analyze iOS apps for UIActivity sharing vulnerabilities. Use this skill whenever you need to test iOS app sharing mechanisms, examine how apps send/receive data through the share sheet, audit Info.plist for document type declarations, or perform dynamic testing of UIActivityViewController. Trigger this skill for any iOS pentesting task involving inter-app communication, share sheet analysis, or document type handling.
---

# iOS UIActivity Sharing Analysis

A skill for security testers to analyze iOS applications for vulnerabilities in their UIActivity sharing implementation.

## Overview

iOS apps can share data (text, URLs, images) through the system-wide share activity sheet. This skill helps you:

- **Analyze sharing mechanisms** - How the app sends data to other apps
- **Audit receiving capabilities** - What document types the app can accept
- **Identify vulnerabilities** - Missing validation, exposed activities, insecure data handling

## Static Analysis

### 1. Examine UIActivityViewController Initialization

Search for how the app creates share sheets:

```bash
# Find UIActivityViewController references
rabin2 -zq <app_name>.app/<app_name> | grep -i activity

# Look for activityItems initialization
rabin2 -zq <app_name>.app/<app_name> | grep -i activityItems

# Check for excludedActivityTypes
rabin2 -zq <app_name>.app/<app_name> | grep -i excluded
```

**What to look for:**
- What data is being passed to `initWithActivityItems:applicationActivities:`
- Whether `excludedActivityTypes` is properly configured
- If custom activities are added (potential attack surface)
- Sensitive data being shared without proper sanitization

### 2. Audit Info.plist Document Type Declarations

Check the app's `Info.plist` for these keys:

```bash
# Extract and search Info.plist
plutil -p <app_name>.app/Info.plist | grep -A 20 -i "document\|uti\|type"
```

**Key declarations to examine:**

| Key | Purpose | Security Concern |
|-----|---------|------------------|
| `UTExportedTypeDeclarations` | Document types the app creates | Can other apps read exported data? |
| `UTImportedTypeDeclarations` | Document types the app can open | Does app validate imported data? |
| `CFBundleDocumentTypes` | File associations | What file types trigger the app? |

**Example Info.plist structure:**
```xml
<key>UTExportedTypeDeclarations</key>
<array>
  <dict>
    <key>UTTypeIdentifier</key>
    <string>com.example.app.document</string>
    <key>UTTypeDescription</key>
    <string>Example Document</string>
  </dict>
</array>

<key>CFBundleDocumentTypes</key>
<array>
  <dict>
    <key>CFBundleTypeName</key>
    <string>Example Document</string>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>LSItemContentTypes</key>
    <array>
      <string>com.example.app.document</string>
    </array>
  </dict>
</array>
```

## Dynamic Testing

### Testing Data Sending

1. **Hook UIActivityViewController initialization:**
   ```objc
   // Frida hook example
   Interceptor.attach(ObjC.classes.UIActivityViewController.init,
     {
       onEnter: function(args) {
         console.log("UIActivityViewController initialized");
         console.log("Activity items:", args[2]);
       }
     }
   );
   ```

2. **Capture shared data:**
   - Trigger the share action in the app
   - Observe what data is passed to the share sheet
   - Check if sensitive information is exposed

3. **Test excluded activities:**
   - Verify that `excludedActivityTypes` is working
   - Attempt to share via excluded methods
   - Check if exclusions can be bypassed

### Testing Data Receiving

1. **Share files to the app:**
   - Use AirDrop, email, or other apps to share files
   - Trigger the "Open with..." dialogue
   - Observe which file types the app accepts

2. **Hook URL handling:**
   ```objc
   // Hook application:openURL:options:
   Interceptor.attach(ObjC.selector('application:openURL:options:'),
     {
       onEnter: function(args) {
         console.log("URL opened:", args[2].toString());
       }
     }
   );
   ```

3. **Fuzz with malformed files:**
   - Create files with valid extensions but invalid content
   - Test with oversized files
   - Try files with embedded scripts or payloads
   - Observe app behavior and error handling

## Common Vulnerabilities

### 1. Insecure Data Sharing
- Sensitive data shared without encryption
- Personal information exposed in share sheet
- Authentication tokens passed in shared content

### 2. Missing Input Validation
- No validation of received document types
- Improper handling of malformed files
- Buffer overflows from large file inputs

### 3. Improper Activity Exclusions
- Sensitive activities not excluded (e.g., saving to cloud)
- Custom activities with insecure implementations
- No filtering of share destinations

### 4. Document Type Confusion
- Accepting dangerous file types (scripts, executables)
- No verification of file content vs. extension
- Improper handling of nested archives

## Testing Checklist

- [ ] Identify all UIActivityViewController instantiations
- [ ] Review what data is being shared
- [ ] Check excludedActivityTypes configuration
- [ ] Audit Info.plist for document type declarations
- [ ] Test sharing sensitive data
- [ ] Test receiving various file types
- [ ] Fuzz with malformed files
- [ ] Hook and monitor data flow
- [ ] Verify input validation on received data
- [ ] Check for custom activity implementations

## Reporting Findings

When documenting vulnerabilities:

1. **Describe the issue** - What vulnerability was found
2. **Show the evidence** - Code snippets, plist entries, or dynamic test results
3. **Explain the impact** - What an attacker could do
4. **Provide remediation** - How to fix the issue

## References

- [Apple Inter-App Communication Guide](https://developer.apple.com/library/archive/documentation/iPhone/Conceptual/iPhoneOSProgrammingGuide/Inter-AppCommunication/Inter-AppCommunication.html)
- [UIActivity.ActivityType Documentation](https://developer.apple.com/documentation/uikit/uiactivity/activitytype)
- [Mobile Security Testing Guide - iOS Platform Interaction](https://mobile-security.gitbook.io/mobile-security-testing-guide/ios-testing-guide/0x06h-testing-platform-interaction)
- [StackOverflow: UTImportedTypeDeclarations and UTExportedTypeDeclarations](https://stackoverflow.com/questions/21937978/what-are-utimportedtypedeclarations-and-utexportedtypedeclarations-used-for-on-i)
