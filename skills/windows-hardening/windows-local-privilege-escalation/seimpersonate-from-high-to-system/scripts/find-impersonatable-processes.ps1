# Find processes that can be impersonated for privilege escalation
# Run as Administrator

Write-Host "[*] Finding SYSTEM processes that Administrators can impersonate..." -ForegroundColor Cyan

# Get all SYSTEM processes
$systemProcesses = Get-Process | Where-Object {
    try {
        $principal = New-Object System.Security.Principal.WindowsIdentity ($_.Id)
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $token = $identity.Token
        $process = [System.Diagnostics.Process]::GetProcessById($_.Id)
        $process.MainModule.FileName -match "\\System32\\"
    } catch {
        $false
    }
} | Select-Object Id, ProcessName, @{Name="Username";Expression={
    try {
        [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    } catch { "Unknown" }
}}

# Common SYSTEM processes to check
$targetProcesses = @("winlogon", "wininit", "lsass", "services")

foreach ($procName in $targetProcesses) {
    $procs = Get-Process $procName -ErrorAction SilentlyContinue
    if ($procs) {
        foreach ($proc in $procs) {
            Write-Host "[+] Found: $($proc.ProcessName) (PID: $($proc.Id))" -ForegroundColor Green
            Write-Host "    Command: impersonateuser.exe $($proc.Id)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[-] Process not found: $procName" -ForegroundColor Gray
    }
}

Write-Host "`n[*] Recommended target: winlogon.exe (most reliable for impersonation)" -ForegroundColor Cyan
Write-Host "[*] Alternative: Check svchost.exe processes with Process Explorer" -ForegroundColor Cyan
