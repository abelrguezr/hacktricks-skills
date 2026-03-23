# LAPS Status Checker
# Quick script to check if LAPS is enabled on the local machine

Write-Host "=== LAPS Status Check ===" -ForegroundColor Cyan

# Check registry
Write-Host "`n[1] Registry Check:" -ForegroundColor Yellow
$regPath = "HKLM:\Software\Policies\Microsoft Services\AdmPwd"
if (Test-Path $regPath) {
    $enabled = Get-ItemProperty -Path $regPath -Name "AdmPwdEnabled" -ErrorAction SilentlyContinue
    if ($enabled.AdmPwdEnabled -eq 1) {
        Write-Host "  LAPS is ENABLED via registry" -ForegroundColor Green
    } else {
        Write-Host "  LAPS registry key exists but may be disabled" -ForegroundColor Yellow
    }
} else {
    Write-Host "  LAPS registry key NOT found" -ForegroundColor Red
}

# Check file system
Write-Host "`n[2] File System Check:" -ForegroundColor Yellow
$lapsPath = "C:\Program Files\LAPS\CSE"
if (Test-Path $lapsPath) {
    $dll = Get-ChildItem $lapsPath -Filter "AdmPwd.dll" -ErrorAction SilentlyContinue
    if ($dll) {
        Write-Host "  LAPS CSE files found:" -ForegroundColor Green
        Write-Host "    $($dll.FullName)" -ForegroundColor Gray
    } else {
        Write-Host "  LAPS folder exists but AdmPwd.dll not found" -ForegroundColor Yellow
    }
} else {
    Write-Host "  LAPS CSE folder NOT found" -ForegroundColor Red
}

# Check for LAPS PowerShell module
Write-Host "`n[3] PowerShell Module Check:" -ForegroundColor Yellow
$cmdlets = Get-Command *AdmPwd* -ErrorAction SilentlyContinue
if ($cmdlets) {
    Write-Host "  LAPS cmdlets available:" -ForegroundColor Green
    $cmdlets | ForEach-Object { Write-Host "    $($_.Name)" -ForegroundColor Gray }
} else {
    Write-Host "  LAPS PowerShell cmdlets NOT found" -ForegroundColor Red
}

Write-Host "`n=== Check Complete ===" -ForegroundColor Cyan
