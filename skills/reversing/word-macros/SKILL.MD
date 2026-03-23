---
name: word-macro-analyzer
description: Analyze and reverse engineer Word macros for security research. Use this skill whenever you need to examine VBA macros in Word documents, identify obfuscation techniques, detect junk code patterns, analyze macro forms for hidden data, or investigate potentially malicious macro behavior. Make sure to use this skill for any Word document macro analysis, VBA code review, or macro security assessment tasks.
---

# Word Macro Analyzer

A skill for analyzing and reverse engineering Word macros, with focus on identifying obfuscation techniques, junk code, and hidden data in macro forms.

## When to Use This Skill

Use this skill when:
- You need to analyze VBA macros in Word documents (.docm, .dotm)
- You suspect a macro contains obfuscation or anti-analysis techniques
- You want to identify junk code patterns that complicate reversing
- You need to extract and analyze data hidden in macro forms
- You're investigating potentially malicious macro behavior
- You're doing security research on macro-based attacks

## Core Analysis Techniques

### 1. Junk Code Detection

Junk code is intentionally useless code inserted to make macro reversing more difficult. Common patterns include:

**Never-true conditions:**
```vba
If False Then
    ' Junk code that never executes
    Dim x As Integer
    x = 1 + 2 + 3 + 4 + 5
    ' More useless operations
End If
```

**Dead code blocks:**
```vba
If SomeVariable = "impossible_value" Then
    ' This code path is unreachable
    Call UselessFunction()
End If
```

**Useless variable assignments:**
```vba
Dim temp As String
temp = "useless"
temp = "also useless"
temp = "never used"
' temp is never referenced again
```

**Analysis approach:**
1. Look for conditions that can never be true (e.g., `If False Then`, `If 1 = 2 Then`)
2. Identify variables that are assigned but never read
3. Find functions that are defined but never called
4. Trace execution paths to find unreachable code

### 2. Macro Forms Analysis

Macros can use forms to hide data, making analysis more difficult:

**GetObject for form data:**
```vba
Dim form As Object
Set form = GetObject("Forms!HiddenForm")
Dim hiddenData As String
hiddenData = form.TextBox1.Text
```

**Nested text boxes:**
- Text boxes can contain other text boxes
- Data can be hidden in properties (Caption, Name, Tag)
- Forms can be hidden from the user interface

**Analysis approach:**
1. Search for `GetObject` calls targeting forms
2. Look for references to `Forms!` or `UserForms`
3. Examine text box properties for hidden data
4. Check for nested container objects

### 3. Common Obfuscation Patterns

**String encoding:**
```vba
Dim encoded As String
encoded = Chr(65) & Chr(66) & Chr(67)  ' = "ABC"
```

**Variable name obfuscation:**
```vba
Dim a1b2c3 As String  ' Unreadable variable names
Dim x9y8z7 As Integer
```

**Control flow obfuscation:**
```vba
If True Then
    If False Then
        ' Dead code
    Else
        ' Actual code
    End If
End If
```

## Analysis Workflow

### Step 1: Extract Macro Code

Use the `extract_macros.py` script to pull VBA code from Word documents:

```bash
python scripts/extract_macros.py document.docm
```

This outputs the macro code to `output/macros/` with each module in a separate file.

### Step 2: Identify Junk Code

Run the junk code analyzer:

```bash
python scripts/analyze_junk_code.py output/macros/
```

This identifies:
- Never-true conditions
- Unused variables
- Dead code blocks
- Unreachable functions

### Step 3: Analyze Macro Forms

Use the form analyzer to find hidden data:

```bash
python scripts/analyze_forms.py output/macros/
```

This extracts:
- Form references via GetObject
- Text box contents and properties
- Nested container structures

### Step 4: Manual Review

Review the analysis results and:
1. Trace actual execution paths (ignoring junk code)
2. Identify the macro's true purpose
3. Look for suspicious behavior (file access, network calls, etc.)
4. Document findings

## Red Flags to Watch For

| Pattern | Risk Level | Description |
|---------|------------|-------------|
| `Shell` or `WScript.Shell` | High | Can execute arbitrary commands |
| `CreateObject("WScript.Shell")` | High | Process execution |
| `GetObject` with forms | Medium | May hide data or code |
| `CreateObject("ADODB.Stream")` | High | File operations, download payloads |
| `CreateObject("MSXML2.XMLHTTP")` | High | Network requests, C2 communication |
| `CreateObject("Scripting.FileSystemObject")` | Medium | File system access |
| `CreateObject("WScript.Network")` | Medium | Network operations |
| `CreateObject("Shell.Application")` | High | Shell operations |
| `CreateObject("Excel.Application")` | Medium | Cross-application attacks |
| `CreateObject("PowerPoint.Application")` | Medium | Cross-application attacks |

## Output Format

When analyzing a macro, structure your findings as:

```
## Macro Analysis Report

### Document Info
- Filename: [name]
- Macro modules: [count]
- Total lines: [count]

### Junk Code Summary
- Never-true conditions: [count]
- Unused variables: [count]
- Dead code blocks: [count]
- Estimated junk percentage: [X%]

### Form Analysis
- Forms referenced: [count]
- Hidden text boxes: [count]
- Data extracted: [summary]

### Suspicious Patterns
- [List any red flags found]

### Execution Flow
- [Describe the actual code path, ignoring junk]

### Conclusion
- [Assessment of macro purpose and risk]
```

## Tips for Effective Analysis

1. **Start with the entry point** - Look for `AutoOpen`, `AutoClose`, `Document_Open` procedures
2. **Ignore the noise** - Junk code is meant to distract; focus on reachable code
3. **Trace data flow** - Follow how data moves through the macro
4. **Check for external calls** - Look for COM objects, API calls, or file operations
5. **Decompile strings** - Convert `Chr()` sequences to readable text
6. **Document everything** - Keep notes on what you find for reporting

## References

- [HackTricks Word Macros](https://book.hacktricks.xyz/windows/active-directory-methodology/word-macros)
- [VBA Security Best Practices](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/security-considerations-for-vba)
- [Macro Analysis Tools](https://github.com/mandiant/flare-vm/wiki/Tools)
