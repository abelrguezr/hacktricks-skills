---
name: macos-memory-inspector
description: Inspect, debug, and analyze macOS/iOS objects in memory using LLDB and Frida. Use this skill whenever the user needs to examine Objective-C or Swift objects at runtime, understand memory layouts, decode type encodings, work with arm64e/PAC pointers, enumerate classes and methods, or perform runtime inspection on macOS applications. Trigger for any task involving memory forensics, reverse engineering, debugging native code, or analyzing object structures in macOS/iOS processes.
---

# macOS Memory Inspector

A skill for inspecting and analyzing macOS/iOS objects in memory using LLDB and Frida. This covers Objective-C, Swift, CFRuntime objects, and modern arm64e considerations.

## When to use this skill

Use this skill when the user needs to:
- Inspect Objective-C or Swift objects at runtime
- Understand memory layouts of macOS objects
- Decode Objective-C type encodings
- Work with arm64e/PAC (Pointer Authentication Code) pointers
- Enumerate classes, methods, and selectors
- Debug or reverse engineer macOS/iOS applications
- Analyze CFRuntimeClass structures
- Use LLDB or Frida for runtime inspection

## Core Concepts

### CFRuntimeClass Structure

CF* objects (CoreFoundation) are instances of `CFRuntimeClass`. Key fields:

| Field | Purpose |
|-------|--------|
| `version` | Bitwise flags for object behavior |
| `className` | ASCII class name |
| `init` | Initializer function |
| `copy` | Copy function |
| `finalize` | Finalizer function |
| `equal` | Equality comparison |
| `hash` | Hash function |
| `copyDebugDesc` | Debug description |
| `refcount` | Custom reference counting |
| `requiredAlignment` | Memory alignment requirements |

### Objective-C Memory Sections

**`__DATA` segment sections:**
- `__objc_msgrefs` - Message references
- `__objc_ivar` - Instance variables
- `__objc_classrefs` - Class references
- `__objc_superrefs` - Superclass references
- `__objc_selrefs` - Selector references
- `__objc_classlist` - All Objective-C classes
- `__objc_catlist` - Categories
- `__objc_nlcatlist` - Non-Lazy Categories

**`__TEXT` segment sections:**
- `__objc_methname` - Method names (C-strings)
- `__objc_classname` - Class names (C-strings)
- `__objc_methtype` - Method type encodings

**Modern macOS (Apple Silicon):**
- `__DATA_CONST` - Immutable metadata (shared read-only)
- `__AUTH` / `__AUTH_CONST` - Pointer Authentication entries
- `__auth_got` - Authenticated GOT entries (replaces legacy `__got`)

### Type Encoding

Objective-C encodes types using single characters:

| Code | Type | Code | Type |
|------|------|------|------|
| `i` | int | `I` | unsigned int |
| `c` | char | `C` | unsigned char |
| `l` | long | `L` | unsigned long |
| `q` | long long | `Q` | unsigned long long |
| `b` | bitfield | `B` | boolean |
| `@` | id (object) | `#` | Class |
| `*` | char * | `^` | generic pointer |
| `:` | SEL (selector) | `?` | undefined |
| `[` | array | `{` | struct |
| `(` | union | | |

**Example:**
```objectivec
- (NSString *)processString:(id)input withOptions:(char *)options andError:(id)error;
```

Type encoding: `@24@0:8@16*20^@24`

Breakdown:
1. `@24` - Return type (NSString *)
2. `@0` - self at offset 0
3. `:8` - _cmd (selector) at offset 8
4. `@16` - input (id) at offset 16
5. `*20` - options (char *) at offset 20
6. `^@24` - error (NSError **) at offset 24

### Modern arm64e Considerations

**Non-pointer isa:**
- On arm64e, the `isa` field is a packed structure, not a raw pointer
- May include PAC (Pointer Authentication Code)
- Fields: `nonpointer`, `has_assoc`, `weakly_referenced`, `extra_rc`, class pointer
- **Never blindly dereference the first 8 bytes** of an Objective-C object

**Strip PAC in LLDB:**
```lldb
(lldb) expr -l objc++ -- #include <ptrauth.h>
(lldb) expr -l objc++ -- void *raw = ptrauth_strip((void*)0xADDR, ptrauth_key_asda);
(lldb) expr -l objc++ -O -- (Class)object_getClass((id)raw)
```

**Tagged Pointers:**
- Some Foundation classes encode payload directly in pointer value
- Detection: MSB on arm64, LSB on x86_64
- No regular `isa` in memory - runtime resolves from tag bits
- **Always use runtime APIs:** `object_getClass(obj)` or `[obj class]`

**Swift Objects:**
- Pure Swift classes use Swift metadata (not Objective-C `isa`)
- Use `swift-inspect` for introspection:
  ```bash
  swift-inspect dump-raw-metadata <pid-or-name>
  swift-inspect dump-arrays <pid-or-name>
  swift-inspect dump-concurrency <pid-or-name>
  ```

## Runtime Inspection Commands

### LLDB Commands

**Print object from raw pointer:**
```lldb
(lldb) expr -l objc++ -O -- (id)0x0000000101234560
(lldb) expr -l objc++ -O -- (Class)object_getClass((id)0x0000000101234560)
```

**Inspect self in breakpoint:**
```lldb
(lldb) br se -n '-[NSFileManager fileExistsAtPath:]'
(lldb) r
(lldb) po (id)$x0
(lldb) expr -l objc++ -O -- (Class)object_getClass((id)$x0)
```

**Dump Objective-C metadata sections:**
```lldb
(lldb) image dump section --section __DATA_CONST.__objc_classlist
(lldb) image dump section --section __DATA_CONST.__objc_selrefs
(lldb) image dump section --section __AUTH_CONST.__auth_got
```

**Read class object memory:**
```lldb
(lldb) image lookup -r -n _OBJC_CLASS_$_NSFileManager
(lldb) memory read -fx -s8 0xADDRESS_OF_CLASS_OBJECT
```

### Frida Scripts

**Enumerate classes and methods:**
```javascript
if (ObjC.available) {
  // List all classes
  console.log(Object.keys(ObjC.classes));
  
  // List a class' own methods
  console.log(ObjC.classes.NSFileManager.$ownMethods);
  
  // List all methods (including inherited)
  console.log(ObjC.classes.NSFileManager.$methods);
}
```

**Intercept method calls:**
```javascript
if (ObjC.available) {
  const impl = ObjC.classes.NSFileManager['- fileExistsAtPath:isDirectory:'].implementation;
  Interceptor.attach(impl, {
    onEnter(args) {
      this.path = new ObjC.Object(args[2]).toString();
      console.log('Called with path:', this.path);
    },
    onLeave(retval) {
      console.log('Result:', retval.toInt32() ? 'true' : 'false');
    }
  });
}
```

**Enumerate selectors:**
```javascript
if (ObjC.available) {
  // Get all selectors
  const selectors = ObjC.classes.NSFileManager.$ownMethods;
  selectors.forEach(sel => {
    console.log('Selector:', sel);
  });
}
```

## Common Tasks

### Task 1: Inspect an Object at Runtime

**LLDB approach:**
1. Set breakpoint on method or use `process attach` to attach to running process
2. Use `po` or `expr` to print the object
3. Use `object_getClass` to get the class
4. Use `image dump section` to find class metadata

**Frida approach:**
1. Attach to process: `frida -U -f com.example.app`
2. Load script to enumerate classes
3. Use `ObjC.Object` to inspect instances

### Task 2: Decode Type Encoding

Given a type encoding string:
1. Parse character by character
2. Map each code to its type
3. Track offsets for method parameters
4. Reconstruct the method signature

### Task 3: Handle arm64e PAC Pointers

1. Check if pointer has PAC bits set
2. Use `ptrauth_strip` to remove authentication
3. Use runtime APIs instead of direct dereferencing
4. Account for `__auth_got` when hooking

### Task 4: Inspect Swift Objects

1. Use `swift-inspect` for non-invasive inspection
2. For Frida, use Swift bridge (requires recent version)
3. Map Swift types to Objective-C equivalents when possible

## Scripts

See the `scripts/` directory for:
- `lldb-inspect-object.py` - LLDB helper for object inspection
- `frida-enum-classes.js` - Frida script to enumerate classes
- `decode-type-encoding.py` - Decode Objective-C type encodings
- `arm64e-pac-stripper.py` - Strip PAC from arm64e pointers

## References

- Apple Open Source: [CFRuntime.h](https://opensource.apple.com/source/CF/CF-1153.18/CFRuntime.h.auto.html)
- Apple Open Source: [objc-runtime-new.h](https://opensource.apple.com/source/objc4/objc4-756.2/runtime/objc-runtime-new.h.auto.html)
- Clang/LLVM: [Pointer Authentication](https://clang.llvm.org/docs/PointerAuthentication.html)
- Frida: [Objective-C Runtime](https://frida.re/docs/javascript-api/#objc)
