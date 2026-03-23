#!/usr/bin/env pwsh
# set-integrity.ps1 - Set integrity level on files
# Usage: .\set-integrity.ps1 -Path <filepath> -Level <Low|Medium|High|System>
# Note: Requires elevated (High integrity) console to set High/System levels

param(
    [Parameter(Mandatory=$true)]
    [string]$Path,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet("Low", "Medium", "High", "System")]
    [string]$Level,
    
    [switch]$Inherit,
    [switch]$Confirm
)

$integritySIDs = @{
    "Low" = "S-1-16-4096"
    "Medium" = "S-1-16-8192"
    "High" = "S-1-16-12288"
    "System" = "S-1-16-16384"
}

function Test-Elevation {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Set-FileIntegrity {
    param(
        [string]$FilePath,
        [string]$IntegrityLevel,
        [switch]$Inherit
    )
    
    if (-not (Test-Path $FilePath)) {
        Write-Error "File not found: $FilePath"
        return $false
    }
    
    $sid = $integritySIDs[$IntegrityLevel]
    $inheritFlag = if ($Inherit) { "(oi)(ci)" } else { "" }
    
    Write-Host "Setting integrity level on: $FilePath"
    Write-Host "Target level: $IntegrityLevel ($sid)"
    Write-Host "Inheritance: $($Inherit.IsPresent)"
    Write-Host ""
    
    # Check if we're trying to set High/System without elevation
    if (($IntegrityLevel -eq "High" -or $IntegrityLevel -eq "System") -and -not (Test-Elevation)) {
        Write-Warning "WARNING: Setting High/System integrity requires elevated console"
        Write-Warning "This operation may fail or be silently ignored"
        Write-Host ""
    }
    
    # Use icacls to set the integrity level
    $command = "icacls `"$FilePath`" /setintegritylevel$inheritFlag $IntegrityLevel"
    Write-Host "Executing: $command"
    Write-Host ""
    
    $result = Invoke-Expression $command 2>&1
    Write-Host $result
    
    # Verify the change
    Write-Host ""
    Write-Host "Verifying..."
    $verify = icacls $FilePath 2>$null
    $verify | Select-String "Mandatory"
    
    return $true
}

# Main execution
if (-not (Test-Path $Path)) {
    Write-Error "Path not found: $Path"
    exit 1
}

if ($Confirm) {
    $response = Read-Host "Set $Path to $Level integrity? (y/n)"
    if ($response -ne "y") {
        Write-Host "Cancelled"
        exit 0
    }
}

Set-FileIntegrity -FilePath $Path -IntegrityLevel $Level -Inherit:$Inherit

Write-Host ""
Write-Host "Done!"
