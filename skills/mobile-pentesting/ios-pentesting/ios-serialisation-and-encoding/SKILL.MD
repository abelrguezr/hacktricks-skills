---
name: ios-serialization-security
description: Security testing for iOS object serialization vulnerabilities. Use this skill whenever testing iOS apps for insecure deserialization, NSCoding/NSSecureCoding issues, NSKeyedArchiver/Unarchiver abuse, or Codable implementation flaws. Trigger when the user mentions iOS serialization, archiving, object persistence, NSCoder, or any iOS data encoding security concerns.
---

# iOS Serialization Security Testing

This skill helps you identify and exploit serialization vulnerabilities in iOS applications. Serialization vulnerabilities can lead to arbitrary code execution, data leakage, and privilege escalation.

## Understanding iOS Serialization

iOS provides multiple serialization mechanisms, each with distinct security implications:

- **NSCoding**: Basic serialization protocol (insecure by default)
- **NSSecureCoding**: Enhanced type-safe serialization (still not encrypted)
- **NSKeyedArchiver/Unarchiver**: File-based object persistence
- **Codable**: Modern Swift serialization (generally safer)
- **JSON/XML**: Text-based formats with their own risks

## Testing NSCoding Vulnerabilities

### Check for NSCoding Implementation

Look for classes implementing `NSCoding` without `NSSecureCoding`:

```objc
// Insecure - vulnerable to class substitution attacks
@interface VulnerableClass : NSObject <NSCoding>
@end

// Secure - requires type checking during decoding
@interface SecureClass : NSObject <NSSecureCoding>
@end
```

**What to look for:**
- Classes with `NSCoding` but missing `NSSecureCoding`
- Missing `supportsSecureCoding` property set to `YES`
- Use of `decodeObject:` instead of `decodeObject(of:forKey:)`

### Exploitation Technique

When `NSSecureCoding` is not enforced, attackers can substitute classes during deserialization:

1. Identify the serialized data format (usually in app's Documents or Library directories)
2. Modify the class name in the archive to point to a malicious class
3. Trigger deserialization to execute arbitrary code

## Testing NSKeyedArchiver/Unarchiver

### Locate Archived Data

Search for archived files in common locations:

```bash
# In jailbroken device or simulator
find ~/Documents -name "*.archive" -o -name "*.dat" -o -name "*.plist"
find ~/Library -name "*.archive" -o -name "*.dat"
```

### Test for Insecure Unarchiving

Check if the app uses deprecated or insecure unarchiving methods:

```objc
// Insecure - deprecated
[NSKeyedUnarchiver unarchiveObjectWithFile:@"path"];

// Secure - requires secure coding
[NSKeyedUnarchiver unarchiveObjectOfClasses:allowedClasses fromData:data];
```

**Red flags:**
- Use of `unarchiveObjectWithFile:` or `unarchiveObjectWithData:`
- No class whitelist validation
- Deserializing data from untrusted sources (network, user input)

## Testing Codable Implementation

### Review Codable Conformance

```swift
// Generally safe - type-safe by default
struct SafeData: Codable {
    let id: Int
    let name: String
}

// Potential issues - custom decoding
struct CustomData: Codable {
    let data: Data
    
    enum CodingKeys: String, CodingKey {
        case data
    }
    
    init(from decoder: Decoder) throws {
        // Check for custom logic that might be vulnerable
    }
}
```

**What to check:**
- Custom `init(from:)` implementations with unsafe operations
- Decoding of `Data` types that might contain serialized objects
- Use of `Decodable` on classes that might be subclassed

## Security Testing Checklist

### Static Analysis

1. **Search for serialization keywords:**
   ```bash
   grep -r "NSCoding" app_source/
   grep -r "NSSecureCoding" app_source/
   grep -r "NSKeyedArchiver" app_source/
   grep -r "NSKeyedUnarchiver" app_source/
   grep -r "Codable" app_source/
   ```

2. **Check for secure coding enforcement:**
   ```bash
   grep -r "supportsSecureCoding" app_source/
   grep -r "decodeObject(of:" app_source/
   ```

3. **Identify data sources:**
   - Network responses being deserialized
   - Files from user downloads
   - Shared preferences or keychain data

### Dynamic Analysis

1. **Hook deserialization methods:**
   ```objc
   // Using Frida
   const NSKeyedUnarchiver = ObjC.classes.NSKeyedUnarchiver;
   NSKeyedUnarchiver.unarchiveObjectWithData.implementation = function(data) {
       console.log("Unarchiving data:", data);
       return this.unarchiveObjectWithData(data);
   };
   ```

2. **Monitor file access:**
   - Track reads from Documents/Library directories
   - Identify archived files being loaded

3. **Test with modified archives:**
   - Create malicious archives with substituted classes
   - Attempt to trigger deserialization

## Common Vulnerable Patterns

### Pattern 1: Insecure Class Substitution

```objc
// Vulnerable code
- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self) {
        self.object = [aDecoder decodeObjectForKey:@"object"]; // No type check!
    }
    return self;
}
```

**Exploitation:** Replace the expected class with a malicious subclass that executes code in `init`.

### Pattern 2: Untrusted Data Deserialization

```swift
// Vulnerable - deserializing network data
func handleResponse(data: Data) {
    let object = NSKeyedUnarchiver.unarchiveObject(with: data) as? MyObject
    // Process object without validation
}
```

**Exploitation:** Send crafted serialized data over the network.

### Pattern 3: Missing Secure Coding Flag

```objc
// Vulnerable - NSCoding without NSSecureCoding
@interface MyModel : NSObject <NSCoding>
@end

@implementation MyModel
- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.data forKey:@"data"];
}
@end
```

**Exploitation:** Same as Pattern 1 - class substitution attacks.

## Mitigation Recommendations

### For Developers

1. **Always use NSSecureCoding:**
   ```objc
   @interface SecureModel : NSObject <NSSecureCoding>
   @end
   
   @implementation SecureModel
   + (BOOL)supportsSecureCoding {
       return YES;
   }
   
   - (id)initWithCoder:(NSCoder *)aDecoder {
       self = [super init];
       if (self) {
           self.data = [aDecoder decodeObjectOfClass:[NSData class] forKey:@"data"];
       }
       return self;
   }
   @end
   ```

2. **Prefer Codable for new code:**
   ```swift
   struct SafeModel: Codable {
       let id: UUID
       let name: String
   }
   ```

3. **Validate data sources:**
   - Never deserialize untrusted data
   - Use JSON for external data exchange
   - Sign and verify serialized data

4. **Encrypt sensitive data:**
   - Serialization is not encryption
   - Use Keychain for sensitive values
   - Encrypt archived data at rest

## References

- [OWASP MASTG - Testing Platform Interaction](https://mas.owasp.org/MASTG/iOS/0x06h-Testing-Platform-Interaction/#object-persistence)
- [Apple - NSCoding Protocol](https://developer.apple.com/documentation/foundation/nscoding)
- [Apple - NSSecureCoding](https://developer.apple.com/documentation/foundation/nscoding/1416145-supportssecurecoding)

## Quick Commands

```bash
# Find all NSCoding implementations
grep -r "<NSCoding>" . --include="*.m" --include="*.swift"

# Find unarchiver usage
grep -r "unarchiveObject" . --include="*.m" --include="*.swift"

# Check for secure coding
grep -r "supportsSecureCoding" . --include="*.m" --include="*.swift"

# List archived files in app container
find ~/Library/Containers/com.example.app/Data/Documents -type f
```

## When to Use This Skill

Use this skill when:
- Testing iOS apps for deserialization vulnerabilities
- Reviewing iOS code for serialization security
- Investigating data persistence mechanisms in iOS
- Analyzing archived files from iOS applications
- Assessing NSCoder/NSKeyedArchiver implementations
- Evaluating Codable implementations for security issues

This skill provides the methodology and patterns needed to identify and exploit iOS serialization vulnerabilities during mobile security assessments.
