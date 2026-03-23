---
name: msi-wrapper
description: Create MSI installer wrappers for Windows privilege escalation and persistence. Use this skill when you need to wrap executables or batch files in MSI installers for authorized penetration testing, security assessments, or red team operations on Windows systems. Trigger this skill for any request involving MSI packaging, ExeMSI configuration, or Windows installer-based privilege escalation techniques.
---

# MSI Wrapper Skill

## Overview

This skill helps you create MSI installer wrappers using ExeMSI, a tool that wraps executables in legitimate-looking MSI installers. This technique is valuable for:

- Bypassing application whitelisting controls
- Achieving persistence on Windows systems
- Privilege escalation scenarios
- Lateral movement operations

## Prerequisites

- Windows system with administrative access
- ExeMSI tool downloaded from https://www.exemsi.com/download/
- Target binary or batch file to wrap

## Quick Start

1. **Download ExeMSI** from the official website
2. **Execute the application** on your Windows system
3. **Select your target** binary or batch file to wrap
4. **Configure wrapper settings** (see Configuration Guide below)
5. **Build the MSI installer** by clicking through the wizard

## Configuration Guide

### Key Settings

When configuring ExeMSI, focus on these critical configuration areas:

#### Executable Selection
- Choose the binary you want to wrap
- For command-line execution only, you can select a `.bat` file instead of `cmd.exe`
- This allows you to execute specific commands without spawning a full command shell

#### Command Line Parameters
- Configure what commands should execute when the MSI runs
- Set appropriate parameters for your use case
- Test parameters in a controlled environment first

#### Installation Behavior
- Configure how the wrapper behaves during installation
- Set execution timing (immediate vs. deferred)
- Configure any persistence mechanisms needed

### For Batch Files

If you only need to execute command lines:

1. Create your `.bat` file with the desired commands
2. In ExeMSI, select the `.bat` file instead of `cmd.exe`
3. Configure the command execution settings
4. Build the MSI installer

## Usage Notes

- **Customization**: When packing your own binaries, you can modify configuration values to suit your needs
- **Testing**: Always test in a controlled environment before deployment
- **Stealth**: The wrapper can be customized to appear as legitimate software
- **Flexibility**: Works with various executable types and batch scripts

## Security Considerations

⚠️ **Important**: This technique should only be used:

- In authorized penetration testing engagements
- On systems you own or have explicit written permission to test
- For educational and defensive security purposes
- In compliance with applicable laws and regulations

## Workflow Example

```
1. Identify target binary → 2. Download ExeMSI → 3. Configure wrapper
4. Build MSI → 5. Test in lab → 6. Deploy (if authorized)
```

## Troubleshooting

- **Build fails**: Verify you have administrative privileges
- **Execution issues**: Check that the wrapped binary path is correct
- **Antivirus detection**: Test in isolated environment; consider additional obfuscation techniques

## References

- ExeMSI Documentation: https://www.exemsi.com/documentation/getting-started/
- HackTricks Windows Privilege Escalation Guide
- Windows MSI Installation Internals
