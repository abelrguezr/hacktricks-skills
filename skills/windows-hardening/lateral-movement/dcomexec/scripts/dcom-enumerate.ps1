# DCOM Enumeration Script
# Use this to enumerate DCOM applications on a target system
# Requires admin access to the target

param(
    [string]$TargetComputer = "localhost",
    [string]$Credential
)

Write-Host "[*] Enumerating DCOM applications on $TargetComputer" -ForegroundColor Cyan

try {
    # Method 1: Using CIM (PowerShell 3.0+)
    Write-Host "`n[+] Using CIM to enumerate DCOM applications..." -ForegroundColor Green
    $dcomApps = Get-CimInstance -ClassName Win32_DCOMApplication -ComputerName $TargetComputer -ErrorAction Stop
    
    if ($dcomApps) {
        Write-Host "`n[+] Found $($dcomApps.Count) DCOM applications:" -ForegroundColor Green
        $dcomApps | Select-Object Name, Description, ApplicationType | Format-Table -AutoSize
    }
    
    # Method 2: Check specific DCOM objects
    Write-Host "`n[+] Checking specific DCOM objects..." -ForegroundColor Green
    
    $testObjects = @(
        @{ProgID="MMC20.Application"; Name="MMC20.Application"},
        @{ProgID="Excel.Application"; Name="Excel.Application"},
        @{ProgID="Word.Application"; Name="Word.Application"},
        @{ProgID="PowerShell.1"; Name="PowerShell.1"}
    )
    
    foreach ($obj in $testObjects) {
        try {
            $com = [activator]::CreateInstance([type]::GetTypeFromProgID($obj.ProgID, $TargetComputer))
            Write-Host "[+] $obj.Name: AVAILABLE" -ForegroundColor Green
        }
        catch {
            Write-Host "[-] $obj.Name: NOT AVAILABLE" -ForegroundColor Red
        }
    }
    
    # Method 3: Check ShellWindows CLSID
    Write-Host "`n[+] Checking ShellWindows CLSID..." -ForegroundColor Green
    try {
        $clsid = "{C08AFD90-F2A1-11D1-8455-00A0C91F3880}"
        $com = [Type]::GetTypeFromCLSID($clsid, $TargetComputer)
        $obj = [System.Activator]::CreateInstance($com)
        Write-Host "[+] ShellWindows: AVAILABLE" -ForegroundColor Green
    }
    catch {
        Write-Host "[-] ShellWindows: NOT AVAILABLE" -ForegroundColor Red
    }
    
} catch {
    Write-Host "[-] Error: $_" -ForegroundColor Red
}

Write-Host "`n[*] Enumeration complete" -ForegroundColor Cyan
