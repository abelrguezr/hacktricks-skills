#!/usr/bin/env pwsh
# Enumerate all dMSA objects and their attributes
# Usage: .\enumerate-dmsas.ps1 [-Domain domain.local]

param(
    [string]$Domain = $env:USERDNSDOMAIN
)

Write-Host "[*] Enumerating dMSA objects in domain: $Domain" -ForegroundColor Cyan

try {
    $searcher = New-Object System.DirectoryServices.DirectorySearcher
    $searcher.SearchRoot = [ADSI]"LDAP://$Domain"
    $searcher.Filter = "(objectClass=msDS-DelegatedManagedServiceAccount)"
    $searcher.SizeLimit = 1000
    
    $properties = @(
        'distinguishedname',
        'name',
        'msDS-DelegatedMSAState',
        'msDS-ManagedAccountPrecededByLink',
        'servicePrincipalName',
        'whenCreated',
        'whenChanged'
    )
    
    foreach ($prop in $properties) {
        $searcher.PropertiesToLoad.Add($prop) | Out-Null
    }
    
    $results = $searcher.FindAll()
    
    if ($results.Count -eq 0) {
        Write-Host "[!] No dMSA objects found" -ForegroundColor Yellow
        exit 0
    }
    
    Write-Host "[+] Found $($results.Count) dMSA objects:" -ForegroundColor Green
    Write-Host ""
    
    foreach ($result in $results) {
        Write-Host "=== $($result.Properties['name'][0]) ===" -ForegroundColor Cyan
        Write-Host "  DN: $($result.Properties['distinguishedname'][0])" -ForegroundColor Gray
        
        if ($result.Properties['msDS-DelegatedMSAState'].Count -gt 0) {
            $state = $result.Properties['msDS-DelegatedMSAState'][0]
            $stateText = switch ($state) {
                0 { "Not Migrated" }
                1 { "Migration In Progress" }
                2 { "Migration Completed" }
                default { "Unknown ($state)" }
            }
            Write-Host "  State: $stateText" -ForegroundColor Gray
        }
        
        if ($result.Properties['msDS-ManagedAccountPrecededByLink'].Count -gt 0) {
            $precededBy = $result.Properties['msDS-ManagedAccountPrecededByLink'][0]
            Write-Host "  PrecededBy: $precededBy" -ForegroundColor Yellow
        }
        
        if ($result.Properties['servicePrincipalName'].Count -gt 0) {
            Write-Host "  SPNs: $($result.Properties['servicePrincipalName'] -join ', ')" -ForegroundColor Gray
        }
        
        Write-Host ""
    }
    
} catch {
    Write-Host "[!] Error: $_" -ForegroundColor Red
    exit 1
}
