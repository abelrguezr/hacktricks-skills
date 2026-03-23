---
name: xamarin-app-pentest
description: Reverse engineer and pentest Xamarin mobile apps. Use this skill whenever the user needs to analyze, decompile, or test Xamarin apps built with .NET/C# for Android or iOS. Trigger for tasks involving: extracting DLLs from APK/IPA files, decompiling Xamarin assemblies, bypassing SSL pinning or root detection in Xamarin apps, static analysis of .NET mobile code, dynamic analysis with Frida, or any Xamarin/MAUI app security testing. Make sure to use this skill for any mobile app that might be Xamarin-based, even if the user doesn't explicitly mention Xamarin.
---

# Xamarin App Pentesting

A skill for reverse engineering and security testing of Xamarin mobile applications built with .NET and C#.

## When to Use This Skill

Use this skill when:
- You need to analyze a mobile app that might be built with Xamarin
- You have an APK or IPA file and want to extract .NET assemblies
- You need to decompile and analyze C# code from a mobile app
- You want to bypass SSL pinning or root detection in Xamarin apps
- You're doing static or dynamic analysis of .NET mobile applications
- You need to modify and repackage a Xamarin app for testing

## Quick Start

```bash
# Extract assemblies from APK
python3 scripts/extract-xamarin-assemblies.py -o /path/to/apk.apk

# Decompress XALZ format (newer Xamarin/MAUI)
python3 scripts/decompress-xalz.py -i /path/to/assemblies/

# Run Frida bypass for SSL pinning
frida -U -l scripts/frida-xamarin-bypass.js com.target.app --no-pause
```

## Workflow Overview

1. **Extract assemblies** from APK/IPA files
2. **Decompress** if using XALZ format (newer builds)
3. **Static analysis** with dnSpy/ILSpy
4. **Dynamic analysis** with Frida for runtime modifications
5. **Resign** the modified app

---

## 1. Extracting Assemblies

### From Android APK

Xamarin apps store .NET assemblies in the `assemblies/` directory. The format varies:

**Standard format:** `.dll` files directly in `assemblies/`

**Blob format:** `assemblies.blob` and `assemblies.manifest` files

**XALZ format (newer):** Compressed assemblies in `/assemblies.blob` or `/resources/assemblies`

Use the extraction script:

```bash
python3 scripts/extract-xamarin-assemblies.py -o /path/to/app.apk
```

This will:
- Unzip the APK
- Detect the assembly format
- Extract and decompress as needed
- Output to `extracted_assemblies/`

### From iOS IPA

iOS assemblies are in `Payload/AppName.app/`. They're readily accessible but may be AOT-compiled:

```bash
unzip app.ipa -d extracted/
cd extracted/Payload/AppName.app/
# DLLs are here, but may be AOT-compiled
```

> **Important for iOS:** AOT compilation means managed IL is compiled into native `*.aotdata.*` files. Patching DLLs alone won't change logic—you need to hook native stubs with Frida because IL bodies are empty placeholders.

---

## 2. Decompressing XALZ Format

Recent Xamarin/MAUI builds use XALZ compression. Use the decompression script:

```bash
python3 scripts/decompress-xalz.py -i /path/to/assemblies/ -o /path/to/output/
```

Or manually with the xamarout library:

```python
from xamarout import xalz
import os

for root, _, files in os.walk("."):
    for f in files:
        filepath = os.path.join(root, f)
        if open(filepath, 'rb').read(4) == b"XALZ":
            xa = xalz.XamarinCompressedAssembly(filepath)
            xa.write("decompressed/" + f)
```

---

## 3. Static Analysis

Once you have the `.dll` files, analyze them with:

### dnSpyEx (Recommended)

```bash
# dnSpy is archived; use dnSpyEx for .NET 8/MAUI support
dnSpyEx
```

- Load the extracted `.dll` files
- Browse the decompiled C# code
- Modify code directly
- Save and recompile

### ILSpy

```bash
ILSpy
```

- Open assemblies
- Export decompiled source
- Good for analysis without modification

### What to Look For

- **Hardcoded secrets:** API keys, tokens, passwords
- **Security controls:** SSL pinning, root detection, obfuscation
- **Business logic:** Authentication flows, data validation
- **Third-party libraries:** Known vulnerabilities

---

## 4. Dynamic Analysis with Frida

### Bypass SSL Pinning

Use the bundled Frida script:

```bash
frida -U -l scripts/frida-xamarin-bypass.js com.target.app --no-pause
```

This hooks `System.Net.Http.HttpClient.SendAsync` and swaps the handler to a permissive one.

### Bypass Root Detection

```bash
frida -U -l scripts/frida-xamarin-bypass.js com.target.app --no-pause --root-bypass
```

### Hook Managed Methods

Use the `frida-mono-api` template:

```javascript
const mono = require('frida-mono-api');
Mono.ensureInitialized();

// List all loaded assemblies
Mono.enumerateLoadedImages().forEach(i => console.log(i.name));

// Hook a specific method
const klass = Mono.classFromName("YourNamespace", "YourClass");
const m = Mono.methodFromName(klass, "YourMethod", 2);
Mono.intercept(m, {
    onEnter(args) {
        console.log("Method called with:", args);
    },
    onLeave(retval) {
        console.log("Method returned:", retval);
    }
});
```

### Useful Frida Scripts

- **xamarin-antiroot:** Bypass root detection
- **xamarin-root-detect-bypass:** Alternative root bypass
- **frida-xamarin-unpin:** SSL pinning bypass (updated for Mono >=6)

---

## 5. Modifying and Resigning

### After Static Analysis

If you modified code in dnSpyEx:

1. Save the modified assemblies
2. Replace the original `.dll` files in the APK
3. Repackage the APK
4. Sign the APK

### Resigning Android APKs

Use Uber APK Signer:

```bash
java -jar uber-apk-signer.jar --apk app-modified.apk --ks keystore.jks --ks-pass pass:yourpassword --key-alias alias --key-pass pass:yourpassword
```

### Resigning iOS Apps

iOS requires code signing with a valid certificate:

```bash
# Using codesign
codesign --force --sign "iPhone Developer: Your Name" app.app

# Or use a tool like ios-deploy for installation
ios-deploy --bundle app.ipa
```

---

## Common Patterns

### Pattern 1: Quick Assembly Extraction

```bash
# One-liner for standard Xamarin APKs
unzip -q app.apk -d extracted/ && cp -r extracted/assemblies/ ./assemblies/
```

### Pattern 2: Find All DLLs

```bash
find . -name "*.dll" -type f
```

### Pattern 3: Search for Secrets in Decompiled Code

```bash
# After decompiling to source
grep -r "api_key\|secret\|password\|token" decompiled/
```

### Pattern 4: List All Classes in Assembly

```bash
# Using ildasm or similar
ildasm assembly.dll /text > classes.txt
```

---

## Troubleshooting

### "Can't find assemblies"

- Check if the APK is actually Xamarin (look for `assemblies/` directory)
- Try `pyxamstore unpack` for blob format
- Use `xamarout` for XALZ format

### "AOT compiled, can't modify"

- iOS apps are always AOT compiled
- Use Frida to hook native stubs instead of modifying DLLs
- Look for `*.aotdata.*` files

### "SSL pinning still works"

- Make sure Frida script runs after app starts
- Try the updated `frida-xamarin-unpin` for Mono >=6
- Check if pinning is in custom handlers

### "App crashes after modification"

- Verify you're using dnSpyEx (not archived dnSpy) for .NET 8/MAUI
- Check for obfuscation that might break on modification
- Ensure proper signing after repackaging

---

## References

- [Xamarin Reverse Engineering Guide](https://www.appknox.com/security/xamarin-reverse-engineering-a-guide-for-penetration-testers)
- [Unpacking Xamarin Assembly Stores](https://thecobraden.com/posts/unpacking_xamarin_assembly_stores/)
- [Exploitation of Xamarin Apps](https://medium.com/@justmobilesec/introduction-to-the-exploitation-of-xamarin-apps-fde419a51bf)
- [pyxamstore](https://github.com/jakev/pyxamstore)
- [xamarout](https://pypi.org/project/xamarout/)
- [frida-xamarin-unpin](https://github.com/GoSecure/frida-xamarin-unpin)
- [dnSpyEx](https://github.com/dnSpyEx/dnSpyEx)
- [ILSpy](https://github.com/icsharpcode/ILSpy)
- [Uber APK Signer](https://github.com/patrickfav/uber-apk-signer)
