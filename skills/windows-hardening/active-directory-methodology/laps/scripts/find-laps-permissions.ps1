# LAPS Permission Finder
# Find who has permission to read LAPS passwords

param(
    [string]$ComputerName = "",
    [string]$OU = ""
)

Write-Host "=== LAPS Permission Analysis ===" -ForegroundColor Cyan

# Function to find extended rights
function Find-LAPSExtendedRights {
    param([string]$Target)
    
    Write-Host "`nSearching for LAPS permissions..." -ForegroundColor Yellow
    
    if ($Target) {
        Write-Host "  Target: $Target" -ForegroundColor Gray
        
        # Get object with LAPS properties
        $obj = Get-DomainObject -Identity $Target -Properties "ms-Mcs-AdmPwd" -ErrorAction SilentlyContinue
        
        if ($obj) {
            Write-Host "  Object found: $($obj.DnsHostname)" -ForegroundColor Green
            
            # Get ACLs
            $acl = Get-DomainObjectAcl -Identity $Target -ResolveGUIDs -ErrorAction SilentlyContinue
            
            # Filter for LAPS-related permissions
            $lapsRights = $acl | Where-Object {
                $_.ActiveDirectoryRights -match "ReadProperty" -and 
                $_.ObjectDN -match "ms-Mcs-AdmPwd"
            }
            
            if ($lapsRights) {
                Write-Host "`nPrincipals with LAPS read access:" -ForegroundColor Green
                $lapsRights | Select-Object @{N="Principal";E={$_.SecurityIdentifier}}, 
                                           @{N="Rights";E={$_.ActiveDirectoryRights}} | 
                Format-Table -AutoSize
            } else {
                Write-Host "`nNo specific LAPS permissions found" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  Object not found" -ForegroundColor Red
        }
    } else {
        Write-Host "  Please specify a ComputerName or OU to analyze" -ForegroundColor Yellow
    }
}

# Execute based on parameters
if ($ComputerName) {
    Find-LAPSExtendedRights -Target $ComputerName
} elseif ($OU) {
    Write-Host "  Analyzing OU: $OU" -ForegroundColor Gray
    # Get all computers in OU and check permissions
    $computers = Get-DomainComputer -SearchBase $OU -ErrorAction SilentlyContinue
    foreach ($comp in $computers) {
        Find-LAPSExtendedRights -Target $comp.Name
    }
} else {
    Write-Host "`nUsage:" -ForegroundColor Yellow
    Write-Host "  .\find-laps-permissions.ps1 -ComputerName <hostname>" -ForegroundColor Gray
    Write-Host "  .\find-laps-permissions.ps1 -OU <distinguished-name>" -ForegroundColor Gray
}

Write-Host "`n=== Analysis Complete ===" -ForegroundColor Cyan
