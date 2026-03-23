# AMSI Status Check Script
# For authorized security research and detection engineering
# Run as administrator for full visibility

Write-Host "=== AMSI Status Check ===" -ForegroundColor Cyan
Write-Host ""

# Check if AMSI is loaded in current process
try {
    $amsiModule = Get-Module -Name "amsi" -ErrorAction SilentlyContinue
    if ($amsiModule) {
        Write-Host "AMSI Module Status: LOADED" -ForegroundColor Green
        Write-Host "Module Path: $($amsiModule.ModuleBase)" -ForegroundColor Gray
    } else {
        Write-Host "AMSI Module Status: NOT LOADED" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Error checking AMSI module: $_" -ForegroundColor Red
}

Write-Host ""

# Check PowerShell version
$psVersion = $PSVersionTable.PSVersion
Write-Host "PowerShell Version: $psVersion" -ForegroundColor Cyan
if ($psVersion.Major -eq 2) {
    Write-Host "WARNING: PowerShell v2 does not load AMSI" -ForegroundColor Yellow
}

Write-Host ""

# Check AMSI registry settings
try {
    $amsiRegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\amsi.dll"
    if (Test-Path $amsiRegPath) {
        Write-Host "AMSI Registry Key: EXISTS" -ForegroundColor Yellow
        Get-ItemProperty -Path $amsiRegPath | Format-List
    } else {
        Write-Host "AMSI Registry Key: NOT FOUND" -ForegroundColor Green
    }
} catch {
    Write-Host "Error checking registry: $_" -ForegroundColor Red
}

Write-Host ""

# Check for AMSI-related processes
Write-Host "Processes with AMSI loaded:" -ForegroundColor Cyan
Get-Process | Where-Object {
    try {
        $_.Modules | Where-Object { $_.ModuleName -eq "amsi.dll" }
    } catch { $false }
} | Select-Object ProcessName, Id | Format-Table

Write-Host ""
Write-Host "=== Check Complete ===" -ForegroundColor Cyan
Write-Host "Note: This script is for authorized security research only."
