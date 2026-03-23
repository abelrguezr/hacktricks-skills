#!/usr/bin/env pwsh
# Detect dynamicObject instances in Active Directory
# Usage: .\detect-dynamic-objects.ps1 -Server "dc.domain.local" -SearchBase "DC=domain,DC=local"

param(
    [Parameter(Mandatory=$false)]
    [string]$Server = $env:USERDNSDOMAIN,
    
    [Parameter(Mandatory=$false)]
    [string]$SearchBase = "DC=$($env:USERDNSDOMAIN)"
)

Write-Host "[*] Searching for dynamicObject instances in $SearchBase" -ForegroundColor Yellow

$ldapServer = "ldap://$Server"
$conn = New-Object System.DirectoryServices.Protocols.LdapConnection($ldapServer)
$conn.Bind()

$searchRequest = New-Object System.DirectoryServices.Protocols.SearchRequest(
    $SearchBase,
    "(objectClass=*)",
    [System.DirectoryServices.Protocols.SearchScope]::Subtree,
    "entryTTL,msDS-Entry-Time-To-Die,objectClass,distinguishedName,name"
)

try {
    $searchResult = $conn.SendRequest($searchRequest)
    
    $dynamicObjects = @()
    
    foreach ($entry in $searchResult.Entries) {
        if ($entry.Attributes.Contains("entryTTL")) {
            $entryTTL = $entry.Attributes["entryTTL"][0]
            $expiryTime = $null
            
            if ($entry.Attributes.Contains("msDS-Entry-Time-To-Die")) {
                $expiryTime = $entry.Attributes["msDS-Entry-Time-To-Die"][0]
            }
            
            $dynamicObjects += [PSCustomObject]@{
                DistinguishedName = $entry.Attributes["distinguishedName"][0]
                Name = $entry.Attributes["name"][0]
                ObjectClass = ($entry.Attributes["objectClass"][0] -join ", ")
                EntryTTL = $entryTTL
                ExpiryTime = $expiryTime
                TimeRemaining = $entryTTL
            }
        }
    }
    
    if ($dynamicObjects.Count -eq 0) {
        Write-Host "[!] No dynamicObject instances found" -ForegroundColor Yellow
    } else {
        Write-Host "[+] Found $($dynamicObjects.Count) dynamicObject instance(s):" -ForegroundColor Green
        $dynamicObjects | Format-Table -AutoSize
    }
    
} catch {
    Write-Host "[-] Search failed: $_" -ForegroundColor Red
}

$conn.Dispose()
