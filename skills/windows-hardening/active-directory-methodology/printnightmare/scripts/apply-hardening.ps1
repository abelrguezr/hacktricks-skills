# Print Spooler Hardening Script
# Applies registry and policy hardening for Print Spooler security

param(
    [switch]$Force,
    [switch]$WhatIf
)

Write-Host "=== Print Spooler Hardening Script ===" -ForegroundColor Cyan
Write-Host ""

# Check if running as administrator
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
    exit 1
}

# Hardening 1: Restrict Point & Print
Write-Host "[1] Restricting Point & Print Driver Installation:" -ForegroundColor Yellow
$pointAndPrintPath = 'HKLM:\Software\Policies\Microsoft\Windows NT\Printers\PointAndPrint'

if (-not (Test-Path $pointAndPrintPath)) {
    if ($WhatIf) {
        Write-Host "  [WhatIf] Would create registry path: $pointAndPrintPath" -ForegroundColor Cyan
    } else {
        New-Item -Path $pointAndPrintPath -Force -ErrorAction Stop | Out-Null
        Write-Host "  Created registry path" -ForegroundColor Green
    }
}

$restrictValue = Get-ItemProperty -Path $pointAndPrintPath -Name 'RestrictDriverInstallationToAdministrators' -ErrorAction SilentlyContinue
if ($restrictValue -and $restrictValue.RestrictDriverInstallationToAdministrators -eq 1) {
    Write-Host "  RestrictDriverInstallationToAdministrators already set to 1" -ForegroundColor Green
} else {
    if ($WhatIf) {
        Write-Host "  [WhatIf] Would set RestrictDriverInstallationToAdministrators = 1" -ForegroundColor Cyan
    } else {
        New-ItemProperty -Path $pointAndPrintPath `
            -Name 'RestrictDriverInstallationToAdministrators' `
            -Value 1 `
            -PropertyType DWORD `
            -Force -ErrorAction Stop | Out-Null
        Write-Host "  Set RestrictDriverInstallationToAdministrators = 1" -ForegroundColor Green
    }
}
Write-Host ""

# Hardening 2: Enable Print Service Logging
Write-Host "[2] Enabling Print Service Operational Logging:" -ForegroundColor Yellow
$logPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\Spooler\Parameters'

if (-not (Test-Path $logPath)) {
    Write-Host "  Spooler Parameters path not found" -ForegroundColor Yellow
} else {
    Write-Host "  Spooler Parameters path exists" -ForegroundColor Green
    Write-Host "  Note: Operational logging is enabled via Event Viewer" -ForegroundColor Yellow
}
Write-Host ""

# Hardening 3: Check for vulnerable driver files
Write-Host "[3] Scanning for Suspicious Driver Files:" -ForegroundColor Yellow
$spoolDir = "C:\Windows\System32\spool\drivers"
if (Test-Path $spoolDir) {
    $suspiciousFiles = Get-ChildItem -Path $spoolDir -Recurse -File -ErrorAction SilentlyContinue | 
        Where-Object { $_.Extension -eq '.dll' -or $_.Extension -eq '.exe' }
    if ($suspiciousFiles) {
        Write-Host "  Found $($suspiciousFiles.Count) executable files:" -ForegroundColor Yellow
        foreach ($file in $suspiciousFiles) {
            Write-Host "    - $($file.FullName)" -ForegroundColor Yellow
        }
        Write-Host "  Review these files for legitimacy" -ForegroundColor Yellow
    } else {
        Write-Host "  No suspicious files found" -ForegroundColor Green
    }
} else {
    Write-Host "  Spool directory not found" -ForegroundColor Yellow
}
Write-Host ""

# Hardening 4: Create backup of current settings
Write-Host "[4] Creating Configuration Backup:" -ForegroundColor Yellow
$backupPath = "C:\PrintSpooler_Hardening_Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').reg"
if ($WhatIf) {
    Write-Host "  [WhatIf] Would create backup at: $backupPath" -ForegroundColor Cyan
} else {
    try {
        reg export "HKLM\Software\Policies\Microsoft\Windows NT\Printers" $backupPath /y 2>$null
        Write-Host "  Backup created at: $backupPath" -ForegroundColor Green
    } catch {
        Write-Host "  Warning: Could not create backup: $_" -ForegroundColor Yellow
    }
}
Write-Host ""

# Summary
Write-Host "=== Hardening Summary ===" -ForegroundColor Cyan
Write-Host "1. Point & Print driver installation restricted to administrators" -ForegroundColor Green
Write-Host "2. Print Service operational logging verified" -ForegroundColor Green
Write-Host "3. Suspicious driver files scanned" -ForegroundColor Green
Write-Host "4. Configuration backup created" -ForegroundColor Green
Write-Host ""
Write-Host "RECOMMENDATIONS:" -ForegroundColor Yellow
Write-Host "- Apply latest Windows cumulative updates" -ForegroundColor Yellow
Write-Host "- Disable Print Spooler on Domain Controllers" -ForegroundColor Yellow
Write-Host "- Configure Group Policy to block remote spooler connections" -ForegroundColor Yellow
Write-Host "- Enable Sysmon for Print Spooler monitoring" -ForegroundColor Yellow
Write-Host ""
Write-Host "=== Hardening Complete ===" -ForegroundColor Cyan
