#!/usr/bin/env pwsh
# Find Missing DLLs from Procmon Events
# Usage: .\find-missing-dlls.ps1 [-ProcmonFile <path-to-pml>] [-Path <hijacking-path>]

param(
    [string]$ProcmonFile = "boot_events.pml",
    [string]$Path = "C:\privesc_hijacking"
)

Write-Host "[*] Analyzing Procmon events for missing DLLs..." -ForegroundColor Cyan
Write-Host "[*] Procmon file: $ProcmonFile" -ForegroundColor Cyan
Write-Host "[*] Target path: $Path" -ForegroundColor Cyan

# Check if Procmon file exists
if (!(Test-Path $ProcmonFile)) {
    Write-Host "[-] Procmon file not found: $ProcmonFile" -ForegroundColor Red
    Write-Host "[*] Make sure to save Procmon boot events first" -ForegroundColor Yellow
    exit 1
}

# Try to use Procmon CLI if available
$procmonExe = "procmon.exe"
if (!(Test-Path $procmonExe)) {
    # Try common locations
    $procmonExe = Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\Sysinternals" -Filter "procmon.exe" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
    if (!$procmonExe) {
        Write-Host "[-] Procmon not found. Please download from Sysinternals" -ForegroundColor Red
        Write-Host "[*] https://learn.microsoft.com/en-us/sysinternals/downloads/procmon" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "[*] Using Procmon: $procmonExe" -ForegroundColor Green

# Export filtered events to CSV
$csvFile = "missing_dlls.csv"
Write-Host "[*] Filtering events and exporting to: $csvFile" -ForegroundColor Yellow

# Use Procmon CLI to filter and export
# Filter: Path contains <Path> AND Result is NAME NOT FOUND AND Operation is Load Image
$procmonArgs = @(
    "-AcceptEula",
    "$ProcmonFile",
    "-AcceptEula",
    "-OutputFormat", "CSV",
    "$csvFile"
)

# Note: Procmon CLI filtering is limited, we'll do post-processing
Write-Host "[*] Opening Procmon for manual filtering..." -ForegroundColor Yellow
Write-Host "[*] Apply these filters in Procmon:" -ForegroundColor Cyan
Write-Host "    1. Path contains $Path" -ForegroundColor White
Write-Host "    2. Result is NAME NOT FOUND" -ForegroundColor White
Write-Host "    3. Operation is Load Image" -ForegroundColor White
Write-Host "" -ForegroundColor White

# Alternative: Parse the PML file directly if possible
Write-Host "[*] Attempting to parse Procmon file..." -ForegroundColor Yellow

try {
    # Try to open with PowerShell (may not work for binary PML)
    $events = Import-Csv -Path $csvFile -ErrorAction SilentlyContinue
    
    if ($events) {
        Write-Host "[+] Found $($events.Count) events" -ForegroundColor Green
        
        # Filter for missing DLLs
        $missingDlls = $events | Where-Object {
            $_.Path -like "*$Path*" -and 
            $_.Result -eq "NAME NOT FOUND" -and 
            $_.Operation -eq "Load Image"
        }
        
        if ($missingDlls.Count -gt 0) {
            Write-Host "" -ForegroundColor White
            Write-Host "[+] Found $($missingDlls.Count) missing DLLs:" -ForegroundColor Green
            Write-Host "" -ForegroundColor White
            
            # Group by DLL name
            $dllGroups = $missingDlls | Group-Object -Property Path
            
            foreach ($group in $dllGroups) {
                $dllName = Split-Path $group.Name -Leaf
                $processName = $group.Group[0].ProcessName
                $pid = $group.Group[0].PID
                $commandLine = $group.Group[0].CommandLine
                
                Write-Host "DLL: $dllName" -ForegroundColor Cyan
                Write-Host "  Process: $processName (PID: $pid)" -ForegroundColor Gray
                Write-Host "  Command: $commandLine" -ForegroundColor Gray
                Write-Host "" -ForegroundColor White
            }
        } else {
            Write-Host "[-] No missing DLLs found with current filters" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[*] Could not parse CSV automatically" -ForegroundColor Yellow
        Write-Host "[*] Please open $csvFile in Excel or similar and filter manually" -ForegroundColor Yellow
    }
} catch {
    Write-Host "[-] Error parsing events: $_" -ForegroundColor Red
    Write-Host "[*] Please use Procmon GUI to filter manually" -ForegroundColor Yellow
}

Write-Host "" -ForegroundColor White
Write-Host "[*] Analysis complete!" -ForegroundColor Cyan
Write-Host "[*] Review the results and identify target services" -ForegroundColor Cyan
