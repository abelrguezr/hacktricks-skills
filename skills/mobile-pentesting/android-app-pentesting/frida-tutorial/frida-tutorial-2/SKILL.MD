---
name: frida-android-pentesting
description: How to use Frida for Android app security testing and reverse engineering. Use this skill whenever the user needs to hook Android Java methods, intercept function calls, modify runtime behavior, find class instances, or create Python-Frida automation scripts. Trigger for any Android pentesting task involving Frida, Java method hooking, runtime instrumentation, or dynamic analysis of APKs.
---

# Frida Android Pentesting

A skill for performing dynamic analysis and security testing on Android applications using Frida.

## Core Concepts

Frida is a dynamic instrumentation toolkit that lets you inject JavaScript into running processes. For Android, this means you can hook Java methods, intercept calls, modify behavior, and extract data at runtime.

## Quick Start

### Basic Setup

1. **Install Frida on your machine:**
   ```bash
   pip install frida frida-tools
   ```

2. **Install Frida Server on the Android device:**
   ```bash
   adb push frida-server-<version>-android-x86 /data/local/tmp/frida-server
   adb shell chmod 755 /data/local/tmp/frida-server
   adb shell /data/local/tmp/frida-server &
   ```

3. **Connect and spawn the target app:**
   ```bash
   frida-ps -U  # List running processes
   frida -U -f com.example.targetapp -l hook.js -H 127.0.0.1:27042
   ```

## Hooking Patterns

### Pattern 1: Hook Methods with Overloads

When a method has multiple overloads (same name, different parameters), you must specify which one to hook:

```javascript
Java.perform(function() {
    var myClass = Java.use("com.example.target.MyClass");
    
    // Hook method with specific parameter types
    myClass.methodName.overload("int", "int").implementation = function(a, b) {
        console.log("Hooked: methodName(" + a + ", " + b + ")");
        // Call original with modified parameters
        return this.methodName(10, 20);
    };
    
    // Hook method with String parameter
    myClass.methodName.overload("java.lang.String").implementation = function(str) {
        console.log("Original string: " + str);
        return this.methodName("modified value");
    };
});
```

### Pattern 2: Find and Call Class Instances

Use `Java.choose()` to find instances of a class and call methods on them:

```javascript
Java.perform(function() {
    Java.choose("com.example.target.MyClass", {
        onMatch: function(instance) {
            console.log("Found instance: " + instance);
            // Call a method on the instance
            var result = instance.privateMethod();
            console.log("Result: " + result);
        },
        onComplete: function() {
            console.log("Search complete");
        }
    });
});
```

### Pattern 3: Create New Objects

To create new Java objects in Frida:

```javascript
Java.perform(function() {
    var stringClass = Java.use("java.lang.String");
    var newString = stringClass.$new("My custom string");
    
    // Or for other classes
    var myClass = Java.use("com.example.target.MyClass");
    var instance = myClass.$new();
});
```

### Pattern 4: Expose Functions to Python

Use `rpc.exports` to make JavaScript functions callable from Python:

```javascript
function myHookFunction() {
    Java.perform(function() {
        var myClass = Java.use("com.example.target.MyClass");
        myClass.secretMethod.overload().implementation = function() {
            return "hacked value";
        };
    });
}

function callInstanceMethod() {
    Java.perform(function() {
        Java.choose("com.example.target.MyClass", {
            onMatch: function(instance) {
                console.log(instance.privateMethod());
            }
        });
    });
}

rpc.exports = {
    myHookFunction: myHookFunction,
    callInstanceMethod: callInstanceMethod
};
```

### Pattern 5: Python-JS Communication

Bidirectional communication using `send()` and `recv()`:

**JavaScript side:**
```javascript
Java.perform(function() {
    var textViewClass = Java.use("android.widget.TextView");
    textViewClass.setText.overload("java.lang.CharSequence").implementation = function(text) {
        // Send data to Python
        send(text.toString());
        
        // Wait for response from Python
        var response = recv(function(msg) {
            return msg.modified_data;
        }).wait();
        
        console.log("Received: " + response);
        return this.setText(response);
    };
});
```

**Python side:**
```python
import frida
import base64
import time

def message_handler(message, data):
    if message["type"] == "send":
        payload = message["payload"]
        # Process and respond
        modified = payload.replace("old", "new")
        script.post({"modified_data": modified})

device = frida.get_usb_device()
pid = device.spawn(["com.example.target"])
device.resume(pid)
time.sleep(1)  # Critical: Java.perform needs time to initialize
session = device.attach(pid)
script = session.create_script(open("hook.js").read())
script.on("message", message_handler)
script.load()
```

## Python Loader Template

Use this as a starting point for Frida automation:

```python
#!/usr/bin/env python3
import frida
import time
import sys

def main():
    if len(sys.argv) < 2:
        print("Usage: python loader.py <package_name>")
        sys.exit(1)
    
    package_name = sys.argv[1]
    
    # Get USB device
    device = frida.get_usb_device()
    
    # Spawn the app (or attach to running process)
    pid = device.spawn([package_name])
    device.resume(pid)
    
    # Wait for Java VM to initialize
    time.sleep(2)
    
    # Attach and load script
    session = device.attach(pid)
    script = session.create_script(open("hook.js").read())
    
    # Optional: Add message handler
    def message_handler(message, data):
        print(f"[+] {message}")
    
    script.on("message", message_handler)
    script.load()
    
    # Keep script running
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\n[!] Stopping...")
        script.unload()

if __name__ == "__main__":
    main()
```

## Common Use Cases

### Intercepting Sensitive Data

```javascript
Java.perform(function() {
    // Hook SharedPreferences
    var prefs = Java.use("android.content.SharedPreferences");
    prefs.getString.overload("java.lang.String", "java.lang.String").implementation = function(key, def) {
        console.log("SharedPreferences.get: " + key);
        return this.getString(key, def);
    };
    
    // Hook network calls
    var urlConnection = Java.use("java.net.HttpURLConnection");
    urlConnection.connect.overload().implementation = function() {
        console.log("URL: " + this.getURL());
        return this.connect();
    };
});
```

### Bypassing SSL Pinning

```javascript
Java.perform(function() {
    var X509TrustManager = Java.use("javax.net.ssl.X509TrustManager");
    var trustAll = {
        checkClientTrusted: function(chain, authType) {},
        checkServerTrusted: function(chain, authType) {},
        getAcceptedIssuers: function() { return []; }
    };
    
    var TrustManagerImpl = Java.use("com.android.org.conscrypt.TrustManagerImpl");
    TrustManagerImpl.checkServerTrusted.overload(
        "[Ljavax.net.ssl.X509Certificate;", "java.lang.String"
    ).implementation = function(chain, authType) {
        trustAll.checkServerTrusted(chain, authType);
    };
});
```

### Logging All Method Calls

```javascript
Java.perform(function() {
    var myClass = Java.use("com.example.target.MyClass");
    
    // Hook all methods
    for (var method in myClass) {
        if (typeof myClass[method] === 'object') {
            myClass[method].overload().implementation = function() {
                console.log("Called: " + method + " with args: " + arguments);
                return myClass[method].overload().apply(this, arguments);
            };
        }
    }
});
```

## Best Practices

1. **Always use `Java.perform()`** - Ensures code runs on the Java VM thread
2. **Add `time.sleep(1)` in Python** - Java.perform silently fails without it
3. **Handle overloads explicitly** - Don't assume single overload
4. **Use `this.methodName()`** - To call the original method
5. **Store instances in arrays** - For repeated access to found instances
6. **Use `rpc.exports`** - For interactive control from Python
7. **Test on debug builds first** - Release builds may have obfuscation

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `Java.perform silently fails` | Add `time.sleep(1)` after `device.resume()` |
| `Class not found` | Check package name, use `frida-ps -U` to verify process |
| `Method not found` | Use `frida-trace` to discover method signatures |
| `Script won't load` | Check Frida server is running on device |
| `Connection refused` | Verify device is connected via USB and ADB works |

## Tools

- `frida-ps` - List processes
- `frida-trace` - Trace function calls
- `frida-ls` - List classes and methods
- `frida-decrypt` - Decrypt obfuscated strings

## References

- [Frida Documentation](https://frida.re/docs/)
- [Frida Android Examples](https://github.com/11x256/frida-android-examples)
- [HackTricks Frida Training](https://book.hacktricks.xyz/pentesting-mobile/android-app-pentesting/frida-tutorial)
