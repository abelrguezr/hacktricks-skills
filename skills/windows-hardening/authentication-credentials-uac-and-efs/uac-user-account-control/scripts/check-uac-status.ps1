#!/usr/bin/env pwsh
# Check-UAC-Status.ps1
# Quick script to assess UAC configuration and current privileges

Write-Host "=== UAC Status Check ===" -ForegroundColor Cyan

# Check UAC EnableLUA
$uacEnabled = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -ErrorAction SilentlyContinue
if ($uacEnabled) {
    $uacValue = $uacEnabled.EnableLUA
    Write-Host "UAC Enabled (EnableLUA): $uacValue" -ForegroundColor $(if ($uacValue -eq 1) { "Yellow" } else { "Green" })
} else {
    Write-Host "Could not read EnableLUA" -ForegroundColor Red
}

# Check ConsentPromptBehaviorAdmin
$consentBehavior = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -ErrorAction SilentlyContinue
if ($consentBehavior) {
    $behavior = $consentBehavior.ConsentPromptBehaviorAdmin
    $behaviorText = switch ($behavior) {
        0 { "Disabled - No prompt" }
        1 { "Prompt for credentials" }
        2 { "Elevate without prompt (not recommended)" }
        5 { "Default - Prompt for consent on secure desktop" }
        default { "Unknown: $behavior" }
    }
    Write-Host "Admin Prompt Behavior: $behavior ($behaviorText)" -ForegroundColor $(if ($behavior -eq 0) { "Green" } else { "Yellow" })
}

# Check current integrity level
Write-Host "`n=== Current Privileges ===" -ForegroundColor Cyan
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$groups = $identity.Groups

$integrityLevels = @{
    "S-1-16-12288" = "Medium"
    "S-1-16-12289" = "High"
    "S-1-16-12287" = "Low"
    "S-1-16-12290" = "System"
}

foreach ($level in $integrityLevels.Keys) {
    if ($groups -contains $level) {
        Write-Host "Integrity Level: $($integrityLevels[$level])" -ForegroundColor $(if ($level -eq "S-1-16-12289") { "Green" } else { "Yellow" })
        break
    }
}

# Check Administrators group membership
Write-Host "`n=== Group Membership ===" -ForegroundColor Cyan
$adminCheck = net localgroup administrators 2>$null | Select-String "\B$($env:USERNAME)\B"
if ($adminCheck) {
    Write-Host "User is in Administrators group: YES" -ForegroundColor Green
} else {
    Write-Host "User is in Administrators group: NO" -ForegroundColor Red
    Write-Host "Note: UAC bypass requires Administrators group membership" -ForegroundColor Yellow
}

# Check Windows version
Write-Host "`n=== System Info ===" -ForegroundColor Cyan
$osVersion = [Environment]::OSVersion.Version
Write-Host "Windows Version: $($osVersion.Major).$($osVersion.Minor) Build $($osVersion.Build)"

# Check for 64-bit
$arch = [Environment]::Is64BitOperatingSystem
Write-Host "64-bit OS: $arch"

Write-Host "`n=== Recommendations ===" -ForegroundColor Cyan
if ($uacValue -eq 0) {
    Write-Host "UAC is disabled - use Start-Process -Verb runAs" -ForegroundColor Green
} elseif ($adminCheck -and $uacValue -eq 1) {
    Write-Host "UAC enabled, you're admin - try fodhelper bypass" -ForegroundColor Green
} elseif (-not $adminCheck) {
    Write-Host "You're not in Administrators - need LPE exploit first" -ForegroundColor Red
} else {
    Write-Host "Consider token duplication or other bypass techniques" -ForegroundColor Yellow
}
