#!/usr/bin/env pwsh
# Windows TAPI Service Hardening Script
# CVE-2026-20931 - Telephony tapsrv Arbitrary DWORD Write to RCE

param(
    [switch]$DryRun,
    [switch]$Verbose,
    [switch]$Confirm
)

$ErrorActionPreference = "Stop"
$Changes = @()

function Write-Change {
    param($Action, $Target, $Details)
    $Changes += [PSCustomObject]@{
        Action = $Action
        Target = $Target
        Details = $Details
    }
    Write-Host "[+] $Action: $Target - $Details" -ForegroundColor Green
}

function Test-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Warning "This script requires Administrator privileges"
    exit 1
}

Write-Host "[*] Windows TAPI Service Hardening Script" -ForegroundColor Cyan
Write-Host "[*] CVE-2026-20931 Mitigation"
Write-Host ""

if ($DryRun) {
    Write-Host "[!] DRY RUN MODE - No changes will be made" -ForegroundColor Yellow
    Write-Host ""
}

if ($Confirm) {
    $response = Read-Host "This will disable TAPI server mode and restrict permissions. Continue? (Y/N)"
    if ($response -ne "Y" -and $response -ne "y") {
        Write-Host "[!] Operation cancelled by user" -ForegroundColor Yellow
        exit 0
    }
}

# Hardening 1: Disable TAPI Server Mode
Write-Host "[+] Disabling TAPI Server Mode..." -ForegroundColor Yellow
try {
    $tapiServerKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Telephony\Server"
    if (Test-Path $tapiServerKey) {
        $currentValue = Get-ItemProperty -Path $tapiServerKey -Name "DisableSharing" -ErrorAction SilentlyContinue
        if ($currentValue -and $currentValue.DisableSharing -eq 1) {
            Write-Change "SKIP" "TAPI Server Mode" "Already disabled (DisableSharing=1)"
        } else {
            if (-not $DryRun) {
                New-ItemProperty -Path $tapiServerKey -Name "DisableSharing" -Value "1" -PropertyType DWORD -Force | Out-Null
            }
            Write-Change "SET" "HKLM:\...\Telephony\Server\DisableSharing" "= 1 (disabled)"
        }
    } else {
        if (-not $DryRun) {
            New-Item -Path $tapiServerKey -Force | Out-Null
            New-ItemProperty -Path $tapiServerKey -Name "DisableSharing" -Value "1" -PropertyType DWORD -Force | Out-Null
        }
        Write-Change "CREATE" "HKLM:\...\Telephony\Server\DisableSharing" "= 1 (disabled)"
    }
} catch {
    Write-Host "[!] Failed to disable TAPI server mode: $_" -ForegroundColor Red
}

# Hardening 2: Stop and Disable TAPI Service
Write-Host "[+] Disabling TAPI Service..." -ForegroundColor Yellow
try {
    $tapiService = Get-Service -Name "TapiSrv" -ErrorAction SilentlyContinue
    if ($tapiService) {
        if ($tapiService.Status -eq "Running") {
            if (-not $DryRun) {
                Stop-Service -Name "TapiSrv" -Force -ErrorAction SilentlyContinue
            }
            Write-Change "STOP" "TapiSrv Service" "Service stopped"
        }
        if ($tapiService.StartType -ne "Disabled") {
            if (-not $DryRun) {
                Set-Service -Name "TapiSrv" -StartupType Disabled -ErrorAction SilentlyContinue
            }
            Write-Change "DISABLE" "TapiSrv Service" "Startup type set to Disabled"
        } else {
            Write-Change "SKIP" "TapiSrv Service" "Already disabled"
        }
    } else {
        Write-Change "SKIP" "TapiSrv Service" "Service not found"
    }
} catch {
    Write-Host "[!] Failed to disable TAPI service: $_" -ForegroundColor Red
}

# Hardening 3: Secure tsec.ini Permissions
Write-Host "[+] Securing tsec.ini Permissions..." -ForegroundColor Yellow
try {
    $tsecIni = "C:\Windows\TAPI\tsec.ini"
    if (Test-Path $tsecIni) {
        $acl = Get-Acl $tsecIni
        $needsChange = $false
        
        # Check if NETWORK SERVICE has write access
        foreach ($access in $acl.Access) {
            if ($access.IdentityReference -like "*NetworkService*" -or $access.IdentityReference -like "*NETWORK SERVICE*") {
                if ($access.FileSystemRights -match "Write" -or $access.FileSystemRights -match "Modify" -or $access.FileSystemRights -match "FullControl") {
                    $needsChange = $true
                    break
                }
            }
        }
        
        if ($needsChange) {
            if (-not $DryRun) {
                $newAcl = Get-Acl $tsecIni
                $newAcl.SetAccessRuleProtection($true, $false)
                
                # Add SYSTEM full control
                $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                    "SYSTEM",
                    "FullControl",
                    "Allow"
                )
                $newAcl.AddAccessRule($systemRule)
                
                # Add Administrators full control
                $adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                    "BUILTIN\Administrators",
                    "FullControl",
                    "Allow"
                )
                $newAcl.AddAccessRule($adminRule)
                
                Set-Acl $tsecIni $newAcl
            }
            Write-Change "SECURE" "C:\Windows\TAPI\tsec.ini" "Restricted to SYSTEM and Administrators only"
        } else {
            Write-Change "SKIP" "C:\Windows\TAPI\tsec.ini" "Already properly secured"
        }
    } else {
        Write-Change "SKIP" "C:\Windows\TAPI\tsec.ini" "File not found"
    }
} catch {
    Write-Host "[!] Failed to secure tsec.ini: $_" -ForegroundColor Red
}

# Hardening 4: Create Audit Rule for TAPI Changes
Write-Host "[+] Creating Audit Configuration..." -ForegroundColor Yellow
try {
    $auditPath = "C:\Windows\TAPI\"
    if (Test-Path $auditPath) {
        if (-not $DryRun) {
            # Enable file audit on TAPI directory
            $auditAcl = Get-Acl $auditPath
            $auditRule = New-Object System.Security.AccessControl.FileSystemAuditRule(
                "Everyone",
                "Write,Modify,Delete",
                "Failure"
            )
            $auditAcl.AddAuditRule($auditRule)
            Set-Acl $auditPath $auditAcl
        }
        Write-Change "AUDIT" "C:\Windows\TAPI\" "File system auditing enabled"
    } else {
        Write-Change "SKIP" "C:\Windows\TAPI\" "Directory not found"
    }
} catch {
    Write-Host "[!] Failed to configure audit: $_" -ForegroundColor Red
}

# Output Summary
Write-Host ""
Write-Host "[*] Hardening Complete" -ForegroundColor Cyan
Write-Host ""

if ($Changes.Count -gt 0) {
    $Changes | Format-Table -AutoSize
    Write-Host ""
    Write-Host "Total changes: $($Changes.Count)" -ForegroundColor Cyan
} else {
    Write-Host "No changes were necessary" -ForegroundColor Green
}

Write-Host ""
Write-Host "[+] Recommended follow-up actions:" -ForegroundColor Cyan
Write-Host "  1. Verify TAPI service is not required by applications" -ForegroundColor Gray
Write-Host "  2. Monitor event logs for TAPI-related events" -ForegroundColor Gray
Write-Host "  3. Review network access to named pipes" -ForegroundColor Gray
Write-Host "  4. Consider blocking remote SMB access to \\pipe\tapsrv" -ForegroundColor Gray

if ($DryRun) {
    Write-Host ""
    Write-Host "[!] This was a dry run. Re-run without -DryRun to apply changes" -ForegroundColor Yellow
}
