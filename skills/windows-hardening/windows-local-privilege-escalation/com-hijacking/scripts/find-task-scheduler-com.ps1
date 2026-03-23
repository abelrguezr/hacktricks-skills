#!/usr/bin/env pwsh
# Find hijackable Task Scheduler COM components
# Usage: . scripts/find-task-scheduler-com.ps1

Write-Host "[*] Enumerating Task Scheduler COM components..." -ForegroundColor Cyan

$Tasks = Get-ScheduledTask -ErrorAction SilentlyContinue

if ($Tasks -eq $null) {
    Write-Host "[!] No scheduled tasks found or insufficient permissions" -ForegroundColor Red
    exit 1
}

$usersSid = "S-1-5-32-545"
$usersGroup = Get-LocalGroup | Where-Object { $_.SID -eq $usersSid }

$found = @()

foreach ($Task in $Tasks) {
    try {
        if ($Task.Actions.ClassId -ne $null) {
            if ($Task.Triggers.Enabled -eq $true) {
                if ($Task.Principal.GroupId -eq $usersGroup) {
                    $clsid = $Task.Actions.ClassId
                    
                    # Check if CLSID exists in HKCU (it shouldn't for a good target)
                    $existsInHkcu = Test-Path "HKCU:Software\Classes\CLSID\$clsid"
                    
                    # Check if CLSID exists in HKLM (it should)
                    $existsInHklm = Test-Path "HKLM:Software\Classes\CLSID\$clsid"
                    
                    $target = @{
                        TaskName = $Task.TaskName
                        TaskPath = $Task.TaskPath
                        CLSID = $clsid
                        ExistsInHKCU = $existsInHkcu
                        ExistsInHKLM = $existsInHklm
                        IsTarget = (-not $existsInHkcu) -and $existsInHklm
                    }
                    
                    $found += $target
                }
            }
        }
    } catch {
        Write-Host "[!] Error processing task $($Task.TaskName): $_" -ForegroundColor Yellow
    }
}

if ($found.Count -eq 0) {
    Write-Host "[!] No hijackable Task Scheduler COM components found" -ForegroundColor Yellow
    exit 0
}

Write-Host "`n[*] Found $($found.Count) potential targets:" -ForegroundColor Green
Write-Host "`n" + ("=" * 100)

foreach ($item in $found) {
    $status = if ($item.IsTarget) { "[TARGET]" } else { "[NOT TARGET]" }
    $statusColor = if ($item.IsTarget) { "Green" } else { "Yellow" }
    
    Write-Host "$status Task: $($item.TaskName)" -ForegroundColor $statusColor
    Write-Host "  Path: $($item.TaskPath)"
    Write-Host "  CLSID: $($item.CLSID)"
    Write-Host "  Exists in HKCU: $($item.ExistsInHKCU)"
    Write-Host "  Exists in HKLM: $($item.ExistsInHKLM)"
    Write-Host ""
}

Write-Host "`n[TIP] Targets marked [TARGET] can be hijacked by creating HKCU entries" -ForegroundColor Cyan
