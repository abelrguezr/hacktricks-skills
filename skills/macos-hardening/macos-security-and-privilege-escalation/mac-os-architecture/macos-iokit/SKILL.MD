---
name: macos-iokit-analysis
description: Use this skill whenever analyzing macOS kernel drivers, IOKit vulnerabilities, or reverse engineering macOS kernel extensions. Trigger for any macOS security research involving IOKit, driver analysis, IORegistry inspection, kernel extension investigation, or when the user mentions macOS drivers, KEXT files, IOKit services, or kernel-level security analysis. Also use when investigating recent macOS CVEs related to IOKit (IOHIDFamily, IOGPUFamily, etc.) or when the user needs to enumerate driver selectors, inspect IORegistry, or understand IOKit communication patterns.
---

# macOS IOKit Analysis

A skill for analyzing macOS IOKit drivers, understanding kernel extension architecture, and investigating IOKit-related vulnerabilities.

## What is IOKit

IOKit is an open-source, object-oriented **device-driver framework** in the XNU kernel that handles **dynamically loaded device drivers**. It allows modular code to be added to the kernel on-the-fly, supporting diverse hardware.

**Key characteristics:**
- IOKit drivers **export functions from the kernel** with predefined, verified parameter types
- Built on top of **Mach messages** (similar to XPC)
- Written in **C++**
- User-space components are open source, but **no IOKit drivers are open source**

**Source code locations:**
- Kernel IOKit: https://github.com/apple-oss-distributions/xnu/tree/main/iokit
- User-space IOKit: https://github.com/opensource-apple/IOKitUser

## Driver Locations

### macOS
- **`/System/Library/Extensions`** - KEXT files built into the OS
- **`/Library/Extensions`** - KEXT files installed by 3rd party software

### iOS
- **`/System/Library/Extensions`**

## Core Commands

### List Loaded Drivers

```bash
# Print all loaded kernel extensions
kextstat

# Search by full bundle-id
kextfind -bundle-id com.apple.iokit.IOReportFamily

# Search by substring in bundle-id
kextfind -bundle-id -substring IOR
```

### Load/Unload Extensions

```bash
kextload com.apple.iokit.IOReportFamily
kextunload com.apple.iokit.IOReportFamily
```

### Inspect IORegistry

```bash
# List all registry entries
ioreg -l

# Don't cut lines
ioreg -w 0

# Check specific plane
ioreg -p <plane>
```

**Common IORegistry planes:**
- **IOService Plane** - General service objects, provider-client relationships
- **IODeviceTree Plane** - Physical device connections (USB, PCI hierarchy)
- **IOPower Plane** - Power management relationships
- **IOUSB Plane** - USB device hierarchy
- **IOAudio Plane** - Audio device relationships

## Demangling C++ Symbols

IOKit is written in C++. Use these commands to get readable symbols:

```bash
# Get demangled symbols from a driver
nm -C com.apple.driver.AppleJPEGDriver

# Demangle symbols from stdin
c++filt
```

Example transformation:
```
__ZN16IOUserClient202222dispatchExternalMethodEjP31IOExternalMethodArgumentsOpaquePK28IOExternalMethodDispatch2022mP8OSObjectPv
↓
IOUserClient2022::dispatchExternalMethod(unsigned int, IOExternalMethodArgumentsOpaque*, IOExternalMethodDispatch2022 const*, unsigned long, OSObject*, void*)
```

## Driver Communication Pattern

User-space code connects to IOKit services using this pattern:

1. **`IOServiceMatching()`** - Create matching dictionary for service name
2. **`IOServiceGetMatchingServices()`** - Get iterator over matching services
3. **`IOServiceOpen()`** - Establish connection to service
4. **`IOConnectCallScalarMethod()`** - Call a function by selector number

**Important:** You call functions by **selector number**, not by name. The selector is the index in the driver's external method dispatch array.

### Available Call Functions

- `IOConnectCallScalarMethod` - For scalar arguments
- `IOConnectCallMethod` - For buffer arguments
- `IOConnectCallStructMethod` - For struct arguments

## Reversing Driver Entrypoints

### Step 1: Get Driver from Firmware

Extract KEXT files from IPSW firmware images to get drivers with symbols for debugging.

### Step 2: Find dispatchExternalMethod

Load the driver into a decompiler and locate the `dispatchExternalMethod` function. This is the entry point that receives user-space calls.

**Function signature:**
```cpp
IOUserClient2022::dispatchExternalMethod(
    uint32_t selector,
    IOExternalMethodArgumentsOpaque *arguments,
    const IOExternalMethodDispatch2022 dispatchArray[],
    size_t dispatchArrayCount,
    OSObject * target,
    void * reference
)
```

### Step 3: Define IOExternalMethodDispatch2022 Struct

The dispatch array structure is open source:
https://github.com/apple-oss-distributions/xnu/blob/main/iokit/IOKit/IOUserClient.h

Define this struct in your decompiler to properly interpret the dispatch array.

### Step 4: Enumerate Exported Functions

The dispatch array contains all exported functions. Each element corresponds to a selector:
- Selector 0 → First function in array
- Selector 1 → Second function in array
- etc.

## Recent IOKit Attack Surface (2023-2025)

### CVE-2024-27799 (IOHIDFamily)
- **Issue:** Permissive `IOHIDSystem` client could grab HID events even with secure input
- **Fix:** Ensure `externalMethod` handlers enforce entitlements, not just user-client type
- **Impact:** Keystroke capture via sandboxed apps

### CVE-2024-44197 & CVE-2025-24257 (IOGPUFamily)
- **Issue:** OOB writes from malformed variable-length data to GPU user clients
- **Root cause:** Poor bounds checking around `IOConnectCallStructMethod` arguments
- **Impact:** Memory corruption from sandboxed apps

### CVE-2023-42891 (IOHIDFamily)
- **Issue:** HID user clients remain a sandbox-escape vector
- **Recommendation:** Fuzz any driver exposing keyboard/event queues

## Quick Triage & Fuzzing Tips

### 1. Enumerate Selectors from Userland

Use the `enumerate_iokit_selectors.py` script to list all external methods for a service:

```bash
python3 scripts/enumerate_iokit_selectors.py --service IOHIDSystem
```

### 2. Check Sandbox Reachability

Before targeting a driver, verify if it's accessible from third-party apps:

```bash
strings /System/Library/Extensions/IOHIDFamily.kext/Contents/MacOS/IOHIDFamily | \
  grep -E "^com\.apple\.(driver|private)"
```

### 3. Common Bug Patterns

- **Inconsistent size fields:** `structureInputSize`/`structureOutputSize` vs. actual `copyin` length → heap OOB
- **Missing entitlement checks:** Only checking user-client type, not entitlements
- **Bounds confusion:** Passing oversized arrays through `IOConnectCallMethod`

### 4. Minimal Fuzzing Harness

For GPU/iomfb bugs, oversized arrays often trigger bounds issues:

```c
uint8_t buf[0x1000];
size_t outSz = sizeof(buf);
IOConnectCallStructMethod(conn, X, buf, sizeof(buf), buf, &outSz);
```

## Analysis Workflow

When investigating an IOKit driver:

1. **Identify the driver** - Use `kextstat` and `kextfind` to locate it
2. **Check IORegistry** - Use `ioreg` to understand service relationships
3. **Extract from firmware** - Get symbolicated version from IPSW
4. **Reverse dispatchExternalMethod** - Find the entry point and dispatch array
5. **Enumerate selectors** - List all exported functions
6. **Check entitlements** - Verify sandbox reachability
7. **Look for CVE patterns** - Compare against known vulnerability patterns
8. **Build test harness** - Create user-space code to call selectors

## Scripts

Use the bundled scripts for common tasks:

- `scripts/enumerate_iokit_selectors.py` - List driver selectors from userland
- `scripts/list_kexts.py` - Enhanced kextstat with filtering
- `scripts/demangle_symbols.py` - Batch demangle C++ symbols

## References

- Apple Security Updates: https://support.apple.com/en-us/121564
- Rapid7 CVE-2024-27799: https://www.rapid7.com/db/vulnerabilities/apple-osx-iohidfamily-cve-2024-27799/
- XNU IOKit Source: https://github.com/apple-oss-distributions/xnu/tree/main/iokit
- IORegistryExplorer: https://developer.apple.com/download/all/
