---
name: frida-android-hooking
description: Use Frida to hook Android methods, bypass security checks, brute-force functions, and intercept arguments/return values. Use this skill whenever the user mentions Android pentesting, Frida, Java hooking, method interception, PIN bypass, encryption analysis, or needs to modify Android app behavior at runtime. Also trigger for Android 14/15/16 compatibility issues, Zygisk stealth injection, or when analyzing APK security.
---

# Frida Android Hooking

A skill for using Frida to hook Android methods, bypass security checks, and analyze app behavior at runtime.

## Quick Start

### Basic Hooking Setup

```bash
# Attach to running app
frida -U -l hook.js -f com.example.app --no-pause

# Or use Python wrapper
python scripts/hooking.py hook.js
```

### Python Wrapper Script

Use `scripts/hooking.py` to load any JavaScript hook file:

```bash
python scripts/hooking.py <hook-file.js>
```

This script:
- Reads JavaScript from file
- Attaches to USB device
- Loads the script
- Keeps connection open

## Hooking Patterns

### 1. Boolean Bypass

Bypass boolean checks (PIN validation, license checks, etc.):

```javascript
Java.perform(function () {
  var TargetClass = Java.use("com.example.ClassName")
  TargetClass.checkMethod.implementation = function (arg) {
    console.log("[+] Bypassed check")
    return true  // Always return true
  }
})
```

**Use case:** PIN validation, license verification, flag checks

### 2. Function Brute-Force

#### Static Functions

```javascript
Java.perform(function () {
  var TargetClass = Java.use("com.example.ClassName")
  
  for (var i = 1000; i < 9999; i++) {
    if (TargetClass.checkPin(i + "") == true) {
      console.log("[+] Found: " + i)
      break
    }
  }
})
```

#### Non-Static Functions

```javascript
Java.perform(function () {
  Java.choose("com.example.ClassName", {
    onMatch: function (instance) {
      // Use instance to call non-static methods
      instance.checkMethod(arg)
    },
    onComplete: function () {}
  })
})
```

**Note:** `Java.choose` requires an existing instance in memory. For static functions, use `Java.use` directly.

### 3. Intercept Arguments and Return Values

Log what goes in and out of a function:

```javascript
Java.perform(function () {
  var TargetClass = Java.use("com.example.ClassName")
  
  TargetClass.targetMethod.implementation = function (arg1, arg2) {
    console.log("Input arg1: " + arg1)
    console.log("Input arg2: " + arg2)
    
    var result = this.targetMethod(arg1, arg2)  // Call original
    
    console.log("Return value: " + result)
    return result
  }
})
```

**Use case:** Encryption analysis, API key extraction, data flow tracing

### 4. Handle Method Overloads

When multiple methods share the same name, specify argument types:

```javascript
var TargetClass = Java.use("com.example.ClassName")

// Select specific overload
TargetClass.methodName.overload('java.lang.String', 'int').implementation = function(s, i) {
  return this.methodName(s, i)
}
```

## Modern Android (14/15/16)

### Compatibility Requirements

- **Frida 17.1.5+** required for stable Java hooking on Android 14+
- Upgrade `frida-server`, `frida-gadget`, and CLI/Python packages

### Spawn Mode for Anti-Debug Bypass

Some apps die before `attach`. Use spawn mode:

```bash
frida -U -f com.example.app -l hook.js --no-pause
```

This loads hooks before `onCreate()` runs.

### Zygisk Stealth Injection

For apps with ptrace/Frida detection:

1. Install Zygisk gadget module (e.g., `zygisk-gadget`)
2. Configure target package:
   ```bash
   adb shell "su -c 'echo com.example.app,5000 > /data/local/tmp/re.zyg.fri/target_packages'"
   ```
3. Attach to gadget:
   ```bash
   frida -U -n Gadget -l hook.js
   ```

**Benefits:**
- No ptrace detection
- APK integrity checks pass
- Bypasses basic Frida string checks

## Common Targets

| Target | Class Pattern | Use Case |
|--------|--------------|----------|
| PIN Validation | `*.utils.PinUtil` | Bypass PIN checks |
| Encryption | `*.utils.EncryptionUtil` | Extract keys, analyze crypto |
| License | `*.License*` | Bypass license verification |
| Network | `*.Network*`, `*.Api*` | Intercept API calls |
| Storage | `*.Storage*`, `*.Prefs*` | Access saved data |

## Debugging Tips

### Hook Not Triggering?

1. Check class name is correct (use `frida-trace` to discover)
2. Try spawn mode (`-f` flag)
3. Verify Frida version >= 17.1.5 for Android 14+
4. Check for anti-debug checks

### Java.choose Returns Nothing?

- Instance may not exist yet (spawn mode helps)
- Try `Java.use` for static methods
- Upgrade Frida for Android 14+

### App Crashes on Attach?

- Anti-debug detection active
- Use Zygisk gadget for stealth
- Add delay in spawn mode

## Script Files

- `scripts/hooking.py` - Python wrapper for loading hooks
- `scripts/hook1.js` - Boolean bypass example
- `scripts/hook2.js` - Brute-force example
- `scripts/hook3.js` - Argument interception example

## References

- [Frida Documentation](https://frida.re/docs/)
- [Frida News (Android 14-16 fixes)](https://frida.re/news/)
- [zygisk-gadget](https://github.com/hackcatml/zygisk-gadget)
