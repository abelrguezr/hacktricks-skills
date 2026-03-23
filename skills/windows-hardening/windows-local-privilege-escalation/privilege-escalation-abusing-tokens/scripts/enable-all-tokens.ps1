# Enable All Token Privileges
# Based on: https://raw.githubusercontent.com/fashionproof/EnableAllTokenPrivs/master/EnableAllTokenPrivs.ps1
# Usage: .\enable-all-tokens.ps1

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class TokenPrivileges {
    [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
    static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall, ref TokPriv1Luid newst, int len, IntPtr prev, IntPtr relen);

    [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
    static extern bool OpenProcessToken(IntPtr h, int acc, out IntPtr tokthandle);

    [DllImport("advapi32.dll", SetLastError = true)]
    static extern bool LookupPrivilegeValue(string host, string name, ref long pluid);

    [DllImport("kernel32.dll", ExactSpelling = true)]
    static extern IntPtr GetCurrentProcess();

    [DllImport("advapi32.dll", ExactSpelling = true)]
    static extern bool CloseHandle(IntPtr h);

    const int SE_PRIVILEGE_ENABLED = 0x00000002;
    const int TOKEN_QUERY = 0x00000008;
    const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;

    [StructLayout(LayoutKind.Sequential)]
    public struct LUID {
        public int LowPart;
        public int HighPart;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct LUID_AND_ATTRIBUTES {
        public LUID Luid;
        public int Attributes;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct TokPriv1Luid {
        public int PrivilegeCount;
        public LUID_AND_ATTRIBUTES Privilege;
    }

    public static void EnablePrivilege(string privilegeName) {
        IntPtr hproc = GetCurrentProcess();
        IntPtr htok;
        OpenProcessToken(hproc, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, out htok);

        TokPriv1Luid tp = new TokPriv1Luid();
        tp.PrivilegeCount = 1;
        long luid = 0;
        LookupPrivilegeValue(null, privilegeName, ref luid);
        tp.Privilege.Luid.LowPart = (int)(luid & 0xFFFFFFFF);
        tp.Privilege.Luid.HighPart = (int)((luid >> 32) & 0xFFFFFFFF);
        tp.Privilege.Attributes = SE_PRIVILEGE_ENABLED;

        int size = Marshal.SizeOf(tp);
        IntPtr psize = Marshal.AllocHGlobal(size);
        Marshal.StructureToPtr(tp, psize, false);

        AdjustTokenPrivileges(htok, false, ref tp, size, IntPtr.Zero, IntPtr.Zero);
        CloseHandle(htok);
    }
}
"@

$privileges = @(
    "SeAssignPrimaryTokenPrivilege",
    "SeBackupPrivilege",
    "SeChangeNotifyPrivilege",
    "SeCreateGlobalPrivilege",
    "SeCreatePagefilePrivilege",
    "SeCreatePermanentPrivilege",
    "SeCreateSymbolicLinkPrivilege",
    "SeCreateTokenPrivilege",
    "SeDebugPrivilege",
    "SeEnableDelegationPrivilege",
    "SeImpersonatePrivilege",
    "SeIncreaseBasePriorityPrivilege",
    "SeIncreaseQuotaPrivilege",
    "SeIncreaseWorkingSetPrivilege",
    "SeLoadDriverPrivilege",
    "SeLockMemoryPrivilege",
    "SeMachineAccountPrivilege",
    "SeManageVolumePrivilege",
    "SeProfileSingleProcessPrivilege",
    "SeRelabelPrivilege",
    "SeRemoteShutdownPrivilege",
    "SeRestorePrivilege",
    "SeSecurityPrivilege",
    "SeShutdownPrivilege",
    "SeSyncAgentPrivilege",
    "SeSystemEnvironmentPrivilege",
    "SeSystemProfilePrivilege",
    "SeSystemtimePrivilege",
    "SeTakeOwnershipPrivilege",
    "SeTcbPrivilege",
    "SeTimeZonePrivilege",
    "SeTrustedCredManAccessPrivilege",
    "SeUndockPrivilege",
    "SeUnsolicitedInputPrivilege"
)

Write-Host "=== Enabling All Token Privileges ===" -ForegroundColor Cyan
Write-Host ""

foreach ($priv in $privileges) {
    try {
        [TokenPrivileges]::EnablePrivilege($priv)
        Write-Host "[+] Enabled: $priv" -ForegroundColor Green
    }
    catch {
        Write-Host "[-] Failed: $priv" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "[+] Run 'whoami /priv' to verify enabled privileges" -ForegroundColor Cyan
