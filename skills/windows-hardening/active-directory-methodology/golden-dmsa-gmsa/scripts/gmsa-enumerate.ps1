#!/usr/bin/env pwsh
# Golden gMSA/dMSA Enumeration Script
# Usage: .\gmsa-enumerate.ps1 -Domain <domain.fqdn> [-OutputFile gmsa-enumeration.csv]

param(
    [Parameter(Mandatory=$true)]
    [string]$Domain,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputFile = "gmsa-enumeration.csv"
)

# Import Active Directory module
Import-Module ActiveDirectory -ErrorAction Stop

Write-Host "[*] Enumerating gMSA/dMSA objects in $Domain..." -ForegroundColor Cyan

try {
    # Query all service accounts with managed password ID
    $gmsas = Get-ADServiceAccount -Filter * -Properties msDS-ManagedPasswordId, objectSid, sAMAccountName -Server $Domain -ErrorAction Stop
    
    if ($gmsas.Count -eq 0) {
        Write-Host "[!] No gMSA/dMSA objects found in $Domain" -ForegroundColor Yellow
        exit 0
    }
    
    Write-Host "[*] Found $($gmsas.Count) managed service account(s)" -ForegroundColor Green
    
    # Format output
    $results = $gmsas | Select-Object @{
        Name = "sAMAccountName"
        Expression = { $_.sAMAccountName }
    }, @{
        Name = "objectSid"
        Expression = { $_.objectSid.Value }
    }, @{
        Name = "ManagedPasswordId"
        Expression = { $_.msDS-ManagedPasswordId }
    }
    
    # Export to CSV
    $results | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
    Write-Host "[*] Results saved to $OutputFile" -ForegroundColor Green
    
    # Display summary
    Write-Host "`n[+] gMSA/dMSA Summary:" -ForegroundColor Cyan
    $results | Format-Table -AutoSize
    
} catch {
    Write-Host "[!] Error: $_" -ForegroundColor Red
    exit 1
}
