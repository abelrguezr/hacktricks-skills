#!/usr/bin/env pwsh
# Parse ProcMon logs to find hijackable COM components
# Usage: . scripts/find-com-hijacks.ps1 -ProcMonLog "C:\path\to\procmon.pml"

param(
    [Parameter(Mandatory=$true)]
    [string]$ProcMonLog
)

Write-Host "[*] Parsing ProcMon log for hijackable COM components..." -ForegroundColor Cyan
Write-Host "    Log file: $ProcMonLog" -ForegroundColor Gray

# Validate log file exists
if (-not (Test-Path $ProcMonLog)) {
    Write-Host "[!] ProcMon log file not found: $ProcMonLog" -ForegroundColor Red
    exit 1
}

# Try to import ProcMon log (requires ProcMon CLI or manual export to CSV)
# ProcMon can export to CSV via File -> Save
$csvPath = $ProcMonLog -replace '\.pml$', '.csv'

if (Test-Path $csvPath) {
    Write-Host "[*] Found CSV export: $csvPath" -ForegroundColor Green
    $logs = Import-Csv -Path $csvPath
} else {
    Write-Host "[!] CSV export not found. Please export ProcMon log to CSV first." -ForegroundColor Yellow
    Write-Host "    In ProcMon: File -> Save, choose CSV format" -ForegroundColor Gray
    exit 1
}

# Filter for RegOpenKey operations with NAME NOT FOUND result and InprocServer32 path
$hijackable = @()

foreach ($log in $logs) {
    try {
        if ($log.Operation -eq "RegOpenKey" -or $log.Operation -eq "RegOpenKeyEx") {
            if ($log.Result -eq "NAME NOT FOUND") {
                if ($log.Path -like "*InprocServer32") {
                    # Extract CLSID from path
                    $parts = $log.Path -split '\\'
                    $clsid = $null
                    
                    foreach ($part in $parts) {
                        if ($part -match '^\{[0-9A-Fa-f-]{36}\}$') {
                            $clsid = $part
                            break
                        }
                    }
                    
                    if ($clsid) {
                        $existing = $hijackable | Where-Object { $_.CLSID -eq $clsid }
                        if (-not $existing) {
                            $hijackable += @{
                                CLSID = $clsid
                                Path = $log.Path
                                Process = $log.ProcessName
                                Count = 1
                            }
                        } else {
                            $existing.Count++
                        }
                    }
                }
            }
        }
    } catch {
        # Skip malformed entries
    }
}

if ($hijackable.Count -eq 0) {
    Write-Host "[!] No hijackable COM components found in log" -ForegroundColor Yellow
    exit 0
}

# Sort by frequency
$hijackable = $hijackable | Sort-Object Count -Descending

Write-Host "`n[*] Found $($hijackable.Count) potential hijack targets:" -ForegroundColor Green
Write-Host "`n" + ("=" * 100)

foreach ($item in $hijackable) {
    Write-Host "CLSID: $($item.CLSID)" -ForegroundColor Cyan
    Write-Host "  Path: $($item.Path)"
    Write-Host "  Process: $($item.Process)"
    Write-Host "  Frequency: $($item.Count) times"
    Write-Host ""
}

Write-Host "[TIP] Lower frequency targets are safer for persistence" -ForegroundColor Yellow
Write-Host "[TIP] Use create-com-hijack.ps1 to create hijack entries" -ForegroundColor Cyan
