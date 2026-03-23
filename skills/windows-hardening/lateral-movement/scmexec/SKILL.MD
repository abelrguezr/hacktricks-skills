---
name: scmexec-analysis
description: Analyze and understand SCMExec lateral movement techniques for security assessments. Use this skill when investigating Windows lateral movement, reviewing Service Control Manager abuse, analyzing SharpMove or similar tools, or when you need to understand how attackers create services to execute commands on remote systems. This skill helps with threat hunting, incident response, and security assessments involving Windows service-based command execution.
---

# SCMExec Analysis Skill

This skill helps security professionals understand, detect, and analyze SCMExec lateral movement techniques used in Windows environments.

## What is SCMExec?

SCMExec is a lateral movement technique that abuses the Service Control Manager (SCM) to execute commands on remote Windows systems. Attackers create a service that runs a malicious command, which can bypass security controls like UAC and Windows Defender.

## How It Works

1. **Service Creation**: The attacker creates a new Windows service on the remote system
2. **Command Execution**: The service is configured to run a specific command or payload
3. **Persistence**: The service may remain on the system for persistence
4. **Privilege Escalation**: Often requires administrative credentials on the target

## Detection Indicators

### Service Creation Events
- **Event ID 7045**: A new service was installed
- **Event ID 7040**: A service was changed
- **Event ID 7046**: A service was installed with a new service type

### PowerShell/Command Line Indicators
- `sc.exe create` commands
- `New-Service` PowerShell cmdlet
- `reg add` commands modifying service registry keys

### Network Indicators
- SMB traffic to remote systems (port 445)
- RPC traffic (port 135)
- Service control manager communication patterns

### File System Indicators
- New executable files in system directories
- Service binary paths pointing to unusual locations
- Temporary files in `%TEMP%` or similar directories

## Common Tools

### SharpMove
A C# tool that implements various lateral movement techniques including SCMExec.

**Example usage pattern:**
```
SharpMove.exe action=scm computername=remote.host.local command="C:\windows\temp\payload.exe" servicename=WindowsDebug amsi=true
```

**Parameters:**
- `action=scm`: Specifies SCMExec technique
- `computername`: Target system
- `command`: Command or payload to execute
- `servicename`: Name of the service to create
- `amsi=true`: Bypass AMSI (Antimalware Scan Interface)

### Other Tools
- `psexec` (Sysinternals - legitimate tool often abused)
- `wmic` service commands
- PowerShell `New-Service` cmdlet
- `sc.exe` command-line tool

## Defensive Recommendations

### Monitoring
1. **Enable Service Creation Logging**: Ensure Event ID 7045 is being captured
2. **Monitor Service Binary Paths**: Alert on services pointing to unusual locations
3. **Track Remote Service Creation**: Monitor for services created via remote connections
4. **Watch for Suspicious Service Names**: Services with random or obfuscated names

### Prevention
1. **Least Privilege**: Limit administrative access to systems
2. **Network Segmentation**: Restrict lateral movement between systems
3. **Application Whitelisting**: Prevent unauthorized executables from running
4. **Disable Unnecessary Services**: Reduce attack surface
5. **Enable Credential Guard**: Protect credentials from theft

### Response Actions
1. **Identify the Service**: Use `sc query` or `Get-Service` to find the malicious service
2. **Stop and Delete**: `sc stop <service>` then `sc delete <service>`
3. **Remove Payload**: Delete the executable or script being run
4. **Investigate Source**: Determine how the attacker gained access
5. **Check for Persistence**: Look for other persistence mechanisms

## Investigation Commands

### Find Recently Created Services
```powershell
Get-EventLog -LogName System -EntryType Information -InstanceId 7045 -Newest 50
```

### List All Services with Details
```powershell
Get-Service | Select-Object Name, DisplayName, Status, StartType
```

### Check Service Binary Path
```powershell
Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Services\<ServiceName> | Select-Object ImagePath
```

### Find Services with Suspicious Paths
```powershell
Get-Service | ForEach-Object {
    $path = (Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Services\$_.Name).ImagePath
    if ($path -match "temp|appdata|users.*documents") {
        Write-Output "Suspicious: $($_.Name) - $path"
    }
}
```

## Registry Keys to Monitor

- `HKLM\SYSTEM\CurrentControlSet\Services\` - Service definitions
- `HKLM\SYSTEM\CurrentControlSet\Services\<ServiceName>\ImagePath` - Service binary path
- `HKLM\SYSTEM\CurrentControlSet\Services\<ServiceName>\Start` - Service startup type

## Related Techniques

- **DCOM/WMIC**: Similar remote execution via Windows Management Instrumentation
- **WMI Event Subscription**: Persistence via WMI event subscriptions
- **Scheduled Tasks**: Alternative persistence and execution mechanism
- **PsExec**: Legitimate tool commonly abused for lateral movement

## References

- [MITRE ATT&CK: Service Execution (T1543.003)](https://attack.mitre.org/techniques/T1543/003/)
- [SharpMove GitHub](https://github.com/0xthirteen/SharpMove)
- [Sysinternals PsExec](https://learn.microsoft.com/en-us/sysinternals/downloads/psexec)
- [Windows Service Control Manager](https://learn.microsoft.com/en-us/windows/win32/services/service-control-manager)

## Usage Notes

This skill is intended for:
- Security professionals conducting authorized assessments
- Incident responders investigating compromises
- Threat hunters looking for lateral movement indicators
- Security engineers building detection capabilities

Always ensure you have proper authorization before testing or investigating systems.
