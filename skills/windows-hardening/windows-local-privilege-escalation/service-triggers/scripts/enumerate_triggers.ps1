#!/usr/bin/env pwsh
# Windows Service Trigger Enumeration Script
# Usage: .\enumerate_triggers.ps1 [-ServiceName <name>] [-All]

param(
    [Parameter(Mandatory=$false)]
    [string]$ServiceName,
    
    [Parameter(Mandatory=$false)]
    [switch]$All
)

# High-value services to check by default
$highValueServices = @(
    'RemoteRegistry',
    'WebClient',
    'EFS',
    'LanmanServer',
    'Spooler',
    'BITS',
    'WSearch',
    'WinRM',
    'DcomLaunch',
    'RpcEptMapper'
)

function Get-ServiceTriggers {
    param([string]$ServiceName)
    
    Write-Host "`n=== Enumerating triggers for: $ServiceName ===" -ForegroundColor Cyan
    
    # Method 1: sc.exe
    Write-Host "`n[sc.exe qtriggerinfo]" -ForegroundColor Yellow
    $scOutput = sc.exe qtriggerinfo $ServiceName 2>$null
    if ($scOutput) {
        Write-Host $scOutput
    } else {
        Write-Host "No triggers found or service does not exist" -ForegroundColor Gray
    }
    
    # Method 2: Registry
    Write-Host "`n[Registry TriggerInfo]" -ForegroundColor Yellow
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName\TriggerInfo"
    if (Test-Path $regPath) {
        $regOutput = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
        if ($regOutput) {
            $regOutput | Format-List
        }
        
        # Recursive query
        Write-Host "`n[Full registry tree]" -ForegroundColor Yellow
        reg query "HKLM\SYSTEM\CurrentControlSet\Services\$ServiceName\TriggerInfo" /s 2>$null | Out-String
    } else {
        Write-Host "No TriggerInfo registry key found" -ForegroundColor Gray
    }
    
    # Method 3: Check for aggregated triggers (Windows 11+)
    Write-Host "`n[Aggregated Triggers Check]" -ForegroundColor Yellow
    $aggPath = "HKLM:\SYSTEM\CurrentControlSet\Control\ServiceAggregatedEvents"
    if (Test-Path $aggPath) {
        $subkeys = Get-ChildItem -Path $aggPath -ErrorAction SilentlyContinue
        if ($subkeys) {
            Write-Host "Aggregated trigger events found:" -ForegroundColor Gray
            $subkeys | ForEach-Object { Write-Host "  - $($_.Name)" }
        } else {
            Write-Host "No aggregated triggers configured" -ForegroundColor Gray
        }
    } else {
        Write-Host "Aggregated triggers path not found (may be Windows 10 or earlier)" -ForegroundColor Gray
    }
}

# Main execution
if ($All) {
    Write-Host "Enumerating triggers for all high-value services..." -ForegroundColor Green
    foreach ($svc in $highValueServices) {
        Get-ServiceTriggers -ServiceName $svc
    }
} elseif ($ServiceName) {
    Get-ServiceTriggers -ServiceName $ServiceName
} else {
    Write-Host "Windows Service Trigger Enumeration" -ForegroundColor Cyan
    Write-Host "=================================" -ForegroundColor Cyan
    Write-Host "`nUsage:" -ForegroundColor Yellow
    Write-Host "  .\enumerate_triggers.ps1 -ServiceName <ServiceName>  # Enumerate specific service"
    Write-Host "  .\enumerate_triggers.ps1 -All                        # Enumerate all high-value services"
    Write-Host "`nHigh-value services checked with -All:" -ForegroundColor Yellow
    $highValueServices | ForEach-Object { Write-Host "  - $_" }
}
