#!/usr/bin/env pwsh
# Find RDP Access Points
# Usage: ./find-rdp-access.ps1 -GroupName "External Users"

param(
    [Parameter(Mandatory=$true)]
    [string]$GroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$LocalGroup = "Remote Desktop Users"
)

Write-Host "[*] Finding computers where '$GroupName' has RDP access..."
Write-Host "[*] Local Group: $LocalGroup"
Write-Host ""

try {
    # Method 1: Using PowerView/AD module
    $results = Get-DomainGPOUserLocalGroupMapping -Identity $GroupName -LocalGroup $LocalGroup | 
               select -expand ComputerName
    
    if ($results) {
        Write-Host "[+] Found $($results.Count) computers:"
        $results | ForEach-Object { Write-Host "    - $_" }
    } else {
        Write-Host "[-] No computers found with this group in Remote Desktop Users"
    }
} catch {
    Write-Host "[!] Error: $_"
    Write-Host "[!] Try alternative method below:"
    Write-Host "    Find-DomainLocalGroupMember -GroupName 'Remote Desktop Users' | select -expand ComputerName"
}

Write-Host ""
Write-Host "[i] Next steps:"
Write-Host "    1. Compromise one of the listed machines"
Write-Host "    2. Monitor with 'net logons' for external user connections"
Write-Host "    3. Inject into RDP process when external user connects"
