#!/usr/bin/env pwsh
# Verify DLL was loaded by target service
# Usage: .\verify-dll-load.ps1 [-ProcmonFile <path-to-pml>] [-Path <hijacking-path>]

param(
    [string]$ProcmonFile = "boot_events.pml",
    [string]$Path = "C:\privesc_hijacking"
)

Write-Host "[*] Verifying DLL load from: $Path" -ForegroundColor Cyan

# Check if DLL exists in the path
$dlls = Get-ChildItem -Path $Path -Filter "*.dll" -ErrorAction SilentlyContinue

if ($dlls.Count -eq 0) {
    Write-Host "[-] No DLLs found in: $Path" -ForegroundColor Red
    exit 1
}

Write-Host "[+] Found $($dlls.Count) DLL(s) in $Path:" -ForegroundColor Green
foreach ($dll in $dlls) {
    Write-Host "    - $($dll.Name)" -ForegroundColor White
}

# Check Procmon for successful loads
if (Test-Path $ProcmonFile) {
    Write-Host "" -ForegroundColor White
    Write-Host "[*] Checking Procmon events for successful DLL loads..." -ForegroundColor Cyan
    
    # Try to parse CSV if available
    $csvFile = "missing_dlls.csv"
    if (Test-Path $csvFile) {
        try {
            $events = Import-Csv -Path $csvFile -ErrorAction SilentlyContinue
            
            if ($events) {
                # Filter for successful loads from our path
                $successfulLoads = $events | Where-Object {
                    $_.Path -like "*$Path*" -and 
                    $_.Result -eq "SUCCESS" -and 
                    $_.Operation -eq "Load Image"
                }
                
                if ($successfulLoads.Count -gt 0) {
                    Write-Host "[+] Found $($successfulLoads.Count) successful DLL load(s):" -ForegroundColor Green
                    Write-Host "" -ForegroundColor White
                    
                    foreach ($load in $successfulLoads) {
                        Write-Host "DLL: $($load.Path)" -ForegroundColor Cyan
                        Write-Host "  Process: $($load.ProcessName) (PID: $($load.PID))" -ForegroundColor Gray
                        Write-Host "  Time: $($load.TimeStamp)" -ForegroundColor Gray
                        Write-Host "" -ForegroundColor White
                    }
                    
                    Write-Host "[+] Privilege escalation likely successful!" -ForegroundColor Green
                    Write-Host "[*] Verify with: whoami /all" -ForegroundColor Cyan
                } else {
                    Write-Host "[-] No successful DLL loads found" -ForegroundColor Yellow
                    Write-Host "[*] The service may not have restarted yet" -ForegroundColor Yellow
                }
            }
        } catch {
            Write-Host "[-] Error parsing CSV: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "[*] CSV file not found. Please use Procmon GUI to verify." -ForegroundColor Yellow
    }
} else {
    Write-Host "[-] Procmon file not found: $ProcmonFile" -ForegroundColor Yellow
}

Write-Host "" -ForegroundColor White
Write-Host "[*] Verification complete!" -ForegroundColor Cyan
