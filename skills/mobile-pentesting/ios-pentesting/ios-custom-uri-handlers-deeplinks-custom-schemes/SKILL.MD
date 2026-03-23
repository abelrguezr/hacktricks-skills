---
name: ios-custom-uri-handlers-pentest
description: iOS security testing for custom URI handlers, deeplinks, and custom schemes. Use this skill whenever testing iOS apps for URL scheme vulnerabilities, deeplink security, custom protocol handling, Info.plist URL configuration, or inter-app communication attacks. Trigger this skill for any iOS pentest involving URL schemes, canOpenURL, LSApplicationQueriesSchemes, URL hijacking, OAuth token theft via custom schemes, or Frida-based URL fuzzing.
---

# iOS Custom URI Handlers / Deeplinks / Custom Schemes Pentest

A skill for security testing iOS applications' custom URL scheme implementations, identifying vulnerabilities in deeplink handling, and detecting potential URL scheme hijacking attacks.

## What This Skill Covers

- Custom URL scheme registration and validation testing
- Info.plist URL configuration analysis
- URL handler method inspection in source code
- URL scheme fuzzing with Frida
- Custom URL scheme hijacking detection
- OAuth token theft via custom schemes
- Inter-app communication security

## Quick Start

```bash
# Analyze Info.plist for registered URL schemes
python scripts/analyze_url_schemes.py <path-to-Info.plist>

# Fuzz URL schemes with Frida
frida -U SpringBoard -l scripts/ios-url-scheme-fuzzing.js
```

## Testing Procedures

### 1. Identify Registered URL Schemes

Check the app's `Info.plist` for `CFBundleURLTypes` to find registered custom schemes:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>myapp</string>
            <string>myapp2</string>
        </array>
        <key>CFBundleURLName</key>
        <string>com.example.myapp</string>
    </dict>
</array>
```

**What to look for:**
- All registered URL schemes
- Whether schemes are predictable or follow patterns
- If schemes could be hijacked by other apps

### 2. Check LSApplicationQueriesSchemes

From iOS 9.0+, apps must declare queryable schemes under `LSApplicationQueriesSchemes` (max 50 schemes):

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>url_scheme1</string>
    <string>url_scheme2</string>
</array>
```

**Security implications:**
- Apps can only query schemes listed here
- Prevents app enumeration attacks
- Check if the app queries schemes it shouldn't
- Verify the 50-scheme limit is respected

### 3. Inspect URL Handler Methods

Search the app's source code for these URL handling methods:

```swift
// Modern URL handling (iOS 9+)
func application(_ app: UIApplication, open url: URL,
                 options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool

// Legacy methods (iOS 8 and earlier)
func application(_ application: UIApplication, open url: URL,
                 sourceApplication: String?) -> Bool

func application(_ application: UIApplication, handleOpen url: URL) -> Bool

func application(_ application: UIApplication, 
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool
```

**What to analyze:**
- How URL parameters are parsed and validated
- Whether malformed URLs are properly rejected
- If URL parameters are used in sensitive operations
- Presence of input sanitization
- Error handling for invalid URLs

### 4. Test URL Parameter Validation

**Critical:** All URL parameters must be validated. Test with:

```bash
# Normal URL
myapp://hostname?data=123876123

# Malformed URLs to test
myapp://hostname?data=<script>alert(1)</script>
myapp://hostname?data=../../../etc/passwd
myapp://hostname?data=%00%00%00
myapp://hostname?data=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
myapp://hostname?data=\x00\x01\x02\x03
myapp://hostname?data=\n\r\t
```

**Expected behavior:**
- Malformed URLs should be rejected
- No crashes or memory corruption
- No unexpected app behavior
- Proper error messages to user

### 5. Fuzz URL Schemes with Frida

Use the bundled Frida script to automate URL scheme fuzzing:

```bash
# Attach to SpringBoard and load the fuzzing script
frida -U SpringBoard -l scripts/ios-url-scheme-fuzzing.js

# In the Frida console, run:
[iPhone::SpringBoard]-> fuzz("targetApp", "targetApp://?param1={0}&param2={0}")
```

**What the script does:**
- Opens URLs with varying payloads
- Monitors for crashes
- Logs URL handling behavior
- Detects memory corruption bugs

**Example output:**
```
Watching for crashes from targetApp...
Opened URL: targetApp://?param1=0&param2=0
Opened URL: targetApp://?param1=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA&param2=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
```

### 6. Test for URL Scheme Hijacking

**Attack scenario:** Malicious apps can register the same URL schemes as victim apps, then intercept sensitive data.

**How it works:**
1. Malicious app registers victim's URL scheme
2. Malicious app opens ASWebAuthenticationSession (Safari with cookies)
3. User is redirected to attacker-controlled page
4. Page redirects to victim's OAuth flow with `prompt=none`
5. OAuth token is sent via custom scheme
6. Malicious app intercepts the token

**Testing steps:**

1. **Check for OAuth flows:**
   - Look for `ASWebAuthenticationSession` usage
   - Check for OAuth authorization endpoints
   - Verify `prompt=none` is not used unsafely

2. **Test scheme registration:**
   - Create a test app with the same URL scheme
   - Attempt to intercept URL callbacks
   - Verify the victim app doesn't receive sensitive data

3. **Verify TCC permissions:**
   - Check if the app requests unnecessary permissions
   - Verify permission prompts are clear and accurate

### 7. Test Inter-App Communication

Identify methods that open URLs to other apps:

```swift
// Modern method
UIApplication.shared.open(url, options: [:], completionHandler: nil)

// Legacy method
UIApplication.shared.openURL(url)
```

**What to check:**
- URLs opened to external apps
- Data passed between apps
- Whether the app validates the target app
- Potential for data leakage

### 8. Check for Deprecated Methods

Identify and review deprecated URL handling methods:

```swift
// Deprecated - iOS 8 and earlier
func application(_ application: UIApplication, handleOpenURL url: URL) -> Bool

// Deprecated - use openURL:options:completionHandler: instead
UIApplication.shared.openURL(url)
```

**Why it matters:**
- Deprecated methods may have known vulnerabilities
- May not receive security updates
- Could indicate outdated code

## Common Vulnerabilities

### 1. Insufficient Input Validation

**Example:**
```swift
// Vulnerable - no validation
func openUrl(url: URL) {
    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    let data = components?.queryItems?.first(where: { $0.name == "data" })?.value
    // Use data directly without validation
    processUserData(data)
}
```

**Fix:**
```swift
// Secure - validate input
func openUrl(url: URL) {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
        return false
    }
    
    guard let dataItem = components.queryItems?.first(where: { $0.name == "data" }),
          let data = dataItem.value,
          isValidData(data) else {
        return false
    }
    
    processUserData(data)
    return true
}

func isValidData(_ data: String) -> Bool {
    // Validate format, length, characters, etc.
    return data.count < 1000 && !data.contains("<") && !data.contains(">")
}
```

### 2. URL Scheme Hijacking

**Vulnerability:** App doesn't verify the source of URL callbacks

**Fix:**
- Verify the source application
- Use app-specific authentication tokens
- Implement callback validation

### 3. Memory Corruption via URL Parameters

**Vulnerability:** Long or malformed URL parameters cause crashes

**Fix:**
- Validate URL length
- Sanitize all parameters
- Use safe string handling
- Test with fuzzing

## Testing Checklist

- [ ] Identify all registered URL schemes in Info.plist
- [ ] Check LSApplicationQueriesSchemes (max 50)
- [ ] Inspect URL handler methods in source code
- [ ] Test URL parameter validation with malformed inputs
- [ ] Run Frida fuzzing on URL schemes
- [ ] Test for URL scheme hijacking
- [ ] Check for OAuth token theft vectors
- [ ] Review inter-app communication
- [ ] Identify deprecated URL handling methods
- [ ] Verify proper error handling

## References

- [OWASP MASTG - iOS URL Scheme Testing](https://mas.owasp.org/MASTG/tests/ios/MASVS-PLATFORM/MASTG-TEST-0075/)
- [iOS OAuth Custom Scheme Hijacking](https://evanconnelly.github.io/post/ios-oauth/)
- [Apple Developer - Inter-App Communication](https://developer.apple.com/library/content/documentation/iPhone/Conceptual/iPhoneOSProgrammingGuide/Inter-AppCommunication/Inter-AppCommunication.html)
- [ASWebAuthenticationSession Documentation](https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession)
- [Frida iOS URL Scheme Fuzzing](https://codeshare.frida.re/@dki/ios-url-scheme-fuzzing/)
