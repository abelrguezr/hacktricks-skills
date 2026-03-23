---
name: macos-objective-c-analysis
description: Analyze and understand Objective-C code in macOS binaries for security research, reverse engineering, and privilege escalation. Use this skill whenever you need to read Objective-C source code, analyze Mach-O binaries with class-dump, understand iOS/macOS app internals, or work with Objective-C runtime concepts in a security context. Trigger this skill for any macOS binary analysis, Objective-C code review, or when investigating app behavior through class/method inspection.
---

# macOS Objective-C Analysis

A skill for analyzing Objective-C code and binaries in macOS security research and reverse engineering.

## When to Use This Skill

Use this skill when:
- Analyzing macOS/iOS binaries for security research
- Reading or understanding Objective-C source code
- Using `class-dump` to extract class information from Mach-O binaries
- Investigating app internals for privilege escalation or vulnerability research
- Working with Objective-C runtime concepts in security contexts
- Understanding class declarations, methods, and instance variables in compiled binaries

## Core Concepts

### Binary Analysis with class-dump

Objective-C programs **retain** their class declarations when compiled into Mach-O binaries. This includes:
- Class names
- Class methods
- Instance variables

Extract this information using:

```bash
class-dump <binary_path>
class-dump -H <binary_path>  # Include header output
class-dump -r <binary_path>  # Recursive for frameworks
```

**Note:** Class names may be obfuscated to complicate reverse engineering.

### Class Structure

#### Interface Declaration

```objectivec
@interface MyVehicle : NSObject

@property NSString *vehicleType;
@property int numberOfWheels;

- (void)startEngine;
- (void)addWheels:(int)value;

@end
```

#### Implementation

```objectivec
@implementation MyVehicle : NSObject

- (void)startEngine {
    NSLog(@"Engine started");
}

- (void)addWheels:(int)value {
    self.numberOfWheels += value;
}

@end
```

### Object Instantiation

```objectivec
// Allocate and initialize
MyVehicle *newVehicle = [[MyVehicle alloc] init];

// Shorthand
MyVehicle *newVehicle = [MyVehicle new];

// Call methods
[newVehicle addWheels:4];
```

### Method Types

| Type | Symbol | Example |
|------|--------|---------|
| Instance method | `-` | `- (void)startEngine` |
| Class method | `+` | `+ (id)stringWithString:(NSString *)aString` |

### Property Access

```objectivec
// Dot notation (setter)
newVehicle.numberOfWheels = 2;

// Method call (setter)
[newVehicle setNumberOfWheels:3];

// Dot notation (getter)
NSLog(@"Wheels: %i", newVehicle.numberOfWheels);

// Method call (getter)
NSLog(@"Wheels: %i", [newVehicle numberOfWheels]);
```

### Instance Variables

Access properties directly using underscore prefix:

```objectivec
- (void)makeLongTruck {
    _numberOfWheels = 10000;
    NSLog(@"Wheels: %i", self.numberOfWheels);
}
```

### Protocols

Protocols define method contracts (no properties):

```objectivec
@protocol myVehicleProtocol
- (void)startEngine;           // mandatory (default)
@required
- (void)addWheels:(int)value;  // mandatory
@optional
- (void)makeLongTruck;         // optional
@end

@interface MyVehicle : NSObject <myVehicleProtocol>
@end
```

## Common Classes for Analysis

### NSString

```objectivec
// String literals
NSString *title = @"The Catcher in the Rye";

// From C string
NSString *author = [NSString stringWithCString:"J.D. Salinger" encoding:NSUTF8StringEncoding];

// Format strings
NSString *desc = [NSString stringWithFormat:@"%@ by %@", title, author];

// Mutable strings
NSMutableString *mutable = [NSMutableString stringWithString:@"The book "];
[mutable appendString:title];
```

### NSNumber

```objectivec
// Character
NSNumber *letter = @'Z';

// Integers
NSNumber *num = @42;
NSNumber *numLong = @42L;

// Floats
NSNumber *pi = @3.14159;

// Booleans
NSNumber *yes = @YES;
NSNumber *no = @NO;
```

### Collections

```objectivec
// Arrays
NSArray *immutable = @[@"red", @"green", @"blue"];
NSMutableArray *mutable = [NSMutableArray array];
[mutable addObject:@"red"];

// Sets
NSSet *immutableSet = [NSSet setWithArray:@[@"apple", @"banana"]];
NSMutableSet *mutableSet = [NSMutableSet set];

// Dictionaries
NSDictionary *dict = @{
    @"apple": @"red",
    @"banana": @"yellow"
};
NSMutableDictionary *mutDict = [NSMutableDictionary dictionaryWithDictionary:dict];
```

### Blocks (Closures)

```objectivec
// Define block
int (^suma)(int, int) = ^(int a, int b) {
    return a + b;
};
NSLog(@"3+4 = %d", suma(3, 4));

// Block type
typedef void (^callbackLogger)(void);

// Use as parameter
void genericLogger(callbackLogger block) {
    block();
}
```

### File Operations

```objectivec
NSFileManager *fileManager = [NSFileManager defaultManager];

// Check existence
[fileManager fileExistsAtPath:@"/path/to/file.txt"];

// Copy
[fileManager copyItemAtPath:@"/src" toPath:@"/dst" error:nil];

// Compare contents
[fileManager contentsEqualAtPath:@"/file1" andPath:@"/file2"];

// Delete
[fileManager removeItemAtPath:@"/path" error:nil];
```

## Security Analysis Patterns

### 1. Extract Class Information

```bash
# Basic dump
class-dump /Applications/Kindle.app/Contents/MacOS/Kindle

# With headers
class-dump -H /path/to/binary > output.h

# Recursive for frameworks
class-dump -r /path/to/framework.framework
```

### 2. Identify Sensitive Methods

Look for methods containing:
- `password`, `credential`, `auth`, `token`
- `key`, `secret`, `private`
- `decrypt`, `encrypt`, `encode`, `decode`
- `file`, `path`, `document`, `home`
- `admin`, `root`, `sudo`, `privilege`

### 3. Find File Operations

Search for `NSFileManager` usage and file paths in:
- `fileExistsAtPath:`
- `copyItemAtPath:toPath:`
- `removeItemAtPath:`
- `contentsEqualAtPath:andPath:`

### 4. Analyze Protocol Implementations

Protocols often indicate:
- Delegation patterns (potential hook points)
- Required vs optional methods (behavior variations)
- Interface contracts (expected behavior)

## Compilation

```bash
# Compile Objective-C file
gcc -framework Foundation test_obj.m -o test_obj

# With clang (recommended)
clang -framework Foundation test_obj.m -o test_obj
```

## Quick Reference

| Task | Command/Pattern |
|------|----------------|
| Dump binary classes | `class-dump <binary>` |
| Create object | `[ClassName new]` |
| Call method | `[object methodName:param]` |
| Access property | `object.property` or `[object property]` |
| Set property | `object.property = value` or `[object setProperty:value]` |
| Check file exists | `[fileManager fileExistsAtPath:path]` |
| Format string | `[NSString stringWithFormat:@"format", args]` |

## Common Pitfalls

1. **Obfuscated names**: Class/method names may be mangled in production binaries
2. **Immutable vs Mutable**: NSString/NSArray/NSDictionary are immutable by default
3. **Memory management**: Modern ARC handles this, but older code may use manual retain/release
4. **Block captures**: Blocks capture variables by reference unless specified otherwise
5. **Protocol conformance**: Classes must explicitly adopt protocols with `<ProtocolName>`

## Next Steps

For deeper analysis:
- Use `otool -tv <binary>` to disassemble methods
- Use `nm <binary>` to list symbols
- Use `lipo -info <binary>` to check architecture
- Use `codesign -dv <binary>` to inspect code signature
