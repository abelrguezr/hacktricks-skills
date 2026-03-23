#!/usr/bin/env pwsh
# Check if the environment supports dMSA objects (Windows Server 2025+)
# Usage: .\check-dmsa-support.ps1

param(
    [string]$Domain = $env:USERDNSDOMAIN
)

Write-Host "[*] Checking for dMSA support in domain: $Domain" -ForegroundColor Cyan

try {
    # Check for msDS-DelegatedManagedServiceAccount class
    $schema = [ADSI]"LDAP://CN=Schema,CN=Configuration,$Domain"
    $dmsaClass = $schema.Children | Where-Object { $_.Name -eq 'msDS-DelegatedManagedServiceAccount' }
    
    if ($dmsaClass) {
        Write-Host "[+] dMSA class found - Windows Server 2025+ detected" -ForegroundColor Green
    } else {
        Write-Host "[-] dMSA class not found - Windows Server 2025+ not detected" -ForegroundColor Red
        exit 1
    }
    
    # Check for existing dMSA objects
    $searcher = New-Object System.DirectoryServices.DirectorySearcher
    $searcher.SearchRoot = [ADSI]"LDAP://$Domain"
    $searcher.Filter = "(objectClass=msDS-DelegatedManagedServiceAccount)"
    $searcher.SizeLimit = 100
    
    $results = $searcher.FindAll()
    
    if ($results.Count -gt 0) {
        Write-Host "[+] Found $($results.Count) existing dMSA objects:" -ForegroundColor Green
        foreach ($result in $results) {
            Write-Host "    - $($result.Properties['distinguishedname'][0])" -ForegroundColor Gray
        }
    } else {
        Write-Host "[!] No existing dMSA objects found" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "[!] Error: $_" -ForegroundColor Red
    exit 1
}
