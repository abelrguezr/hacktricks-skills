---
name: macos-office-sandbox-bypass
description: Security testing skill for macOS Microsoft Office sandbox escape techniques. Use this skill when performing authorized security assessments, penetration testing, or vulnerability research on macOS Office applications. Trigger when users mention Office sandbox testing, macOS security auditing, privilege escalation research, or need to understand Office sandbox bypass methods for defensive purposes.
---

# macOS Office Sandbox Bypass Testing

This skill provides guidance on testing Microsoft Office sandbox escapes on macOS for **authorized security research and penetration testing only**. Never use these techniques on systems you don't own or have explicit permission to test.

## Overview

Microsoft Office on macOS uses a custom sandbox with the entitlement `com.apple.security.temporary-exception.sbpl`. This allows writing files anywhere if the filename starts with `~$`. Several bypass techniques have been discovered over time.

## Bypass Techniques

### 1. Launch Agent Bypass (Original)

**Mechanism**: Write a LaunchAgent plist to `~/Library/LaunchAgents/~$escape.plist`

**Sandbox Rule**: `(require-any (require-all (vnode-type REGULAR-FILE) (regex #"(^|/)~$[^/]+$")))`

**How it works**:
- Office sandbox allows writing files starting with `~$`
- LaunchAgents in `~/Library/LaunchAgents/` are executed at login
- Writing `~$escape.plist` creates persistence

**Test with script**:
```bash
python scripts/create-launchagent-plist.py --payload "your-command-here"
```

**Reference**: [MDSEC Report](https://www.mdsec.co.uk/2018/08/escaping-the-sandbox-microsoft-office-on-macos/)

---

### 2. Login Items + Zip Bypass

**Mechanism**: Use Login Items to unzip a malicious plist into LaunchAgents

**Why it works**:
- After patch #1, writing to `~/Library/LaunchAgents` was blocked
- Login Items can be set to zip files
- Archive Utility unzips to current location
- If `~/Library/LaunchAgents` doesn't exist, it gets created

**Steps**:
1. Create a plist file for LaunchAgent
2. Zip it as `~$escape.zip`
3. Add zip to Login Items
4. User login triggers unzip → persistence

**Test with script**:
```bash
python scripts/create-loginitem-zip.py --payload "your-command-here"
```

**Reference**: [Objective-See Report](https://objective-see.org/blog/blog_0x4B.html)

---

### 3. Login Items + .zshenv/.bash_profile Bypass

**Mechanism**: Overwrite shell profile files via Login Items

**Why it works**:
- Previous technique failed if `~/Library/LaunchAgents` already existed
- Shell profiles (`.zshenv`, `.bash_profile`) execute on terminal launch
- Zip can overwrite these files

**Steps**:
1. Create `.zshenv` and `.bash_profile` with payload
2. Zip them as `~$escape.zip`
3. Write zip to `~/~$escape.zip`
4. Add zip to Login Items, then add Terminal app
5. User login → unzip → terminal executes payload

**Test with script**:
```bash
python scripts/create-loginitem-zip.py --shell-profile --payload "your-command-here"
```

**Reference**: [Desi Jarvis Report](https://desi-jarvis.medium.com/office365-macos-sandbox-escape-fcce4fa4123c)

---

### 4. Open + Environment Variables Bypass

**Mechanism**: Use `open --env` to run Terminal with modified HOME

**Why it works**:
- `open` utility can launch apps from sandboxed processes
- `--env` option sets environment variables for launched app
- Setting `HOME` to a folder containing `.zshenv` causes execution

**Steps**:
1. Create `.zshenv` with payload inside sandbox-accessible folder
2. Run: `open --env HOME=/path/to/folder --env __OSINSTALL_ENVIROMENT=1 -a Terminal`
3. Terminal executes `.zshenv` from modified HOME

**Test with script**:
```bash
python scripts/create-env-bypass.py --payload "your-command-here" --target-folder /path/to/sandbox/folder
```

**Reference**: [Perception Point Report](https://perception-point.io/blog/technical-analysis-of-cve-2021-30864/)

---

### 5. Open + Stdin Bypass

**Mechanism**: Pass Python script via stdin to bypass quarantine

**Why it works**:
- `open --stdin` parameter allows passing input to launched app
- Python won't execute quarantined files from filesystem
- But stdin input bypasses quarantine checks
- Child process of launchd, not bound to Word's sandbox

**Steps**:
1. Drop `~$exploit.py` with Python payload
2. Run: `open --stdin='~$exploit.py' -a Python`
3. Python executes code from stdin

**Test with script**:
```bash
python scripts/create-env-bypass.py --stdin --payload "your-python-code-here"
```

---

## Testing Workflow

### Before Testing

1. **Verify authorization** - Only test on systems you own or have written permission to assess
2. **Document scope** - Record which techniques you're testing and why
3. **Backup data** - Some techniques modify system files
4. **Use isolated environment** - Prefer VMs or test machines

### Testing Steps

1. **Identify Office version** - Different versions have different patches
2. **Check sandbox status** - Verify Office is running sandboxed
3. **Select appropriate bypass** - Based on Office version and system state
4. **Run test script** - Use provided scripts to generate test files
5. **Verify execution** - Check if payload executed (use logging, not destructive commands)
6. **Clean up** - Remove test files and restore system state

### Cleanup Commands

```bash
# Remove test LaunchAgents
rm -f ~/Library/LaunchAgents/~$*.plist

# Remove test shell profiles
rm -f ~/.zshenv ~/.bash_profile

# Remove test Python files
rm -f ~/~$*.py

# Remove test zips
rm -f ~/~$*.zip
```

---

## Defensive Recommendations

### For Security Teams

1. **Keep Office updated** - Microsoft patches these vulnerabilities
2. **Monitor LaunchAgents** - Alert on new plist files in `~/Library/LaunchAgents/`
3. **Watch Login Items** - Monitor for unusual additions
4. **Restrict shell profile modifications** - Use configuration management
5. **Deploy EDR** - Detect sandbox escape attempts
6. **Application allowlisting** - Restrict which apps can be launched

### Detection Indicators

- New files starting with `~$` in user directories
- Unusual LaunchAgent plists created
- Login Items modified to include zip files
- `open` commands with `--env` or `--stdin` parameters
- Python processes spawned from Office parent

---

## Legal and Ethical Notice

**This skill is for authorized security testing only.**

- Only use on systems you own or have explicit written permission to test
- Document all testing activities
- Clean up after testing
- Report findings to appropriate parties
- Never use for malicious purposes

Violating computer misuse laws can result in criminal charges and civil liability.

---

## References

- [MDSEC: Escaping the Sandbox Microsoft Office on macOS](https://www.mdsec.co.uk/2018/08/escaping-the-sandbox-microsoft-office-on-macos/)
- [Objective-See: Blog 0x4B](https://objective-see.org/blog/blog_0x4B.html)
- [Desi Jarvis: Office365 macOS Sandbox Escape](https://desi-jarvis.medium.com/office365-macos-sandbox-escape-fcce4fa4123c)
- [Perception Point: CVE-2021-30864 Analysis](https://perception-point.io/blog/technical-analysis-of-cve-2021-30864/)
