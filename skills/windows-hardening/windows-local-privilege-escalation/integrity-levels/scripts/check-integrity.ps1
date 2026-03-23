#!/usr/bin/env pwsh
# check-integrity.ps1 - Check integrity levels of files and processes
# Usage: .\check-integrity.ps1 [-Path <filepath>] [-ProcessName <name>] [-All]

param(
    [string]$Path,
    [string]$ProcessName,
    [switch]$All
)

$integrityMap = @{
    "S-1-16-0" = "Untrusted"
    "S-1-16-4096" = "Low"
    "S-1-16-8192" = "Medium"
    "S-1-16-12288" = "High"
    "S-1-16-16384" = "System"
    "S-1-16-20480" = "Installer"
}

function Get-IntegrityLevelFromSID {
    param([string]$SID)
    return $integrityMap[$SID] -or "Unknown"
}

function Get-FileIntegrity {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) {
        Write-Warning "File not found: $FilePath"
        return
    }
    
    $acl = Get-Acl $FilePath
    $identityReferences = $acl.IdentityReference | Where-Object { $_.Value -like "S-1-16-*" }
    
    if ($identityReferences) {
        foreach ($ref in $identityReferences) {
            $level = Get-IntegrityLevelFromSID $ref.Value
            Write-Host "File: $FilePath"
            Write-Host "Integrity Level: $level"
            Write-Host "SID: $($ref.Value)"
        }
    } else {
        Write-Host "File: $FilePath"
        Write-Host "Integrity Level: Default (Medium)"
    }
}

function Get-ProcessIntegrity {
    param([string]$ProcessName)
    
    $processes = if ($ProcessName) {
        Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    } else {
        Get-Process
    }
    
    foreach ($proc in $processes) {
        try {
            $acl = Get-Acl -InputObject $proc -ErrorAction Stop
            $identityReferences = $acl.IdentityReference | Where-Object { $_.Value -like "S-1-16-*" }
            
            $level = if ($identityReferences) {
                Get-IntegrityLevelFromSID $identityReferences[0].Value
            } else {
                "Unknown"
            }
            
            Write-Host "Process: $($proc.Name) (PID: $($proc.Id))"
            Write-Host "Integrity Level: $level"
            Write-Host ""
        }
        catch {
            Write-Warning "Could not access process: $($proc.Name) - $($_.Exception.Message)"
        }
    }
}

function Get-CurrentIntegrity {
    Write-Host "=== Current Process Integrity ==="
    $groups = whoami /groups 2>$null
    $integrityLine = $groups | Select-String "Mandatory"
    
    if ($integrityLine) {
        Write-Host $integrityLine
    } else {
        Write-Host "Could not determine current integrity level"
    }
}

# Main execution
if ($Path) {
    Get-FileIntegrity -FilePath $Path
}
elseif ($ProcessName) {
    Get-ProcessIntegrity -ProcessName $ProcessName
}
elseif ($All) {
    Write-Host "=== Current Process ==="
    Get-CurrentIntegrity
    Write-Host ""
    Write-Host "=== All Processes ==="
    Get-ProcessIntegrity
}
else {
    Write-Host "Windows Integrity Level Checker"
    Write-Host "=============================="
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  .\check-integrity.ps1 -Path <filepath>     Check file integrity"
    Write-Host "  .\check-integrity.ps1 -ProcessName <name>  Check process integrity"
    Write-Host "  .\check-integrity.ps1 -All                 Check current and all processes"
    Write-Host ""
    Write-Host "Example:"
    Write-Host "  .\check-integrity.ps1 -Path C:\Windows\System32\cmd.exe"
    Write-Host "  .\check-integrity.ps1 -ProcessName explorer"
    Write-Host "  .\check-integrity.ps1 -All"
}
