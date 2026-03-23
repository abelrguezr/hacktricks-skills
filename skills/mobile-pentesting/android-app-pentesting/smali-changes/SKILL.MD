---
name: android-smali-pentest
description: Android APK decompilation, Smali code modification, and recompilation for security testing. Use this skill whenever the user mentions APK analysis, Android app security testing, decompiling Android applications, modifying Smali code, reverse engineering Android apps, or needs to extract hidden information from Android applications. This skill handles the complete workflow: decompile APKs with APKTool, modify Smali bytecode, recompile, sign, and optimize the modified APK.
---

# Android Smali Pentesting

A skill for decompiling, modifying, and recompiling Android APKs for security testing and reverse engineering.

## Workflow Overview

1. **Decompile** the APK to access Smali code and resources
2. **Analyze** the decompiled code for security issues or hidden data
3. **Modify** Smali code to extract information or bypass protections
4. **Recompile** the modified APK
5. **Sign** the APK with a test key
6. **Optimize** with zipalign (optional but recommended)

## Step 1: Decompile the APK

Use APKTool to decompile the APK and access Smali code:

```bash
apktool d APP.apk
```

This creates a folder with:
- `smali/` - Decompiled Smali bytecode
- `res/` - Resources (layouts, strings, etc.)
- `AndroidManifest.xml` - App manifest

### Key files to examine:
- `res/values/strings.xml` - String resources (may contain hardcoded secrets)
- `AndroidManifest.xml` - Permissions, activities, services
- Any `.sqlite` or `.db` files - Databases

### Troubleshooting APKTool errors:
- Install the latest version: https://ibotpeaches.github.io/Apktool/install/
- If decoding fails, try with `-r` flag (skip resource decoding):
  ```bash
  apktool d -r APP.apk
  ```
- For framework issues, see: https://ibotpeaches.github.io/Apktool/documentation/#framework-files

## Step 2: Analyze and Modify Smali Code

### Finding interesting code:
1. Search for strings in `res/values/strings.xml` to find related Smali files
2. Look for hardcoded credentials, API keys, or flags
3. Examine authentication logic in activity files
4. Check for obfuscated code patterns

### Common Smali modifications:

#### Modify variable values:
```smali
# Change a constant value
const v9, 0xf4240          # Change to: const v9, 0x0
const-string v5, "wins"    # Change to: const-string v5, "LOSE"
```

#### Add logging to trace execution:
```smali
# Log a variable value
iget v5, p0, Lcom/example/Activity;->variable:I
invoke-static {v5}, Ljava/lang/String;->valueOf(I)Ljava/lang/String;
move-result-object v1
const-string v5, "DEBUG"
invoke-static {v5, v1}, Landroid/util/Log;->d(Ljava/lang/String;Ljava/lang/String;)I
```

#### Add toast notifications:
```smali
# Show a toast with a variable value
iget v10, p0, Lcom/example/Activity;->variable:I
invoke-static {v10}, Ljava/lang/String;->valueOf(I)Ljava/lang/String;
move-result-object v11
const/4 v12, 0x1
invoke-static {p0, v11, v12}, Landroid/widget/Toast;->makeText(Landroid/content/Context;Ljava/lang/CharSequence;I)Landroid/widget/Toast;
move-result-object v12
invoke-virtual {v12}, Landroid/widget/Toast;->show()V
```

#### Bypass authentication checks:
```smali
# Change conditional to always pass
if-eq v0, v1, :cond_1      # Original: if not equal, jump
# Change to:
const/4 v0, 0x1            # Force success condition
```

### Important Smali patterns:

| Pattern | Description |
|---------|-------------|
| `.registers N` | Number of registers used in method |
| `.locals N` | Number of local variables |
| `const v0, 0x1` | Set register v0 to value 1 |
| `const-string v0, "text"` | Set register v0 to string |
| `invoke-virtual {v0, v1}` | Call virtual method |
| `invoke-static {v0}` | Call static method |
| `iget v0, p0, Lclass;->field:I` | Get instance field |
| `iput v0, p0, Lclass;->field:I` | Set instance field |
| `if-eq v0, v1, :label` | If equal, jump to label |
| `goto :label` | Unconditional jump |

### When adding code to a method:
1. Increase `.locals` count by the number of new variables needed
2. Use the next available register numbers (e.g., if using v0-v9, use v10, v11)
3. Place new code between `.locals` declaration and variable declarations

## Step 3: Recompile the APK

Navigate to the decompiled folder and recompile:

```bash
apktool b .
```

The compiled APK will be in the `dist/` folder.

## Step 4: Sign the APK

Android requires all APKs to be signed. Generate a test key and sign:

### Generate signing key:
```bash
keytool -genkey -v -keystore key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias myalias
```

### Sign with jarsigner (before zipalign):
```bash
jarsigner -keystore key.jks dist/modified.apk myalias
```

### OR sign with apksigner (after zipalign):
```bash
apksigner sign --ks key.jks dist/modified.apk
```

**Note:** Sign only once - either with jarsigner before zipalign OR with apksigner after zipalign.

## Step 5: Optimize with zipalign (recommended)

```bash
zipalign -v 4 dist/modified.apk dist/optimized.apk
```

If using apksigner, sign after this step.

## Common Use Cases

### Extract hidden flags or secrets:
1. Decompile the APK
2. Search `res/values/strings.xml` for suspicious strings
3. Find the Smali file that uses those strings
4. Add logging or toast to reveal values at runtime
5. Recompile, sign, and install

### Bypass license checks:
1. Find the license verification method
2. Modify the conditional to always return true
3. Recompile and test

### Enable debug features:
1. Search for debug-related strings or methods
2. Modify flags or conditions to enable debug mode
3. Recompile and test

### Log sensitive data:
1. Identify where sensitive data is processed
2. Add logging statements to trace the data flow
3. Recompile, install, and check logcat

## Tools and Resources

- **APKTool**: https://ibotpeaches.github.io/Apktool/
- **APKLab (VS Code extension)**: https://github.com/APKLab/APKLab
- **apk.sh script**: https://github.com/ax/apk.sh
- **Dalvik Opcodes Reference**: http://pallergabor.uw.hu/androidblog/dalvik_opcodes.html
- **Smali Instruction Set**: https://source.android.com/devices/tech/dalvik/dalvik-bytecode

## Tips

1. **Backup the original APK** before modifying
2. **Use VS Code with Smali extension** for syntax highlighting and validation
3. **Test incrementally** - make small changes and verify before proceeding
4. **Check logcat** after installing modified APKs to see your logging output
5. **Keep track of register usage** - don't overwrite registers that are still in use
6. **Update `.locals` count** when adding new variables to a method
