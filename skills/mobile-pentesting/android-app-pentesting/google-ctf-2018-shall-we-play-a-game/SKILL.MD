---
name: android-smali-patching
description: How to reverse engineer Android APKs, analyze and modify smali code to bypass game conditions, unlock features, or extract flags. Use this skill whenever the user needs to decompile an APK, modify smali bytecode, change comparison operators, bypass win conditions, or perform any Android app reverse engineering. Trigger on mentions of APK analysis, smali modification, Android pentesting, game hacking, or CTF challenges involving Android apps.
---

# Android Smali Patching

A skill for reverse engineering Android APKs and modifying smali bytecode to bypass conditions, unlock features, or extract hidden content.

## Workflow Overview

1. **Analyze the APK** - Upload to an emulator or decompile to understand behavior
2. **Decompile** - Extract smali code and Java source for analysis
3. **Identify target logic** - Find the code controlling the condition you want to bypass
4. **Modify smali** - Apply one of several patching techniques
5. **Recompile and sign** - Rebuild the APK with your changes
6. **Test** - Verify the modification works

## Step 1: Analyze the APK

Before decompiling, understand what the app does:

- Upload to [appetize.io](https://appetize.io) (free account) to run the APK in a browser-based emulator
- Observe the app's behavior, UI, and what conditions need to be met
- Note any win conditions, score requirements, or feature gates

This helps you know what to look for when you decompile.

## Step 2: Decompile the APK

Use these tools to extract the code:

```bash
# Install apktool if needed
sudo apt install apktool

# Decompile the APK
apktool d app.apk -o app-decompiled

# View Java source with jadx (optional but helpful)
jadx app.apk -d app-jadx
```

The decompiled output contains:
- `smali/` - Android bytecode in smali format (what you'll modify)
- `res/` - Resources (layouts, strings, images)
- `AndroidManifest.xml` - App configuration

## Step 3: Identify Target Logic

Search for the condition you want to bypass:

1. **Look for numeric constants** - If the game requires 1000000 wins, search for that number in smali files
2. **Find comparison operations** - Look for `if-ne`, `if-eq`, `if-lt`, `if-gt` instructions
3. **Trace function calls** - Find where the flag or reward is printed
4. **Use jadx** - The Java decompilation is often easier to read than smali

Example pattern to find:
```
# Check if wins == 1000000
const v9, 0xf4240      # 1000000 in hex
iget v0, p0, Lcom/example/Game;->o:I  # Get this.o (wins counter)
if-ne v0, v9, :cond_2  # If not equal, skip flag
```

## Step 4: Smali Patching Techniques

Choose one of these approaches based on your goal:

### Technique 1: Change Comparison Operator

Flip the condition so it triggers when you DON'T meet the requirement:

**Before:**
```
if-ne v0, v9, :cond_2  # If NOT equal, skip
```

**After:**
```
if-eq v0, v9, :cond_2  # If EQUAL, skip (opposite behavior)
```

This makes the flag print when wins != 1000000, which is true on first run.

### Technique 2: Change the Compared Value

Modify the constant to match your current state:

**Before:**
```
const v9, 0xf4240      # 1000000
```

**After:**
```
const v9, 0x1          # 1 (or 0 if starting fresh)
```

Now the condition triggers when you have 1 win instead of 1000000.

### Technique 3: Set the Variable Directly

Force the variable to the required value before the check:

**Before:**
```
iget v0, p0, Lcom/example/Game;->o:I
```

**After:**
```
iget v0, p0, Lcom/example/Game;->o:I
const v0, 0xf4240      # Force v0 = 1000000
```

### Technique 4: Add a Move Instruction

Copy the target value into the variable:

**Before:**
```
iget v0, p0, Lcom/example/Game;->o:I
```

**After:**
```
iget v0, p0, Lcom/example/Game;->o:I
move v0, v9            # Copy 1000000 into v0
```

### Technique 5: Create a Goto Loop

For conditions that need to run multiple times, create a loop:

**Before:**
```
# Single execution path
invoke-virtual {p0}, Lcom/example/Game;->m()V
```

**After:**
```
:goto_6
invoke-virtual {p0}, Lcom/example/Game;->m()V
iget v0, p0, Lcom/example/Game;->o:I
const v9, 0xf4240
if-ne v0, v9, :cond_2
goto :goto_6           # Loop back until condition met
```

This runs the function repeatedly until the condition is satisfied.

## Step 5: Recompile and Sign

After modifying smali files:

```bash
# Recompile with apktool
cd app-decompiled
apktool b . -o app-patched.apk

# Sign the APK (required for installation)
# Generate a debug key if you don't have one
keytool -genkey -v -keystore debug.keystore -alias androiddebugkey \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass android -keypass android

# Sign the APK
jarsigner -verbose -keystore debug.keystore -storepass android -keypass android \
  app-patched.apk androiddebugkey

# Or use apksigner (newer method)
apksigner sign --ks debug.keystore app-patched.apk
```

## Step 6: Test the Modification

1. **Upload to appetize.io** - Quick test without installing
2. **Install on emulator** - `adb install app-patched.apk`
3. **Install on physical device** - Some modifications only work on real hardware

**Note:** Some smali modifications work differently on emulators vs physical devices. If something doesn't work in an emulator, try a physical device.

## Common Smali Instructions

| Instruction | Meaning |
|-------------|----------|
| `if-ne` | If not equal, jump |
| `if-eq` | If equal, jump |
| `if-lt` | If less than, jump |
| `if-gt` | If greater than, jump |
| `const` | Load constant value |
| `move` | Copy register value |
| `iget` | Get instance field |
| `invoke-virtual` | Call method |
| `goto` | Unconditional jump |

## Debugging Tips

- **Check register usage** - Make sure you're modifying the right registers
- **Verify hex values** - 1000000 = 0xf4240, use a calculator if unsure
- **Look at surrounding code** - Understand the full context before modifying
- **Test incrementally** - Make one change at a time to isolate issues
- **Use jadx** - The Java decompilation helps understand the logic flow

## Example: Bypassing a Win Condition

**Scenario:** Game requires 1000000 wins to show flag

**Solution:**
1. Find the comparison: `if-ne v0, v9, :cond_2` where v9 = 1000000
2. Change to: `if-eq v0, v9, :cond_2`
3. Recompile and sign
4. Run the game - flag appears on first win

**Alternative:** Change `const v9, 0xf4240` to `const v9, 0x1` so one win is enough.

## Security Note

This skill is for educational purposes, CTF challenges, and authorized security testing. Only modify APKs you own or have explicit permission to test. Do not use these techniques to:
- Bypass licensing on software you haven't purchased
- Cheat in online multiplayer games
- Violate terms of service
- Distribute modified apps without authorization

## References

- [apktool documentation](https://ibotpeaches.github.io/Apktool/)
- [jadx documentation](https://github.com/skylot/jadx)
- [Smali documentation](https://sourceforge.net/p/smali/wiki/)
- [Android smali instructions](https://www.smali.com/)
