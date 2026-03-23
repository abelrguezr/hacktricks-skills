---
name: android-apk-decompiler
description: How to decompile and analyze Android APK files using various decompilation tools. Use this skill whenever the user needs to reverse engineer Android applications, extract Java source code from APKs, analyze Android bytecode, or investigate mobile app security. Trigger on mentions of APK analysis, Android reverse engineering, decompiling Android apps, extracting source code from mobile applications, or any request to understand what an Android app does internally.
---

# Android APK Decompiler

A comprehensive guide to decompiling and analyzing Android APK files using industry-standard tools.

## Quick Start

When you receive an APK file to analyze, follow this workflow:

1. **Initial inspection**: Use Jadx for quick, readable source code extraction
2. **Deep analysis**: Use multiple decompilers in parallel for complex cases
3. **Obfuscated apps**: Use frida-DEXdump to extract runtime DEX files
4. **Modern Java features**: Use CFR for better handling of recent Java syntax

## Tool Selection Guide

### For Quick Analysis (Recommended Default)

**Jadx** - Best all-around tool for most scenarios
- User-friendly GUI and CLI options
- Cross-platform support
- Good balance of speed and accuracy

```bash
# GUI mode
jadx-gui

# CLI mode - basic decompilation
jadx app.apk

# CLI mode - with options
jadx app.apk -d ./output --no-res --no-src --no-imports
```

### For Complex/Obfuscated Apps

**Bytecode-Viewer** - Multiple decompilers in one interface
- Compare outputs from different decompilers simultaneously
- Best for apps with heavy obfuscation
- Download from releases page, run, load APK, select decompilers

**GDA-android-reversing-Tool** - Windows-only, feature-rich
- Extensive reverse engineering features
- Install on Windows, load APK for analysis

### For Modern Java Features

**CFR** - Handles modern Java syntax well
```bash
# Standard decompilation
java -jar ./cfr.jar "app.jar" --outputdir "output_directory"

# For large JAR files (increase memory)
java -Xmx4G -jar ./cfr.jar "app.jar" --outputdir "output_directory"
```

### For Runtime Analysis (Beating Obfuscation)

**frida-DEXdump** - Extract DEX from running app in memory
- Useful when static obfuscation is removed at runtime
- Dump the DEX of a running APK to analyze deobfuscated code

### For Bytecode Translation

**Enjarify** - Convert Dalvik to Java bytecode
```bash
enjarify app.apk
```
- Enables Java analysis tools to work with Android apps
- Generates Java bytecode equivalent of the APK

### For Detailed Control

**Krakatau** - Fine-grained decompilation control
```bash
./Krakatau/decompile.py -out "output_directory" -skip -nauto -path "./jrt-extractor/rt.jar" "app.jar"
```
- Specify standard library paths
- Handle external libraries effectively

### For Simple JAR Decompilation

**procyon** - Straightforward decompilation
```bash
procyon -jar "app.jar" -o "output_directory"
```

**Fernflower** - JetBrains' analytical decompiler
```bash
# After building from source
java -jar ./fernflower.jar "app.jar" "output_directory"
# Then extract .java files from generated JAR
unzip output.jar
```

**JD-Gui** - Pioneering GUI decompiler
- Open APK directly in JD-Gui
- Simple, straightforward interface
- Good for quick inspection

## Analysis Workflow

### Step 1: Initial Reconnaissance
1. Run Jadx on the APK to get a quick overview
2. Look at the manifest file for permissions and components
3. Identify main entry points and suspicious activities

### Step 2: Deep Dive
1. Use multiple decompilers if code is obfuscated
2. Compare outputs to find the most readable version
3. Focus on key areas: network calls, file operations, crypto functions

### Step 3: Runtime Analysis (if needed)
1. If static analysis shows heavy obfuscation, use frida-DEXdump
2. Run the app and dump DEX from memory
3. Analyze the deobfuscated runtime code

### Step 4: Documentation
1. Document findings: vulnerabilities, suspicious behavior, data flows
2. Note which decompiler produced the clearest results
3. Save relevant code snippets for reporting

## Common Use Cases

### Finding Hardcoded Secrets
- Search for API keys, passwords, tokens in decompiled source
- Look in strings.xml, constants, and initialization code
- Check for encryption keys and certificates

### Analyzing Network Communication
- Find HTTP/HTTPS client implementations
- Identify endpoints and data being transmitted
- Check for SSL pinning and certificate validation

### Understanding App Behavior
- Review manifest for permissions and components
- Trace main activity and service flows
- Identify third-party SDKs and libraries

### Security Assessment
- Look for insecure data storage
- Check for proper input validation
- Identify potential attack vectors

## Tips for Success

1. **Start simple**: Jadx works for 80% of cases
2. **Use multiple tools**: Different decompilers handle edge cases differently
3. **Check the manifest first**: It tells you what the app can do
4. **Look for patterns**: Obfuscated code often has telltale signs
5. **Document everything**: Keep track of which tool produced which output
6. **Be patient**: Complex apps may require multiple passes

## When to Use Each Tool

| Scenario | Recommended Tool |
|----------|------------------|
| Quick inspection | Jadx |
| Obfuscated code | Bytecode-Viewer + multiple decompilers |
| Modern Java (records, var, etc.) | CFR |
| Runtime deobfuscation | frida-DEXdump |
| Windows environment | GDA |
| Dalvik to Java conversion | Enjarify |
| Fine-grained control | Krakatau |
| Simple JAR files | procyon or Fernflower |

## References

- Original decompilation guide: https://eiken.dev/blog/2021/02/how-to-break-your-jar-in-2021-decompilation-guide-for-jars-and-apks/
- Jadx: https://github.com/skylot/jadx
- CFR: https://github.com/leibnitz27/cfr
- Bytecode-Viewer: https://github.com/Konloch/bytecode-viewer/releases
- frida-DEXdump: https://github.com/hluwa/frida-dexdump
