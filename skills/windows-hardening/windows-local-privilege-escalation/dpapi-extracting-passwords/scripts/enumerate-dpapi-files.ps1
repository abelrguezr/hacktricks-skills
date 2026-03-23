#!/usr/bin/env pwsh
# DPAPI File Enumerator
# Lists all DPAPI-related files for a user or all users

param(
    [string]$Username = $env:USERNAME,
    [switch]$AllUsers,
    [switch]$Verbose
)

function Get-DPAPIPaths {
    param([string]$UserPath)
    
    $paths = @(
        "$UserPath\AppData\Roaming\Microsoft\Protect",
        "$UserPath\AppData\Local\Microsoft\Protect",
        "$UserPath\AppData\Roaming\Microsoft\Credentials",
        "$UserPath\AppData\Local\Microsoft\Credentials",
        "$UserPath\AppData\Roaming\Microsoft\Vault",
        "$UserPath\AppData\Local\Microsoft\Vault"
    )
    
    return $paths
}

function Write-Header {
    param([string]$Title)
    Write-Host "`n=== $Title ===" -ForegroundColor Cyan
}

if ($AllUsers) {
    $users = Get-ChildItem "C:\Users" -Directory | Where-Object { $_.Name -notmatch 'Default|Default User|Public|NTUSER' }
    
    foreach ($user in $users) {
        Write-Header "User: $($user.Name)"
        $paths = Get-DPAPIPaths $user.FullName
        
        foreach ($path in $paths) {
            if (Test-Path $path) {
                Write-Host "Path: $path" -ForegroundColor Yellow
                $files = Get-ChildItem $path -Recurse -Force -ErrorAction SilentlyContinue
                
                if ($files) {
                    $files | Select-Object FullName, Length, LastWriteTime | Format-Table -AutoSize
                } else {
                    Write-Host "  (no files found)" -ForegroundColor Gray
                }
            } else {
                Write-Host "  (path not found)" -ForegroundColor Gray
            }
        }
    }
} else {
    $userPath = "C:\Users\$Username"
    
    if (-not (Test-Path $userPath)) {
        Write-Host "Error: User path not found: $userPath" -ForegroundColor Red
        exit 1
    }
    
    Write-Header "User: $Username"
    $paths = Get-DPAPIPaths $userPath
    
    foreach ($path in $paths) {
        if (Test-Path $path) {
            Write-Host "Path: $path" -ForegroundColor Yellow
            $files = Get-ChildItem $path -Recurse -Force -ErrorAction SilentlyContinue
            
            if ($files) {
                if ($Verbose) {
                    $files | Select-Object FullName, Length, LastWriteTime | Format-Table -AutoSize
                } else {
                    $files | ForEach-Object { Write-Host "  $($_.FullName)" }
                }
            } else {
                Write-Host "  (no files found)" -ForegroundColor Gray
            }
        } else {
            Write-Host "  (path not found)" -ForegroundColor Gray
        }
    }
}

Write-Host "`nDone." -ForegroundColor Green
