---
name: macos-kext-analysis
description: How to analyze macOS kernel extensions (Kexts), extract and inspect kernelcaches, enumerate loaded kexts, debug kernel panics, and identify kernel-level security issues. Use this skill whenever the user mentions kernel extensions, kexts, kernelcache, macOS kernel debugging, KDK, kmutil, kextstat, kernel vulnerabilities, SIP bypass, or any macOS kernel-level security analysis. Make sure to use this skill for any macOS security research, kernel extension management, or kernel debugging tasks.
---

# macOS Kernel Extension Analysis

A skill for analyzing macOS kernel extensions, extracting kernelcaches, debugging kernel panics, and identifying kernel-level security issues.

## When to Use This Skill

Use this skill when the user needs to:
- Enumerate or manage loaded kernel extensions on macOS
- Extract and analyze kernelcaches from IPSW or local systems
- Debug kernel panics or attach to running kernel extensions
- Research kernel extension vulnerabilities or SIP bypasses
- Work with KDK (Kernel Debug Kit) for kernel debugging
- Analyze macOS kernel security configurations

## Core Concepts

### Kernel Extensions (Kexts)

Kernel extensions are packages with `.kext` extension loaded directly into macOS kernel space. Key facts:

- **Deprecated**: Most legacy KPIs deprecated in macOS Catalina (10.15)
- **System Extensions**: Apple introduced DriverKit/System Extensions running in user-space
- **Big Sur+**: Third-party kexts with deprecated KPIs require Reduced Security mode
- **Apple Silicon**: Requires Recovery → Startup Security Utility → Reduced Security

### Kernelcache

Pre-compiled, pre-linked XNU kernel with drivers and kexts:
- Stored compressed, decompressed at boot
- Faster boot time, modules prelinked
- Once loaded, XNU cannot load new KEXTs
- Located in `/System/Volumes/Preboot/*/boot/*/System/Library/Caches/com.apple.kernelcaches/kernelcache`

## Enumeration & Management

### List Loaded Kexts

```bash
# Modern tool (preferred)
sudo kmutil showloaded --sort

# Third-party only
sudo kmutil showloaded --collection aux

# Deprecated but still works
kextstat
```

### Unload a Kext

```bash
sudo kmutil unload -b com.example.mykext
```

### Inspect Kernel Collections

```bash
# List fileset entries in boot KC
kmutil inspect -B /System/Library/KernelCollections/BootKernelExtensions.kc --show-fileset-entries

# Check undefined symbols before loading
kmutil libraries -p /Library/Extensions/FancyUSB.kext --undef-symbols
```

## Kernelcache Extraction

### Find Local Kernelcache

```bash
find / -name "kernelcache" 2>/dev/null
```

### Extract from IPSW

```bash
# Install ipsw tool
brew install blacktop/tap/ipsw

# Extract kernelcache from IPSW
ipsw extract --kernel /path/to/firmware.ipsw -o out/

# If IMG4 payload, extract it
ipsw img4 im4p extract out/Firmware/kernelcache*.im4p -o kcache.raw
```

### Decompress IMG4 Format

```bash
# Using img4tool
img4tool -e kernelcache.release.iphone14 -o kernelcache.release.iphone14.e

# Using pyimg4
pyimg4 im4p extract -i kernelcache.release.iphone14 -o kernelcache.release.iphone14.e

# Using disarm (direct on IMG4)
disarm -L kernelcache.release.v57
```

### Extract Kexts from Kernelcache

```bash
# List all extensions
kextex -l kernelcache.release.iphone14.e

# Extract specific kext
kextex -e com.apple.security.sandbox kernelcache.release.iphone14.e

# Extract all
kextex_all kernelcache.release.iphone14.e
```

### Check for Symbols

```bash
nm -a kernelcache.release.iphone14.e | wc -l
nm -a ~/Downloads/Sandbox.kext/Contents/MacOS/Sandbox | wc -l
```

### Symbolicate with Disarm

```bash
# Extract filesets
disarm -e filesets kernelcache.release.d23

# Analyze with matchers
cd /tmp/extracted
JMATCHERS=xnu.matchers disarm --analyze kernel.rebuilt
```

## Debugging

### One-Shot Panic Analysis

```bash
# Create symbolication bundle for latest panic
sudo kdpwrit dump latest.kcdata
kmutil analyze-panic latest.kcdata -o ~/panic_report.txt
```

### Live Remote Debugging

1. **Download KDK** matching target build
2. **Connect** target and host via USB-C/Thunderbolt
3. **On target**:
   ```bash
   sudo nvram boot-args="debug=0x100 kdp_match_name=macbook-target"
   reboot
   ```
4. **On host**:
   ```bash
   lldb
   (lldb) kdp-remote "udp://macbook-target"
   (lldb) bt
   ```

### Attach LLDB to Loaded Kext

```bash
# Get load address
ADDR=$(kmutil showloaded --bundle-identifier com.example.driver | awk '{print $4}')

# Attach
sudo lldb -n kernel_task -o "target modules load --file /Library/Extensions/Example.kext/Contents/MacOS/Example --slide $ADDR"
```

## Security Analysis

### Check Entitled Daemons

```bash
codesign -dvv /path/to/binary | grep entitlements
```

Look for:
- `com.apple.rootless.install` - can execute post-install scripts
- `com.apple.private.security.kext-management` - can load kexts

### Monitor Kext Loading

```bash
# Alert on writes to Extensions directory
# Monitor kmutil load/create invocations
# Endpoint Security: ES_EVENT_TYPE_NOTIFY_KEXTLOAD
```

### Known Vulnerabilities

| CVE | Summary |
|-----|--------|
| CVE-2024-44243 | storagekitd logic flaw allowed unsigned kext loading, bypassing SIP |
| CVE-2021-30892 | Shrootless - entitled daemon abuse to disable SIP and load kexts |

## Resources

### Download Sources

- **KernelDebugKit**: https://github.com/dortania/KdkSupportPkg/releases
- **Firmware with symbols**: https://theapplewiki.com/wiki/Firmware/Mac/14.x
- **IPSW archives**: https://ipsw.me/, https://www.theiphonewiki.com/

### Tools

- **img4tool**: https://github.com/tihmstar/img4tool
- **pyimg4**: https://github.com/m1stadev/PyIMG4
- **disarm**: https://newandroidbook.com/tools/disarm.html
- **aeota**: https://github.com/dhinakg/aeota (decrypts AEA containers)

## Workflow Patterns

### Pattern 1: Analyze Loaded Kexts

1. Run `kmutil showloaded --sort` to enumerate
2. Identify third-party kexts with `--collection aux`
3. Check for unsigned or suspicious kexts
4. Inspect with `kmutil inspect` for symbol dependencies

### Pattern 2: Extract and Analyze Kernelcache

1. Download IPSW or find local kernelcache
2. Extract kernelcache from IPSW using `ipsw extract`
3. Decompress IMG4 format with `img4tool` or `pyimg4`
4. Check for symbols with `nm -a`
5. Extract specific kexts with `kextex`
6. Symbolicate with `disarm` if needed

### Pattern 3: Debug Kernel Panic

1. Capture panic with `kdpwrit dump`
2. Analyze with `kmutil analyze-panic`
3. For live debugging, set up KDP with matching KDK
4. Attach LLDB and get backtrace

### Pattern 4: Security Assessment

1. Check SIP status and kext loading permissions
2. Enumerate entitled daemons
3. Monitor for `kmutil load` invocations
4. Check for known vulnerability patterns
5. Review `/Library/Extensions` for unauthorized kexts
