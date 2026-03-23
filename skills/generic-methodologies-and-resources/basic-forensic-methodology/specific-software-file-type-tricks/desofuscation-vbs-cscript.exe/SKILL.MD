---
name: vbs-desobfuscation
description: Analyze, debug, and deobfuscate VBS/VBScript files for forensic investigation. Use this skill whenever the user mentions VBS files, VBScript analysis, malware investigation, script obfuscation, or needs to understand what a VBS file does. This is essential for security researchers, incident responders, and anyone investigating suspicious scripts.
---

# VBS Desobfuscation and Analysis

A skill for analyzing, debugging, and deobfuscating VBScript files during forensic investigations.

## When to Use This Skill

Use this skill when:
- You need to analyze a suspicious or malicious VBS file
- A VBS script appears obfuscated or encoded
- You're investigating malware that uses VBScript
- You need to understand what a VBS file does before execution
- You're doing incident response involving script-based attacks

## Core Analysis Techniques

### 1. Run with cscript.exe for Debug Output

The most important first step is running the script with `cscript.exe` instead of `wscript.exe` to get console output:

```bash
# Run and capture output
cscript.exe //nologo <script.vbs>

# Run with echo statements to trace execution
cscript.exe //nologo <script.vbs> 2>&1 | tee output.log
```

**Why this matters:** `cscript.exe` outputs to console while `wscript.exe` uses GUI dialogs. For analysis, you need the console output to see what the script is doing.

### 2. Add Debug Echo Statements

Insert `Wscript.Echo` statements to trace execution flow:

```vbs
' Add at key points in the script
Wscript.Echo "=== Starting execution ==="
Wscript.Echo "Variable value: " & someVariable
Wscript.Echo "About to execute: " & someFunction
```

**Pattern:** Place echo statements before and after suspicious code blocks to understand control flow.

### 3. Extract and Analyze Comments

VBS comments start with `'` (single quote). Extract them to understand the script's intent:

```bash
# Extract all comment lines
grep "^'" script.vbs

# Or extract inline comments
grep "'" script.vbs
```

**Why this matters:** Comments often reveal the script's purpose, author notes, or even hidden functionality that the obfuscation tries to hide.

### 4. Write Data to Files for Analysis

When you need to inspect binary data or encoded strings, write them to files:

```vbs
Function writeBinary(strBinary, strPath)
    Dim oFSO: Set oFSO = CreateObject("Scripting.FileSystemObject")
    Dim oTxtStream
    
    On Error Resume Next
    Set oTxtStream = oFSO.createTextFile(strPath)
    
    If Err.number <> 0 Then 
        Wscript.Echo "Error: " & Err.message
        Exit Function
    End If
    On Error GoTo 0
    
    Set oTxtStream = Nothing
    
    With oFSO.createTextFile(strPath)
        .Write(strBinary)
        .Close
    End With
    
    Wscript.Echo "Written to: " & strPath
End Function
```

**Use case:** When a script decodes or decrypts data, use this to capture the decoded output for analysis.

## Analysis Workflow

### Step 1: Initial Reconnaissance

Before running anything:

1. **Check file size and encoding**
   ```bash
   file script.vbs
   wc -l script.vbs
   ```

2. **Look for obvious obfuscation patterns**
   - Base64 encoded strings
   - Hex-encoded data
   - `Eval()` or `Execute()` calls
   - String concatenation chains
   - `Chr()` or `Asc()` functions

3. **Extract comments** to understand intent

### Step 2: Safe Execution

**Never run suspicious scripts directly on your system.** Use:

- A VM with snapshots
- A sandbox environment
- Static analysis first

When you do run:

```bash
# In isolated environment
cscript.exe //nologo script.vbs 2>&1 | tee execution.log
```

### Step 3: Trace and Debug

1. **Add echo statements** at entry points and before suspicious operations
2. **Capture all output** to a log file
3. **Look for:**
   - File system operations
   - Registry modifications
   - Network connections
   - Process spawning
   - Data exfiltration

### Step 4: Deobfuscate

Common obfuscation patterns and how to handle them:

| Pattern | Detection | Resolution |
|---------|-----------|------------|
| Base64 | `=` padding, alphanumeric | Decode with `base64 -d` |
| Hex strings | `&H` prefix or hex pairs | Convert with hex decoder |
| String concat | `"a" & "b" & "c"` | Join the strings |
| Chr() chains | `Chr(65) & Chr(66)` | Convert ASCII codes |
| Eval/Execute | `Eval(`, `Execute(` | Extract and analyze the string argument |

## Common Malicious Patterns

Watch for these indicators:

- **PowerShell invocation:** `CreateObject("WScript.Shell").Run "powershell ..."`
- **File downloads:** `CreateObject("MSXML2.XMLHTTP")` or `CreateObject("WinHttp.WinHttpRequest")`
- **Registry changes:** `CreateObject("WScript.Shell").RegWrite`
- **Persistence:** Writing to startup folders or registry run keys
- **Anti-analysis:** `WScript.Sleep`, checking for VMs, timing checks

## Output Format

When analyzing a VBS file, structure your findings as:

```
## VBS Analysis Report

### File Information
- Path: <path>
- Size: <size>
- MD5: <hash>

### Static Analysis
- Obfuscation detected: <yes/no>
- Comment count: <number>
- Suspicious patterns: <list>

### Dynamic Analysis
- Execution output: <summary>
- File operations: <list>
- Network activity: <list>
- Registry changes: <list>

### Deobfuscated Code
<key decoded sections>

### Risk Assessment
- Threat level: <low/medium/high>
- Recommended action: <action>
```

## Safety Reminders

1. **Always analyze in isolation** - Use VMs or sandboxes
2. **Network isolation** - Disable network access during analysis
3. **Take snapshots** - Before running anything
4. **Document everything** - For incident response and reporting
5. **Don't trust comments** - They can be misleading

## Quick Reference

```bash
# Run with output
cscript.exe //nologo script.vbs

# Extract comments
grep "'" script.vbs

# Check for base64
grep -E "[A-Za-z0-9+/]{20,}={0,2}" script.vbs

# Check for hex strings
grep -E "&H[0-9A-Fa-f]+" script.vbs

# Find Eval/Execute
grep -iE "(eval|execute)\s*\(" script.vbs

# Find network objects
grep -iE "(xmlhttp|winhttp|socket)" script.vbs
```

## Next Steps

After initial analysis:

1. **If malicious:** Document indicators of compromise (IOCs)
2. **If unclear:** Run in deeper sandbox with network monitoring
3. **If safe:** Consider the script's legitimate purpose
4. **Always:** Report findings to appropriate security team
