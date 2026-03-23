---
name: windows-integrity-levels
description: Windows Integrity Levels analysis and manipulation for security research and privilege escalation assessment. Use this skill whenever the user asks about Windows integrity levels, Mandatory Integrity Control (MIC), process integrity, file integrity levels, or needs to understand how Windows restricts access based on integrity levels. Trigger for questions about checking integrity levels, modifying integrity levels, understanding integrity level restrictions, or analyzing Windows security boundaries.
---

# Windows Integrity Levels

A skill for understanding and working with Windows Mandatory Integrity Control (MIC) system.

## Overview

Windows Vista and later use **integrity levels** to tag protected items. This prevents processes with lower integrity from modifying objects with higher integrity, regardless of traditional DACL permissions.

## Integrity Level Hierarchy

From lowest to highest:

1. **Untrusted** - Anonymous logins (e.g., Chrome sandbox)
2. **Low** - Internet interactions, Protected Mode, Temporary Internet Folder
3. **Medium** - Default for standard users and most activities
4. **High** - Administrators (when elevated)
5. **System** - Windows kernel and core services
6. **Installer** - Special level above all others for uninstallation

## Key Rules

- Objects cannot be modified by processes with lower integrity levels
- High integrity can modify lower levels; lower cannot modify higher
- Even Administrators group members run at Medium by default
- System level is out of reach even for administrators
- File system objects may have minimum integrity requirements
- All processes run under an integrity level

## Checking Integrity Levels

### Current Process Integrity

```powershell
whoami /groups
```

Look for the `Mandatory Level` entry in the output.

### Process Explorer Method

1. Open Process Explorer from Sysinternals
2. Right-click a process → Properties
3. View the **Security** tab
4. Check the integrity level in the security descriptor

### File Integrity Level

```powershell
icacls <filepath>
```

Look for `Mandatory Label\<Level> Mandatory Level:(NW)` in the output.

## Modifying Integrity Levels

### Set File Integrity Level

**Must be run from an elevated (High integrity) console:**

```powershell
icacls <filepath> /setintegritylevel(oi)(ci) <Level>
```

Where `<Level>` is: `Low`, `Medium`, `High`, `System`

**Important:** A Medium integrity process cannot assign High integrity to objects.

### Set Binary Integrity Level

```powershell
icacls C:\Windows\System32\cmd.exe /setintegritylevel Low
```

**Note:** Setting a binary to High integrity does NOT make it run at High integrity automatically. The process inherits integrity from its parent.

## Practical Implications

### File System Access

When a file has a minimum integrity level:
- You must run at **at least** that integrity level to modify it
- Read access may still be possible from lower levels
- Traditional DACL permissions are secondary to integrity levels

**Example:**
```powershell
# Create file as regular user (Medium integrity)
echo test > test.txt

# Set High integrity (requires admin)
icacls test.txt /setintegritylevel High

# Try to modify as regular user
echo new > test.txt  # Access is denied!
```

### Process Access

- A process cannot write to another process with higher integrity
- Low integrity processes cannot open handles with full access to Medium integrity processes
- This is a key defense against privilege escalation

### Binary Execution

- Setting a binary to Low integrity makes it run at Low integrity
- Setting a binary to High integrity does NOT make it run at High integrity
- Process integrity is inherited from the parent process

## Security Best Practices

1. **Run processes at the lowest integrity level possible** - minimizes attack surface
2. **Understand integrity boundaries** - know what your process can and cannot access
3. **Check integrity levels** - use `whoami /groups` to verify your current level
4. **Be aware of elevation** - Administrator group ≠ High integrity by default

## Common Use Cases

### Privilege Escalation Assessment

When assessing for privilege escalation:
1. Check your current integrity level
2. Identify files/processes with lower integrity that you can modify
3. Look for files with High integrity that you cannot modify
4. Understand which processes you can inject into or manipulate

### Security Hardening

To harden a system:
1. Set critical files to High integrity
2. Run untrusted applications at Low integrity
3. Verify integrity levels are properly configured
4. Monitor for integrity level violations

## Tools

### Included Scripts

- `check-integrity.ps1` - Check integrity levels of files and processes
- `set-integrity.ps1` - Set integrity levels on files (requires elevation)

### External Tools

- **Process Explorer** (Sysinternals) - View process integrity levels
- **whoami** - Built-in Windows tool for checking groups and integrity
- **icacls** - Built-in Windows tool for managing file permissions and integrity

## References

- [Microsoft: Mandatory Integrity Control](https://learn.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/user-account-control-admin-approval-mode-for-privileged-accounts)
- [Sysinternals Process Explorer](https://learn.microsoft.com/en-us/sysinternals/downloads/process-explorer)

## Quick Reference

| Level | Typical Use | Can Modify |
|-------|-------------|------------|
| Untrusted | Anonymous, sandboxed | Nothing |
| Low | Internet, Protected Mode | Low only |
| Medium | Standard users | Low, Medium |
| High | Elevated admins | All except System |
| System | Kernel, services | All except Installer |
| Installer | Uninstaller | Everything |
