# Active Directory ACL Enumeration Script
# Usage: .\enumerate-acls.ps1 -DomainUser "DOMAIN\username" -TargetType "All|User|Group|Computer|GPO"

param(
    [Parameter(Mandatory=$true)]
    [string]$DomainUser,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("All", "User", "Group", "Computer", "GPO")]
    [string]$TargetType = "All",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputFile = "acl-enumeration-results.json"
)

# Load PowerView if available
$PowerViewPath = ".\PowerView.ps1"
if (Test-Path $PowerViewPath) {
    . $PowerViewPath
    Write-Host "[+] PowerView loaded" -ForegroundColor Green
} else {
    Write-Host "[!] PowerView not found at $PowerViewPath - some functions may not work" -ForegroundColor Yellow
}

$results = @()

Write-Host "[*] Enumerating ACLs for: $DomainUser" -ForegroundColor Cyan

# Function to check ACLs on objects
function Test-ObjectACLs {
    param(
        [string]$ObjectDN,
        [string]$ObjectType,
        [string]$ObjectName
    )
    
    try {
        $acls = Get-ObjectAcl -ResolveGUIDs -Identity $ObjectDN 2>$null
        
        if ($acls) {
            $relevant = $acls | Where-Object {
                $_.IdentityReference -eq $DomainUser -or 
                $_.IdentityReference -like "*\$DomainUser"
            }
            
            if ($relevant) {
                foreach ($acl in $relevant) {
                    $result = [PSCustomObject]@{
                        ObjectType = $ObjectType
                        ObjectName = $ObjectName
                        ObjectDN = $ObjectDN
                        Permission = $acl.ActiveDirectoryRights
                        AccessControlType = $acl.AccessControlType
                        Inherited = $acl.IsInherited
                        Timestamp = Get-Date
                    }
                    $results += $result
                    Write-Host "[+] Found: $Permission on $ObjectType '$ObjectName'" -ForegroundColor Green
                }
            }
        }
    }
    catch {
        Write-Host "[-] Error checking $ObjectDN: $_" -ForegroundColor Red
    }
}

# Enumerate based on target type
switch ($TargetType) {
    "User" {
        Write-Host "[*] Enumerating user objects..." -ForegroundColor Cyan
        try {
            $users = Get-DomainUser 2>$null
            foreach ($user in $users) {
                Test-ObjectACLs -ObjectDN $user.DistinguishedName -ObjectType "User" -ObjectName $user.SamAccountName
            }
        }
        catch {
            Write-Host "[-] Error enumerating users: $_" -ForegroundColor Red
        }
    }
    
    "Group" {
        Write-Host "[*] Enumerating group objects..." -ForegroundColor Cyan
        try {
            $groups = Get-DomainGroup 2>$null
            foreach ($group in $groups) {
                Test-ObjectACLs -ObjectDN $group.DistinguishedName -ObjectType "Group" -ObjectName $group.SamAccountName
            }
        }
        catch {
            Write-Host "[-] Error enumerating groups: $_" -ForegroundColor Red
        }
    }
    
    "Computer" {
        Write-Host "[*] Enumerating computer objects..." -ForegroundColor Cyan
        try {
            $computers = Get-DomainComputer 2>$null
            foreach ($computer in $computers) {
                Test-ObjectACLs -ObjectDN $computer.DistinguishedName -ObjectType "Computer" -ObjectName $computer.Name
            }
        }
        catch {
            Write-Host "[-] Error enumerating computers: $_" -ForegroundColor Red
        }
    }
    
    "GPO" {
        Write-Host "[*] Enumerating GPO objects..." -ForegroundColor Cyan
        try {
            $gpos = Get-NetGPO 2>$null
            foreach ($gpo in $gpos) {
                Test-ObjectACLs -ObjectDN $gpo.DistinguishedName -ObjectType "GPO" -ObjectName $gpo.Name
            }
        }
        catch {
            Write-Host "[-] Error enumerating GPOs: $_" -ForegroundColor Red
        }
    }
    
    "All" {
        Write-Host "[*] Enumerating all object types..." -ForegroundColor Cyan
        
        # Users
        try {
            $users = Get-DomainUser 2>$null
            foreach ($user in $users) {
                Test-ObjectACLs -ObjectDN $user.DistinguishedName -ObjectType "User" -ObjectName $user.SamAccountName
            }
        }
        catch { Write-Host "[-] Error with users: $_" -ForegroundColor Red }
        
        # Groups
        try {
            $groups = Get-DomainGroup 2>$null
            foreach ($group in $groups) {
                Test-ObjectACLs -ObjectDN $group.DistinguishedName -ObjectType "Group" -ObjectName $group.SamAccountName
            }
        }
        catch { Write-Host "[-] Error with groups: $_" -ForegroundColor Red }
        
        # Computers
        try {
            $computers = Get-DomainComputer 2>$null
            foreach ($computer in $computers) {
                Test-ObjectACLs -ObjectDN $computer.DistinguishedName -ObjectType "Computer" -ObjectName $computer.Name
            }
        }
        catch { Write-Host "[-] Error with computers: $_" -ForegroundColor Red }
        
        # GPOs
        try {
            $gpos = Get-NetGPO 2>$null
            foreach ($gpo in $gpos) {
                Test-ObjectACLs -ObjectDN $gpo.DistinguishedName -ObjectType "GPO" -ObjectName $gpo.Name
            }
        }
        catch { Write-Host "[-] Error with GPOs: $_" -ForegroundColor Red }
    }
}

# Export results
if ($results.Count -gt 0) {
    $results | ConvertTo-Json -Depth 10 | Out-File $OutputFile
    Write-Host "[+] Found $($results.Count) ACL entries. Results saved to $OutputFile" -ForegroundColor Green
} else {
    Write-Host "[-] No ACL entries found for $DomainUser" -ForegroundColor Yellow
}

# Summary of dangerous permissions
Write-Host "`n[*] Summary of dangerous permissions:" -ForegroundColor Cyan
$dangerous = $results | Where-Object { $_.Permission -match "GenericAll|GenericWrite|WriteProperty|WriteOwner|WriteDACL|ForceChangePassword" }
if ($dangerous) {
    $dangerous | Format-Table ObjectType, ObjectName, Permission -AutoSize
} else {
    Write-Host "[!] No dangerous permissions found" -ForegroundColor Yellow
}
