#!/usr/bin/env pwsh
# Create a dynamicObject in Active Directory
# Usage: .\create-dynamic-object.ps1 -Server "dc.domain.local" -DN "CN=test,CN=Users,DC=domain,DC=local" -ObjectClass "Computer" -TTL 3600

param(
    [Parameter(Mandatory=$true)]
    [string]$Server,
    
    [Parameter(Mandatory=$true)]
    [string]$DN,
    
    [Parameter(Mandatory=$true)]
    [string]$ObjectClass,
    
    [Parameter(Mandatory=$false)]
    [int]$TTL = 86400,
    
    [Parameter(Mandatory=$false)]
    [hashtable]$AdditionalAttributes = @{}
)

$ldapServer = "ldap://$Server"
$conn = New-Object System.DirectoryServices.Protocols.LdapConnection($ldapServer)
$conn.Bind()

$entry = New-Object System.DirectoryServices.Protocols.DirectoryEntry($DN)

# Add objectClass with dynamicObject
$objectClassAttr = New-Object System.DirectoryServices.Protocols.DirectoryAttribute("objectClass")
$objectClassAttr.Add("dynamicObject")
$objectClassAttr.Add($ObjectClass)
$conn.Attributes.Add($objectClassAttr)

# Set entryTTL
$ttlAttr = New-Object System.DirectoryServices.Protocols.DirectoryAttribute("entryTTL")
$ttlAttr.Add($TTL)
$conn.Attributes.Add($ttlAttr)

# Add any additional attributes
foreach ($key in $AdditionalAttributes.Keys) {
    $attr = New-Object System.DirectoryServices.Protocols.DirectoryAttribute($key)
    foreach ($value in $AdditionalAttributes[$key]) {
        $attr.Add($value)
    }
    $conn.Attributes.Add($attr)
}

# Send add request
$addRequest = New-Object System.DirectoryServices.Protocols.AddRequest($entry)
try {
    $result = $conn.SendRequest($addRequest)
    Write-Host "[+] Successfully created dynamic object: $DN" -ForegroundColor Green
    Write-Host "[+] TTL: $TTL seconds" -ForegroundColor Green
} catch {
    Write-Host "[-] Failed to create object: $_" -ForegroundColor Red
}

$conn.Dispose()
