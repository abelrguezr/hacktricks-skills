#!/usr/bin/env pwsh
# Find orphan SIDs in Active Directory ACLs
# Usage: .\find-orphan-sids.ps1 -Server "dc.domain.local" -TargetDN "CN=AdminSDHolder,CN=System,DC=domain,DC=local"

param(
    [Parameter(Mandatory=$false)]
    [string]$Server = $env:USERDNSDOMAIN,
    
    [Parameter(Mandatory=$false)]
    [string]$TargetDN = "CN=AdminSDHolder,CN=System,DC=$($env:USERDNSDOMAIN)"
)

Write-Host "[*] Scanning for orphan SIDs in: $TargetDN" -ForegroundColor Yellow

try {
    $acl = Get-Acl -Path "AD:$TargetDN" -ErrorAction Stop
    
    $orphanSids = @()
    
    foreach ($access in $acl.Access) {
        $sid = $access.IdentityReference.Value
        
        # Try to resolve the SID
        try {
            $resolved = [System.Security.Principal.NTAccount]::new($sid)
            if ($resolved -eq $null -or $resolved.Value -eq $sid) {
                # SID couldn't be resolved to a name
                $orphanSids += [PSCustomObject]@{
                    SID = $sid
                    AccessType = $access.AccessControlType
                    FileSystemRights = $access.FileSystemRights
                    IsInherited = $access.IsInherited
                }
            }
        } catch {
            # SID resolution failed - likely orphan
            $orphanSids += [PSCustomObject]@{
                SID = $sid
                AccessType = $access.AccessControlType
                FileSystemRights = $access.FileSystemRights
                IsInherited = $access.IsInherited
            }
        }
    }
    
    if ($orphanSids.Count -eq 0) {
        Write-Host "[+] No orphan SIDs found" -ForegroundColor Green
    } else {
        Write-Host "[!] Found $($orphanSids.Count) orphan SID(s):" -ForegroundColor Red
        $orphanSids | Format-Table -AutoSize
    }
    
} catch {
    Write-Host "[-] Failed to scan ACL: $_" -ForegroundColor Red
}
