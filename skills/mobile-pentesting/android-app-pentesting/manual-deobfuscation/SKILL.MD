---
name: android-deobfuscation
description: De-obfuscate Android apps using manual and automated techniques. Use this skill whenever the user needs to analyze obfuscated Android APKs, decrypt runtime strings, recover meaningful code from ProGuard/DexGuard obfuscation, or investigate malware samples. Trigger on mentions of: de-obfuscation, obfuscated APK, string decryption, ProGuard, DexGuard, Allatori, control-flow flattening, Dalvik bytecode analysis, Android malware analysis, or any request to understand obscured Android code.
---

# Android De-obfuscation Skill

A comprehensive guide for de-obfuscating Android applications using both manual techniques and modern LLM-powered automation.

## When to Use This Skill

Use this skill when:
- You have an obfuscated Android APK that needs analysis
- Strings appear encrypted or missing from decompiled code
- You encounter control-flow flattening or virtualization
- You need to extract runtime-decrypted values without running the app
- You're analyzing malware or suspicious Android applications
- Decompiled code has meaningless identifiers (a, b, c, method_1, etc.)

## Quick Start

### 1. Identify Obfuscation Indicators

First, check for common obfuscation patterns:

```bash
# Check for missing/scrambled strings
strings app.apk | grep -i "http\|url\|api\|key" | head -20

# Look for DexClassLoader (dynamic loading)
strings app.apk | grep -i "dexclassloader"

# Check for native libraries with unknown JNI functions
unzip -l app.apk | grep -E "lib.*\.so"

# Inspect assets for packed code
unzip -l app.apk | grep -E "assets/.*\.dex|assets/.*\.class"
```

**Key indicators:**
- Absence of readable strings in decompiled Java
- Binary files in `assets/` directory
- Calls to `DexClassLoader` or `OdinClassLoader`
- Native libraries with unidentifiable JNI function names
- Control-flow flattening (opaque switch-case state machines)

### 2. Decompile the APK

```bash
# Using jadx (recommended)
jadx -d decompiled/ target.apk

# Or using apktool for resources
apktool d target.apk -o resources/
```

### 3. Choose Your De-obfuscation Strategy

| Scenario | Recommended Approach |
|----------|---------------------|
| Heavily obfuscated Java code | Androidmeda (LLM-powered) |
| Runtime string decryption | DaliVM (static emulation) |
| Native code obfuscation | Manual analysis + IDA/Ghidra |
| Control-flow flattening | Androidmeda or manual restructuring |
| Quick triage | Automated scan + manual review |

---

## Automated De-obfuscation with Androidmeda

Androidmeda is an LLM-powered tool that automatically renames identifiers, restructures control-flow, and generates security reports.

### Installation

```bash
git clone https://github.com/In3tinct/Androidmeda
cd Androidmeda
pip3 install -r requirements.txt
```

### Usage

**Option A: Remote LLM (Gemini-1.5-flash)**
```bash
export OPENAI_API_KEY="your_api_key"
python3 androidmeda.py \
  --llm_provider google \
  --llm_model gemini-1.5-flash \
  --source_dir decompiled/ \
  --output_dir deobfuscated/ \
  --save_code true
```

**Option B: Local LLM (Ollama + Llama 3.2)**
```bash
python3 androidmeda.py \
  --llm_provider ollama \
  --llm_model llama3.2 \
  --source_dir decompiled/ \
  --output_dir deobfuscated/ \
  --save_code true
```

### Output Files

- `deobfuscated/vuln_report.json` - Security findings with severity levels
- `deobfuscated/<package_tree>/` - De-obfuscated Java source files

### Tips

- **Speed up processing**: Trim `source_dir` to only include app packages you care about
- **Handle skipped classes**: Isolate problematic packages or update parser regex
- **Always review**: LLM hallucinations can cause false positives/negatives

---

## Static String Decryption with DaliVM

DaliVM emulates Dalvik bytecode to extract runtime-decrypted values without running the app.

### Workflow

1. **Identify the decryption method** signature (e.g., `Lutil/Crypto;->decrypt(Ljava/lang/String;)Ljava/lang/String;`)
2. **Run emulation** to collect return values
3. **Review outputs** for decrypted strings/configs

### Usage

```bash
# Basic usage - emulate a decryptor method
python emulate.py app.apk "Lcom/example/Decryptor;->decrypt"

# Verbose mode with debug tracing
python emulate.py app.apk "Lcom/example/Decryptor;->decrypt" -v --debug --limit 10
```

### Finding Method Signatures

```bash
# Search for potential decryptor methods in decompiled code
grep -r "decrypt\|decode\|obfusc" decompiled/ | grep "public\|private" | head -20

# Look for string manipulation patterns
grep -r "String\|byte\[\]" decompiled/ | grep -E "for\(|while\(" | head -20
```

### Capabilities

- Emulates 120+ Dalvik opcodes
- Mocks Android APIs (Context, PackageManager, Signature, reflection)
- Handles class initialization (`<clinit>`)
- Supports multi-DEX analysis
- Traces PC/register changes for debugging

---

## Manual De-obfuscation Techniques

### Strategy 1: Replicate De-obfuscation Logic in Java

For DEX bytecode obfuscation:

1. Identify the de-obfuscation method in the decompiled code
2. Copy the logic into a standalone Java file
3. Execute to reverse obfuscation on target elements

```java
// Example: Replicate string decryption
public class Decryptor {
    public static String decrypt(String encrypted) {
        // Copy the exact logic from the obfuscated app
        // This runs the de-obfuscation algorithm
        return decryptedString;
    }
}
```

### Strategy 2: Translate to Python

For complex algorithms, translate to Python for easier debugging:

```python
# Example: Translate obfuscation algorithm
def decrypt_string(encrypted_bytes, key):
    # Replicate the algorithm logic
    result = []
    for i, byte in enumerate(encrypted_bytes):
        decrypted = byte ^ key[i % len(key)]
        result.append(chr(decrypted))
    return ''.join(result)
```

**Key principle**: You don't need to fully understand the algorithm—just execute it correctly.

---

## Dynamic Analysis for De-obfuscation

When static analysis fails, use dynamic analysis to observe runtime behavior.

### Runtime Decryption Capture

```bash
# Using Frida to hook string decryption
frida -U -f com.example.app -l hook_decrypt.js --no-pause

# hook_decrypt.js example:
/*
var decrypt = Module.findExportByName("libcrypto.so", "decrypt_string");
Interceptor.attach(decrypt, {
    onEnter: function(args) {
        console.log("Decrypt called with:", Memory.readUtf8String(args[0]));
    },
    onLeave: function(retval) {
        console.log("Decrypted:", Memory.readUtf8String(retval));
    }
});
*/
```

### What Dynamic Analysis Reveals

- **Runtime-decrypted strings**: Captured at the moment of decryption
- **Obfuscation techniques**: Code virtualization, packers, dynamic code generation
- **Hidden functionality**: Conditionally executed code paths
- **Anti-analysis behavior**: Detection of emulators, debuggers, root

---

## Practical Workflow

### Step-by-Step Analysis

1. **Initial Reconnaissance**
   ```bash
   # Quick scan for obfuscation indicators
   ./scripts/identify-obfuscation.sh target.apk
   ```

2. **Decompile**
   ```bash
   jadx -d decompiled/ target.apk
   ```

3. **Automated De-obfuscation** (if available)
   ```bash
   ./scripts/run-androidmeda.sh decompiled/ deobfuscated/
   ```

4. **String Extraction** (if strings are encrypted)
   ```bash
   ./scripts/run-dalivm.sh target.apk "Lcom/example/Decryptor;->decrypt"
   ```

5. **Manual Review**
   - Check `vuln_report.json` for security findings
   - Review de-obfuscated code for suspicious patterns
   - Cross-reference with dynamic analysis if needed

### Malware Triage Checklist

- [ ] Extract all decrypted strings
- [ ] Identify C2 URLs and API endpoints
- [ ] Map call graph to understand functionality
- [ ] Check for accessibility API abuse
- [ ] Look for hardcoded credentials
- [ ] Identify persistence mechanisms
- [ ] Document obfuscation techniques used

---

## Common Obfuscation Patterns

| Pattern | Indicator | Solution |
|---------|-----------|----------|
| String encryption | No readable strings in decompiled code | DaliVM or runtime hooking |
| Control-flow flattening | Opaque switch-case state machines | Androidmeda or manual restructuring |
| Code virtualization | Custom bytecode or native execution | Dynamic analysis + emulation |
| Dynamic loading | DexClassLoader, assets/*.dex | Extract and analyze loaded DEX |
| Native obfuscation | Unknown JNI functions, packed .so | IDA/Ghidra + manual analysis |
| Anti-analysis | Debugger detection, root checks | Disable detection or use VM |

---

## References

- [Androidmeda GitHub](https://github.com/In3tinct/Androidmeda)
- [DaliVM GitHub](https://github.com/fatalSec/DaliVM)
- [Android App RE - Obfuscation](https://maddiestone.github.io/AndroidAppRE/obfuscation.html)
- BlackHat USA 2018: "Unpacking the Packed Unpacker"
- REcon 2019: "The Path to the Payload: Android Edition"

---

## Troubleshooting

### Androidmeda Issues

- **Skipped class**: Isolate the package or update parser regex
- **Slow runtime**: Point `--source_dir` to specific packages only
- **High token usage**: Use local LLM or trim input directory

### DaliVM Issues

- **Execution stalls**: Enable opcode-level tracing (`-v --debug`)
- **Missing mocks**: Extend API mocks for custom Android calls
- **Wrong return values**: Verify method signature and arguments

### General Issues

- **Can't find decryptor**: Search for string manipulation patterns in decompiled code
- **Native code blocked**: Use IDA/Ghidra with Android plugin
- **Anti-analysis triggered**: Use VM with root disabled or patch detection code
