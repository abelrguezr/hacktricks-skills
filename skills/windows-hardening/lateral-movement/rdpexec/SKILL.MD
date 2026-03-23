---
name: rdpexec
description: Execute commands on remote Windows systems via RDP. Use this skill whenever you need to run commands on a remote Windows machine through Remote Desktop Protocol, including authorized security testing, system administration, or troubleshooting remote Windows systems. Make sure to use this skill when the user mentions RDP, remote desktop, Windows remote access, or needs to execute commands on a remote Windows system.
---

# RDPexec - Remote Desktop Command Execution

## Overview

RDPexec enables command execution on remote Windows systems by establishing an RDP (Remote Desktop Protocol) connection and running commands through the remote desktop session.

## When to Use This Skill

Use this skill when:
- You need to execute commands on a remote Windows system
- You have legitimate access credentials and authorization
- You're conducting authorized security assessments
- You need to troubleshoot or administer remote Windows systems
- The user mentions RDP, remote desktop, or Windows remote access

## Prerequisites

Before using this skill, ensure:
- You have valid credentials for the target system
- You have explicit authorization to access the target system
- RDP is enabled on the target (port 3389 by default)
- Network connectivity to the target system

## Security Warning

⚠️ **Authorization Required**: Only use RDPexec on systems you own or have explicit written authorization to test. Unauthorized access to computer systems is illegal and violates computer crime laws.

## Methods

### Method 1: Direct RDP Connection

1. Establish RDP connection to the target system
2. Open Command Prompt or PowerShell in the remote session
3. Execute desired commands

**Windows RDP Client:**
```powershell
mstsc /v:target-ip /admin
```

**Linux RDP Client (xfreerdp):**
```bash
xfreerdp /v:target-ip /u:username /p:password
```

### Method 2: Automated RDP Scripts

For repeated tasks, use the bundled scripts in `scripts/` to automate RDP connections and command execution.

### Method 3: PowerShell Remoting via RDP

Use PowerShell commands within the RDP session for advanced scripting:

```powershell
# Run commands in remote session
Get-Process
Get-Service
Get-NetTCPConnection -LocalPort 3389
```

## Common Use Cases

- **System Administration**: Deploy configurations, manage services, update software
- **Security Assessments**: Authorized penetration testing, vulnerability validation
- **Troubleshooting**: Diagnose remote system issues, check logs, verify connectivity
- **Software Deployment**: Install or update applications on remote systems
- **Configuration Management**: Apply security policies, modify registry settings

## Best Practices

1. **Document Everything**: Log all access and actions taken
2. **Least Privilege**: Use minimum necessary permissions
3. **Clean Exit**: Log out properly when finished
4. **Follow Policies**: Adhere to organizational security policies
5. **Authorization**: Never use on systems without explicit authorization

## Troubleshooting

### Connection Issues

| Problem | Solution |
|---------|----------|
| Cannot connect | Verify RDP is enabled on target (port 3389) |
| Authentication failed | Confirm credentials are correct |
| Network timeout | Check firewall rules and network connectivity |
| Session limit reached | Close existing RDP sessions or use /admin flag |

### Command Execution Issues

| Problem | Solution |
|---------|----------|
| Permission denied | Verify user has appropriate permissions |
| Command not found | Check if command is available on target system |
| Execution blocked | Review Windows security policies and AppLocker |

## Example Workflows

### Example 1: Basic Remote Command Execution

**Input:** "I need to check running services on a remote Windows server at 192.168.1.100"

**Output:**
```powershell
# Connect via RDP
mstsc /v:192.168.1.100

# In remote session, run:
Get-Service | Where-Object {$_.Status -eq 'Running'}
```

### Example 2: Security Assessment

**Input:** "I'm authorized to test RDP security on 10.0.0.50"

**Output:**
```powershell
# Check RDP configuration
Get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections'

# Verify security settings
Get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name 'UserAuthentication'
```

## References

- [Pentesting RDP](../../network-services-pentesting/pentesting-rdp.md)
- Microsoft RDP Documentation
- Windows Remote Desktop Security Guidelines
- NIST SP 800-123 Guide to General Server Security

## Scripts

This skill includes helper scripts in the `scripts/` directory:

- `rdp-connect.ps1` - PowerShell script for RDP connection automation
- `rdp-check.sh` - Bash script to verify RDP connectivity
- `rdp-security-audit.ps1` - PowerShell script for RDP security assessment

Use these scripts to streamline common RDP tasks. Read the script documentation for usage details.
