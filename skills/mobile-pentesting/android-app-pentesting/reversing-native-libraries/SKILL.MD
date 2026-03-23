---
name: android-native-reversing
description: How to reverse engineer Android native libraries (.so files) for security analysis, malware triage, and vulnerability research. Use this skill whenever you need to analyze, decompile, or instrument Android native code, extract JNI bindings, dump runtime-decrypted libraries, or patch ELF initializers. Make sure to use this skill when you mention Android .so files, native libraries, JNI, Frida instrumentation, ELF analysis, or any Android security/reversing task involving native code.
---

# Android Native Library Reversing

This skill provides practical workflows for reversing Android native libraries (`.so` files) written in C/C++. These are commonly used for performance-critical tasks and are frequently abused by malware authors because ELF shared objects are harder to decompile than DEX/OAT bytecode.

## Quick Triage Workflow

When you receive a fresh `.so` file, follow this systematic approach:

### 1. Extract the Library

```bash
# From an installed application (requires root or run-as)
adb shell "run-as <package_name> cat lib/arm64-v8a/libfoo.so" > libfoo.so

# Or from the APK directly
unzip -j target.apk "lib/*/libfoo.so" -d extracted_libs/
```

### 2. Identify Architecture & Protections

```bash
# Check architecture (arm64, arm32, x86)
file libfoo.so

# Check OS ABI, PIE, NX, RELRO, etc.
readelf -h libfoo.so

# Comprehensive security check (requires checksec/pwntools)
checksec --file libfoo.so
```

### 3. List Exported Symbols & JNI Bindings

```bash
# Dynamic-linked JNI functions (Java_ prefix)
readelf -s libfoo.so | grep ' Java_'

# Static-registered JNI (RegisterNatives calls)
strings libfoo.so | grep -i "RegisterNatives" -n
```

### 4. Load in a Decompiler

Use one of these tools and run auto-analysis:
- **Ghidra ≥ 11.0** (recommended - has AArch64 decompiler with PAC/BTI support)
- **IDA Pro**
- **Binary Ninja**
- **Hopper**
- **Cutter/Rizin**

> **Note:** Newer Ghidra versions recognize PAC/BTI stubs and MTE tags, greatly improving analysis of libraries built with Android 14 NDK.

### 5. Decide Static vs Dynamic Reversing

- **Static analysis** works for most cases
- **Dynamic instrumentation** (Frida, ptrace/gdbserver, LLDB) is needed for stripped, obfuscated, or runtime-decrypted code

---

## Dynamic Instrumentation with Frida (≥ 16)

Frida 16+ brings Android-specific improvements for modern Clang/LLD optimizations:

- `thumb-relocator` hooks tiny ARM/Thumb functions from LLD's aggressive alignment
- ELF import slot enumeration enables per-module `dlopen()`/`dlsym()` patching
- Java hooking fixed for ART quick-entrypoint (Android 14 `--enable-optimizations`)

### Enumerate RegisterNatives at Runtime

```javascript
// frida-registernatives.js
Java.perform(function () {
  var register = Module.findExportByName(null, 'RegisterNatives');
  if (!register) {
    console.log('[-] RegisterNatives not found');
    return;
  }
  
  Interceptor.attach(register, {
    onEnter(args) {
      var envPtr  = args[0];
      var clazz   = Java.cast(args[1], Java.use('java.lang.Class'));
      var methods = args[2];
      var count   = args[3].toInt32();
      
      console.log('[+] RegisterNatives on ' + clazz.getName() + ' -> ' + count + ' methods');
      
      // Iterate and dump JNI nativeMethod structs
      for (var i = 0; i < count; i++) {
        var method = methods.add(i);
        var name = Memory.readUtf8String(method.add(0));
        var sig = Memory.readUtf8String(method.add(8));
        var fnPtr = Memory.readPointer(method.add(16));
        console.log('    ' + name + ' ' + sig + ' @ ' + fnPtr);
      }
    }
  });
});
```

**Run:**
```bash
frida -U -f com.example.app -l frida-registernatives.js --no-pause
```

> **PAC/BTI Support:** Frida works on PAC/BTI-enabled devices (Pixel 8/Android 14+) with frida-server 16.2+. Earlier versions failed to locate padding for inline hooks.

---

## Dumping Runtime-Decrypted Libraries (soSaver)

When protected APKs keep native code encrypted or only map it at runtime (packers, downloaded payloads, generated libs), dump the mapped ELF directly from process memory.

### soSaver Workflow

The tool:
1. Hooks `dlopen` and `android_dlopen_ext` to detect load-time library mapping
2. Periodically scans process memory mappings for ELF headers
3. Reads each module in blocks and streams bytes through Frida messages
4. Saves reconstructed `.so` files for offline analysis

### Setup & Run

```bash
# Clone and setup
git clone https://github.com/TheQmaks/sosaver.git
cd sosaver && uv sync
source .venv/bin/activate  # .venv\Scripts\activate on Windows

# Target by package name
sosaver com.example.app

# Target by PID with custom output
sosaver 1234 -o /tmp/so-dumps --debug
```

**Requirements:** Root + frida-server, Python ≥3.8, uv

This bypasses "only decrypted in RAM" protections by recovering the live mapped image.

---

## Process-Local JNI Telemetry (SoTap)

When full instrumentation is overkill or blocked, preload a small logger inside the target process. SoTap is a lightweight Android native library that logs JNI/native interactions (no root required).

### Setup

1. **Drop the proper ABI build into the APK:**
   ```
   lib/arm64-v8a/libsotap.so    # for arm64
   lib/armeabi-v7a/libsotap.so  # for arm32
   ```

2. **Ensure SoTap loads before other JNI libs.** Inject early in Application subclass:
   ```smali
   const-string v0, "sotap"
   invoke-static {v0}, Ljava/lang/System;->loadLibrary(Ljava/lang/String;)V
   ```

3. **Rebuild, sign, install, run the app, then collect logs.**

### Log Paths (checked in order)

```
/data/user/0/<package>/files/sotap.log
/data/data/<package>/files/sotap.log
/sdcard/Android/data/<package>/files/sotap.log
/sdcard/Download/sotap-<package>.log
# Fallback: Logcat only
```

### Troubleshooting

- **ABI alignment is mandatory** - mismatch raises `UnsatisfiedLinkError`
- **Storage constraints** are common; SoTap falls back to Logcat
- **Customize verbosity** by editing `sotap.c` and rebuilding

**Use case:** Malware triage and JNI debugging where observing native call flows from process start is critical but root/system-wide hooks aren't available.

---

## Neutralizing Early Native Initializers

Highly protected apps place root/emulator/debug checks in native constructors that run via `.init_array` before `JNI_OnLoad` and any Java code. You can make these implicit initializers explicit and regain control.

### The Problem

- `.init_array` entries run automatically at load time
- On AArch64, entries are populated by `R_AARCH64_RELATIVE` relocations
- The bytes may look empty statically; the dynamic linker writes resolved addresses during relocation

### The Solution

1. Remove `INIT_ARRAY`/`INIT_ARRAYSZ` from DYNAMIC table (loader skips auto-execution)
2. Resolve constructor address from RELATIVE relocations
3. Export it as a regular function symbol (e.g., `INIT0`)
4. Rename `JNI_OnLoad` to `JNI_OnLoad0` to prevent ART from calling it implicitly

### Use the Patching Script

```bash
python scripts/remove_init_array.py libfoo.so libfoo.so.patched
```

This script:
- Locates `.init_array` VA range
- Finds the `R_AARCH64_RELATIVE` relocation landing in `.init_array`
- Removes `INIT_ARRAY`/`INIT_ARRAYSZ` DYNAMIC tags
- Adds exported `INIT0` symbol at constructor address
- Renames `JNI_OnLoad` → `JNI_OnLoad0`

### Validation After Patch

```bash
# Should NOT show init_array tags
readelf -W -d libfoo.so.patched | egrep -i 'init_array|fini_array|flags'

# Should show INIT0 and JNI_OnLoad0 symbols
readelf -W -s libfoo.so.patched | egrep 'INIT0|JNI_OnLoad0'
```

### Bootstrapping Manual Initialization

Use a minimal ART/JNI harness to call `INIT0()` and `JNI_OnLoad0(vm)` manually before any Java code. See the `caller.c` example in the references for a complete working harness.

---

## Common Vulnerabilities to Check

When you spot third-party `.so` files inside an APK, cross-check their hash against upstream advisories:

| Year | CVE | Library | Notes |
|------|-----|---------|-------|
| 2023 | CVE-2023-4863 | `libwebp` ≤ 1.3.1 | Heap buffer overflow in WebP decoder. Many apps bundle vulnerable versions. |
| 2024 | Multiple | OpenSSL 3.x | Memory-safety and padding-oracle issues. Common in Flutter/ReactNative bundles. |

**Action:** When you see `libwebp.so` or `libcrypto.so` in an APK, check the version and attempt exploitation or recommend patching.

---

## Anti-Reversing Trends (Android 13-15)

Be aware of these modern hardening techniques:

### Pointer Authentication (PAC) & Branch Target Identification (BTI)

- Android 14 enables PAC/BTI in system libraries on ARMv8.3+ silicon
- Decompilers display PAC-related pseudo-instructions
- For dynamic analysis, Frida injects trampolines after stripping PAC
- Custom trampolines should call `pacda`/`autibsp` where necessary

### MTE & Scudo Hardened Allocator

- Memory-tagging is opt-in but common in Play-Integrity aware apps
- Built with `-fsanitize=memtag`
- Capture tag faults: `setprop arm64.memtag.dump 1` then `adb shell am start ...`

### LLVM Obfuscator

- Commercial packers (Bangcle, SecNeo) protect native code, not just Java
- Expect opaque predicates, control-flow flattening, encrypted string blobs in `.rodata`

---

## References

- **Learning ARM Assembly:** [Azeria Labs – ARM Assembly Basics](https://azeria-labs.com/writing-arm-assembly-part-1/)
- **JNI & NDK Documentation:** [Oracle JNI Spec](https://docs.oracle.com/javase/7/docs/technotes/guides/jni/spec/jniTOC.html) · [Android JNI Tips](https://developer.android.com/training/articles/perf-jni)
- **Frida 16.x Change-log:** [frida.re/news](https://frida.re/news/)
- **soSaver:** [github.com/TheQmaks/sosaver](https://github.com/TheQmaks/sosaver)
- **SoTap:** [github.com/RezaArbabBot/SoTap](https://github.com/RezaArbabBot/SoTap)
- **LIEF Project:** [github.com/lief-project/LIEF](https://github.com/lief-project/LIEF)
- **CVE-2023-4863:** [nvd.nist.gov](https://nvd.nist.gov/vuln/detail/CVE-2023-4863)
- **Patching Android ARM64 initializers:** [blog.nviso.eu](https://blog.nviso.eu/2025/10/14/patching-android-arm64-library-initializers-for-easy-frida-instrumentation-and-debugging/)

---

## Quick Reference Commands

```bash
# Extract .so from APK
unzip -j app.apk "lib/*/lib*.so" -d libs/

# Quick triage
file libfoo.so && readelf -h libfoo.so && strings libfoo.so | grep -i "RegisterNatives"

# Frida hook RegisterNatives
frida -U -f com.example.app -l frida-registernatives.js --no-pause

# Dump runtime-decrypted libs
sosaver com.example.app -o /tmp/dumps/

# Patch init_array
python scripts/remove_init_array.py libfoo.so libfoo.so.patched

# Validate patch
readelf -W -d libfoo.so.patched | egrep -i 'init_array'
readelf -W -s libfoo.so.patched | egrep 'INIT0|JNI_OnLoad0'
```
