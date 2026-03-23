---
name: macos-sandbox-debug
description: Create and debug sandboxed macOS applications for security research and testing. Use this skill whenever the user mentions macOS sandboxing, app entitlements, codesigning, creating sandboxed apps, testing macOS security protections, privilege escalation research, or needs to build a macOS app bundle with specific sandbox permissions. This is for legitimate security research, penetration testing, and understanding macOS security mechanisms.
---

# macOS Sandbox Debug

A skill for creating sandboxed macOS applications to test and understand macOS security protections. This is designed for security researchers, penetration testers, and developers who need to understand how the macOS sandbox works.

## What this skill does

This skill helps you create a minimal sandboxed macOS application that can execute arbitrary commands within the sandbox. This is useful for:

- Testing macOS sandbox restrictions
- Understanding what the default sandbox allows
- Security research and penetration testing
- Learning about macOS app signing and entitlements

## Quick Start

The fastest way to create a sandboxed app is to use the bundled scripts:

```bash
# Create a sandboxed app with default permissions
./scripts/create-sandboxed-app.sh

# Or with downloads folder access
./scripts/create-sandboxed-app.sh --with-downloads
```

This will create `SandboxedShellApp.app` ready to sign and run.

## Manual Process

If you need to understand or customize the process, here's the full workflow:

### Step 1: Create the Application Code

Create a simple Objective-C program that runs commands:

```objectivec
// main.m
#include <Foundation/Foundation.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        while (true) {
            char input[512];

            printf("Enter command to run (or 'exit' to quit): ");
            if (fgets(input, sizeof(input), stdin) == NULL) {
                break;
            }

            // Remove newline character
            size_t len = strlen(input);
            if (len > 0 && input[len - 1] == '\n') {
                input[len - 1] = '\0';
            }

            if (strcmp(input, "exit") == 0) {
                break;
            }

            system(input);
        }
    }
    return 0;
}
```

**Why this approach**: We use a simple shell loop because it lets us test arbitrary commands interactively. The `system()` call runs commands through `/bin/sh`, which is what we want to test sandbox restrictions against.

### Step 2: Compile the Application

```bash
clang -framework Foundation -o SandboxedShellApp main.m
```

**Why clang with Foundation**: macOS apps need the Foundation framework for basic Cocoa functionality. The `-framework` flag links it properly.

### Step 3: Build the .app Bundle

macOS applications are actually directories with a specific structure:

```bash
mkdir -p SandboxedShellApp.app/Contents/MacOS
mv SandboxedShellApp SandboxedShellApp.app/Contents/MacOS/
```

Create the Info.plist (required for any macOS app):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.example.SandboxedShellApp</string>
    <key>CFBundleName</key>
    <string>SandboxedShellApp</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>SandboxedShellApp</string>
</dict>
</plist>
```

**Why the bundle structure**: macOS expects apps to be bundles (directories with `.app` extension). The `Contents/MacOS/` directory holds the executable, and `Contents/Info.plist` describes the app to the system.

### Step 4: Define Entitlements

Entitlements control what the sandboxed app can do. Choose based on your testing needs:

#### Default Sandbox (Most Restrictive)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
</dict>
</plist>
```

This enables the sandbox with minimal permissions. The app can only access its own container and a few system resources.

#### Sandbox + Downloads Folder

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>
</dict>
</plist>
```

This adds read-write access to the user's Downloads folder, useful for testing file access restrictions.

**Why entitlements matter**: Each entitlement grants specific capabilities. The default sandbox is very restrictive - you can't access arbitrary files, network, or system resources. Adding entitlements lets you test what happens when you grant specific permissions.

### Step 5: Sign the Application

```bash
# Sign with your development certificate
codesign --entitlements entitlements.plist -s "Your Identity" SandboxedShellApp.app

# Run the app
./SandboxedShellApp.app/Contents/MacOS/SandboxedShellApp
```

**Why signing is required**: macOS requires all sandboxed apps to be signed. The signature proves the app hasn't been tampered with and identifies who created it.

**Getting a certificate**: You need a development certificate in your keychain. Create one via Keychain Access or use the default "Apple Development" certificate if you have an Apple Developer account.

### Step 6: Test the Sandbox

Run the app and try various commands:

```bash
$ ./SandboxedShellApp.app/Contents/MacOS/SandboxedShellApp
Enter command to run (or 'exit' to quit): ls
Enter command to run (or 'exit' to quit): whoami
Enter command to run (or 'exit' to quit): cat /etc/passwd
Enter command to run (or 'exit' to quit): exit
```

**What to test**:
- File access: Try reading files outside the app container
- Network: Try `curl` or `ping`
- System commands: Try `sudo`, `su`, or accessing system directories
- Process listing: Try `ps` to see what processes are visible

## Common Sandbox Restrictions

The default sandbox blocks:

- Access to files outside the app's container
- Network access (unless you add network entitlements)
- Access to most system directories
- Inter-process communication with other apps
- Hardware access (camera, microphone, etc.)

## Troubleshooting

### "App is damaged" error

```bash
codesign --remove-signature SandboxedShellApp.app
codesign --entitlements entitlements.plist -s "Your Identity" SandboxedShellApp.app
```

### "App can't be opened" error

The app may need to be notarized for Gatekeeper. For local testing, you can right-click and "Open" to bypass.

### Certificate not found

Check available certificates:

```bash
security find-identity -v -p codesigning
```

## Security Research Tips

When testing sandbox escapes:

1. **Start with the default sandbox** - Understand baseline restrictions first
2. **Add one entitlement at a time** - See what each permission enables
3. **Test edge cases** - Symlinks, pipes, shared memory, etc.
4. **Check system logs** - `log show --predicate 'process == "SandboxedShellApp"'` shows sandbox violations
5. **Use sandbox-debugger** - macOS has built-in tools to analyze sandbox profiles

## Important Notes

- This skill is for **legitimate security research and testing only**
- Always test on systems you own or have permission to test
- The sandbox is a security feature - understanding it helps improve security
- Real-world apps should request only the minimum permissions they need

## References

- [Apple App Sandbox Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/AppSandboxDesignGuide/)
- [Entitlement Keys Reference](https://developer.apple.com/documentation/bundleresources/entitlements/)
- [codesign man page](https://ss64.com/mac/codesign.html)
