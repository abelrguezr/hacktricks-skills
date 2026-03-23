---
name: ios-hooking-with-objection
description: iOS mobile security testing with Objection for runtime hooking and enumeration. Use this skill whenever the user needs to analyze iOS apps, enumerate classes/methods, hook functions, or modify runtime behavior on iOS devices. Trigger for iOS pentesting, mobile app security assessment, Frida/Objection usage, or any iOS runtime manipulation tasks.
---

# iOS Hooking with Objection

This skill guides you through iOS mobile application security testing using [Objection](https://github.com/sensepost/objection), a runtime mobile exploration toolkit powered by Frida.

## Prerequisites

- iOS device (jailbroken or with sideloaded app)
- Objection installed on your testing machine
- Frida server running on the target device
- Target iOS app installed

## Getting Started

### Start an Objection Session

Connect to the device and explore the target app:

```bash
# Connect to device and explore a specific app by gadget name
objection -d --gadget "iGoat-Swift" explore
objection -d --gadget "OWASP.iGoat-Swift" explore

# Check running processes on the device
frida-ps -Uia
```

## Basic Enumeration

### Find Application Paths

Use `env` to discover where the application stores data on the device:

```bash
env
```

This reveals:
- **BundlePath**: Application bundle location
- **CachesDirectory**: App cache storage
- **DocumentDirectory**: App documents storage
- **LibraryDirectory**: App library storage

### List Bundles, Frameworks, and Libraries

**List application bundles:**
```bash
ios bundles list_bundles
```

**List external frameworks:**
```bash
ios bundles list_frameworks
```

**List loaded modules in memory:**
```bash
memory list modules
```

**List exports of a specific module:**
```bash
memory list exports <module_name>
```

### Enumerate Classes

**List all classes in the app:**
```bash
ios hooking list classes
```

**Search for classes by name pattern:**
```bash
ios hooking search classes <search_term>
```

*Tip: Search for unique terms related to the app's package name to find main application classes.*

### Enumerate Methods

**List methods of a specific class:**
```bash
ios hooking list class_methods <class_name>
```

**Search for methods by name pattern:**
```bash
ios hooking search methods <search_term>
```

## Basic Hooking

After enumeration, you'll have identified interesting classes and methods to hook.

### Hook All Methods of a Class

Watch all methods in a class, dumping parameters and return values:

```bash
ios hooking watch class <class_name>
```

### Hook a Single Method

Hook a specific method with detailed output:

```bash
ios hooking watch method "-[<class_name> <method_name>]" --dump-args --dump-return --dump-backtrace
```

**Example:**
```bash
ios hooking watch method "-[iGoat_Swift.BinaryCookiesExerciseVC verifyItemPressed]" --dump-args --dump-backtrace --dump-return
```

### Modify Return Values

Force a method to return a specific boolean value:

```bash
ios hooking set return_value "-[<class_name> <method_name>]" <true|false>
```

**Example:**
```bash
ios hooking set return_value "-[iGoat_Swift.BinaryCookiesExerciseVC verifyItemPressed]" false
```

### Generate Hooking Template

Create a Frida script template for a class:

```bash
ios hooking generate simple <class_name>
```

This generates a JavaScript template you can customize for advanced hooking scenarios.

## Common Workflow

1. **Connect and explore**: Start objection session with target app
2. **Enumerate**: List bundles, frameworks, classes, and methods
3. **Identify targets**: Search for classes/methods related to sensitive operations
4. **Hook and observe**: Watch methods to understand behavior
5. **Modify behavior**: Change return values to bypass checks or test logic
6. **Generate scripts**: Create custom Frida scripts for complex scenarios

## Method Signature Format

iOS methods use Objective-C syntax:
- **Instance methods**: `-[ClassName methodName]` or `-[ClassName methodName:]`
- **Class methods**: `+[ClassName methodName]` or `+[ClassName methodName:]`

## Tips

- Use `search classes` and `search methods` to quickly find relevant code
- Start with `watch class` to get an overview before targeting specific methods
- Use `--dump-backtrace` to understand call context
- Generate templates for reusable custom hooks
- Always test hooks in a controlled environment

## Troubleshooting

- If `frida-ps -Uia` shows no processes, verify Frida server is running on device
- If gadget name is unknown, use `frida-ps -Uia` to find the correct bundle identifier
- For complex hooking, generate a template and customize it rather than using interactive commands
